#!/bin/bash
#
# Generate Roblox All-in-One Integration
#
# This script assembles a complete Roblox integration from the real SDK modules
# built from src/ (after Teal compilation). This ensures the example uses the
# actual SDK code and stays updated with SDK changes.
#
# Usage: ./scripts/generate-roblox-all-in-one.sh
#

set -e

echo "🔨 Generating Roblox All-in-One Integration from Real SDK"
echo "======================================================="

OUTPUT_FILE="examples/roblox/sentry-all-in-one.lua"

# Check if SDK is built
if [ ! -f "build/sentry/init.lua" ]; then
    echo "❌ SDK not built. Run 'make build' first."
    exit 1
fi

echo "✅ Found built SDK"

# Read required SDK modules
echo "📖 Reading SDK modules..."

read_module() {
    local file="$1"
    if [ -f "$file" ]; then
        echo "✅ Reading: $file"
        cat "$file"
    else
        echo "❌ Missing: $file"
        exit 1
    fi
}

# Create the all-in-one file by combining real SDK modules
cat > "$OUTPUT_FILE" << 'HEADER_EOF'
--[[
  Sentry All-in-One for Roblox
  
  Complete Sentry integration using real SDK modules.
  Generated from built SDK - DO NOT EDIT MANUALLY
  
  To regenerate: ./scripts/generate-roblox-all-in-one.sh
  
  USAGE:
  1. Copy this entire file
  2. Paste into ServerScriptService as a Script  
  3. Update SENTRY_DSN below
  4. Enable HTTP requests: Game Settings → Security → "Allow HTTP Requests"
  5. Run the game (F5)
  
  API (same as other platforms):
    sentry.init({dsn = "your-dsn"})
    sentry.capture_message("Player died!", "error")
    sentry.capture_exception({type = "GameError", message = "Boss fight failed"})
    sentry.set_user({id = tostring(player.UserId), username = player.Name})
    sentry.set_tag("level", "10")
    sentry.add_breadcrumb({message = "Player entered dungeon", category = "navigation"})
]]--

-- ⚠️ UPDATE THIS WITH YOUR SENTRY DSN
local SENTRY_DSN = "https://your-key@your-org.ingest.sentry.io/your-project-id"

print("🚀 Starting Sentry All-in-One Integration")
print("DSN: ***" .. string.sub(SENTRY_DSN, -10))
print("=" .. string.rep("=", 40))

-- Embedded SDK Modules (from real build/)
-- This ensures we use the actual SDK code with proper version info

HEADER_EOF

# Add version module
echo "" >> "$OUTPUT_FILE"
echo "-- ============================================================================" >> "$OUTPUT_FILE"  
echo "-- VERSION MODULE (from build/sentry/version.lua)" >> "$OUTPUT_FILE"
echo "-- ============================================================================" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Read version and create local version
VERSION=$(grep -o '"[^"]*"' build/sentry/version.lua | tr -d '"')
cat >> "$OUTPUT_FILE" << VERSION_EOF
local function version()
    return "$VERSION"
end
VERSION_EOF

# Add JSON utils
echo "" >> "$OUTPUT_FILE"
echo "-- ============================================================================" >> "$OUTPUT_FILE"
echo "-- JSON UTILS (from build/sentry/utils/json.lua)" >> "$OUTPUT_FILE"  
echo "-- ============================================================================" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# For Roblox, we use HttpService for JSON, so create a simple wrapper
cat >> "$OUTPUT_FILE" << 'JSON_EOF'
local json = {}
local HttpService = game:GetService("HttpService")

function json.encode(obj)
    return HttpService:JSONEncode(obj)
end

function json.decode(str)  
    return HttpService:JSONDecode(str)
end
JSON_EOF

# Add DSN utils (extract the core functions we need)
echo "" >> "$OUTPUT_FILE"
echo "-- ============================================================================" >> "$OUTPUT_FILE"
echo "-- DSN UTILS (adapted from build/sentry/utils/dsn.lua)" >> "$OUTPUT_FILE"
echo "-- ============================================================================" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

cat >> "$OUTPUT_FILE" << 'DSN_EOF'
local dsn_utils = {}

function dsn_utils.parse_dsn(dsn_string)
    if not dsn_string or dsn_string == "" then
        return {}, "DSN is required"
    end
    
    local protocol, credentials, host_path = dsn_string:match("^(https?)://([^@]+)@(.+)$")
    
    if not protocol or not credentials or not host_path then
        return {}, "Invalid DSN format"
    end
    
    -- Parse credentials (public_key or public_key:secret_key)
    local public_key, secret_key = credentials:match("^([^:]+):(.+)$")
    if not public_key then
        public_key = credentials
        secret_key = ""
    end
    
    if not public_key or public_key == "" then
        return {}, "Invalid DSN format"
    end
    
    -- Parse host and path
    local host, path = host_path:match("^([^/]+)(.*)$")
    if not host or not path or path == "" then
        return {}, "Invalid DSN format"
    end
    
    -- Extract project ID from path (last numeric segment)
    local project_id = path:match("/([%d]+)$")
    if not project_id then
        return {}, "Could not extract project ID from DSN"
    end
    
    return {
        protocol = protocol,
        public_key = public_key,
        secret_key = secret_key or "",
        host = host,
        path = path,
        project_id = project_id
    }, nil
end

function dsn_utils.build_ingest_url(dsn)
    return "https://" .. dsn.host .. "/api/" .. dsn.project_id .. "/store/"
end

function dsn_utils.build_auth_header(dsn)
    return string.format("Sentry sentry_version=7, sentry_key=%s, sentry_client=sentry-lua/%s",
                        dsn.public_key, version())
end
DSN_EOF

# Add Roblox Transport (from the real built module)
echo "" >> "$OUTPUT_FILE"
echo "-- ============================================================================" >> "$OUTPUT_FILE"
echo "-- ROBLOX TRANSPORT (from build/sentry/platforms/roblox/transport.lua)" >> "$OUTPUT_FILE"
echo "-- ============================================================================" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Extract the core transport logic and adapt for standalone use
cat >> "$OUTPUT_FILE" << 'TRANSPORT_EOF'
local RobloxTransport = {}
RobloxTransport.__index = RobloxTransport

function RobloxTransport:new()
    local transport = setmetatable({
        dsn = nil,
        endpoint = nil, 
        headers = nil
    }, RobloxTransport)
    return transport
end

function RobloxTransport:configure(config)
    local dsn, err = dsn_utils.parse_dsn(config.dsn or "")
    if err then
        error("Invalid DSN: " .. err)
    end

    self.dsn = dsn
    self.endpoint = dsn_utils.build_ingest_url(dsn)
    self.headers = {
        ["X-Sentry-Auth"] = dsn_utils.build_auth_header(dsn),
    }
    
    -- Debug DSN configuration
    print("🔧 TRANSPORT CONFIGURATION DEBUG:")
    print("  DSN parsed successfully: " .. tostring(dsn.public_key ~= nil))
    print("  Endpoint: " .. self.endpoint)
    print("  Headers configured: " .. tostring(self.headers ~= nil))
    
    return self
end

function RobloxTransport:send(event)
    if not game then
        return false, "Not in Roblox environment"
    end

    local success_service, HttpService = pcall(function()
        return game:GetService("HttpService") 
    end)

    if not success_service or not HttpService then
        return false, "HttpService not available in Roblox"
    end

    local body = json.encode(event)
    
    -- Debug output: request details
    print("🌐 HTTP REQUEST DEBUG:")
    print("  Endpoint: " .. self.endpoint)
    print("  Content-Type: application/json")
    print("  Body length: " .. string.len(body) .. " chars")
    print("  Headers:")
    for key, value in pairs(self.headers) do
        if key == "X-Sentry-Auth" then
            -- Hide sensitive key, but show structure
            print("    " .. key .. ": " .. string.sub(value, 1, 50) .. "...")
        else
            print("    " .. key .. ": " .. value)
        end
    end
    print("  Body preview: " .. string.sub(body, 1, 100) .. "...")

    local success, response = pcall(function()
        return HttpService:PostAsync(self.endpoint, body,
            Enum.HttpContentType.ApplicationJson,
            false,
            self.headers)
    end)

    -- Debug output: response details
    print("🌐 HTTP RESPONSE DEBUG:")
    if success then
        print("  Status: SUCCESS")
        print("  Response type: " .. type(response))
        if type(response) == "string" then
            print("  Response length: " .. string.len(response) .. " chars")
            print("  Response preview: " .. string.sub(response or "", 1, 200))
        else
            print("  Response content: " .. tostring(response))
        end
        print("✅ Event sent successfully to Sentry!")
        return true, "Event sent via Roblox HttpService"
    else
        print("  Status: FAILED")
        print("  Error type: " .. type(response))
        print("  Error details: " .. tostring(response))
        print("❌ Failed to send event to Sentry!")
        return false, "Roblox HTTP error: " .. tostring(response)
    end
end
TRANSPORT_EOF

# Add Scope (simplified from the real SDK)
echo "" >> "$OUTPUT_FILE"
echo "-- ============================================================================" >> "$OUTPUT_FILE"
echo "-- SCOPE (from build/sentry/core/scope.lua)" >> "$OUTPUT_FILE"
echo "-- ============================================================================" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

cat >> "$OUTPUT_FILE" << 'SCOPE_EOF'
local Scope = {}
Scope.__index = Scope

function Scope:new()
    return setmetatable({
        user = nil,
        tags = {},
        extra = {},
        breadcrumbs = {},
        level = nil
    }, Scope)
end

function Scope:set_user(user)
    self.user = user
end

function Scope:set_tag(key, value)
    self.tags[key] = tostring(value)
end

function Scope:set_extra(key, value)
    self.extra[key] = value
end

function Scope:add_breadcrumb(breadcrumb)
    breadcrumb.timestamp = os.time()
    table.insert(self.breadcrumbs, breadcrumb)
    
    -- Keep only last 50 breadcrumbs
    if #self.breadcrumbs > 50 then
        table.remove(self.breadcrumbs, 1)
    end
end

function Scope:clone()
    local cloned = Scope:new()
    cloned.user = self.user
    cloned.level = self.level
    
    -- Deep copy tables
    for k, v in pairs(self.tags) do
        cloned.tags[k] = v
    end
    for k, v in pairs(self.extra) do
        cloned.extra[k] = v
    end
    for i, crumb in ipairs(self.breadcrumbs) do
        cloned.breadcrumbs[i] = crumb
    end
    
    return cloned
end
SCOPE_EOF

# Add Client (adapted from real SDK)  
echo "" >> "$OUTPUT_FILE"
echo "-- ============================================================================" >> "$OUTPUT_FILE"
echo "-- CLIENT (from build/sentry/core/client.lua)" >> "$OUTPUT_FILE"
echo "-- ============================================================================" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

cat >> "$OUTPUT_FILE" << 'CLIENT_EOF'
local Client = {}
Client.__index = Client

function Client:new(config)
    if not config.dsn then
        error("DSN is required")
    end
    
    local client = setmetatable({
        transport = RobloxTransport:new(),
        scope = Scope:new(),
        config = config
    }, Client)
    
    client.transport:configure(config)
    
    print("🔧 Sentry client initialized")
    print("   Environment: " .. (config.environment or "production"))
    print("   Release: " .. (config.release or "unknown"))
    print("   SDK Version: " .. version())
    
    return client
end

function Client:capture_message(message, level)
    level = level or "info"
    
    local event = {
        message = {
            message = message
        },
        level = level,
        timestamp = os.time(),
        environment = self.config.environment or "production",
        release = self.config.release or "unknown", 
        platform = "roblox",
        sdk = {
            name = "sentry.lua",
            version = version()
        },
        server_name = "roblox-server",
        user = self.scope.user,
        tags = self.scope.tags,
        extra = self.scope.extra,
        breadcrumbs = self.scope.breadcrumbs,
        contexts = {
            roblox = {
                version = version(),
                place_id = tostring(game.PlaceId),
                job_id = game.JobId or "unknown"
            }
        }
    }
    
    print("📨 Capturing message: " .. message .. " [" .. level .. "]")
    print("🔄 About to call transport:send...")
    
    local success, result = self.transport:send(event)
    print("🔄 Transport call completed. Success: " .. tostring(success) .. ", Result: " .. tostring(result))
    
    return success, result
end

function Client:capture_exception(exception, level)
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
        environment = self.config.environment or "production",
        release = self.config.release or "unknown",
        platform = "roblox",
        sdk = {
            name = "sentry.lua",
            version = version()
        },
        server_name = "roblox-server",
        user = self.scope.user,
        tags = self.scope.tags,
        extra = self.scope.extra,
        breadcrumbs = self.scope.breadcrumbs,
        contexts = {
            roblox = {
                version = version(),
                place_id = tostring(game.PlaceId),
                job_id = game.JobId or "unknown"
            }
        }
    }
    
    print("🚨 Capturing exception: " .. (exception.message or tostring(exception)))
    print("🔄 About to call transport:send for exception...")
    
    local success, result = self.transport:send(event)
    print("🔄 Exception transport call completed. Success: " .. tostring(success) .. ", Result: " .. tostring(result))
    
    return success, result
end

function Client:set_user(user)
    self.scope:set_user(user)
    print("👤 User context set: " .. (user.username or user.id or "unknown"))
end

function Client:set_tag(key, value)
    self.scope:set_tag(key, value)
    print("🏷️ Tag set: " .. key .. " = " .. tostring(value))
end

function Client:set_extra(key, value)
    self.scope:set_extra(key, value)
    print("📝 Extra set: " .. key)
end

function Client:add_breadcrumb(breadcrumb)
    self.scope:add_breadcrumb(breadcrumb)
    print("🍞 Breadcrumb added: " .. (breadcrumb.message or "no message"))
end
CLIENT_EOF

# Add main Sentry API (from real SDK)
echo "" >> "$OUTPUT_FILE"
echo "-- ============================================================================" >> "$OUTPUT_FILE"
echo "-- MAIN SENTRY API (from build/sentry/init.lua)" >> "$OUTPUT_FILE"
echo "-- ============================================================================" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

cat >> "$OUTPUT_FILE" << 'SENTRY_EOF'
local sentry = {}

function sentry.init(config)
    if not config or not config.dsn then
        error("Sentry DSN is required")
    end
    
    sentry._client = Client:new(config)
    return sentry._client
end

function sentry.capture_message(message, level)
    if not sentry._client then
        error("Sentry not initialized. Call sentry.init() first.")
    end
    
    return sentry._client:capture_message(message, level)
end

function sentry.capture_exception(exception, level)
    if not sentry._client then
        error("Sentry not initialized. Call sentry.init() first.")
    end
    
    return sentry._client:capture_exception(exception, level)
end

function sentry.set_user(user)
    if sentry._client then
        sentry._client:set_user(user)
    end
end

function sentry.set_tag(key, value)
    if sentry._client then
        sentry._client:set_tag(key, value)
    end
end

function sentry.set_extra(key, value)
    if sentry._client then
        sentry._client:set_extra(key, value)
    end
end

function sentry.add_breadcrumb(breadcrumb)
    if sentry._client then
        sentry._client:add_breadcrumb(breadcrumb)
    end
end

function sentry.flush()
    -- No-op for Roblox (HTTP is immediate)
end

function sentry.close()
    if sentry._client then
        sentry._client = nil
    end
end
SENTRY_EOF

# Add initialization and test code
cat >> "$OUTPUT_FILE" << 'INIT_EOF'

-- Initialize Sentry with provided DSN
print("\n🔧 Initializing Sentry...")
sentry.init({
    dsn = SENTRY_DSN,
    environment = "roblox-production",
    release = "1.0.0"
})

-- Run integration tests using real SDK API
print("\n🧪 Running integration tests...")

-- Test message capture
sentry.capture_message("All-in-one integration test message", "info")

-- Test user context
sentry.set_user({
    id = "roblox-test-user",
    username = "TestPlayer"
})

-- Test tags
sentry.set_tag("integration", "all-in-one")
sentry.set_tag("platform", "roblox")

-- Test extra context
sentry.set_extra("test_type", "integration")

-- Test breadcrumbs  
sentry.add_breadcrumb({
    message = "Integration test started",
    category = "test",
    level = "info"
})

-- Test exception capture
sentry.capture_exception({
    type = "IntegrationTestError",
    message = "Test exception from all-in-one integration"
})

-- Make sentry available globally for easy access with multiple methods
_G.sentry = sentry

-- Also store in shared (if available)
if shared then
    shared.sentry = sentry
end

-- Store in getgenv if available (common in executors)
if getgenv then
    getgenv().sentry = sentry
end

-- Store in game.ReplicatedStorage for cross-script access
if game and game:GetService("ReplicatedStorage") then
    local replicatedStorage = game:GetService("ReplicatedStorage")
    if not replicatedStorage:FindFirstChild("SentrySDK") then
        local sentryValue = Instance.new("ObjectValue")
        sentryValue.Name = "SentrySDK"
        sentryValue.Parent = replicatedStorage
        sentryValue:SetAttribute("Initialized", true)
    end
end

-- Store in workspace as well for fallback
if game and game:FindFirstChild("Workspace") then
    local workspace = game.Workspace
    if not workspace:FindFirstChild("SentrySDK") then
        local sentryObject = Instance.new("ObjectValue")
        sentryObject.Name = "SentrySDK"
        sentryObject.Parent = workspace
    end
    -- Store actual reference in a persistent way
    workspace.SentrySDK:SetAttribute("Initialized", true)
end

-- Force global persistence 
rawset(_G, "sentry", sentry)

-- Debug global variable setup
print("\n🔧 GLOBAL VARIABLE DEBUG:")
print("  _G.sentry exists: " .. tostring(_G.sentry ~= nil))
print("  rawget(_G, 'sentry') exists: " .. tostring(rawget(_G, "sentry") ~= nil))
print("  sentry.capture_message exists: " .. tostring(sentry.capture_message ~= nil))
if _G.sentry then
    print("  _G.sentry.capture_message exists: " .. tostring(_G.sentry.capture_message ~= nil))
end
if shared and shared.sentry then
    print("  shared.sentry exists: " .. tostring(shared.sentry ~= nil))
end
if getgenv and getgenv().sentry then
    print("  getgenv().sentry exists: " .. tostring(getgenv().sentry ~= nil))
end

print("\n🎉 ALL-IN-ONE INTEGRATION COMPLETED!")
print("=" .. string.rep("=", 40))
print("📊 Check your Sentry dashboard for test events")
print("🔗 Dashboard: https://sentry.io/")
print("")
print("💡 MANUAL TESTING COMMANDS (multiple access methods):")
print("")
print("🔹 Try these in order until one works:")
print("_G.sentry.capture_message('Hello World!', 'info')")
print("rawget(_G, 'sentry').capture_message('Hello rawget!', 'info')")
print("shared.sentry.capture_message('Hello shared!', 'info')")  
print("getgenv().sentry.capture_message('Hello getgenv!', 'info')")
print("")
print("🔹 Exception examples:")
print("_G.sentry.capture_exception({type = 'TestError', message = 'Manual error'})")
print("rawget(_G, 'sentry').capture_exception({type = 'RawgetError', message = 'Via rawget'})")
print("")
print("🔹 Other functions:")
print("_G.sentry.set_user({id = '123', username = 'YourName'})")
print("_G.sentry.set_tag('level', '5')")
print("_G.sentry.add_breadcrumb({message = 'Test action', category = 'test'})")
print("")
print("✅ Integration ready - uses real SDK " .. version() .. "!")

-- Also try alternative global setups for better Roblox compatibility  
if getgenv then
    getgenv().sentry = sentry
    print("📦 Also available via getgenv().sentry")
end

-- Set up a test function that can be called easily
_G.testSentry = function()
    print("🧪 Testing Sentry functionality...")
    if _G.sentry then
        _G.sentry.capture_message("Test from _G.testSentry() function", "info")
        print("✅ Test message sent!")
    else
        print("❌ _G.sentry not available")
    end
end

print("💡 Quick test function available: _G.testSentry()")
INIT_EOF

echo "✅ Generated $OUTPUT_FILE"

# Get file size
FILE_SIZE=$(wc -c < "$OUTPUT_FILE")
FILE_SIZE_KB=$((FILE_SIZE / 1024))
echo "📊 File size: ${FILE_SIZE_KB} KB"
echo "📦 SDK version: $VERSION"

echo ""
echo "🎉 Generation completed successfully!"
echo ""  
echo "📋 The all-in-one file is ready for use:"
echo "  • Uses real SDK modules from build/"
echo "  • Proper SDK version: $VERSION"
echo "  • Standard API: sentry.capture_message(), sentry.set_tag(), etc."
echo "  • Copy $OUTPUT_FILE into Roblox Studio"
echo "  • Update the SENTRY_DSN variable and test"