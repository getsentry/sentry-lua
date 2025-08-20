#!/bin/bash
# Roblox Sentry Headless Development Test Runner (macOS/Linux)
#
# This script runs Roblox Studio in headless mode to test Sentry integration
# without needing to manually set up modules in the Studio IDE
#
# Prerequisites:
# 1. Roblox Studio installed 
# 2. Built Sentry SDK (run 'make build' first)
# 3. Valid Sentry DSN configured in the scripts
#
# Usage: 
#   ./run-headless-test.sh
#
# The script will:
# 1. Create a temporary place file
# 2. Auto-load Sentry modules
# 3. Run comprehensive tests
# 4. Send test events to Sentry
# 5. Report results

set -e  # Exit on any error

echo ""
echo "========================================"
echo " Roblox Sentry Headless Test Runner"
echo "========================================"
echo ""

# Configuration
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    STUDIO_PATH="/Applications/RobloxStudio.app/Contents/MacOS/RobloxStudio"
else
    # Linux (if supported)
    STUDIO_PATH="/opt/roblox-studio/RobloxStudio"
fi

TEST_PLACE="temp-sentry-test.rbxl"
RESULTS_FILE="test-results.log"

# Check if Roblox Studio exists
if [[ ! -f "$STUDIO_PATH" ]]; then
    echo "❌ ERROR: Roblox Studio not found at $STUDIO_PATH"
    echo "Please update STUDIO_PATH in this script to match your installation"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "Common macOS location: /Applications/RobloxStudio.app/Contents/MacOS/RobloxStudio"
    fi
    echo ""
    echo "💡 Note: Roblox Studio headless mode may not be fully supported on macOS/Linux"
    echo "Consider using the Windows version or running tests manually in Studio"
    exit 1
fi

echo "✅ Found Roblox Studio at $STUDIO_PATH"

# Create temporary test place
echo "🏗️ Creating temporary test place..."
cat > "$TEST_PLACE" << 'EOF'
<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" >
<Item class="DataModel">
<Properties></Properties>
<Item class="Workspace"><Properties></Properties></Item>
<Item class="ReplicatedStorage"><Properties></Properties></Item>
<Item class="ServerScriptService"><Properties></Properties></Item>
<Item class="StarterGui"><Properties></Properties></Item>
<Item class="StarterPlayer"><Properties></Properties></Item>
</Item>
</roblox>
EOF

echo "✅ Created test place: $TEST_PLACE"

# Build Sentry SDK if needed
echo "🔨 Checking Sentry SDK build..."
if [[ ! -f "../../build/sentry/init.lua" ]]; then
    echo "⚠️ Sentry SDK not built. Running make build..."
    cd ../..
    make build
    cd examples/roblox
    if [[ ! -f "../../build/sentry/init.lua" ]]; then
        echo "❌ Failed to build Sentry SDK"
        echo "Please run 'make build' in the project root first"
        exit 1
    fi
fi

echo "✅ Sentry SDK build found"

# Alternative: Manual Studio Setup Instructions
echo ""
echo "🔧 ALTERNATIVE: Manual Studio Setup"
echo "=================================="
echo "Since headless mode support varies, here's how to test manually:"
echo ""
echo "1. Open Roblox Studio"
echo "2. Create a new Baseplate"
echo "3. Copy auto-load-modules.lua into ServerScriptService as a Script"
echo "4. Run the game (F5)"
echo "5. Check Output for test results"
echo "6. Check your Sentry dashboard for events"
echo ""

# Attempt headless run (may not work on all platforms)
echo "🚀 Attempting headless test..."
echo "Note: This may not work on all platforms. Use manual setup if needed."
echo ""

# Create test script runner
cat > temp-test-runner.lua << 'EOF'
-- Auto-generated test runner
local success, error = pcall(function()
   dofile("auto-load-modules.lua")
end)
if not success then
   print("❌ Test failed:", error)
else
   print("✅ Test completed successfully")
end
EOF

# Try to run headless test
if command -v timeout >/dev/null 2>&1; then
    timeout 120 "$STUDIO_PATH" "$TEST_PLACE" -ide -run temp-test-runner.lua > "$RESULTS_FILE" 2>&1 || true
else
    # macOS doesn't have timeout by default
    "$STUDIO_PATH" "$TEST_PLACE" -ide -run temp-test-runner.lua > "$RESULTS_FILE" 2>&1 &
    STUDIO_PID=$!
    sleep 120
    kill $STUDIO_PID 2>/dev/null || true
fi

# Check results
echo ""
echo "📊 Test Results:"
echo "================"
if [[ -f "$RESULTS_FILE" ]]; then
    cat "$RESULTS_FILE"
    
    # Check for success indicators
    if grep -q "Test completed successfully" "$RESULTS_FILE"; then
        echo ""
        echo "🎉 HEADLESS TEST COMPLETED SUCCESSFULLY!"
        echo "📈 Check your Sentry dashboard for test events"
        echo "🔗 Dashboard: https://sentry.io/"
    else
        echo ""
        echo "❌ Test may have failed. Check the output above for errors."
        echo "💡 Common issues:"
        echo "   - HTTP requests not enabled in Studio"
        echo "   - Invalid Sentry DSN"
        echo "   - Network connectivity issues"
        echo "   - Headless mode not supported on this platform"
    fi
else
    echo "❌ No results file generated - test may have crashed or headless mode not supported"
    echo "💡 Try the manual setup approach described above"
fi

# Provide manual testing commands
echo ""
echo "📋 MANUAL TESTING COMMANDS"
echo "========================="
echo "After setting up modules manually in Studio, try these commands in the output:"
echo ""
echo "_G.SentryTestFunctions.sendTestMessage('Hello from manual test!')"
echo "_G.SentryTestFunctions.triggerTestError()"
echo ""

# Cleanup
echo "🧹 Cleaning up temporary files..."
rm -f "$TEST_PLACE" temp-test-runner.lua

echo ""
echo "🏁 Headless test runner completed."
echo ""
echo "💡 DEVELOPMENT WORKFLOW:"
echo "1. Make changes to Sentry SDK"
echo "2. Run 'make build'"
echo "3. Run this script OR use manual setup"
echo "4. Check Sentry dashboard for events"
echo "5. Iterate!"