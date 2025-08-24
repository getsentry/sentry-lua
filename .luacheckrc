-- Luacheck configuration file

-- Standard library compatibility
std = "lua51+lua52+lua53+lua54+luajit"

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

files["**/love2d*"] = {
   globals = {
      "love",
   }
}

files["**/roblox*"] = {
   globals = {
      "game", "DateTime", "task", "Instance", "getgenv", "shared", "Enum"
   }
}

ignore = {
   "212", -- unused argument (common in callbacks)
   "213", -- unused loop variable (common in iterations)
}

max_line_length = 160
max_cyclomatic_complexity = 20