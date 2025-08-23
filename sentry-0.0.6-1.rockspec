rockspec_format = "3.0"
package = "sdk"
version = "0.0.6-1"
source = {
   url = "git+https://github.com/getsentry/sentry-lua.git",
   tag = "0.0.6"
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
   "luasocket"
}
build = {
   type = "command",
}