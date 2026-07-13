-- Sentry inside Redis Lua scripting.
--
-- When running inside Redis (the `redis` global is present), the SDK
-- automatically selects the Redis transport, which LPUSHes serialized Sentry
-- envelopes onto a list for a companion uploader to deliver out-of-band.
local sentry = require("sentry.init")

sentry.init({
   dsn = "https://your-dsn@sentry.io/project-id",
   environment = "redis",
   redis_key = "sentry:envelopes",  -- Redis list that receives envelopes
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
