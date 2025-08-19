local sentry = require("sentry.init")
local redis_integration = require("sentry.integrations.redis")

-- Initialize Sentry with Redis transport
local RedisTransport = redis_integration.setup_redis_integration()

sentry.init({
   dsn = "https://your-dsn@sentry.io/project-id",
   environment = "redis",
   transport = RedisTransport,
   redis_key = "sentry:events"
})

-- Redis-specific context
sentry.set_tag("platform", "redis")
sentry.set_extra("redis_version", "7.0")

-- Simulate Redis script execution
sentry.add_breadcrumb({
   message = "Redis script started",
   category = "redis",
   level = "info"
})

-- Capture events that will be queued in Redis
sentry.capture_message("Redis script executed successfully", "info")

-- Example of error in Redis context
local success, err = pcall(function()
   -- Simulate Redis operation error
   redis.call("INVALID_COMMAND")
end)

if not success then
   sentry.capture_exception({
      type = "RedisError",
      message = err
   })
end