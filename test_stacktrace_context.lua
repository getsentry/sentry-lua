#!/usr/bin/env lua

-- Test stacktrace context directly
package.path = "examples/love2d/?.lua;build-single-file/?.lua;;"

print("=== Stacktrace Context Direct Test ===")

local sentry = require("sentry")

-- Access internal stacktrace utilities through the single-file SDK
-- Since it's bundled, let's just load the sentry module and test internally
print("Sentry loaded:", type(sentry))

-- Initialize sentry to make sure all modules are available
sentry.init({
    dsn = "https://e247e6e48f8f482499052a65adaa9f6b@o117736.ingest.us.sentry.io/4504930623356928",
    debug = true
})

-- This function will cause an error on a specific line
local function test_error_function()
    -- Line that will cause error (let's make it line 21)
    local nil_value = nil
    local result = nil_value.nonexistent_field  -- Error on this line
    return result
end

local function wrapper_function()
    return test_error_function()
end

-- Capture the actual error and examine the stacktrace
print("\n=== Testing Error Capture with Context ===")

-- Create a custom capture that shows us the stacktrace details
local original_capture = sentry.capture_exception

local function debug_capture_exception(exception_data, level)
    print("Debug: Capturing exception...")
    print("Exception type:", exception_data.type)
    print("Exception message:", exception_data.message)
    
    -- Call original capture
    return original_capture(exception_data, level)
end

-- Temporarily replace capture function
sentry.capture_exception = debug_capture_exception

-- Trigger the error
local success, error_msg = pcall(wrapper_function)

if not success then
    print("Error caught:", error_msg)
    
    -- Manually capture to see what gets sent
    sentry.capture_exception({
        type = "StacktraceContextTest",
        message = error_msg
    }, "error")
    
    print("Error captured to Sentry")
else
    print("No error occurred (unexpected)")
end

-- Restore original function
sentry.capture_exception = original_capture

sentry.flush()

print("\n=== Test completed - check Sentry for source context ===")

-- Also test what files can be read from current directory
print("\n=== File Access Test ===")

local test_files = {
    "test_stacktrace_context.lua",
    "examples/love2d/main.lua",
    "/Users/bruno/git/sentry-lua/test_stacktrace_context.lua",
    "/Users/bruno/git/sentry-lua/examples/love2d/main.lua"
}

for _, file_path in ipairs(test_files) do
    local file = io.open(file_path, "r")
    if file then
        local line_count = 0
        for line in file:lines() do
            line_count = line_count + 1
        end
        file:close()
        print("✅", file_path, "- lines:", line_count)
    else
        print("❌", file_path, "- cannot open")
    end
end