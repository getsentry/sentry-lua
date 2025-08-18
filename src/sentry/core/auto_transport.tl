local transport = require("sentry.core.transport")
local file_io = require("sentry.core.file_io")
local FileTransport = require("sentry.core.file_transport")

local function detect_platform(): string
   if game and game.GetService then
      return "roblox"
   elseif ngx and ngx.say then
      return "nginx"
   elseif redis and redis.call then
      return "redis"
   elseif love and love.graphics then
      return "love2d"
   elseif sys and sys.get_save_file then
      return "defold"
   elseif _G.corona then
      return "solar2d"
   else
      return "standard"
   end
end

local function create_auto_transport(config: table): any
   local platform = detect_platform()
   
   if platform == "roblox" then
      local roblox_integration = require("sentry.integrations.roblox")
      local RobloxTransport = roblox_integration.setup_roblox_integration()
      return RobloxTransport:configure(config)
   
   elseif platform == "nginx" then
      local nginx_integration = require("sentry.integrations.nginx")
      local NginxTransport = nginx_integration.setup_nginx_integration()
      return NginxTransport:configure(config)
   
   elseif platform == "redis" then
      local redis_integration = require("sentry.integrations.redis")
      local RedisTransport = redis_integration.setup_redis_integration()
      return RedisTransport:configure(config)
   
   elseif platform == "love2d" then
      local love2d_integration = require("sentry.integrations.love2d")
      local Love2DTransport = love2d_integration.setup_love2d_integration()
      return Love2DTransport:configure(config)
   
   elseif platform == "defold" then
      local defold_file_io = require("sentry.integrations.defold_file_io")
      local file_transport = FileTransport:configure({
         dsn = (config as any).dsn,
         file_path = "defold-sentry.log",
         file_io = defold_file_io.create_defold_file_io()
      })
      return file_transport
   
   else
      local HttpTransport = transport.HttpTransport
      return HttpTransport:configure(config)
   end
end

return {
   detect_platform = detect_platform,
   create_auto_transport = create_auto_transport
}