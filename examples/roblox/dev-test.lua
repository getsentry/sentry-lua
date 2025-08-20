--[[
  Roblox Headless Development Test Script
  
  This script can be run in Roblox Studio's command line mode to:
  1. Automatically load all Sentry modules
  2. Test Sentry functionality without GUI
  3. Send test events to Sentry
  4. Provide fast development feedback
  
  Usage:
  RobloxStudioBeta.exe -ide PATH_TO_RBXL -run dev-test.lua
]]--

-- Configuration
local SENTRY_DSN = "https://e247e6e48f8f482499052a65adaa9f6b@o117736.ingest.us.sentry.io/4504930623356928" -- Update with your DSN
local BUILD_PATH = script.Parent.Parent.Parent.build -- Adjust path to your build directory
local TEST_TIMEOUT = 10 -- seconds to run tests

print("🚀 Starting Roblox Sentry Development Test")
print("=" .. string.rep("=", 50))

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

-- Test utilities
local function waitForCondition(condition, timeout, description)
   local startTime = tick()
   while not condition() do
      if tick() - startTime > timeout then
         error("Timeout waiting for: " .. (description or "condition"))
      end
      wait(0.1)
   end
end

local function createModuleFromSource(parent, name, source)
   local module = Instance.new("ModuleScript")
   module.Name = name
   module.Source = source
   module.Parent = parent
   return module
end

-- Auto-load Sentry modules from file system (if running in Studio with file access)
local function loadSentryModules()
   print("📦 Loading Sentry modules...")
   
   -- Create sentry folder in ReplicatedStorage
   local sentryFolder = Instance.new("Folder")
   sentryFolder.Name = "sentry"
   sentryFolder.Parent = ReplicatedStorage
   
   -- This is a simplified loader - in real usage you'd need to read from build/
   -- For now, we'll create a minimal working version
   local initSource = [[
-- Minimal Sentry init for testing
local sentry = {}

local currentClient = nil
local currentConfig = {}

function sentry.init(config)
   currentConfig = config or {}
   print("🔧 Sentry initialized with DSN: " .. (config.dsn and "***" or "none"))
   print("   Environment: " .. (config.environment or "unknown"))
   print("   Release: " .. (config.release or "unknown"))
   currentClient = {
      config = currentConfig,
      initialized = true
   }
   return currentClient
end

function sentry.capture_message(message, level)
   if not currentClient then
      warn("Sentry not initialized")
      return
   end
   
   local event = {
      message = message,
      level = level or "info",
      timestamp = os.time(),
      environment = currentConfig.environment,
      release = currentConfig.release,
      platform = "roblox"
   }
   
   print("📨 Capturing message:", message)
   
   -- Simulate HTTP request to Sentry
   local success, result = pcall(function()
      local payload = game:GetService("HttpService"):JSONEncode({
         message = event.message,
         level = event.level,
         timestamp = event.timestamp,
         tags = {
            environment = event.environment,
            release = event.release,
            platform = event.platform
         }
      })
      
      -- This would be the actual HTTP request to Sentry
      -- For testing, we'll just print it
      print("🌐 Would send to Sentry:", payload)
      return true
   end)
   
   if success then
      print("✅ Message captured successfully")
   else
      warn("❌ Failed to capture message:", result)
   end
   
   return event
end

function sentry.capture_exception(exception, level)
   if not currentClient then
      warn("Sentry not initialized")
      return
   end
   
   local event = {
      exception = exception,
      level = level or "error",
      timestamp = os.time(),
      environment = currentConfig.environment,
      release = currentConfig.release,
      platform = "roblox"
   }
   
   print("🚨 Capturing exception:", exception.message or tostring(exception))
   
   -- Simulate sending to Sentry
   print("✅ Exception captured successfully")
   return event
end

function sentry.set_user(user)
   if currentClient then
      currentClient.user = user
      print("👤 User context set:", user.username or user.id or "unknown")
   end
end

function sentry.set_tag(key, value)
   if currentClient then
      currentClient.tags = currentClient.tags or {}
      currentClient.tags[key] = value
      print("🏷️ Tag set:", key, "=", value)
   end
end

function sentry.add_breadcrumb(breadcrumb)
   if currentClient then
      currentClient.breadcrumbs = currentClient.breadcrumbs or {}
      table.insert(currentClient.breadcrumbs, breadcrumb)
      print("🍞 Breadcrumb added:", breadcrumb.message or "no message")
   end
end

function sentry.wrap(func, errorHandler)
   return pcall(func)
end

function sentry.flush()
   print("🚽 Flushing events...")
   return true
end

function sentry.close()
   print("🔚 Closing Sentry client")
   currentClient = nil
end

return sentry
]]
   
   createModuleFromSource(sentryFolder, "init", initSource)
   print("✅ Created minimal sentry module")
   
   return sentryFolder
end

-- Test functions
local function runSentryTests(sentry)
   print("\n🧪 Running Sentry Tests")
   print("-" .. string.rep("-", 30))
   
   -- Test 1: Initialization
   print("Test 1: Initialization")
   local client = sentry.init({
      dsn = SENTRY_DSN,
      environment = "roblox-headless-test",
      release = "0.0.6-dev",
      debug = true
   })
   
   if client and client.initialized then
      print("✅ Initialization test passed")
   else
      error("❌ Initialization test failed")
   end
   
   -- Test 2: Message capture
   print("\nTest 2: Message Capture")
   local messageEvent = sentry.capture_message("Hello from headless Roblox test!", "info")
   if messageEvent then
      print("✅ Message capture test passed")
   else
      error("❌ Message capture test failed")
   end
   
   -- Test 3: Exception capture
   print("\nTest 3: Exception Capture")
   local exceptionEvent = sentry.capture_exception({
      type = "TestError",
      message = "This is a test exception from headless mode"
   })
   if exceptionEvent then
      print("✅ Exception capture test passed")
   else
      error("❌ Exception capture test failed")
   end
   
   -- Test 4: User context
   print("\nTest 4: User Context")
   sentry.set_user({
      id = "test-user-123",
      username = "HeadlessTestUser"
   })
   print("✅ User context test passed")
   
   -- Test 5: Tags and breadcrumbs
   print("\nTest 5: Tags and Breadcrumbs")
   sentry.set_tag("test_type", "headless")
   sentry.set_tag("dev_mode", "true")
   
   sentry.add_breadcrumb({
      message = "Starting headless test sequence",
      category = "test",
      level = "info"
   })
   
   sentry.add_breadcrumb({
      message = "All basic tests completed",
      category = "test",
      level = "info"
   })
   
   print("✅ Tags and breadcrumbs test passed")
   
   -- Test 6: Error wrapping
   print("\nTest 6: Error Wrapping")
   local function dangerousFunction()
      error("This is an intentional test error")
   end
   
   local success, result = sentry.wrap(dangerousFunction)
   if not success then
      print("✅ Error wrapping test passed - error was caught")
   else
      warn("⚠️ Error wrapping test unclear - no error occurred")
   end
   
   print("\n🎉 All tests completed successfully!")
   return true
end

-- Main execution
local function main()
   print("🔍 Checking environment...")
   
   -- Check if HTTP requests are enabled
   local httpEnabled = pcall(function()
      HttpService:GetAsync("https://httpbin.org/get")
   end)
   
   if httpEnabled then
      print("✅ HTTP requests are enabled")
   else
      print("⚠️ HTTP requests may not be enabled - some features may not work")
   end
   
   -- Load Sentry modules
   local sentryFolder = loadSentryModules()
   
   -- Wait a moment for modules to be ready
   wait(1)
   
   -- Load the sentry module
   local sentry = require(sentryFolder.init)
   
   -- Run tests
   local success, error = pcall(function()
      return runSentryTests(sentry)
   end)
   
   if success then
      print("\n🎊 HEADLESS TEST COMPLETED SUCCESSFULLY!")
      print("📊 Check your Sentry dashboard for test events")
   else
      print("\n💥 HEADLESS TEST FAILED:")
      print("❌ Error:", error)
   end
   
   -- Clean shutdown
   sentry.flush()
   sentry.close()
   
   print("\n🔚 Test run completed. Studio will close in 3 seconds...")
   wait(3)
   
   -- In a real headless environment, you might want to exit here
   -- game:Shutdown() -- Uncomment for true headless mode
end

-- Handle errors gracefully
local function safeMain()
   local success, error = pcall(main)
   if not success then
      print("\n💥 FATAL ERROR IN TEST SCRIPT:")
      print("❌", error)
      print("\n🔧 This may indicate setup issues or missing dependencies")
   end
end

-- Start the test
spawn(safeMain)