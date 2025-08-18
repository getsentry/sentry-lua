package = "sentry-lua"
version = "0.0.1-1"
source = {
   url = "git+https://github.com/bruno-garcia/sentry-lua.git"
}
description = {
   summary = "Sentry SDK for Lua - Platform agnostic error tracking",
   detailed = [[
      A comprehensive Sentry SDK for Lua that works across multiple platforms
      including Redis, nginx, Roblox, Defold and other game engines and standard Lua environments.
      Written in Teal Language for better type safety and developer experience.
   ]],
   license = "MIT",
   homepage = "https://github.com/bruno-garcia/sentry-lua"
}
dependencies = {
   "lua >= 5.1",
   "lua-cjson",
   "luasocket"
}
build = {
   type = "builtin",
   modules = {
      ["sentry.init"] = "build/sentry/init.lua",
      ["sentry.core.client"] = "build/sentry/core/client.lua",
      ["sentry.core.transport"] = "build/sentry/core/transport.lua",
      ["sentry.core.context"] = "build/sentry/core/context.lua",
      ["sentry.utils.stacktrace"] = "build/sentry/utils/stacktrace.lua",
      ["sentry.utils.serialize"] = "build/sentry/utils/serialize.lua"
   }
}


