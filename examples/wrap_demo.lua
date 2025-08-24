-- Demonstration of sentry.wrap() for automatic error capture
-- This shows the recommended way to automatically capture unhandled errors

package.path = "src/?.lua;src/?/init.lua;" .. package.path
local sentry = require("sentry.init")

-- Initialize Sentry
sentry.init({
  dsn = "https://e247e6e48f8f482499052a65adaa9f6b@o117736.ingest.us.sentry.io/4504930623356928",
  environment = "demo",
  release = "wrap-demo@1.0",
  debug = true,
})

-- Set up context that will be included with any captured errors
sentry.set_user({
  id = "wrap-demo-user",
  username = "error_demo",
})

sentry.set_tag("demo_type", "wrap_function")

-- Define your main application logic with parameters for stack trace visibility
local function process_database_config(environment, service_name, retry_count)
  local config = nil -- Simulate missing configuration
  local timeout_ms = 5000
  local connection_pool_size = 10

  -- This will cause an error that gets automatically captured
  local db_url = config.database_url -- Error: attempt to index nil
  return db_url .. "?timeout=" .. timeout_ms .. "&pool=" .. connection_pool_size
end

local function validate_user_permissions(user_id, action_type, resource_id)
  -- Process permissions validation
  return process_database_config("production", "user_service", 3)
end

local function main(app_version, startup_mode)
  print("=== Sentry.wrap() Demo === (v" .. app_version .. ", mode: " .. startup_mode .. ")")
  -- Add some context
  sentry.add_breadcrumb({
    message = "Application started",
    category = "lifecycle",
    level = "info",
  })

  print("1. Setting up user data...")
  local users = { "alice", "bob", "charlie" }

  print("2. Processing payments...")
  sentry.add_breadcrumb({
    message = "Starting payment processing",
    category = "business",
    level = "info",
  })

  -- Simulate some successful operations
  for i, user in ipairs(users) do
    local amount = 100 * i
    print("   Processing payment for:", user, "($" .. amount .. ")")
    sentry.add_breadcrumb({
      message = "Payment processed",
      category = "payment",
      level = "info",
      data = { user = user, amount = amount },
    })
  end

  print("3. Validating user permissions...")
  -- This will ultimately cause an error through the call chain
  local result = validate_user_permissions("user_12345", "database_write", "config_table")

  print("This line should never be reached:", result)
end

-- Method 1: Simple wrap - Errors terminate the program but get sent to Sentry
print("\n=== Method 1: Simple Wrap ===")
local success, result = sentry.wrap(function() main("2.1.4", "production") end)

if success then
  print("✓ Program completed successfully")
else
  print("✗ Program failed but error was captured in Sentry")
  print("Error:", result)
end

print("\n=== Method 2: Custom Error Handler ===")

-- Method 2: Custom error handler - You can handle errors gracefully
local function attempt_risky_operation(operation_id, max_retries, timeout_seconds)
  local cache_key = "op_" .. operation_id
  print("Attempting risky operation (ID: " .. operation_id .. ", retries: " .. max_retries .. ")...")

  local risky_data = nil
  return risky_data.missing_field .. " cached as " .. cache_key -- This will error
end

local function main_with_recovery() return attempt_risky_operation("op_789", 5, 30) end

local function custom_error_handler(err)
  local error_id = "err_" .. math.random(10000, 99999)
  local timestamp = os.date("%Y-%m-%d %H:%M:%S")

  print("Custom handler: Caught error [" .. error_id .. " at " .. timestamp .. "]:", err)
  print("Custom handler: Performing cleanup...")
  -- You could do cleanup, logging, etc. here
  return "Handled gracefully (error ID: " .. error_id .. ")"
end

local success2, result2 = sentry.wrap(main_with_recovery, custom_error_handler)

if success2 then
  print("✓ Program handled error gracefully")
  print("Result:", result2)
else
  print("✗ Even custom handler couldn't save us")
  print("Error:", result2)
end

print("\n=== Comparison with Manual Approach ===")

-- Show equivalent manual approach for comparison
local function manual_error_simulation(task_name, priority_level)
  local task_id = "task_" .. math.random(100, 999)
  error("Manual error handling for " .. task_name .. " (priority: " .. priority_level .. ", task: " .. task_id .. ")")
end

local function manual_approach()
  return xpcall(function() manual_error_simulation("data_processing", "high") end, function(err)
    sentry.capture_exception({
      type = "ManualError",
      message = tostring(err),
    })
    return err
  end)
end

local manual_success, manual_result = manual_approach()
print("Manual approach - Success:", manual_success, "Result:", manual_result)

sentry.close()

print("\n=== Summary ===")
print("• sentry.wrap(main_function) - Simple automatic error capture")
print("• sentry.wrap(main_function, error_handler) - Custom error handling")
print("• All Sentry context (user, tags, breadcrumbs) is automatically included")
print("• Much simpler than manually wrapping every error-prone operation")
