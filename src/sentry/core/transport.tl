-- Platform-agnostic transport interface
-- Load all platform-specific transport implementations
require("sentry.platforms.standard.transport")
require("sentry.platforms.standard.file_transport")
require("sentry.platforms.roblox.transport")
require("sentry.platforms.love2d.transport")
require("sentry.platforms.nginx.transport")
require("sentry.platforms.redis.transport")
require("sentry.platforms.defold.transport")
require("sentry.platforms.test.transport")

-- Re-export transport utilities
local transport_utils = require("sentry.utils.transport")

return {
   Transport = transport_utils.Transport,
   create_transport = transport_utils.create_transport,
   get_available_transports = transport_utils.get_available_transports,
   register_transport_factory = transport_utils.register_transport_factory
}