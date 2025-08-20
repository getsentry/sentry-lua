--[[
  Simple Test Script to Verify Sentry Module Installation
  
  Place this in ServerScriptService as a Script (not LocalScript)
  Run this first to verify the Sentry module is properly installed
]]--

local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("🔍 Testing Sentry module installation...")

-- Check if sentry folder exists
local sentryFolder = ReplicatedStorage:FindFirstChild("sentry")
if not sentryFolder then
   warn("❌ SETUP ERROR: 'sentry' folder not found in ReplicatedStorage")
   warn("📝 Please follow these steps:")
   warn("   1. Create a Folder in ReplicatedStorage named 'sentry'")
   warn("   2. Add all the built Sentry modules as ModuleScripts inside this folder")
   warn("   3. Ensure the main 'init' ModuleScript exists in the sentry folder")
   return
end

print("✅ Found sentry folder in ReplicatedStorage")

-- Check for main init module
local initModule = sentryFolder:FindFirstChild("init")
if not initModule then
   warn("❌ SETUP ERROR: 'init' ModuleScript not found in sentry folder")
   warn("📝 The main sentry module should be a ModuleScript named 'init'")
   return
end

print("✅ Found init ModuleScript")

-- Try to require the main sentry module
local success, sentry = pcall(require, initModule)
if not success then
   warn("❌ MODULE ERROR: Failed to load sentry module:")
   warn("   " .. tostring(sentry))
   warn("📝 Check that all required ModuleScripts are present and properly structured")
   return
end

print("✅ Successfully loaded sentry module")

-- Check that sentry has expected functions
local expectedFunctions = {"init", "capture_message", "capture_exception", "set_user", "add_breadcrumb"}
local missingFunctions = {}

for _, funcName in ipairs(expectedFunctions) do
   if type(sentry[funcName]) ~= "function" then
      table.insert(missingFunctions, funcName)
   end
end

if #missingFunctions > 0 then
   warn("❌ MODULE ERROR: Missing expected functions:")
   for _, funcName in ipairs(missingFunctions) do
      warn("   - " .. funcName)
   end
   warn("📝 The sentry module may be incomplete or incorrectly built")
   return
end

print("✅ All expected functions found")

-- Test basic module functionality (without network calls)
print("🧪 Testing basic module functionality...")

-- This should work without a real DSN
local testSuccess, testError = pcall(function()
   -- Try to initialize with a dummy DSN
   sentry.init({
      dsn = "https://test@test.ingest.sentry.io/1234567",
      environment = "test",
      debug = true
   })
end)

if testSuccess then
   print("✅ Module initialization test passed")
   print("🎉 Sentry module is properly installed and ready to use!")
   print("")
   print("Next steps:")
   print("1. Update the DSN in your scripts with your real Sentry project DSN")
   print("2. Run the main ServerScript and LocalScript")
   print("3. Test with the GUI or manual commands")
else
   warn("❌ MODULE TEST FAILED: " .. tostring(testError))
   warn("📝 There may be issues with the module dependencies")
end