#!/usr/bin/env lua

-- Test script to check what the Love2D single-file SDK exposes
package.path = "examples/love2d/?.lua;build-single-file/?.lua;;"

print("=== Testing Love2D Single-File SDK ===")

local success, sentry = pcall(require, "sentry")

if not success then
    print("❌ Failed to load sentry:", sentry)
    os.exit(1)
end

print("✅ Successfully loaded sentry module")
print("Type:", type(sentry))

print("\n=== Available functions ===")
for k, v in pairs(sentry) do
    print(string.format("  %-20s: %s", k, type(v)))
end

print("\n=== Testing logger availability ===")
if sentry.logger then
    print("✅ sentry.logger is available")
    print("Logger type:", type(sentry.logger))
    
    if type(sentry.logger) == "table" then
        print("Logger functions:")
        for k, v in pairs(sentry.logger) do
            if type(v) == "function" then
                print("  " .. k .. ": function")
            end
        end
    end
else
    print("❌ sentry.logger is NOT available")
    
    -- Try to require it directly
    local logger_success, logger_module = pcall(require, "sentry.logger")
    if logger_success then
        print("✅ But sentry.logger module can be required directly")
        print("Logger direct type:", type(logger_module))
    else
        print("❌ sentry.logger module cannot be required:", logger_module)
    end
end

print("\n=== Testing tracing availability ===")
if sentry.start_transaction then
    print("✅ sentry.start_transaction is available")
    print("start_transaction type:", type(sentry.start_transaction))
else
    print("❌ sentry.start_transaction is NOT available")
    
    -- Try to require tracing directly
    local tracing_success, tracing_module = pcall(require, "sentry.tracing")
    if tracing_success then
        print("✅ But sentry.tracing module can be required directly")
        print("Tracing direct type:", type(tracing_module))
        if tracing_module.start_transaction then
            print("✅ tracing.start_transaction is available in direct module")
        end
    else
        print("❌ sentry.tracing module cannot be required:", tracing_module)
    end
end

print("\n=== Testing initialization ===")
print("Attempting to initialize Sentry...")

local init_success, result = pcall(function()
    return sentry.init({
        dsn = "https://e247e6e48f8f482499052a65adaa9f6b@o117736.ingest.us.sentry.io/4504930623356928",
        debug = true,
        enable_logs = true
    })
end)

if init_success then
    print("✅ Sentry initialized successfully")
    print("Client type:", type(result))
    
    -- Test again after init
    print("\n=== Re-testing after init ===")
    if sentry.logger then
        print("✅ sentry.logger is now available")
        
        -- Test a logger function
        local log_success, log_error = pcall(function()
            sentry.logger.info("Test log message from single-file SDK")
        end)
        
        if log_success then
            print("✅ Logger test successful")
        else
            print("❌ Logger test failed:", log_error)
        end
    else
        print("❌ sentry.logger still not available after init")
    end
    
    if sentry.start_transaction then
        print("✅ sentry.start_transaction is now available")
        
        -- Test tracing
        local trace_success, trace_error = pcall(function()
            local tx = sentry.start_transaction("test_transaction", "test")
            if tx then
                print("✅ Transaction created successfully")
                tx:finish()
                print("✅ Transaction finished successfully")
            end
        end)
        
        if not trace_success then
            print("❌ Tracing test failed:", trace_error)
        end
    else
        print("❌ sentry.start_transaction still not available after init")
    end
    
else
    print("❌ Sentry initialization failed:", result)
end

print("\n=== Test completed ===")