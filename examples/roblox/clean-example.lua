--[[
  Clean Roblox Sentry Example
  
  This example shows how to use the separate Sentry SDK module.
  
  SETUP:
  1. Place sentry-roblox-sdk.lua in ReplicatedStorage as ModuleScript named "SentrySDK"
  2. Copy this script to ServerScriptService
  3. Update DSN below and run
  
  This approach separates the SDK from your game logic for cleaner organization.
]]--

-- ⚠️ UPDATE THIS WITH YOUR SENTRY DSN
local SENTRY_DSN = "https://e247e6e48f8f482499052a65adaa9f6b@o117736.ingest.us.sentry.io/4504930623356928"

print("🚀 Clean Roblox Sentry Example")
print("=" .. string.rep("=", 40))

-- Load SDK module from ReplicatedStorage
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local sentryModule = ReplicatedStorage:WaitForChild("SentrySDK", 5)

if not sentryModule then
    error("❌ Place sentry-roblox-sdk.lua as ModuleScript named 'SentrySDK' in ReplicatedStorage")
end

local sentry = require(sentryModule)

-- Initialize Sentry
print("🔧 Initializing Sentry...")
local client = sentry.init({
    dsn = SENTRY_DSN,
    environment = "roblox-clean",
    release = "1.0.0"
})

if client then
    print("✅ Sentry initialized successfully")
    
    -- Test basic functionality
    sentry.capture_message("Clean example test message", "info")
    sentry.set_user({
        id = "clean-example-user",
        username = "CleanExampleUser"
    })
    sentry.set_tag("example", "clean")
    sentry.add_breadcrumb({
        message = "Clean example started", 
        category = "example"
    })
    
    -- Make sentry globally available
    _G.sentry = sentry
    
    print("✅ Clean example ready!")
    print("💡 Try: sentry.capture_message('Hello Clean SDK!', 'info')")
    print("💡 Try: sentry.capture_exception({type = 'TestError', message = 'Manual error'})")
    print("💡 Try: sentry.set_user({id = '456', username = 'TestUser'})")
    print("💡 Try: sentry.set_tag('example', 'clean')")
else
    error("❌ Failed to initialize Sentry")
end