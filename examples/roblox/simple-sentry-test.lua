--[[
  Simple Sentry Test Script for Roblox (No Module Creation)
  
  This version works around Roblox's security restrictions by embedding
  everything directly in the script without creating ModuleScripts.
  
  INSTRUCTIONS:
  1. Copy this entire script
  2. In Roblox Studio, create a Script in ServerScriptService  
  3. Paste this code and save
  4. Enable HTTP: Game Settings → Security → "Allow HTTP Requests"
  5. Run the game (F5)
  6. Check Output panel and Sentry dashboard
]]--

-- ⚠️ UPDATE THIS WITH YOUR SENTRY DSN
local SENTRY_DSN = "https://e247e6e48f8f482499052a65adaa9f6b@o117736.ingest.us.sentry.io/4504930623356928"

print("🚀 Starting Simple Roblox Sentry Test")
print("DSN: ***" .. string.sub(SENTRY_DSN, -10))
print("=" .. string.rep("=", 40))

local HttpService = game:GetService("HttpService")

-- Simple Sentry implementation (no module creation needed)
local sentry = {}
local client = nil

function sentry.init(config)
    config = config or {}
    
    if not config.dsn then
        warn("❌ No DSN provided to sentry.init()")
        return nil
    end
    
    client = {
        dsn = config.dsn,
        environment = config.environment or "roblox-simple",
        release = config.release or "1.0.0",
        user = nil,
        tags = {},
        breadcrumbs = {}
    }
    
    print("🔧 Sentry initialized successfully")
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
        server_name = "roblox-server",
        user = client.user,
        tags = client.tags,
        breadcrumbs = client.breadcrumbs,
        extra = {
            roblox_version = version(),
            place_id = tostring(game.PlaceId),
            job_id = game.JobId or "unknown"
        }
    }
    
    print("📨 Capturing message: " .. message .. " [" .. level .. "]")
    
    return sendEventToSentry(event)
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
                        frames = {}
                    }
                }
            }
        },
        level = level,
        timestamp = os.time(),
        environment = client.environment,
        release = client.release,
        platform = "roblox",
        server_name = "roblox-server",
        user = client.user,
        tags = client.tags,
        breadcrumbs = client.breadcrumbs,
        extra = {
            roblox_version = version(),
            place_id = tostring(game.PlaceId),
            job_id = game.JobId or "unknown"
        }
    }
    
    print("🚨 Capturing exception: " .. (exception.message or tostring(exception)))
    
    return sendEventToSentry(event)
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

-- Internal function to send events to Sentry
function sendEventToSentry(event)
    if not client or not client.dsn then
        print("📝 Would send event (no DSN): " .. HttpService:JSONEncode(event))
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
        
        -- Prepare headers (without Content-Type as Roblox doesn't allow it)
        local headers = {
            ["X-Sentry-Auth"] = string.format(
                "Sentry sentry_version=7, sentry_key=%s, sentry_client=roblox-simple/1.0",
                key
            )
        }
        
        -- Send the event
        local payload = HttpService:JSONEncode(event)
        print("🌐 Sending to Sentry: " .. url)
        print("📡 Payload size: " .. #payload .. " bytes")
        
        local response = HttpService:PostAsync(url, payload, Enum.HttpContentType.ApplicationJson, false, headers)
        
        print("✅ Event sent successfully!")
        print("📊 Response: " .. string.sub(response or "no response", 1, 50) .. "...")
        
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

-- Initialize Sentry
print("\n🔧 Initializing Sentry...")
local sentryClient = sentry.init({
    dsn = SENTRY_DSN,
    environment = "roblox-simple-test",
    release = "1.0.0"
})

if not sentryClient then
    error("❌ Failed to initialize Sentry client")
end

-- Run basic tests
print("\n🧪 Running basic tests...")

-- Test 1: Message capture
sentry.capture_message("Simple test message from Roblox Studio", "info")

-- Test 2: User context
sentry.set_user({
    id = "simple-test-user",
    username = "SimpleTestUser"
})

-- Test 3: Tags
sentry.set_tag("test_type", "simple_test")
sentry.set_tag("studio_version", "current")

-- Test 4: Breadcrumbs
sentry.add_breadcrumb({
    message = "Simple test started",
    category = "test",
    level = "info"
})

-- Test 5: Exception capture
sentry.capture_exception({
    type = "SimpleTestError",
    message = "This is a test exception from simple test"
})

-- Create global test functions for manual testing
-- Wait a frame to ensure everything is loaded
game:GetService("RunService").Heartbeat:Wait()

_G.SimpleSentryTest = {
    sendMessage = function(message)
        local msg = message or "Manual test message from Command Bar"
        sentry.capture_message(msg, "info")
        print("📨 Sent: " .. msg)
    end,
    
    triggerError = function()
        sentry.capture_exception({
            type = "ManualTestError", 
            message = "Manual test error triggered from Command Bar"
        })
        print("🚨 Test error triggered")
    end,
    
    setUser = function(username)
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

-- Debug: Check if global was set properly
print("🔍 _G.SimpleSentryTest =", _G.SimpleSentryTest)
print("🔍 Available functions:", _G.SimpleSentryTest and "✅" or "❌")

print("\n🎉 SIMPLE TEST COMPLETED!")
print("=" .. string.rep("=", 40))
print("📊 Check your Sentry dashboard for test events")
print("🔗 Dashboard: https://sentry.io/")
print("")
print("💡 MANUAL TESTING COMMANDS:")
print("_G.SimpleSentryTest.sendMessage('Hello World!')")
print("_G.SimpleSentryTest.triggerError()")
print("_G.SimpleSentryTest.setUser('YourName')")
print("_G.SimpleSentryTest.addBreadcrumb('Test breadcrumb')")
print("")
print("✅ Simple integration is ready!")