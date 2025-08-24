package.path = "src/?/init.lua;" .. package.path
local sentry = require("sentry")

-- Initialize Sentry with your DSN
sentry.init({
   dsn = "https://e247e6e48f8f482499052a65adaa9f6b@o117736.ingest.us.sentry.io/4504930623356928",
   environment = "production",
   release = "wrap-demo@1.0",
   debug = true,
})

-- Set user context
sentry.set_user({
   id = "user123",
   email = "user@example.com",
   username = "testuser"
})

-- Add tags for filtering
sentry.set_tag("server", "web-1")
sentry.set_tag("feature", "checkout")

-- Add extra context
sentry.set_extra("session_id", "abc123")
sentry.set_extra("request_id", "req456")

-- Add breadcrumbs for debugging context
sentry.add_breadcrumb({
   message = "User started checkout process",
   category = "navigation",
   level = "info"
})

-- Helper functions to create deeper stack traces with parameters
local function send_confirmation_email(user_email, order_id, amount)
   sentry.capture_message("Purchase confirmation sent to " .. user_email .. " for order #" .. order_id, "info")
end

local function process_payment(payment_method, amount, currency)
   local order_id = "ORD-" .. math.random(1000, 9999)
   send_confirmation_email("customer@example.com", order_id, amount)
end

local function validate_cart(items_count, total_price)
   if items_count > 0 then
      process_payment("credit_card", total_price, "USD")
   end
end

local function checkout_handler(user_id, session_token)
   local cart_items = 3
   local total = 149.99
   validate_cart(cart_items, total)
end

-- Capture a message with multiple stack frames and parameters
checkout_handler("user_12345", "sess_abcdef123456")

-- Functions that demonstrate common Lua pitfalls and errors

-- Common pitfall: Using 0-based indexing (Lua uses 1-based)
local function array_access_error(department, min_users_required)
   local users = {"alice", "bob", "charlie"}
   local debug_info = "Checking " .. department .. " (need " .. min_users_required .. " users)"

   -- This will access nil (common mistake from other languages)
   local first_user = users[0]  -- Should be users[1]

   -- This will cause an error when trying to use nil
   return string.upper(first_user) .. " in " .. debug_info
end

-- Common pitfall: Using + for string concatenation instead of ..
local function string_concat_error(greeting_type, username, user_id)
   local timestamp = os.time()
   local session_id = "sess_" .. math.random(1000, 9999)

   -- Wrong: using + instead of .. for concatenation
   local message = greeting_type + " " + username + " (ID: " + user_id + ") at " + timestamp
   return message .. " session: " .. session_id
end

-- Common pitfall: Calling methods on nil values
local function nil_method_call(service_name, environment)
   local config = nil  -- Simulate missing configuration
   local default_timeout = 30

   -- This will error: attempt to index a nil value
   local timeout = config.timeout or default_timeout
   return "Service " .. service_name .. " (" .. environment .. ") timeout: " .. timeout
end

-- Common pitfall: Incorrect table iteration
local function table_iteration_error(record_type, max_items)
   local data = {name = "test_record", value = 42, priority = "high"}
   local result = ""
   local processed_count = 0

   -- Wrong: using ipairs on a hash table (should use pairs)
   for i, v in ipairs(data) do
      result = result .. tostring(v)
      processed_count = processed_count + 1
   end

   return record_type .. ": processed " .. processed_count .. "/" .. max_items .. " -> " .. result
end

-- Demonstrate each error type with proper context
sentry.add_breadcrumb({
   message = "Starting error demonstration",
   category = "demo",
   level = "info"
})

-- Test array indexing error
sentry.with_scope(function(scope)
   scope:set_tag("error_type", "array_indexing")
   scope:set_extra("expected_behavior", "Lua arrays are 1-indexed, not 0-indexed")

   local function safe_array_access()
      array_access_error("engineering", 2)
   end

   xpcall(safe_array_access, function(err)
      sentry.capture_exception({
         type = "IndexError",
         message = "Array indexing error: " .. tostring(err)
      })
      return err
   end)
end)

-- Test string concatenation error
sentry.with_scope(function(scope)
   scope:set_tag("error_type", "string_concatenation")
   scope:set_extra("expected_behavior", "Lua uses .. for string concatenation, not +")

   local function safe_string_concat()
      string_concat_error("Hello", "john_doe", 42)
   end

   xpcall(safe_string_concat, function(err)
      sentry.capture_exception({
         type = "TypeError", 
         message = "String concatenation error: " .. tostring(err)
      })
      return err
   end)
end)

-- Test nil method call error
sentry.with_scope(function(scope)
   scope:set_tag("error_type", "nil_access")
   scope:set_extra("expected_behavior", "Always check for nil before accessing table fields")

   local function safe_nil_access()
      nil_method_call("database", "production")
   end

   xpcall(safe_nil_access, function(err)
      sentry.capture_exception({
         type = "NilAccessError",
         message = "Nil access error: " .. tostring(err)
      })
      return err
   end)
end)

-- Test table iteration error (this one might not error but produces wrong results)
sentry.with_scope(function(scope)
   scope:set_tag("error_type", "iteration_logic")
   scope:set_extra("expected_behavior", "Use pairs() for hash tables, ipairs() for arrays")

   local result = table_iteration_error("user_profile", 10)
   if result:find("processed 0/") then
      sentry.capture_message("Table iteration produced empty result - likely using wrong iterator", "warning")
   end
end)

-- Original database error for comparison with parameters
local function database_query(query_type, table_name, timeout_ms)
   local connection_attempts = 3
   local last_error = "Connection timeout after " .. timeout_ms .. "ms"
   error("Database query failed: " .. query_type .. " on " .. table_name .. " (" .. last_error .. ")")
end

local function fetch_user_data(user_id, include_preferences)
   database_query("SELECT", "users", 5000)
end

local function authenticate_user(username, password_hash)
   fetch_user_data("user_12345", true)
end

local function handle_request(request_id, client_ip)
   authenticate_user("john.doe", "sha256_abc123")
end

-- Capture the original authentication error
local function error_handler(err)
   sentry.capture_exception({
      type = "AuthenticationError",
      message = err
   })
   return err
end

xpcall(function() handle_request("req_789", "192.168.1.100") end, error_handler)

-- Demonstrate automatic error capture vs manual handling
sentry.add_breadcrumb({
   message = "About to demonstrate automatic vs manual error handling",
   category = "demo",
   level = "info"
})

-- Example 1: Manual error handling with xpcall (traditional approach)
print("\n=== Manual Error Handling ===")
sentry.with_scope(function(scope)
   scope:set_tag("handling_method", "manual")

   local function manual_error_demo(operation_type, resource_id)
      local data = nil
      local context = "Processing " .. operation_type .. " for resource " .. resource_id
      return data.missing_field .. " (" .. context .. ")"  -- Will cause nil access error
   end

   xpcall(function() manual_error_demo("update", "res_456") end, function(err)
      sentry.capture_exception({
         type = "ManuallyHandledError", 
         message = "Manually captured: " .. tostring(err)
      })
      print("[Manual] Error captured and handled gracefully")
      return err
   end)
end)

-- Example 2: Automatic error capture (new functionality)
-- NOTE: This will terminate the program after capturing the error
print("\n=== Automatic Error Handling ===")
print("The following error will be automatically captured by Sentry:")
sentry.with_scope(function(scope)
   scope:set_tag("handling_method", "automatic")
   scope:set_extra("note", "This error is automatically captured without xpcall")

   -- Uncomment the next line to test automatic capture
   -- WARNING: This will terminate the program!
   -- error("This error is automatically captured!")

   print("[Automatic] Error capture is enabled - any unhandled error() calls are automatically sent to Sentry")
end)

-- Use scoped context for temporary changes
sentry.with_scope(function(scope)
   scope:set_tag("temporary", "value")
   sentry.capture_message("OS Detection Test Message", "warning")
   -- Temporary context is automatically restored
end)

-- Clean up
sentry:close()