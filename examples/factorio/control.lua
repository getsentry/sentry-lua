-- Example Factorio mod using Sentry (control.lua).
--
-- Factorio mods are sandboxed (no HTTP). Events are spooled to script-output via
-- a file-backed provider and delivered later by the companion uploader.

local sentry = require("sentry")
local factorio = require("sentry.platforms.factorio.integration")
local persistence = require("sentry.core.persistence")

-- A minimal PersistenceProvider backed by Factorio's helpers.write_file, which
-- writes into the script-output directory.
local function script_output_provider(path)
   local lines = {}
   return {
      append = function(env)
         table.insert(lines, (env:gsub("\n", "\\n")))
         helpers.write_file(path, table.concat(lines, "\n") .. "\n", false)
         return true, ""
      end,
      read_all = function() return lines end,
      clear = function() lines = {}; helpers.write_file(path, "", false) end,
      size = function() return #lines end,
   }
end

sentry.init({
   dsn = "https://your-key@your-org.ingest.sentry.io/your-project",
   release = "my-mod@0.4.2",
   spool = true,
   persistence_provider = script_output_provider("sentry/spool.envelopes"),
   -- Attaches the Factorio version and the full active-mod list with versions.
   integrations = { factorio.integration() },
})

-- Wrap event handlers so errors are captured (Factorio has no global hook).
local function guarded(handler)
   return function(event)
      local ok, err = pcall(handler, event)
      if not ok then
         sentry.capture_exception(err)
      end
   end
end

script.on_event(defines.events.on_tick, guarded(function(_event)
   -- ... mod logic ...
end))
