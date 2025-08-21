#!/usr/bin/env lua

-- Simple source context test by triggering an error
package.path = "examples/love2d/?.lua;build-single-file/?.lua;;"

print("=== Simple Source Context Test ===")

local sentry = require("sentry")

-- Initialize Sentry
sentry.init({
    dsn = "https://e247e6e48f8f482499052a65adaa9f6b@o117736.ingest.us.sentry.io/4504930623356928",
    debug = true
})

print("✅ Sentry initialized")
print("Current working directory:", io.popen("pwd"):read("*a"):gsub("\n", ""))

-- This function will create an error with a clear line number
local function test_error_with_context()
    local x = nil
    local y = x.nonexistent_field  -- This will cause an error on this specific line
end

local function wrapper_function()
    test_error_with_context()
end

-- Capture the error
local success, error_msg = pcall(wrapper_function)

if not success then
    print("Error occurred:", error_msg)
    
    -- Capture it to Sentry
    local event_id = sentry.capture_exception({
        type = "SourceContextTestError",
        message = error_msg
    })
    
    print("Event captured with ID:", event_id)
else
    print("No error occurred (unexpected)")
end

print("\n=== Test file paths ===")

-- Test if we can read this current file
local current_file = "test_source_context_simple.lua"
print("Testing current file:", current_file)

local file = io.open(current_file, "r")
if file then
    print("✅ Current file can be opened")
    file:close()
else
    print("❌ Current file cannot be opened")
end

-- Test Love2D main.lua
local love2d_file = "examples/love2d/main.lua"
print("Testing Love2D file:", love2d_file)

local file2 = io.open(love2d_file, "r")
if file2 then
    print("✅ Love2D file can be opened")
    file2:close()
else
    print("❌ Love2D file cannot be opened")
end

-- Test absolute path
local abs_love2d_file = "/Users/bruno/git/sentry-lua/examples/love2d/main.lua"
print("Testing absolute Love2D file:", abs_love2d_file)

local file3 = io.open(abs_love2d_file, "r")
if file3 then
    print("✅ Absolute Love2D file can be opened")
    file3:close()
else
    print("❌ Absolute Love2D file cannot be opened")
end

print("=== Test completed ===")

-- Flush to make sure event is sent
sentry.flush()