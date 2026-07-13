#!/usr/bin/env lua
-- Amalgamate the built SDK (build/sentry/**.lua) into a single-file bundle for
-- sandboxed platforms (WoW addons, Factorio mods, Roblox) that lack require()
-- and luarocks. Each module is registered in a preload table, resolved by a
-- self-contained `require` shim prepended to the bundle.
--
-- The shim matters: WoW's Lua 5.1 removes BOTH `package` and `require`, so a
-- bundle that assumed either would error on its first line in-game. The shim
-- declares local `require`/`package` that shadow the globals for the whole
-- single-chunk bundle, seeding from the host's `package.preload` when it exists
-- (standard Lua, Factorio, Roblox) and falling back to the host `require` for
-- anything not bundled (e.g. optional compat53) — all inside a pcall at the call
-- sites, so absence degrades gracefully.
--
-- Usage: lua scripts/bundle.lua [output.lua]   (default: dist/sentry-bundle.lua)

local build_dir = "build/sentry"
local out_path = arg[1] or "dist/sentry-bundle.lua"

-- Ensure output directory exists.
local out_dir = out_path:match("^(.*)/[^/]+$")
if out_dir then
   os.execute('mkdir -p "' .. out_dir .. '" 2>/dev/null')
end

-- Collect built module files (deterministic order).
local files = {}
local pipe = assert(io.popen('find "' .. build_dir .. '" -name "*.lua" -type f | sort'))
for line in pipe:lines() do
   files[#files + 1] = line
end
pipe:close()

if #files == 0 then
   io.stderr:write("No built modules found in " .. build_dir .. " (run the build first)\n")
   os.exit(1)
end

-- build/sentry/logger/init.lua -> "sentry.logger"; build/sentry/utils/json.lua -> "sentry.utils.json"
local function module_name(path)
   local rel = path:gsub("^build/", ""):gsub("%.lua$", "")
   rel = rel:gsub("/init$", "")
   return (rel:gsub("/", "."))
end

local out = assert(io.open(out_path, "w"))
out:write("-- Sentry Lua SDK - single-file bundle (generated, do not edit).\n")
out:write("-- Regenerate with: make bundle\n")
out:write("-- Self-contained: runs in sandboxes without require()/package (e.g. WoW addons).\n\n")

-- Self-contained module system. These locals shadow the globals for every
-- module registration and body below (single chunk), so the bundle never
-- depends on the host providing `package` or `require` (WoW strips both).
out:write([[
local _real_require = require
local _preload = (package and package.preload) or {}
local _loaded = {}
local function require(name)
   local m = _loaded[name]
   if m ~= nil then return m end
   local loader = _preload[name]
   if loader then
      m = loader(name)
      if m == nil then m = true end
      _loaded[name] = m
      return m
   end
   if _real_require then return _real_require(name) end
   error("module '" .. tostring(name) .. "' not found", 2)
end
local package = package or {}
package.preload = _preload

]])

for _, f in ipairs(files) do
   local name = module_name(f)
   local fh = assert(io.open(f, "r"))
   local body = fh:read("*a")
   fh:close()
   out:write('package.preload["' .. name .. '"] = function(...)\n')
   out:write(body)
   out:write("\nend\n\n")
end

-- Expose the entry module three ways so every host can reach it:
--   • `return sentry`                 — require()-based hosts (standard, Factorio)
--   • `sentry.require`                — reach bundled sub-modules (platform
--                                       integrations) where the host has no require
--   • WoW addon-table handoff (`...`) — a .toc file gets (addonName, addonTable);
--                                       stash Sentry there since .toc chunks share
--                                       neither locals nor return values.
out:write([[
local sentry = require("sentry")
sentry.require = require
local _addon_name, _addon_table = ...
if type(_addon_table) == "table" then _addon_table.Sentry = sentry end
return sentry
]])
out:close()

print("Wrote " .. out_path .. " (" .. #files .. " modules)")
