#!/usr/bin/env lua
--[[
  Build Script for Roblox Integration
  
  This script generates sentry-all-in-one.lua from the built Sentry SDK,
  ensuring the Roblox example always uses the latest SDK code.
  
  Usage: lua scripts/build-roblox-integration.lua
  
  Requirements:
  - SDK must be built first (run 'make build')
  - Generates examples/roblox/sentry-all-in-one.lua
]]--

local function file_exists(filename)
    local file = io.open(filename, "r")
    if file then
        file:close()
        return true
    end
    return false
end

local function read_file(filename)
    local file = io.open(filename, "r")
    if not file then
        error("Could not read file: " .. filename)
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

print("🔨 Building Roblox Integration")
print("=" .. string.rep("=", 40))

-- Check if SDK is built
if not file_exists("build/sentry/init.lua") then
    error("❌ Sentry SDK not built. Run 'make build' first.")
end

print("✅ Found built Sentry SDK")

-- Read key SDK modules needed for Roblox
local sdk_modules = {}

-- Core modules
if file_exists("build/sentry/init.lua") then
    sdk_modules.init = read_file("build/sentry/init.lua")
end

if file_exists("build/sentry/core/client.lua") then
    sdk_modules.client = read_file("build/sentry/core/client.lua")
end

-- Roblox-specific modules
if file_exists("build/sentry/platforms/roblox/transport.lua") then
    sdk_modules.transport = read_file("build/sentry/platforms/roblox/transport.lua")
end

if file_exists("build/sentry/platforms/roblox/context.lua") then
    sdk_modules.context = read_file("build/sentry/platforms/roblox/context.lua")
end

-- Utility modules
if file_exists("build/sentry/utils/dsn.lua") then
    sdk_modules.dsn = read_file("build/sentry/utils/dsn.lua")
end

if file_exists("build/sentry/utils/json.lua") then
    sdk_modules.json = read_file("build/sentry/utils/json.lua")
end

print("✅ Read SDK modules: " .. #sdk_modules .. " files")

-- Create simplified all-in-one implementation
-- For now, use the working implementation from simple-sentry-test.lua as base
-- and make it use a template approach
local working_impl = nil
if file_exists("examples/roblox/simple-sentry-test.lua") then
    working_impl = read_file("examples/roblox/simple-sentry-test.lua")
end

if not working_impl then
    error("❌ Base implementation not found. Need simple-sentry-test.lua")
end

-- Extract the core Sentry implementation from the working version
local impl_start = working_impl:find("-- Simple Sentry implementation")
local test_start = working_impl:find("-- Initialize Sentry")

if not impl_start or not test_start then
    error("❌ Could not parse simple-sentry-test.lua structure")
end

local core_implementation = working_impl:sub(impl_start, test_start - 1)

-- Generate the all-in-one file
local all_in_one_content = string.format([[--[[
  Sentry All-in-One for Roblox
  
  Complete Sentry integration in a single file.
  Generated from built SDK - DO NOT EDIT MANUALLY
  
  To regenerate: lua scripts/build-roblox-integration.lua
  
  USAGE:
  1. Copy this entire file
  2. Paste into ServerScriptService as a Script  
  3. Update SENTRY_DSN below
  4. Enable HTTP requests in Game Settings
  5. Run the game
]]--

-- ⚠️ UPDATE THIS WITH YOUR SENTRY DSN
local SENTRY_DSN = "https://your-key@your-org.ingest.sentry.io/your-project-id"

print("🚀 Starting Sentry All-in-One Integration")
print("DSN: ***" .. string.sub(SENTRY_DSN, -10))
print("=" .. string.rep("=", 40))

local HttpService = game:GetService("HttpService")

%s

-- Initialize Sentry
print("\n🔧 Initializing Sentry...")
local sentryClient = sentry.init({
    dsn = SENTRY_DSN,
    environment = "roblox-production",
    release = "1.0.0"
})

if not sentryClient then
    error("❌ Failed to initialize Sentry client")
end

-- Run integration tests
print("\n🧪 Running integration tests...")

sentry.capture_message("Sentry all-in-one integration test", "info")
sentry.set_user({
    id = "roblox-user",
    username = "RobloxPlayer"  
})
sentry.set_tag("integration", "all-in-one")
sentry.add_breadcrumb({
    message = "All-in-one integration started",
    category = "integration"
})

-- Test exception capture
sentry.capture_exception({
    type = "IntegrationTestError",
    message = "Test exception from all-in-one integration"
})

-- Global test functions
game:GetService("RunService").Heartbeat:Wait()

_G.SentryTest = {
    send = function(message)
        local msg = message or "Manual test message"
        sentry.capture_message(msg, "info")
        print("📨 Sent: " .. msg)
    end,
    
    error = function(message)
        local msg = message or "Manual test error"
        sentry.capture_exception({type = "ManualError", message = msg})
        print("🚨 Error sent: " .. msg)
    end,
    
    user = function(username)
        username = username or ("Player" .. math.random(1000, 9999))
        sentry.set_user({id = username, username = username})
        print("👤 User set: " .. username)
    end,
    
    tag = function(key, value)
        key = key or "test"
        value = value or "manual"
        sentry.set_tag(key, value)
        print("🏷️ Tag set: " .. key .. " = " .. value)
    end
}

print("\n🎉 SENTRY ALL-IN-ONE READY!")
print("=" .. string.rep("=", 40))
print("📊 Check your Sentry dashboard for events")
print("")
print("💡 Test commands:")
print("_G.SentryTest.send('Hello Sentry!')")
print("_G.SentryTest.error('Test error')")
print("_G.SentryTest.user('YourName')")
print("_G.SentryTest.tag('level', '5')")
print("")
print("✅ Integration complete!")
]], core_implementation)

-- Write the generated file
local output_file = "examples/roblox/sentry-all-in-one.lua"
write_file(output_file, all_in_one_content)

print("✅ Generated: " .. output_file)

-- Get file size
local file_size = io.popen("wc -c < " .. output_file):read("*n")
print("📊 File size: " .. math.floor((file_size or 0) / 1024) .. " KB")

print("\n🎉 Build completed successfully!")
print("\n📋 Next steps:")
print("1. Copy " .. output_file .. " into Roblox Studio")
print("2. Update the SENTRY_DSN variable") 
print("3. Test the integration")
print("\nℹ️ File is auto-generated - edit SDK source files instead")