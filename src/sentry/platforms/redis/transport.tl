-- Redis transport for queuing events
local transport_utils = require("sentry.utils.transport")
local json = require("sentry.utils.json")
local version = require("sentry.version")

local record RedisTransport
   endpoint: string
   timeout: number
   headers: {string: string}
   redis_key: string
end

function RedisTransport:send(event: table): boolean, string
   if not _G.redis then
      return false, "Redis not available in this environment"
   end
   
   local body = json.encode(event)
   
   local success, err = pcall(function()
      (_G.redis as any).call("LPUSH", self.redis_key or "sentry:events", body)
      (_G.redis as any).call("LTRIM", self.redis_key or "sentry:events", 0, 999)
   end)
   
   if success then
      return true, "Event queued in Redis"
   else
      return false, "Redis error: " .. tostring(err)
   end
end

function RedisTransport:configure(config: table): transport_utils.Transport
   self.endpoint = (config as any).dsn or ""
   self.timeout = (config as any).timeout or 30
   self.redis_key = (config as any).redis_key or "sentry:events"
   self.headers = {
      ["Content-Type"] = "application/json",
      ["User-Agent"] = "sentry-lua-redis/" .. version
   }
   return self as transport_utils.Transport
end

-- Create factory function
local function create_redis_transport(config: table): transport_utils.Transport
   local transport = RedisTransport
   return transport:configure(config)
end

-- Check if redis transport is available
local function is_redis_available(): boolean
   return _G.redis ~= nil
end

-- Register this transport factory with medium priority
transport_utils.register_transport_factory({
   name = "redis",
   priority = 150, -- Medium priority for Redis environments
   create = create_redis_transport,
   is_available = is_redis_available
})

return {
   RedisTransport = RedisTransport,
   create_redis_transport = create_redis_transport,
   is_redis_available = is_redis_available
}