#!/usr/bin/env lua
--[[
  Simple Roblox SDK Packer
  
  Creates a working Sentry implementation for Roblox by combining
  the current simple-sentry-test.lua approach with SDK structure.
]]--

local function read_file(filename)
    local file = io.open(filename, "r")
    if not file then
        return nil
    end
    local content = file:read("*all")
    file:close()
    return content
end

local function write_file(filename, content)
    local file = io.open(filename, "w")
    if not file then
        error("Could not write file: " .. filename)
    end
    file:write(content)
    file:close()
end

print("🔨 Creating Simple Roblox SDK")

-- Read the working simple test as a base
local simple_test = read_file("examples/roblox/simple-sentry-test.lua")
if not simple_test then
    error("❌ simple-sentry-test.lua not found")
end

-- Extract just the Sentry implementation part (remove test code)
local sentry_impl_start = simple_test:find("-- Simple Sentry implementation")
local test_start = simple_test:find("-- Initialize Sentry")

if not sentry_impl_start or not test_start then
    error("❌ Could not find Sentry implementation in simple-sentry-test.lua")
end

local sentry_implementation = simple_test:sub(sentry_impl_start, test_start - 1)

-- Create the packed SDK module
local packed_sdk = [[--[[
  Sentry SDK for Roblox - Packed Module
  
  This is a self-contained Sentry SDK module for Roblox.
  Based on the working simple-sentry-test.lua implementation.
  
  Usage:
    local sentry = require(this_module)
    sentry.init({dsn = "your-sentry-dsn"})
    sentry.capture_message("Hello Sentry!")
    sentry.capture_exception({type = "Error", message = "Something went wrong"})
]]--

local HttpService = game:GetService("HttpService")

]] .. sentry_implementation .. [[

-- Export the sentry module
return sentry
]]

-- Write the packed SDK module
local output_file = "examples/roblox/sentry-roblox-sdk.lua"
write_file(output_file, packed_sdk)

print("✅ Created packed SDK module: " .. output_file)

-- Create a clean example that uses the packed SDK
local example_content = [[--[[
  Clean Roblox Sentry Integration Example
  
  This example uses the packed Sentry SDK module for clean integration.
  
  SETUP:
  1. Copy this script to ServerScriptService
  2. Copy sentry-roblox-sdk.lua to ReplicatedStorage as a ModuleScript named "SentrySDK"
  3. Update DSN below
  4. Enable HTTP requests in Game Settings
  5. Run the game
]]--

-- ⚠️ UPDATE THIS WITH YOUR SENTRY DSN
local SENTRY_DSN = "https://e247e6e48f8f482499052a65adaa9f6b@o117736.ingest.us.sentry.io/4504930623356928"

print("🚀 Starting Clean Roblox Sentry Integration")
print("=" .. string.rep("=", 40))

-- Load the Sentry SDK module
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local sentryModule = ReplicatedStorage:WaitForChild("SentrySDK", 5)

if not sentryModule then
    error("❌ SentrySDK module not found in ReplicatedStorage")
end

local sentry = require(sentryModule)

-- Initialize Sentry
print("🔧 Initializing Sentry...")
local client = sentry.init({
    dsn = SENTRY_DSN,
    environment = "roblox-clean",
    release = "1.0.0"
})

if not client then
    error("❌ Failed to initialize Sentry")
end

-- Run tests
print("🧪 Running integration tests...")

sentry.capture_message("Clean integration test message", "info")
sentry.set_user({id = "test-user", username = "CleanTestUser"})
sentry.set_tag("integration", "clean")
sentry.add_breadcrumb({message = "Clean test started", category = "test"})
sentry.capture_exception({type = "TestError", message = "Clean test exception"})

-- Create global functions
_G.CleanSentryTest = {
    sendMessage = function(msg)
        sentry.capture_message(msg or "Manual message", "info")
        print("📨 Message sent: " .. (msg or "Manual message"))
    end,
    
    triggerError = function()
        sentry.capture_exception({type = "ManualError", message = "Manual test error"})
        print("🚨 Error triggered")
    end
}

print("✅ Clean integration ready!")
print("💡 Try: _G.CleanSentryTest.sendMessage('Hello Clean SDK!')")
]]

-- Write the clean example
local example_file = "examples/roblox/clean-integration-example.lua"
write_file(example_file, example_content)

print("✅ Created clean example: " .. example_file)

-- Create all-in-one version (for easy testing)
local all_in_one = [[--[[
  All-in-One Roblox Sentry Integration
  
  This file contains both the SDK and example code in one script.
  Perfect for quick testing - just copy and paste into Roblox Studio.
  
  INSTRUCTIONS:
  1. Copy this entire script
  2. Create a Script in ServerScriptService
  3. Paste and update DSN below
  4. Enable HTTP requests
  5. Run the game
]]--

-- ⚠️ UPDATE THIS WITH YOUR SENTRY DSN
local SENTRY_DSN = "https://e247e6e48f8f482499052a65adaa9f6b@o117736.ingest.us.sentry.io/4504930623356928"

print("🚀 Starting All-in-One Roblox Sentry")
print("=" .. string.rep("=", 40))

]] .. sentry_implementation .. [[

-- Initialize and test
print("🔧 Initializing Sentry...")
local client = sentry.init({
    dsn = SENTRY_DSN,
    environment = "roblox-allinone",
    release = "1.0.0"
})

print("🧪 Running tests...")
sentry.capture_message("All-in-one test message", "info")
sentry.set_tag("version", "allinone")

-- Global test functions  
_G.SentryTest = {
    send = function(msg) sentry.capture_message(msg or "Test message", "info") end,
    error = function() sentry.capture_exception({type = "TestError", message = "Test error"}) end
}

print("✅ All-in-one integration ready!")
print("💡 Try: _G.SentryTest.send('Hello!')")
]]

local allinone_file = "examples/roblox/all-in-one-sentry.lua"
write_file(allinone_file, all_in_one)

print("✅ Created all-in-one version: " .. allinone_file)

print("\n🎉 Packing completed!")
print("\n📋 Created files:")
print("  • sentry-roblox-sdk.lua     (SDK module)")
print("  • clean-integration-example.lua  (Clean example)")  
print("  • all-in-one-sentry.lua    (Complete single-file solution)")
print("\n💡 Recommended: Use all-in-one-sentry.lua for testing")