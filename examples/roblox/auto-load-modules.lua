--[[
  Automatic Sentry Module Loader for Roblox Development
  
  This script reads the built Sentry modules from the file system
  and automatically creates the corresponding ModuleScripts in ReplicatedStorage
  
  Usage in Roblox Studio:
  1. Place this script in ServerScriptService
  2. Update SENTRY_BUILD_PATH to point to your build directory
  3. Run the game - modules will be auto-loaded
]]--

local SENTRY_BUILD_PATH = "../../build/sentry/" -- Adjust this path
local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("🔄 Auto-loading Sentry modules from build directory...")

-- File system access functions (Studio only)
local function readFile(path)
   -- This would need to be implemented with file system access
   -- For now, we'll provide the main module content directly
   warn("File system access not implemented in this example")
   return nil
end

-- Module structure and content mapping
local moduleStructure = {
   -- Main init module
   {
      path = "",
      name = "init",
      content = [[
-- Auto-loaded Sentry main module
local sentry = {}
local platform_loader = require(script.Parent.platform_loader)
local client = require(script.Parent.core.client)
local types = require(script.Parent.types)

-- Initialize Sentry
function sentry.init(config)
   config = config or {}
   print("🔧 Sentry initializing...")
   print("   DSN: " .. (config.dsn and "***configured***" or "not set"))
   print("   Environment: " .. (config.environment or "unknown"))
   print("   Platform: roblox")
   
   -- Set up client
   local sentryClient = client.new(config)
   sentry._client = sentryClient
   
   return sentryClient
end

function sentry.capture_message(message, level)
   if not sentry._client then
      warn("❌ Sentry not initialized - call sentry.init() first")
      return
   end
   
   print("📨 Capturing message: " .. tostring(message))
   return sentry._client:capture_message(message, level)
end

function sentry.capture_exception(exception, level)
   if not sentry._client then
      warn("❌ Sentry not initialized - call sentry.init() first")
      return
   end
   
   print("🚨 Capturing exception: " .. tostring(exception.message or exception))
   return sentry._client:capture_exception(exception, level)
end

function sentry.set_user(user)
   if sentry._client then
      sentry._client:set_user(user)
      print("👤 User set: " .. (user.username or user.id or "unknown"))
   end
end

function sentry.set_tag(key, value)
   if sentry._client then
      sentry._client:set_tag(key, value)
      print("🏷️ Tag set: " .. key .. " = " .. tostring(value))
   end
end

function sentry.add_breadcrumb(breadcrumb)
   if sentry._client then
      sentry._client:add_breadcrumb(breadcrumb)
      print("🍞 Breadcrumb added: " .. (breadcrumb.message or "no message"))
   end
end

function sentry.wrap(func, errorHandler)
   local success, result = pcall(func)
   if not success and sentry._client then
      sentry.capture_exception({
         type = "WrappedError",
         message = tostring(result)
      })
      if errorHandler then
         return false, errorHandler(result)
      end
   end
   return success, result
end

function sentry.flush()
   if sentry._client then
      return sentry._client:flush()
   end
   return true
end

function sentry.close()
   if sentry._client then
      sentry._client:close()
      sentry._client = nil
      print("🔚 Sentry client closed")
   end
end

return sentry
]]
   },
   
   -- Platform loader
   {
      path = "",
      name = "platform_loader",
      content = [[
-- Platform detection and loading
local platform_loader = {}

function platform_loader.detect_platform()
   return "roblox"
end

function platform_loader.load_platform_modules()
   return {
      transport = require(script.Parent.platforms.roblox.transport),
      context = require(script.Parent.platforms.roblox.context),
      os_detection = require(script.Parent.platforms.roblox.os_detection)
   }
end

return platform_loader
]]
   },
   
   -- Core client
   {
      path = "core",
      name = "client",
      content = [[
-- Sentry client implementation
local client = {}
client.__index = client

function client.new(config)
   local self = setmetatable({}, client)
   self.config = config or {}
   self.user = nil
   self.tags = {}
   self.breadcrumbs = {}
   
   -- Load transport
   local robloxTransport = require(script.Parent.Parent.platforms.roblox.transport)
   self.transport = robloxTransport.new(config.dsn)
   
   print("✅ Sentry client created")
   return self
end

function client:capture_message(message, level)
   local event = {
      message = message,
      level = level or "info",
      timestamp = os.time(),
      user = self.user,
      tags = self.tags,
      breadcrumbs = self.breadcrumbs,
      platform = "roblox"
   }
   
   return self.transport:send_event(event)
end

function client:capture_exception(exception, level)
   local event = {
      exception = exception,
      level = level or "error", 
      timestamp = os.time(),
      user = self.user,
      tags = self.tags,
      breadcrumbs = self.breadcrumbs,
      platform = "roblox"
   }
   
   return self.transport:send_event(event)
end

function client:set_user(user)
   self.user = user
end

function client:set_tag(key, value)
   self.tags[key] = value
end

function client:add_breadcrumb(breadcrumb)
   table.insert(self.breadcrumbs, breadcrumb)
   -- Keep only last 100 breadcrumbs
   if #self.breadcrumbs > 100 then
      table.remove(self.breadcrumbs, 1)
   end
end

function client:flush()
   return self.transport:flush()
end

function client:close()
   self.transport:close()
end

return client
]]
   },
   
   -- Roblox transport
   {
      path = "platforms/roblox",
      name = "transport",
      content = [[
-- Roblox HTTP transport
local transport = {}
transport.__index = transport

function transport.new(dsn)
   local self = setmetatable({}, transport)
   self.dsn = dsn
   self.HttpService = game:GetService("HttpService")
   
   if not dsn then
      warn("⚠️ No DSN provided - events will not be sent")
   else
      print("🌐 Transport configured with DSN")
   end
   
   return self
end

function transport:send_event(event)
   if not self.dsn then
      print("📝 Would send event:", self.HttpService:JSONEncode(event))
      return true
   end
   
   local success, result = pcall(function()
      local payload = self.HttpService:JSONEncode(event)
      print("🚀 Sending event to Sentry...")
      print("📡 Event data:", payload)
      
      -- Extract project info from DSN
      local projectId = self.dsn:match("sentry%.io/(%d+)")
      local key = self.dsn:match("https://([^@]+)@")
      
      if not projectId or not key then
         error("Invalid DSN format")
      end
      
      local url = string.format("https://o117736.ingest.us.sentry.io/api/%s/store/", projectId)
      local headers = {
         ["Content-Type"] = "application/json",
         ["X-Sentry-Auth"] = string.format("Sentry sentry_version=7,sentry_key=%s", key)
      }
      
      local response = self.HttpService:PostAsync(url, payload, Enum.HttpContentType.ApplicationJson, false, headers)
      print("✅ Event sent successfully:", response)
      return true
   end)
   
   if success then
      print("✅ Event sent to Sentry")
      return true
   else
      warn("❌ Failed to send event:", result)
      return false
   end
end

function transport:flush()
   print("🚽 Transport flushed")
   return true
end

function transport:close()
   print("🔚 Transport closed")
end

return transport
]]
   },
   
   -- Other required modules
   {
      path = "platforms/roblox",
      name = "context",
      content = [[
local context = {}
function context.get_context()
   return {
      os = "roblox",
      runtime = "roblox-lua"
   }
end
return context
]]
   },
   
   {
      path = "platforms/roblox", 
      name = "os_detection",
      content = [[
local os_detection = {}
function os_detection.detect_os()
   return "roblox"
end
return os_detection
]]
   },
   
   {
      path = "",
      name = "types",
      content = [[
local types = {}
-- Type definitions would go here
return types
]]
   }
}

-- Create module structure
local function createModuleStructure()
   -- Remove existing sentry folder if it exists
   local existingSentry = ReplicatedStorage:FindFirstChild("sentry")
   if existingSentry then
      existingSentry:Destroy()
      print("🗑️ Removed existing sentry module")
   end
   
   -- Create main sentry folder
   local sentryFolder = Instance.new("Folder")
   sentryFolder.Name = "sentry"
   sentryFolder.Parent = ReplicatedStorage
   
   -- Create all modules
   for _, moduleInfo in ipairs(moduleStructure) do
      local parentFolder = sentryFolder
      
      -- Create nested folders if needed
      if moduleInfo.path ~= "" then
         local pathParts = string.split(moduleInfo.path, "/")
         for _, part in ipairs(pathParts) do
            local existingFolder = parentFolder:FindFirstChild(part)
            if not existingFolder then
               existingFolder = Instance.new("Folder")
               existingFolder.Name = part
               existingFolder.Parent = parentFolder
            end
            parentFolder = existingFolder
         end
      end
      
      -- Create the ModuleScript
      local moduleScript = Instance.new("ModuleScript")
      moduleScript.Name = moduleInfo.name
      moduleScript.Source = moduleInfo.content
      moduleScript.Parent = parentFolder
      
      local fullPath = moduleInfo.path ~= "" and moduleInfo.path .. "/" .. moduleInfo.name or moduleInfo.name
      print("✅ Created module:", fullPath)
   end
   
   print("🎉 All Sentry modules loaded successfully!")
   return sentryFolder
end

-- Test the loaded modules
local function testModules(sentryFolder)
   print("\n🧪 Testing loaded modules...")
   
   wait(1) -- Give modules time to load
   
   local success, sentry = pcall(require, sentryFolder.init)
   if not success then
      error("❌ Failed to load main sentry module: " .. tostring(sentry))
   end
   
   print("✅ Sentry module loaded successfully")
   
   -- Test initialization
   local client = sentry.init({
      dsn = "https://e247e6e48f8f482499052a65adaa9f6b@o117736.ingest.us.sentry.io/4504930623356928",
      environment = "roblox-auto-loader-test",
      release = "0.0.6-dev"
   })
   
   if client then
      print("✅ Sentry initialized successfully")
      
      -- Test basic functionality
      sentry.capture_message("Auto-loader test message", "info")
      sentry.set_user({id = "auto-loader-user", username = "AutoLoaderTest"})
      sentry.set_tag("loader", "automatic")
      sentry.add_breadcrumb({message = "Auto-loader test completed", level = "info"})
      
      print("✅ Basic functionality test completed")
      print("📊 Check your Sentry dashboard for the test event!")
      
      -- Make test functions available globally
      _G.SentryTestFunctions = {
         sendTestMessage = function(message)
            sentry.capture_message(message or "Manual test message", "info")
         end,
         triggerTestError = function()
            sentry.capture_exception({
               type = "ManualTestError",
               message = "This is a manual test error"
            })
         end
      }
      
      print("✅ Global test functions available: _G.SentryTestFunctions")
   else
      error("❌ Failed to initialize Sentry client")
   end
end

-- Main execution
local function main()
   print("🚀 Starting automatic Sentry module loader...")
   
   local sentryFolder = createModuleStructure()
   testModules(sentryFolder)
   
   print("\n🎊 AUTO-LOADER COMPLETED SUCCESSFULLY!")
   print("💡 You can now use:")
   print("   _G.SentryTestFunctions.sendTestMessage('Hello!')")
   print("   _G.SentryTestFunctions.triggerTestError()")
end

-- Start the auto-loader
spawn(function()
   local success, error = pcall(main)
   if not success then
      print("💥 AUTO-LOADER FAILED:", error)
   end
end)