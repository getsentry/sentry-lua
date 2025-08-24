rockspec_format = "3.0"
package = "sentry"
version = "0.0.7-1"
source = {
   url = "git+https://github.com/getsentry/sentry-lua.git",
   tag = "0.0.7"
}
description = {
   summary = "Sentry SDK for Lua",
   detailed = [[
      A Sentry SDK for Lua focus on portability
   ]],
   homepage = "https://github.com/getsentry/sentry-lua",
   license = "MIT"
}
dependencies = {
   "lua >= 5.1",
   "luasocket >= 3.0",
   "luasec >= 1.0",
}
test_dependencies = {
   "luacheck >= 0.23.0",
}
build = {
  type = "builtin",
  modules = {
    ["sentry"] = "src/sentry/init.lua",
  }
}