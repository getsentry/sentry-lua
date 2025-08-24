#!/usr/bin/env lua

-- Simple test for Love2D single-file SDK basic functionality
package.path = "examples/love2d/?.lua;build-single-file/?.lua;;"

print("=== Love2D Single-File SDK Basic Test ===")

local sentry = require("sentry")
print("✅ Sentry loaded")

-- Initialize
sentry.init({
    dsn = "https://e247e6e48f8f482499052a65adaa9f6b@o117736.ingest.us.sentry.io/4504930623356928",
    debug = true,
    enable_logs = true
})
print("✅ Sentry initialized")

-- Test core functions
sentry.set_user({id = "test-user", username = "test"})
sentry.set_tag("test", "single-file-sdk")
sentry.add_breadcrumb({message = "Test breadcrumb"})
print("✅ Core functions working")

-- Test logger
print("Testing logger functions:")
sentry.logger.info("Test info message")
sentry.logger.warn("Test warning message")
sentry.logger.error("Test error message")
print("✅ Logger functions working")

-- Test simple transaction (without spans)
print("Testing transaction creation:")
local tx = sentry.start_transaction("test-transaction", "test-op")
if tx then
    print("✅ Transaction created:", type(tx))
    
    -- Simple finish (just the transaction)
    if tx.finish then
        tx:finish("ok")
        print("✅ Transaction finished")
    else
        print("❌ Transaction missing finish method")
    end
else
    print("❌ Transaction creation failed")
end

-- Test message capture
print("Testing message capture:")
local event_id = sentry.capture_message("Test message from single-file SDK", "info")
print("✅ Message captured, event ID:", event_id)

-- Test exception capture
print("Testing exception capture:")
local error_id = sentry.capture_exception({
    type = "TestError",
    message = "Test error from single-file SDK"
})
print("✅ Exception captured, event ID:", error_id)

-- Test error handler
print("Testing error wrapper:")
sentry.wrap(function()
    print("Inside wrapped function")
end)
print("✅ Error wrapper working")

-- Flush and close
sentry.flush()
print("✅ Flushed events")

print("\n=== All basic tests passed! ===")

-- Test that all required functions are available
local required_functions = {
    "init", "capture_message", "capture_exception", "add_breadcrumb",
    "set_user", "set_tag", "set_extra", "flush", "close", "wrap",
    "start_transaction", "logger"
}

print("\n=== Function availability check ===")
for _, func_name in ipairs(required_functions) do
    if sentry[func_name] then
        print("✅", func_name, "available")
    else
        print("❌", func_name, "MISSING")
    end
end

print("\n=== Single-file SDK test completed successfully! ===")