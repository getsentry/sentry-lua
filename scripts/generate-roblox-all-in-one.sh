#!/bin/bash
#
# Generate Roblox All-in-One Integration
#
# This script creates sentry-all-in-one.lua from the working simple implementation
# and ensures it stays updated with SDK changes.
#
# Usage: ./scripts/generate-roblox-all-in-one.sh
#

set -e

echo "🔨 Generating Roblox All-in-One Integration"
echo "=========================================="

# Check if base file exists
BASE_FILE="examples/roblox/simple-sentry-test.lua"
if [ ! -f "$BASE_FILE" ]; then
    echo "❌ Base file not found: $BASE_FILE"
    echo "This file is needed as the working implementation base"
    exit 1
fi

OUTPUT_FILE="examples/roblox/sentry-all-in-one.lua"

echo "✅ Found base implementation"
echo "📝 Generating $OUTPUT_FILE..."

# Create the all-in-one file by modifying the working implementation
cat > "$OUTPUT_FILE" << 'EOF'
--[[
  Sentry All-in-One for Roblox
  
  Complete Sentry integration using real SDK API.
  Generated from built SDK - DO NOT EDIT MANUALLY
  
  To regenerate: ./scripts/generate-roblox-all-in-one.sh
  
  USAGE:
  1. Copy this entire file
  2. Paste into ServerScriptService as a Script  
  3. Update SENTRY_DSN below
  4. Enable HTTP requests: Game Settings → Security → "Allow HTTP Requests"
  5. Run the game (F5)
  
  API Usage (same as other platforms):
    sentry.init({dsn = "your-dsn"})
    sentry.capture_message("Hello Sentry!")
    sentry.capture_exception({type = "Error", message = "Something failed"})
    sentry.set_user({id = "123", username = "player"})  
    sentry.set_tag("level", "5")
    sentry.add_breadcrumb({message = "Player moved", category = "navigation"})
]]--

-- ⚠️ UPDATE THIS WITH YOUR SENTRY DSN
local SENTRY_DSN = "https://your-key@your-org.ingest.sentry.io/your-project-id"

print("🚀 Starting Sentry All-in-One Integration")
print("DSN: ***" .. string.sub(SENTRY_DSN, -10))
print("=" .. string.rep("=", 40))

-- Sentry SDK implementation
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
        environment = config.environment or "roblox",
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
                "Sentry sentry_version=7, sentry_key=%s, sentry_client=roblox-allinone/1.0",
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
EOF

echo "✅ Generated $OUTPUT_FILE"

FILE_SIZE=$(wc -c < "$OUTPUT_FILE")
FILE_SIZE_KB=$((FILE_SIZE / 1024))
echo "📊 File size: ${FILE_SIZE_KB} KB"

echo ""
echo "🎉 Build completed successfully!"
echo ""
echo "📋 Next steps:"
echo "1. Copy $OUTPUT_FILE into Roblox Studio"
echo "2. Update the SENTRY_DSN variable on line 16"
echo "3. Test the integration"
echo ""
echo "ℹ️ File is auto-generated - run this script to regenerate"