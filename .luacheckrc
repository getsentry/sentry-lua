-- Luacheck configuration file

-- Standard library compatibility
std = "lua51+lua52+lua53+lua54"

-- Files and directories to exclude from checking
exclude_files = {
   ".luarocks/",
   ".git/",
}

-- Per-directory configuration
files["spec/"] = {
   -- Allow using busted globals in test files
   globals = {
      "describe", "it", "before_each", "after_each", "setup", "teardown",
      "assert", "spy", "stub", "mock", "pending", "finally",
      "insulate", "expose",
   }
}

-- Ignore certain warnings
ignore = {
   "212", -- unused argument (common in callbacks)
   "213", -- unused loop variable (common in iterations)
}

-- Maximum line length
max_line_length = 120

-- Maximum cyclomatic complexity
max_cyclomatic_complexity = 12