package = "sentry"
version = "0.0.2-1"
source = {
   url = "git+https://github.com/getsentry/sentry-lua.git"
}
description = {
   summary = "Sentry SDK for Lua - Platform agnostic error tracking",
   detailed = [[
      A comprehensive Sentry SDK for Lua that works across multiple platforms
      including Redis, nginx, Roblox, Defold and other game engines and standard Lua environments.
      Written in Teal Language for better type safety and developer experience.
   ]],
   license = "MIT",
   homepage = "https://github.com/getsentry/sentry-lua"
}
dependencies = {
   "lua >= 5.1",
   "lua-cjson >= 2.1.0"
}
build = {
   type = "builtin",
   modules = {
      -- Main module
      ["sentry"] = "build/sentry/init.lua",
      ["sentry.init"] = "build/sentry/init.lua",
      
      -- Core modules
      ["sentry.core.auto_transport"] = "build/sentry/core/auto_transport.lua",
      ["sentry.core.client"] = "build/sentry/core/client.lua",
      ["sentry.core.context"] = "build/sentry/core/context.lua",
      ["sentry.core.file_io"] = "build/sentry/core/file_io.lua",
      ["sentry.core.file_transport"] = "build/sentry/core/file_transport.lua",
      ["sentry.core.scope"] = "build/sentry/core/scope.lua",
      ["sentry.core.test_transport"] = "build/sentry/core/test_transport.lua",
      ["sentry.core.transport"] = "build/sentry/core/transport.lua",
      
      -- Logger
      ["sentry.logger"] = "build/sentry/logger/init.lua",
      
      -- Performance/Tracing
      ["sentry.performance"] = "build/sentry/performance/init.lua",
      ["sentry.tracing"] = "build/sentry/tracing/init.lua",
      ["sentry.tracing.headers"] = "build/sentry/tracing/headers.lua",
      ["sentry.tracing.propagation"] = "build/sentry/tracing/propagation.lua",
      
      -- Platform loader
      ["sentry.platform_loader"] = "build/sentry/platform_loader.lua",
      
      -- Platform-specific modules
      ["sentry.platforms.defold.file_io"] = "build/sentry/platforms/defold/file_io.lua",
      ["sentry.platforms.defold.transport"] = "build/sentry/platforms/defold/transport.lua",
      ["sentry.platforms.love2d.context"] = "build/sentry/platforms/love2d/context.lua",
      ["sentry.platforms.love2d.os_detection"] = "build/sentry/platforms/love2d/os_detection.lua",
      ["sentry.platforms.love2d.transport"] = "build/sentry/platforms/love2d/transport.lua",
      ["sentry.platforms.nginx.os_detection"] = "build/sentry/platforms/nginx/os_detection.lua",
      ["sentry.platforms.nginx.transport"] = "build/sentry/platforms/nginx/transport.lua",
      ["sentry.platforms.redis.transport"] = "build/sentry/platforms/redis/transport.lua",
      ["sentry.platforms.roblox.context"] = "build/sentry/platforms/roblox/context.lua",
      ["sentry.platforms.roblox.file_io"] = "build/sentry/platforms/roblox/file_io.lua",
      ["sentry.platforms.roblox.os_detection"] = "build/sentry/platforms/roblox/os_detection.lua",
      ["sentry.platforms.roblox.transport"] = "build/sentry/platforms/roblox/transport.lua",
      ["sentry.platforms.standard.file_transport"] = "build/sentry/platforms/standard/file_transport.lua",
      ["sentry.platforms.standard.os_detection"] = "build/sentry/platforms/standard/os_detection.lua",
      ["sentry.platforms.standard.transport"] = "build/sentry/platforms/standard/transport.lua",
      ["sentry.platforms.test.transport"] = "build/sentry/platforms/test/transport.lua",
      
      -- Types and utilities
      ["sentry.types"] = "build/sentry/types.lua",
      ["sentry.utils"] = "build/sentry/utils.lua",
      ["sentry.utils.dsn"] = "build/sentry/utils/dsn.lua",
      ["sentry.utils.envelope"] = "build/sentry/utils/envelope.lua",
      ["sentry.utils.http"] = "build/sentry/utils/http.lua",
      ["sentry.utils.json"] = "build/sentry/utils/json.lua",
      ["sentry.utils.os"] = "build/sentry/utils/os.lua",
      ["sentry.utils.runtime"] = "build/sentry/utils/runtime.lua",
      ["sentry.utils.serialize"] = "build/sentry/utils/serialize.lua",
      ["sentry.utils.stacktrace"] = "build/sentry/utils/stacktrace.lua",
      ["sentry.utils.transport"] = "build/sentry/utils/transport.lua",
      
      -- Version
      ["sentry.version"] = "build/sentry/version.lua"
   }
}




