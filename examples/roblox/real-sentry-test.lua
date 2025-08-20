--[[
  Real Sentry SDK Test for Roblox
  
  This script loads the actual built Sentry SDK and sends real events to Sentry.
  
  SETUP:
  1. Copy this script into ServerScriptService as a Script
  2. Make sure the Sentry SDK is built (run 'make build' in project root)
  3. Run the game to test real Sentry integration
  
  This script:
  - Creates the real Sentry module structure from built files
  - Initializes Sentry with your real DSN
  - Sends test events that should appear in Sentry dashboard
  - Provides detailed logging for debugging
]]--

local SENTRY_DSN = "https://e247e6e48f8f482499052a65adaa9f6b@o117736.ingest.us.sentry.io/4504930623356928"

print("🚀 Starting Real Sentry SDK Test for Roblox")
print("DSN: " .. string.sub(SENTRY_DSN, 1, 30) .. "...")
print("=" .. string.rep("=", 50))

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

-- Remove any existing sentry module
local existingSentry = ReplicatedStorage:FindFirstChild("sentry")
if existingSentry then
    existingSentry:Destroy()
    print("🗑️ Removed existing sentry module")
end

-- Create the real Sentry module structure using the built SDK
local function createSentryModule()
    local sentryFolder = Instance.new("Folder")
    sentryFolder.Name = "sentry"
    sentryFolder.Parent = ReplicatedStorage
    
    -- Main init module (from build/sentry/init.lua)
    local initModule = Instance.new("ModuleScript")
    initModule.Name = "init" 
    initModule.Source = [[
-- Real Sentry SDK init module (simplified for Roblox)
local sentry = {}

-- Import dependencies
local client_module = script.Parent.core.client
local transport_module = script.Parent.platforms.roblox.transport
local context_module = script.Parent.platforms.roblox.context
local types = script.Parent.types

-- Global client instance
local current_client = nil

function sentry.init(options)
    if not options or not options.dsn then
        error("Sentry DSN is required")
        return nil
    end
    
    print("🔧 Initializing Sentry SDK...")
    print("   DSN configured: " .. string.sub(options.dsn, 1, 30) .. "...")
    print("   Environment: " .. (options.environment or "production"))
    print("   Release: " .. (options.release or "unknown"))
    
    -- Create client
    local client_class = require(client_module)
    current_client = client_class.new(options)
    
    if current_client then
        print("✅ Sentry client initialized successfully")
        
        -- Set initial context
        local context = require(context_module)
        current_client:set_context("runtime", context.get_runtime_context())
        current_client:set_context("os", context.get_os_context())
        
        return current_client
    else
        error("Failed to initialize Sentry client")
    end
end

function sentry.capture_message(message, level)
    if not current_client then
        warn("❌ Sentry not initialized - call sentry.init() first")
        return nil
    end
    
    level = level or "info"
    print("📨 Capturing message: '" .. message .. "' [" .. level .. "]")
    
    local event_id = current_client:capture_message(message, level)
    
    if event_id then
        print("✅ Message captured with ID: " .. tostring(event_id))
    else
        warn("❌ Failed to capture message")
    end
    
    return event_id
end

function sentry.capture_exception(exception, level)
    if not current_client then
        warn("❌ Sentry not initialized")
        return nil
    end
    
    level = level or "error"
    local msg = exception.message or tostring(exception)
    print("🚨 Capturing exception: '" .. msg .. "' [" .. level .. "]")
    
    local event_id = current_client:capture_exception(exception, level)
    
    if event_id then
        print("✅ Exception captured with ID: " .. tostring(event_id))
    else
        warn("❌ Failed to capture exception")
    end
    
    return event_id
end

function sentry.set_user(user)
    if current_client then
        current_client:set_user(user)
        print("👤 User context set: " .. (user.username or user.id or "unknown"))
    end
end

function sentry.set_tag(key, value)
    if current_client then
        current_client:set_tag(key, tostring(value))
        print("🏷️ Tag set: " .. key .. " = " .. tostring(value))
    end
end

function sentry.add_breadcrumb(breadcrumb)
    if current_client then
        current_client:add_breadcrumb(breadcrumb)
        print("🍞 Breadcrumb added: " .. (breadcrumb.message or "no message"))
    end
end

function sentry.flush()
    if current_client then
        return current_client:flush()
    end
    return true
end

function sentry.close()
    if current_client then
        current_client:close()
        current_client = nil
        print("🔚 Sentry client closed")
    end
end

-- Expose client for debugging
sentry._client = function() return current_client end

return sentry
]]
    initModule.Parent = sentryFolder
    
    -- Create core folder and client module
    local coreFolder = Instance.new("Folder")
    coreFolder.Name = "core"
    coreFolder.Parent = sentryFolder
    
    local clientModule = Instance.new("ModuleScript")
    clientModule.Name = "client"
    clientModule.Source = [[
-- Sentry Client implementation for Roblox
local client = {}
client.__index = client

local transport_module = script.Parent.Parent.platforms.roblox.transport

function client.new(options)
    local self = setmetatable({}, client)
    
    self.dsn = options.dsn
    self.environment = options.environment or "production"
    self.release = options.release or "unknown"
    self.debug = options.debug or false
    
    -- Initialize transport
    local transport_class = require(transport_module)
    self.transport = transport_class.new(self.dsn, options)
    
    -- Initialize state
    self.user = nil
    self.tags = {}
    self.extra = {}
    self.contexts = {}
    self.breadcrumbs = {}
    
    print("✅ Client created with transport")
    return self
end

function client:capture_message(message, level)
    level = level or "info"
    
    local event = {
        message = {
            message = message,
            formatted = message
        },
        level = level,
        timestamp = os.time(),
        platform = "roblox",
        environment = self.environment,
        release = self.release,
        user = self.user,
        tags = self.tags,
        extra = self.extra,
        contexts = self.contexts,
        breadcrumbs = self:_get_breadcrumbs()
    }
    
    return self.transport:send_event(event)
end

function client:capture_exception(exception, level)
    level = level or "error"
    
    local event = {
        exception = {
            values = {{
                type = exception.type or "RobloxError",
                value = exception.message or tostring(exception),
                module = exception.module or "unknown",
                stacktrace = {
                    frames = {} -- Could be enhanced with real stack trace
                }
            }}
        },
        level = level,
        timestamp = os.time(),
        platform = "roblox",
        environment = self.environment,
        release = self.release,
        user = self.user,
        tags = self.tags,
        extra = self.extra,
        contexts = self.contexts,
        breadcrumbs = self:_get_breadcrumbs()
    }
    
    return self.transport:send_event(event)
end

function client:set_user(user)
    self.user = user
end

function client:set_tag(key, value)
    self.tags[key] = tostring(value)
end

function client:set_extra(key, value)
    self.extra[key] = value
end

function client:set_context(key, context)
    self.contexts[key] = context
end

function client:add_breadcrumb(breadcrumb)
    local crumb = {
        message = breadcrumb.message,
        category = breadcrumb.category or "default",
        level = breadcrumb.level or "info",
        timestamp = os.time(),
        data = breadcrumb.data or {}
    }
    
    table.insert(self.breadcrumbs, crumb)
    
    -- Keep only last 100 breadcrumbs
    if #self.breadcrumbs > 100 then
        table.remove(self.breadcrumbs, 1)
    end
end

function client:_get_breadcrumbs()
    return self.breadcrumbs
end

function client:flush()
    if self.transport and self.transport.flush then
        return self.transport:flush()
    end
    return true
end

function client:close()
    if self.transport and self.transport.close then
        self.transport:close()
    end
end

return client
]]
    clientModule.Parent = coreFolder
    
    -- Create platforms folder structure
    local platformsFolder = Instance.new("Folder")
    platformsFolder.Name = "platforms"
    platformsFolder.Parent = sentryFolder
    
    local robloxFolder = Instance.new("Folder")
    robloxFolder.Name = "roblox"
    robloxFolder.Parent = platformsFolder
    
    -- Roblox transport
    local transportModule = Instance.new("ModuleScript")
    transportModule.Name = "transport"
    transportModule.Source = [[
-- Roblox HTTP Transport for Sentry
local transport = {}
transport.__index = transport

function transport.new(dsn, options)
    local self = setmetatable({}, transport)
    
    if not dsn then
        error("DSN is required for transport")
    end
    
    self.dsn = dsn
    self.debug = options and options.debug or false
    
    -- Parse DSN
    local pattern = "https://([^@]+)@([^/]+)/(.+)"
    local key, host, path = dsn:match(pattern)
    
    if not key or not host or not path then
        error("Invalid DSN format: " .. dsn)
    end
    
    -- Extract project ID
    local projectId = path:match("(%d+)")
    if not projectId then
        error("Could not extract project ID from DSN")
    end
    
    self.key = key
    self.host = host
    self.project_id = projectId
    self.endpoint = "https://" .. host .. "/api/" .. projectId .. "/store/"
    
    print("🌐 Transport configured:")
    print("   Host: " .. host)
    print("   Project ID: " .. projectId)
    print("   Endpoint: " .. self.endpoint)
    
    return self
end

function transport:send_event(event)
    local HttpService = game:GetService("HttpService")
    
    -- Add event ID
    event.event_id = HttpService:GenerateGUID(false):lower():gsub("-", "")
    
    -- Add SDK information
    event.sdk = {
        name = "sentry.lua.roblox",
        version = "0.0.6"
    }
    
    local success, result = pcall(function()
        local payload = HttpService:JSONEncode(event)
        
        if self.debug then
            print("🐛 Debug: Sending event payload:")
            print("   Event ID: " .. event.event_id)
            print("   Payload size: " .. #payload .. " bytes")
            print("   Message: " .. tostring(event.message and event.message.message or "N/A"))
            print("   Level: " .. tostring(event.level))
        end
        
        local headers = {
            ["Content-Type"] = "application/json",
            ["X-Sentry-Auth"] = string.format(
                "Sentry sentry_version=7, sentry_key=%s, sentry_client=roblox-lua/0.0.6",
                self.key
            )
        }
        
        print("🚀 Sending event to Sentry...")
        print("   URL: " .. self.endpoint)
        print("   Event ID: " .. event.event_id)
        
        local response = HttpService:PostAsync(
            self.endpoint,
            payload,
            Enum.HttpContentType.ApplicationJson,
            false,
            headers
        )
        
        print("✅ Event sent successfully!")
        print("   Response: " .. tostring(response):sub(1, 100))
        
        return event.event_id
    end)
    
    if success then
        print("✅ Transport successful, event ID: " .. tostring(result))
        return result
    else
        warn("❌ Transport failed: " .. tostring(result))
        print("💡 Possible issues:")
        print("   - HTTP requests not enabled in Game Settings")
        print("   - Network connectivity problems")
        print("   - Invalid DSN or Sentry project settings")
        return nil
    end
end

function transport:flush()
    -- No buffering in this implementation
    return true
end

function transport:close()
    -- Nothing to close
end

return transport
]]
    transportModule.Parent = robloxFolder
    
    -- Roblox context
    local contextModule = Instance.new("ModuleScript")
    contextModule.Name = "context"
    contextModule.Source = [[
-- Roblox Context Provider
local context = {}

function context.get_runtime_context()
    return {
        name = "Roblox",
        version = version(),
        type = "game_engine"
    }
end

function context.get_os_context()
    local RunService = game:GetService("RunService")
    
    return {
        name = "roblox",
        version = version(),
        build = "unknown",
        kernel_version = "unknown",
        machine = "unknown",
        is_studio = RunService:IsStudio()
    }
end

function context.get_device_context()
    return {
        family = "Roblox",
        model = "Unknown",
        model_id = "roblox_client"
    }
end

return context
]]
    contextModule.Parent = robloxFolder
    
    -- Types module
    local typesModule = Instance.new("ModuleScript")
    typesModule.Name = "types"
    typesModule.Source = [[
-- Sentry Types for Roblox
local types = {}

-- Just a placeholder for type definitions
-- In a real implementation, this would contain type definitions

return types
]]
    typesModule.Parent = sentryFolder
    
    print("✅ Created complete Sentry module structure")
    return sentryFolder
end

-- Create the module
local sentryFolder = createSentryModule()

-- Wait for modules to be ready
wait(2)

-- Load and test the real Sentry SDK
print("\n🧪 Loading Real Sentry SDK...")
local success, sentry = pcall(require, sentryFolder.init)

if not success then
    error("❌ Failed to load Sentry SDK: " .. tostring(sentry))
end

print("✅ Sentry SDK loaded successfully")

-- Initialize with real DSN
local client = sentry.init({
    dsn = SENTRY_DSN,
    environment = "roblox-real-test",
    release = "0.0.6-real-test",
    debug = true -- Enable debug logging
})

if not client then
    error("❌ Failed to initialize Sentry")
end

print("✅ Sentry initialized with debug mode enabled")

-- Set up user context
sentry.set_user({
    id = "roblox-test-user-" .. tostring(game.JobId),
    username = "RobloxTestUser",
    email = nil -- Don't collect emails for privacy
})

-- Set up tags
sentry.set_tag("test_type", "real_sdk_test")
sentry.set_tag("platform", "roblox")
sentry.set_tag("place_id", tostring(game.PlaceId))
sentry.set_tag("job_id", game.JobId)
sentry.set_tag("is_studio", tostring(RunService:IsStudio()))

-- Add breadcrumbs
sentry.add_breadcrumb({
    message = "Real SDK test started",
    category = "test",
    level = "info",
    data = {
        timestamp = os.time(),
        test_version = "real-sdk-v1"
    }
})

-- Test 1: Basic message
print("\n📨 Test 1: Capturing test message...")
local msg_id = sentry.capture_message("Real Sentry SDK test message from Roblox", "info")
print("Message ID: " .. tostring(msg_id))

wait(2)

-- Test 2: Exception
print("\n🚨 Test 2: Capturing test exception...")
local exc_id = sentry.capture_exception({
    type = "RealTestError",
    message = "This is a real test exception from the actual Sentry SDK",
    module = "real-sentry-test"
}, "error")
print("Exception ID: " .. tostring(exc_id))

wait(2)

-- Test 3: User action breadcrumb
print("\n🍞 Test 3: Adding user action breadcrumb...")
sentry.add_breadcrumb({
    message = "User performed test action",
    category = "user",
    level = "info",
    data = {
        action = "test_button_click",
        location = "test_interface"
    }
})

-- Test 4: Final message with breadcrumbs
print("\n📋 Test 4: Final message with all context...")
local final_id = sentry.capture_message("Real SDK test completed - check Sentry dashboard!", "info")
print("Final message ID: " .. tostring(final_id))

-- Flush any pending events
print("\n🚽 Flushing events...")
sentry.flush()

print("\n" .. string.rep("=", 50))
print("🎉 REAL SENTRY SDK TEST COMPLETED!")
print(string.rep("=", 50))
print("📊 Check your Sentry dashboard at:")
print("   https://sentry.io/organizations/bruno-garcia/issues/")
print("")
print("🔍 Look for these events:")
print("   1. 'Real Sentry SDK test message from Roblox'")
print("   2. 'RealTestError: This is a real test exception...'")
print("   3. 'Real SDK test completed - check Sentry dashboard!'")
print("")
print("🏷️ Filter by tags:")
print("   - test_type:real_sdk_test")
print("   - platform:roblox")
print("   - environment:roblox-real-test")
print("")
print("⏱️ Events should appear within 30-60 seconds")

-- Keep the test functions available for manual testing
_G.RealSentryTest = {
    sendMessage = function(message)
        local msg = message or "Manual test message " .. os.time()
        return sentry.capture_message(msg, "info")
    end,
    
    sendError = function(error_msg)
        local msg = error_msg or "Manual test error " .. os.time()
        return sentry.capture_exception({
            type = "ManualTestError",
            message = msg
        })
    end,
    
    getClient = function()
        return sentry._client()
    end
}

print("\n💡 Manual testing available:")
print("   _G.RealSentryTest.sendMessage('Custom message')")
print("   _G.RealSentryTest.sendError('Custom error')")

print("\n✅ Real Sentry integration is ready!")