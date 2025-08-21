#!/bin/bash
#
# Generate Single-File Sentry SDK using lua-amalg
#
# This script uses the lua-amalg tool to properly bundle all compiled SDK modules
# from the build/ directory into a single self-contained sentry.lua file.
#
# Unlike the previous manual approach, this uses the actual compiled Teal sources
# and preserves all platform integrations, stacktraces, and functionality.
#
# Usage: ./scripts/generate-single-file-amalg.sh
#

set -e

echo "🔨 Generating Single-File Sentry SDK using lua-amalg"
echo "=================================================="

OUTPUT_DIR="build-single-file"
OUTPUT_FILE="$OUTPUT_DIR/sentry.lua"

# Check if SDK is built
if [ ! -f "build/sentry/init.lua" ]; then
    echo "❌ SDK not built. Run 'make build' first."
    exit 1
fi

echo "✅ Found built SDK"

# Check if amalg.lua is available
if ! command -v amalg.lua > /dev/null 2>&1; then
    echo "❌ amalg.lua not found. Installing..."
    luarocks install --local amalg
    eval "$(luarocks path --local)"
fi

echo "✅ Found lua-amalg tool"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Read version from version.lua
VERSION=$(grep -o '"[^"]*"' build/sentry/version.lua | tr -d '"')
echo "📦 SDK Version: $VERSION"

# Set up Lua path to include our build directory
export LUA_PATH="build/?.lua;build/?/init.lua;;"

# Create a header file with usage information
cat > "$OUTPUT_DIR/header.lua" << EOF
--[[
  Sentry Lua SDK - Single File Distribution
  
  Version: $VERSION
  Generated from built SDK using lua-amalg - DO NOT EDIT MANUALLY
  
  To regenerate: ./scripts/generate-single-file-amalg.sh
  
  USAGE:
    local sentry = require('sentry')  -- if saved as sentry.lua
    
    sentry.init({dsn = "https://your-key@your-org.ingest.sentry.io/your-project-id"})
    sentry.capture_message("Hello from Sentry!", "info")
    sentry.capture_exception({type = "Error", message = "Something went wrong"})
    sentry.set_user({id = "123", username = "player1"})
    sentry.set_tag("environment", "production")
    sentry.add_breadcrumb({message = "User clicked button", category = "ui"})
    
    -- Logger functions
    sentry.logger.info("Application started")
    sentry.logger.error("Something went wrong")
    
    -- Tracing functions  
    local transaction = sentry.start_transaction("my-operation", "operation")
    local span = transaction:start_span("sub-task", "task")
    span:finish()
    transaction:finish()
    
    -- Error handling wrapper
    sentry.wrap(function()
        -- Your code here - errors will be automatically captured
    end)
    
    -- Clean shutdown
    sentry.close()
]]--

EOF

echo "🔄 Bundling modules with lua-amalg..."

# Use amalg.lua to bundle all modules starting from sentry.init
# The -d flag preserves debug information (file names and line numbers)
# The -s flag specifies the main script (entry point)
# The -p flag adds our header as prefix
# The -o flag specifies output file
# Auto-discover all modules by scanning the build directory
echo "🔍 Discovering modules from build directory..."
MODULES=""
for lua_file in $(find build/sentry -name "*.lua" | sort); do
    # Convert file path to module name (e.g., build/sentry/core/client.lua -> sentry.core.client)
    module=$(echo "$lua_file" | sed 's|build/||' | sed 's|/|.|g' | sed 's|\.lua$||')
    MODULES="$MODULES $module"
done

echo "📦 Found $(echo $MODULES | wc -w | tr -d ' ') modules to bundle"

# Use amalg.lua to bundle all discovered modules (without -s flag to make it a proper module)
eval "$(luarocks path --local)" && amalg.lua \
    -d \
    -p "$OUTPUT_DIR/header.lua" \
    -o "$OUTPUT_FILE" \
    $MODULES

# Add the module return statement at the end
echo "" >> "$OUTPUT_FILE"
echo "-- Return the main sentry module" >> "$OUTPUT_FILE"  
echo "return require('sentry.init')" >> "$OUTPUT_FILE"

echo "✅ Generated $OUTPUT_FILE"

# Clean up header file
rm -f "$OUTPUT_DIR/header.lua"

# Get file size
FILE_SIZE=$(wc -c < "$OUTPUT_FILE")
FILE_SIZE_KB=$((FILE_SIZE / 1024))
echo "📊 File size: ${FILE_SIZE_KB} KB"
echo "📦 SDK version: $VERSION"
echo ""

echo "🎉 Single-file generation completed using lua-amalg!"
echo ""
echo "📋 The single file is ready for use:"
echo "  • Contains complete SDK functionality from compiled Teal sources"
echo "  • All functions under 'sentry' namespace"
echo "  • Includes all platform integrations (Love2D, Roblox, etc.)"
echo "  • Includes logging: sentry.logger.info(), etc."
echo "  • Includes tracing: sentry.start_transaction(), etc."
echo "  • Self-contained - no external dependencies"
echo "  • Auto-detects runtime environment"  
echo "  • Preserves debug information (file names and line numbers)"
echo "  • Copy $OUTPUT_FILE to your project"
echo "  • Use: local sentry = require('sentry')"