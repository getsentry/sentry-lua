local redis = require("redis")
local sentry = require("sentry.init")

print("=== Testing Sentry SDK with Redis Lua Scripts ===")

-- Connect to Redis
local client = redis.connect("redis", 6379)
if not client then
   print("❌ Failed to connect to Redis")
   os.exit(1)
end

print("✓ Connected to Redis")

-- Initialize Sentry
local sentry_client = sentry.init({
   dsn = "https://e247e6e48f8f482499052a65adaa9f6b@o117736.ingest.us.sentry.io/4504930623356928",
   environment = "docker-redis-test",
   debug = true
})

print("✓ Sentry initialized")

-- Set tags and context
sentry.set_tag("platform", "redis")
sentry.set_tag("test_type", "lua_script")
sentry.set_extra("redis_info", "Docker test with Lua scripts")

sentry.add_breadcrumb({
   message = "Redis connection established",
   category = "redis",
   level = "info"
})

-- Test 1: Basic Redis operations with Sentry tracking
print("\n--- Test 1: Basic Redis Operations ---")
sentry.add_breadcrumb({
   message = "Starting basic Redis operations test",
   category = "test",
   level = "info"
})

client:set("test:key", "hello_redis")
local value = client:get("test:key")
print("✓ SET/GET test: " .. (value or "nil"))

-- Test 2: Load and execute a Lua script in Redis
print("\n--- Test 2: Redis Lua Script Execution ---")
sentry.add_breadcrumb({
   message = "Loading Lua script into Redis",
   category = "redis",
   level = "info"
})

-- Lua script that increments a counter and logs activity
local lua_script = [[
    local key = KEYS[1]
    local increment = tonumber(ARGV[1]) or 1
    local current = redis.call('GET', key)
    
    if not current then
        current = 0
    else
        current = tonumber(current)
    end
    
    local new_value = current + increment
    redis.call('SET', key, new_value)
    
    -- Log the operation
    local log_key = key .. ':log'
    redis.call('LPUSH', log_key, 'Incremented from ' .. current .. ' to ' .. new_value)
    redis.call('EXPIRE', log_key, 300) -- Expire after 5 minutes
    
    return {new_value, current}
]]

-- Load the script and get its SHA1 hash
local script_sha = client:script_load(lua_script)
print("✓ Lua script loaded: " .. script_sha)

-- Execute the script multiple times
for i = 1, 5 do
    local result = client:evalsha(script_sha, 1, "test:counter", i)
    print("  Execution " .. i .. ": counter = " .. result[1] .. " (was " .. result[2] .. ")")
    
    sentry.add_breadcrumb({
       message = "Script execution " .. i .. " completed",
       category = "redis",
       level = "debug",
       data = {
           counter_value = result[1],
           increment = i
       }
    })
end

-- Check the log entries
local logs = client:lrange("test:counter:log", 0, -1)
print("✓ Script execution log:")
for i, log_entry in ipairs(logs) do
    print("  " .. i .. ". " .. log_entry)
end

-- Test 3: Error handling in Redis Lua script
print("\n--- Test 3: Error Handling in Lua Scripts ---")
local error_script = [[
    local key = KEYS[1]
    if key == "error" then
        error("Intentional error in Lua script")
    end
    return "success"
]]

local error_script_sha = client:script_load(error_script)

-- Test successful execution
local success_result = client:evalsha(error_script_sha, 1, "success")
print("✓ Success case: " .. success_result)

-- Test error case with Sentry error capture
local success, err = pcall(function()
    return client:evalsha(error_script_sha, 1, "error")
end)

if not success then
    print("✓ Caught Redis Lua script error: " .. err)
    local exception_id = sentry.capture_exception({
        type = "RedisLuaScriptError",
        message = "Redis Lua script execution failed: " .. err
    })
    print("✓ Exception sent to Sentry: " .. exception_id)
end

-- Test 4: Complex Redis operations with transaction
print("\n--- Test 4: Complex Operations with Transaction ---")
sentry.add_breadcrumb({
   message = "Starting Redis transaction test",
   category = "redis",
   level = "info"
})

-- Multi-operation Lua script (atomic transaction)
local transaction_script = [[
    local user_key = KEYS[1]
    local session_key = KEYS[2]
    local user_data = ARGV[1]
    local session_id = ARGV[2]
    
    -- Set user data
    redis.call('HSET', user_key, 'data', user_data, 'last_seen', ARGV[3])
    
    -- Create session
    redis.call('SET', session_key, session_id)
    redis.call('EXPIRE', session_key, 3600) -- 1 hour
    
    -- Update activity counter
    local activity_key = 'activity:' .. ARGV[4]
    local count = redis.call('INCR', activity_key)
    
    return {
        redis.call('HGETALL', user_key),
        redis.call('GET', session_key),
        count
    }
]]

local tx_script_sha = client:script_load(transaction_script)
local timestamp = os.time()
local result = client:evalsha(tx_script_sha, 2, 
    "user:123", "session:abc", 
    "test_user_data", "session_abc_123", timestamp, "daily")

print("✓ Transaction completed:")
print("  User data: " .. table.concat(result[1], ", "))
print("  Session: " .. result[2])
print("  Activity count: " .. result[3])

-- Clean up
client:del("test:key", "test:counter", "test:counter:log", "user:123", "session:abc", "activity:daily")
print("✓ Cleanup completed")

-- Final Sentry message
local final_event_id = sentry.capture_message("Redis Lua script integration test completed successfully!", "info")
print("\n✓ Final test report sent to Sentry: " .. final_event_id)

-- Test general Sentry error handling
local success, err = pcall(function()
   error("Test error for stack trace verification")
end)

if not success then
   local exception_id = sentry.capture_exception({
      type = "TestError", 
      message = err,
      extra = {
          test_phase = "final_error_test",
          redis_connected = true
      }
   })
   print("✓ Test exception captured: " .. exception_id)
end

print("\n=== All Redis + Sentry integration tests completed successfully! ===")

-- Close Redis connection
client:quit()