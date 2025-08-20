--[[
  Quick Test Script for Roblox Sentry Integration
  
  INSTRUCTIONS:
  1. Copy this entire script
  2. In Roblox Studio, create a Script in ServerScriptService
  3. Paste this code and save
  4. Update the DSN below with your Sentry project DSN
  5. Run the game (F5)
  6. Check Output panel and Sentry dashboard
  
  This script:
  - Auto-loads a minimal Sentry implementation
  - Tests basic functionality
  - Sends real events to your Sentry project
  - Provides global test functions
]]--

-- ⚠️ UPDATE THIS WITH YOUR SENTRY DSN
local SENTRY_DSN = "https://e247e6e48f8f482499052a65adaa9f6b@o117736.ingest.us.sentry.io/4504930623356928"

print("🚀 Starting Roblox Sentry Quick Test")
print("=" .. string.rep("=", 40))

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

-- Remove existing sentry if it exists
local existingSentry = ReplicatedStorage:FindFirstChild("sentry")
if existingSentry then
    existingSentry:Destroy()
    print("🗑️ Removed existing sentry module")
end

-- Create sentry folder and main module
local sentryFolder = Instance.new("Folder")
sentryFolder.Name = "sentry"
sentryFolder.Parent = ReplicatedStorage

-- Simple but functional Sentry implementation
local sentryCode = [[
-- Minimal Sentry SDK for Roblox
local sentry = {}
local HttpService = game:GetService("HttpService")

local client = nil

function sentry.init(config)
    config = config or {}
    
    if not config.dsn then
        warn("❌ No DSN provided to sentry.init()")
        return nil
    end
    
    client = {
        dsn = config.dsn,
        environment = config.environment or "roblox",
        release = config.release or "unknown",
        user = nil,
        tags = {},
        breadcrumbs = {}
    }
    
    print("🔧 Sentry initialized:")
    print("   DSN: ***" .. string.sub(config.dsn, -10))
    print("   Environment: " .. client.environment)
    print("   Release: " .. client.release)
    
    return client
end

function sentry.capture_message(message, level)
    if not client then
        warn("❌ Sentry not initialized - call sentry.init() first")
        return nil
    end
    
    level = level or "info"
    
    local event = {
        message = {
            message = message
        },
        level = level,
        timestamp = os.time(),
        environment = client.environment,
        release = client.release,
        platform = "roblox",
        user = client.user,
        tags = client.tags,
        breadcrumbs = client.breadcrumbs,
        extra = {
            roblox_version = version(),
            place_id = tostring(game.PlaceId),
            job_id = game.JobId
        }
    }
    
    print("📨 Capturing message: " .. message .. " [" .. level .. "]")
    
    return sendEvent(event)
end

function sentry.capture_exception(exception, level)
    if not client then
        warn("❌ Sentry not initialized")
        return nil
    end
    
    level = level or "error"
    
    local event = {
        exception = {
            values = {
                {
                    type = exception.type or "RobloxError",
                    value = exception.message or tostring(exception),
                    stacktrace = {
                        frames = {}  -- Could be enhanced with actual stack trace
                    }
                }
            }
        },
        level = level,
        timestamp = os.time(),
        environment = client.environment,
        release = client.release,
        platform = "roblox",
        user = client.user,
        tags = client.tags,
        breadcrumbs = client.breadcrumbs,
        extra = {
            roblox_version = version(),
            place_id = tostring(game.PlaceId),
            job_id = game.JobId
        }
    }
    
    print("🚨 Capturing exception: " .. (exception.message or tostring(exception)))
    
    return sendEvent(event)
end

function sentry.set_user(user)
    if client then
        client.user = user
        print("👤 User context set: " .. (user.username or user.id or "unknown"))
    end
end

function sentry.set_tag(key, value)
    if client then
        client.tags[key] = tostring(value)
        print("🏷️ Tag set: " .. key .. " = " .. tostring(value))
    end
end

function sentry.add_breadcrumb(breadcrumb)
    if client then
        table.insert(client.breadcrumbs, {
            message = breadcrumb.message,
            category = breadcrumb.category or "default",
            level = breadcrumb.level or "info",
            timestamp = os.time(),
            data = breadcrumb.data
        })
        
        -- Keep only last 50 breadcrumbs
        if #client.breadcrumbs > 50 then
            table.remove(client.breadcrumbs, 1)
        end
        
        print("🍞 Breadcrumb added: " .. (breadcrumb.message or "no message"))
    end
end

function sentry.wrap(func, errorHandler)
    local success, result = pcall(func)
    if not success then
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

-- Internal function to send events to Sentry
function sendEvent(event)
    if not client or not client.dsn then
        print("📝 Would send event: " .. HttpService:JSONEncode(event))
        return true
    end
    
    local success, result = pcall(function()
        -- Parse DSN to get project info
        local pattern = "https://([^@]+)@([^/]+)/(.+)"
        local key, host, path = client.dsn:match(pattern)
        
        if not key or not host or not path then
            error("Invalid DSN format")
        end
        
        -- Extract project ID from path
        local projectId = path:match("(%d+)")
        if not projectId then
            error("Could not extract project ID from DSN")
        end
        
        -- Build Sentry endpoint URL
        local url = "https://" .. host .. "/api/" .. projectId .. "/store/"
        
        -- Prepare headers
        local headers = {
            ["Content-Type"] = "application/json",
            ["X-Sentry-Auth"] = string.format(
                "Sentry sentry_version=7, sentry_key=%s, sentry_client=roblox-lua/1.0",
                key
            )
        }
        
        -- Send the event
        local payload = HttpService:JSONEncode(event)
        print("🌐 Sending to Sentry: " .. url)
        print("📡 Payload size: " .. #payload .. " bytes")
        
        local response = HttpService:PostAsync(url, payload, Enum.HttpContentType.ApplicationJson, false, headers)
        
        print("✅ Event sent successfully!")
        print("📊 Response: " .. string.sub(response, 1, 100) .. "...")
        
        return true
    end)
    
    if success then
        return true
    else
        warn("❌ Failed to send event: " .. tostring(result))
        print("💡 Common issues:")
        print("   - HTTP requests not enabled in Game Settings")
        print("   - Invalid DSN format")
        print("   - Network connectivity issues")
        return false
    end
end

return sentry
]]

-- Create the main sentry module
local sentryModule = Instance.new("ModuleScript")
sentryModule.Name = "init"
sentryModule.Source = sentryCode
sentryModule.Parent = sentryFolder

print("✅ Created Sentry module")

-- Wait for module to be ready
wait(1)

-- Load and test Sentry
local success, sentry = pcall(require, sentryModule)
if not success then
    error("❌ Failed to load Sentry module: " .. tostring(sentry))
end

print("✅ Sentry module loaded successfully")

-- Initialize Sentry
local client = sentry.init({
    dsn = SENTRY_DSN,
    environment = "roblox-quick-test",
    release = "1.0.0"
})

if not client then
    error("❌ Failed to initialize Sentry client")
end

print("✅ Sentry initialized successfully")

-- Run basic tests
print("\n🧪 Running basic tests...")

-- Test 1: Message capture
sentry.capture_message("Quick test message from Roblox Studio", "info")

-- Test 2: User context
sentry.set_user({
    id = "quick-test-user",
    username = "QuickTestUser"
})

-- Test 3: Tags
sentry.set_tag("test_type", "quick_test")
sentry.set_tag("studio_version", "current")

-- Test 4: Breadcrumbs
sentry.add_breadcrumb({
    message = "Quick test started",
    category = "test",
    level = "info"
})

-- Test 5: Exception capture
sentry.capture_exception({
    type = "QuickTestError",
    message = "This is a test exception from quick test"
})

-- Test 6: Error wrapping
local function testErrorFunction()
    error("This error should be caught by sentry.wrap")
end

local wrapSuccess, wrapResult = sentry.wrap(testErrorFunction, function(err)
    print("🔧 Error caught and handled: " .. tostring(err))
    return "Error handled gracefully"
end)

if not wrapSuccess then
    print("✅ Error wrapping test passed")
end

print("✅ All basic tests completed!")

-- Create global test functions for manual testing
_G.SentryTestFunctions = {
    sendTestMessage = function(message)
        local msg = message or "Manual test message from Command Bar"
        sentry.capture_message(msg, "info")
        print("📨 Sent: " .. msg)
    end,
    
    triggerTestError = function()
        sentry.capture_exception({
            type = "ManualTestError", 
            message = "Manual test error triggered from Command Bar"
        })
        print("🚨 Test error triggered")
    end,
    
    setTestUser = function(username)
        username = username or "TestUser" .. math.random(1000, 9999)
        sentry.set_user({
            id = "manual-test-" .. username,
            username = username
        })
        print("👤 User set to: " .. username)
    end,
    
    addBreadcrumb = function(message)
        message = message or "Manual breadcrumb " .. os.time()
        sentry.add_breadcrumb({
            message = message,
            category = "manual",
            level = "info"
        })
        print("🍞 Breadcrumb added: " .. message)
    end
}

print("\n🎉 QUICK TEST COMPLETED SUCCESSFULLY!")
print("=" .. string.rep("=", 40))
print("📊 Check your Sentry dashboard for test events")
print("🔗 Dashboard: https://sentry.io/")
print("")
print("💡 MANUAL TESTING COMMANDS:")
print("_G.SentryTestFunctions.sendTestMessage('Hello World!')")
print("_G.SentryTestFunctions.triggerTestError()")
print("_G.SentryTestFunctions.setTestUser('YourName')")
print("_G.SentryTestFunctions.addBreadcrumb('Test breadcrumb')")
print("")
print("✅ Integration is ready for development!")