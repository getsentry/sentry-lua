#!/usr/bin/env lua
--[[
  Create Clean Roblox Files
  
  Generates clean Roblox integration files from the working simple test.
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

print("🔨 Creating Clean Roblox Files")

-- Read the working simple test
local simple_test = read_file("examples/roblox/simple-sentry-test.lua")
if not simple_test then
    error("❌ simple-sentry-test.lua not found")
end

-- Extract the core Sentry implementation
local impl_start = simple_test:find("local sentry = {}")
local init_start = simple_test:find("-- Initialize Sentry")

if not impl_start or not init_start then
    error("❌ Could not parse simple-sentry-test.lua")
end

local sentry_core = simple_test:sub(impl_start, init_start - 1)

-- Create SDK module
local sdk_content = string.format([[--[[
  Sentry SDK for Roblox - Module Version
  
  Self-contained Sentry SDK module for Roblox projects.
  Based on working implementation from simple-sentry-test.lua
  
  Usage:
    local sentry = require(this_module)
    sentry.init({dsn = "your-dsn"})
    sentry.capture_message("Hello!")
]]--

local HttpService = game:GetService("HttpService")

%s

return sentry
]], sentry_core)

-- Write SDK module
write_file("examples/roblox/sentry-roblox-sdk.lua", sdk_content)
print("✅ Created sentry-roblox-sdk.lua")

-- Create all-in-one version (copy of working simple test with better name)
local allinone_content = simple_test:gsub("Simple Sentry Test Script", "All-in-One Sentry Integration")
allinone_content = allinone_content:gsub("SimpleSentryTest", "SentryAllInOne")
allinone_content = allinone_content:gsub("roblox%-simple%-test", "roblox-allinone")

write_file("examples/roblox/sentry-all-in-one.lua", allinone_content)
print("✅ Created sentry-all-in-one.lua")

-- Create clean example using the SDK module
local example_content = [[--[[
  Clean Roblox Sentry Example
  
  This example shows how to use the separate SDK module.
  
  SETUP:
  1. Place sentry-roblox-sdk.lua in ReplicatedStorage as ModuleScript named "SentrySDK"
  2. Copy this script to ServerScriptService
  3. Update DSN below and run
]]--

-- ⚠️ UPDATE THIS WITH YOUR SENTRY DSN
local SENTRY_DSN = "https://e247e6e48f8f482499052a65adaa9f6b@o117736.ingest.us.sentry.io/4504930623356928"

print("🚀 Clean Roblox Sentry Example")
print("=" .. string.rep("=", 40))

-- Load SDK module
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local sentryModule = ReplicatedStorage:WaitForChild("SentrySDK", 5)

if not sentryModule then
    error("❌ Place sentry-roblox-sdk.lua as ModuleScript named 'SentrySDK' in ReplicatedStorage")
end

local sentry = require(sentryModule)

-- Initialize
local client = sentry.init({
    dsn = SENTRY_DSN,
    environment = "roblox-clean",
    release = "1.0.0"
})

if client then
    print("✅ Sentry initialized successfully")
    
    -- Test basic functionality
    sentry.capture_message("Clean example test message", "info")
    sentry.set_tag("example", "clean")
    
    -- Global test functions
    _G.CleanSentryTest = {
        send = function(msg)
            sentry.capture_message(msg or "Manual test", "info")
            print("📨 Sent: " .. (msg or "Manual test"))
        end,
        error = function()
            sentry.capture_exception({type = "TestError", message = "Manual error"})
            print("🚨 Error sent")
        end
    }
    
    print("✅ Clean example ready!")
    print("💡 Try: _G.CleanSentryTest.send('Hello Clean!')")
else
    error("❌ Failed to initialize Sentry")
end
]]

write_file("examples/roblox/clean-example.lua", example_content)
print("✅ Created clean-example.lua")

print("\n🎉 Created clean Roblox files!")
print("\n📋 Files created:")
print("  • sentry-roblox-sdk.lua  (Reusable SDK module)")
print("  • sentry-all-in-one.lua  (Complete single-file solution)")  
print("  • clean-example.lua      (Example using SDK module)")
print("\n💡 Recommended for testing: sentry-all-in-one.lua")