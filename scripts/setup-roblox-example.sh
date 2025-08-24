#!/bin/bash
#
# Generate Roblox Single-File Example
#
# This script creates a simple Roblox example using the single-file SDK
#
# Usage: ./scripts/generate-roblox-single-file.sh
#

set -e

echo "🔨 Generating Roblox Single-File Example"
echo "========================================"

OUTPUT_DIR="examples/roblox"
OUTPUT_FILE="$OUTPUT_DIR/sentry.lua"

# Check if single-file SDK exists
if [ ! -f "build-single-file/sentry.lua" ]; then
    echo "❌ Single-file SDK not built. Run 'make build-single-file' first."
    exit 1
fi

echo "✅ Found single-file SDK"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Read version from the single file
VERSION=$(grep -o 'local VERSION = "[^"]*"' build-single-file/sentry.lua | grep -o '"[^"]*"' | tr -d '"')
echo "📦 SDK Version: $VERSION"

# Start creating the example file
cat > "$OUTPUT_FILE" << EOF
--[[
  Sentry Single-File Example for Roblox
  
  Version: $VERSION
  Generated from single-file SDK
  
  INSTRUCTIONS:
  1. Copy this entire file into Roblox Studio
  2. Paste into ServerScriptService as a Script
  3. Update SENTRY_DSN below with your actual DSN
  4. Enable HTTP requests: Game Settings → Security → "Allow HTTP Requests"
  5. Run the game (F5)
  
  The single-file SDK is embedded below and will be available as a global 'sentry' module.
]]--

-- ⚠️ UPDATE THIS WITH YOUR SENTRY DSN
local SENTRY_DSN = "https://your-key@your-org.ingest.sentry.io/your-project-id"

print("🚀 Starting Sentry Single-File Integration")
print("DSN: ***" .. string.sub(SENTRY_DSN, -10))
print("=" .. string.rep("=", 40))

-- ============================================================================
-- EMBEDDED SENTRY SDK (Single File)
-- ============================================================================

EOF

# Add the single-file SDK content (skip the initial comment block)
tail -n +36 build-single-file/sentry.lua >> "$OUTPUT_FILE"

# Add the initialization and example code
cat >> "$OUTPUT_FILE" << 'INIT_EOF'

-- ============================================================================
-- ROBLOX EXAMPLE USAGE
-- ============================================================================

-- Initialize Sentry with your DSN
sentry.init({
    dsn = SENTRY_DSN,
    environment = "roblox-production",
    release = "1.0.0"
})

print("✅ Sentry initialized successfully")

-- Set user context
sentry.set_user({
    id = "12345",
    username = "roblox_player",
    ip_address = "{{auto}}"
})

-- Set tags
sentry.set_tag("game_type", "showcase")
sentry.set_tag("server_region", "us-east")

-- Set extra context
sentry.set_extra("place_info", {
    place_id = game.PlaceId,
    job_id = game.JobId or "unknown"
})

-- Add breadcrumb
sentry.add_breadcrumb({
    message = "Player joined the game",
    category = "navigation",
    level = "info"
})

-- Example 1: Capture a simple message
print("📨 Sending test message to Sentry...")
local success1, result1 = sentry.capture_message("Hello from Roblox single-file SDK!", "info")
if success1 then
    print("✅ Message sent successfully")
else
    print("❌ Failed to send message: " .. tostring(result1))
end

-- Example 2: Capture an exception
print("🚨 Sending test exception to Sentry...")
local success2, result2 = sentry.capture_exception({
    type = "RobloxTestError",
    message = "This is a test exception from the single-file SDK"
}, "error")
if success2 then
    print("✅ Exception sent successfully")
else
    print("❌ Failed to send exception: " .. tostring(result2))
end

-- Example 3: Use logging functions
print("📝 Testing logger functions...")
sentry.logger.info("Info message from single-file SDK")
sentry.logger.warn("Warning message from single-file SDK")
sentry.logger.error("Error message from single-file SDK")

-- Example 4: Use tracing functions
print("📊 Testing tracing functions...")
local transaction = sentry.start_transaction("game_initialization", "Initialize game world")
wait(0.1) -- Simulate some work
local span = transaction:start_span("load_assets", "Load game assets")
wait(0.05) -- Simulate asset loading
span:finish()
transaction:finish()
print("✅ Transaction completed")

-- Example 5: Use scope functionality
print("🎯 Testing scope functionality...")
sentry.with_scope(function(scope)
    scope:set_tag("test_scope", "true")
    scope:set_extra("scope_data", {test = "value"})
    sentry.capture_message("Message with custom scope", "info")
end)

-- Example 6: Use error wrapping
print("🛡️ Testing error wrapping...")
local wrapped_success, wrapped_result = sentry.wrap(function()
    -- This would normally cause an error, but we'll simulate success
    return "Function executed successfully"
end, function(err)
    print("Custom error handler called: " .. tostring(err))
    return "Error handled gracefully"
end)

if wrapped_success then
    print("✅ Wrapped function executed: " .. tostring(wrapped_result))
end

-- Make sentry available globally
_G.sentry = sentry
shared.sentry = sentry

-- Store in ReplicatedStorage for easy access from other scripts
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local sentryFolder = ReplicatedStorage:FindFirstChild("SentrySDK")
if not sentryFolder then
    sentryFolder = Instance.new("Folder")
    sentryFolder.Name = "SentrySDK"
    sentryFolder.Parent = ReplicatedStorage
end
sentryFolder:SetAttribute("Initialized", true)
sentryFolder:SetAttribute("Version", "$VERSION")

print("")
print("🎉 Sentry single-file integration complete!")
print("💡 Access Sentry from other scripts with: _G.sentry")
print("💡 Example: _G.sentry.capture_message('Hello!', 'info')")
print("💡 Check your Sentry dashboard for the test events")
print("")

-- Set up a test function for easy manual testing
_G.testSentry = function(message)
    message = message or "Manual test from _G.testSentry()"
    local success, result = _G.sentry.capture_message(message, "info")
    if success then
        print("✅ Test message sent: " .. message)
    else
        print("❌ Failed to send test message: " .. tostring(result))
    end
    return success
end

print("💡 Manual test function available: _G.testSentry('Your message here')")
INIT_EOF

echo "✅ Generated $OUTPUT_FILE"

# Get file size
FILE_SIZE=$(wc -c < "$OUTPUT_FILE")
FILE_SIZE_KB=$((FILE_SIZE / 1024))
echo "📊 File size: ${FILE_SIZE_KB} KB"
echo "📦 SDK version: $VERSION"

echo ""
echo "🎉 Roblox single-file example generated!"
echo ""  
echo "📋 The example is ready for use:"
echo "  • Contains embedded single-file SDK"
echo "  • All functions under 'sentry' namespace" 
echo "  • Includes comprehensive examples"
echo "  • Copy $OUTPUT_FILE into Roblox Studio"
echo "  • Update the SENTRY_DSN variable"
echo "  • Enable HTTP requests and run"