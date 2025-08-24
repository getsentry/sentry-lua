-- default is: max
-- std = "lua51+lua52+lua53+lua54+luajit"

exclude_files = {
   ".luarocks/",
   ".git/",
}

files["spec/"] = {
   -- Allow using busted globals in test files
   globals = {
      "describe", "it", "before_each", "after_each", "setup", "teardown",
      "assert", "spy", "stub", "mock", "pending", "finally",
      "insulate", "expose",
   }
}

local love = { "love", }
files["**/love2d*"] = { globals = love }

local roblox = { "game", "DateTime", "task", "Instance", "getgenv", "shared", "Enum" }
files["**/roblox*"] = { globals = roblox }

local defold = { "http", }
files["**/defold*"] = { globals = defold }

local openresty = { "ngx", }
files["**/openresty*"] = { globals = openresty }

local platform_bootstrapper = {}
local n = 0
for _, t in ipairs{love, roblox, defold, openresty} do
    table.move(t, 1, #t, n + 1, platform_bootstrapper)
    n = n + #t
end

files["src/sentry/platforms/init.lua"] = { globals = platform_bootstrapper }

ignore = {
   "212", -- unused argument (common in callbacks)
   "213", -- unused loop variable (common in iterations)
}

max_line_length = 200
max_cyclomatic_complexity = 20