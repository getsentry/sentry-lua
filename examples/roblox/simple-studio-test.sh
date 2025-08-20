#!/bin/bash
# Roblox Sentry Development Test Runner (macOS/Linux)
#
# This script helps you set up and test Sentry integration in Roblox Studio
# Optimized for macOS/Linux development workflow
#
# Usage: 
#   ./simple-studio-test.sh
#
# This will:
# 1. Check prerequisites and build SDK
# 2. Provide step-by-step instructions
# 3. Open Studio for you (macOS)
# 4. Guide you through the testing process

set -e  # Exit on any error

echo ""
echo "========================================"
echo " 🚀 Roblox Sentry Development Helper"
echo "========================================"
echo ""

# Configuration for macOS (primary target)
STUDIO_PATH="/Applications/RobloxStudio.app"

# Check if we're on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "⚠️  This script is optimized for macOS"
    echo "   For other platforms, follow the manual instructions below"
    echo ""
fi

# Check if build exists
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

# Check if Roblox Studio exists
if [[ -e "$STUDIO_PATH" ]]; then
    echo "✅ Found Roblox Studio at $STUDIO_PATH"
    STUDIO_AVAILABLE=true
else
    echo "⚠️ Roblox Studio not found at $STUDIO_PATH"
    echo "Please install Roblox Studio manually"
    STUDIO_AVAILABLE=false
fi

echo ""
echo "🎯 QUICK START INSTRUCTIONS"
echo "==========================="
echo ""
echo "Follow these steps to test Sentry in Roblox Studio:"
echo ""
echo "1️⃣ OPEN STUDIO"
if [[ $STUDIO_AVAILABLE == true ]]; then
    echo "   - Launching Roblox Studio now..."
else
    echo "   - Please open Roblox Studio manually"
fi
echo "   - Create a new Baseplate project"
echo "   - Enable HTTP requests: Game Settings > Security > \"Allow HTTP Requests\""
echo ""
echo "2️⃣ ADD AUTO-LOADER"
echo "   - In Explorer, right-click ServerScriptService"
echo "   - Insert Object > Script"
echo "   - Rename to \"SentryAutoLoader\""
echo "   - Copy the contents of: auto-load-modules.lua"
echo "   - Paste into the script"
echo ""
echo "3️⃣ UPDATE DSN"
echo "   - In the script, find line ~405: dsn = \"https://...\""
echo "   - Replace with your actual Sentry DSN"
echo "   - Save (Cmd+S)"
echo ""
echo "4️⃣ RUN TEST"
echo "   - Press F5 to run the game"
echo "   - Watch Output panel for success messages"
echo "   - Look for: \"✅ Sentry initialized successfully\""
echo ""
echo "5️⃣ TEST FUNCTIONALITY"
echo "   - In Command Bar (View > Command Bar), run:"
echo "     _G.SentryTestFunctions.sendTestMessage(\"Hello World!\")"
echo "   - Check your Sentry dashboard for the event"
echo ""

# Try to open Studio on macOS
if [[ $STUDIO_AVAILABLE == true && "$OSTYPE" == "darwin"* ]]; then
    echo "⏳ Opening Roblox Studio now..."
    open "$STUDIO_PATH"
fi

echo ""
echo "📋 COPY THESE COMMANDS FOR TESTING:"
echo "===================================="
echo ""
echo "-- Test message capture:"
echo "_G.SentryTestFunctions.sendTestMessage(\"Manual test message\")"
echo ""
echo "-- Test error capture:"
echo "_G.SentryTestFunctions.triggerTestError()"
echo ""
echo "-- Check if functions exist:"
echo "print(_G.SentryTestFunctions)"
echo ""

echo "🔗 HELPFUL FILES:"
echo "================="
echo "- auto-load-modules.lua    (Main script to copy)"
echo "- DEV_WORKFLOW.md         (Complete development guide)"
echo "- DETAILED_SETUP.md       (Manual setup instructions)"
echo ""

echo "💡 TROUBLESHOOTING:"
echo "==================="
echo "If you see errors, check:"
echo "- HTTP requests enabled in Game Settings"
echo "- Valid Sentry DSN configured" 
echo "- All modules loaded successfully"
echo "- Network connectivity"
echo ""

echo "🎯 DEVELOPMENT WORKFLOW:"
echo "========================"
echo "1. Make changes to Sentry SDK"
echo "2. Run: make build"
echo "3. In Studio: Stop game (Shift+F5), then start (F5)"
echo "4. Auto-loader will use latest modules"
echo "5. Test your changes"
echo "6. Check Sentry dashboard"
echo ""

echo "🎉 Once you see events in Sentry dashboard, integration is working!"
echo ""

if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "Press Enter to continue..."
    read
fi