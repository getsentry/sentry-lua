-- Redis transport: queues serialized envelopes on a Redis list for a companion
-- uploader/relay to drain. Used inside Redis Lua scripting (no outbound HTTP).
local transport_utils = require("sentry.utils.transport")
local version = require("sentry.version")

local record RedisTransport
   endpoint: string
   timeout: number
   headers: {string: string}
   redis_key: string
   max_queue: number
end

function RedisTransport:send_envelope(payload: string, _categories: {string}): boolean, string
   if not _G.redis then
      return false, "Redis not available in this environment"
   end

   local success, err = pcall(function()
      (_G.redis as any).call("LPUSH", self.redis_key, payload)
      (_G.redis as any).call("LTRIM", self.redis_key, 0, self.max_queue - 1)
   end)

   if success then
      return true, "Envelope queued in Redis"
   end
   return false, "Redis error: " .. tostring(err)
end

function RedisTransport:configure(config: table): transport_utils.Transport
   self.endpoint = (config as any).dsn or ""
   self.timeout = (config as any).timeout or 30
   self.redis_key = (config as any).redis_key or "sentry:envelopes"
   self.max_queue = (config as any).max_queue or 1000
   self.headers = {
      ["Content-Type"] = "application/x-sentry-envelope",
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
