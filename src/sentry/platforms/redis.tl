local transport = require("sentry.core.transport")

local record RedisTransport
   endpoint: string
   timeout: number
   headers: {string: string}
   redis_key: string
end

function RedisTransport:send(event: table): boolean, string
   local json = require("cjson")
   
   if not redis then
      return false, "Redis not available in this environment"
   end
   
   local body = json.encode(event)
   
   local success, err = pcall(function()
      redis.call("LPUSH", self.redis_key or "sentry:events", body)
      redis.call("LTRIM", self.redis_key or "sentry:events", 0, 999)
   end)
   
   if success then
      return true, "Event queued in Redis"
   else
      return false, "Redis error: " .. tostring(err)
   end
end

function RedisTransport:configure(config: table): transport.Transport
   self.endpoint = config.dsn or ""
   self.timeout = config.timeout or 30
   self.redis_key = config.redis_key or "sentry:events"
   self.headers = {
      ["Content-Type"] = "application/json",
      ["User-Agent"] = "sentry-lua-redis/0.0.1"
   }
   return self as transport.Transport
end

local function setup_redis_integration()
   return RedisTransport
end

return {
   setup_redis_integration = setup_redis_integration,
   RedisTransport = RedisTransport
}