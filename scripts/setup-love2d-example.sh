#!/bin/bash
#
# Setup Love2D Single-File Example
#
# This script sets up a Love2D example using the single-file SDK
#
# Usage: ./scripts/setup-love2d-single-file.sh
#

set -e

echo "🔨 Setting up Love2D Single-File Example"
echo "======================================="

LOVE2D_DIR="examples/love2d"
SINGLE_FILE_SDK="build-single-file/sentry.lua"

# Check if single-file SDK exists
if [ ! -f "$SINGLE_FILE_SDK" ]; then
    echo "❌ Single-file SDK not built. Run 'make build-single-file' first."
    exit 1
fi

echo "✅ Found single-file SDK"

# Create love2d directory if it doesn't exist
mkdir -p "$LOVE2D_DIR"

# Copy the single-file SDK to the Love2D directory
echo "📋 Copying single-file SDK to Love2D directory..."
cp "$SINGLE_FILE_SDK" "$LOVE2D_DIR/"

# Check if we already have the single-file main
if [ ! -f "$LOVE2D_DIR/main-single-file.lua" ]; then
    echo "❌ main-single-file.lua not found. It should have been created already."
    exit 1
fi

echo "✅ Single-file main.lua already exists"

# Copy conf.lua if it doesn't exist
if [ ! -f "$LOVE2D_DIR/conf-single-file.lua" ]; then
    echo "📋 Creating conf-single-file.lua..."
    cat > "$LOVE2D_DIR/conf-single-file.lua" << 'EOF'
-- Love2D configuration for Sentry Single-File Demo
function love.conf(t)
    t.identity = "sentry-love2d-single-file"
    t.version = "11.4"
    t.console = false
    
    t.window.title = "Love2D Sentry Single-File Demo"
    t.window.icon = nil
    t.window.width = 800
    t.window.height = 600
    t.window.borderless = false
    t.window.resizable = false
    t.window.minwidth = 1
    t.window.minheight = 1
    t.window.fullscreen = false
    t.window.fullscreentype = "desktop"
    t.window.vsync = 1
    t.window.msaa = 0
    t.window.display = 1
    t.window.highdpi = false
    t.window.x = nil
    t.window.y = nil
    
    t.modules.joystick = false
    t.modules.physics = false
    t.modules.video = false
end
EOF
else
    echo "✅ conf-single-file.lua already exists"
fi

# Create a README for the single-file setup
echo "📋 Creating README-single-file.md..."
cat > "$LOVE2D_DIR/README-single-file.md" << 'EOF'
# Love2D Single-File Sentry Example

This example demonstrates how to use the Sentry SDK with Love2D using the single-file distribution approach.

## Quick Setup

Instead of copying multiple files from the `build/sentry/` directory, you only need:

1. **One file**: `sentry.lua` (the complete SDK in a single file)
2. Your main Love2D files: `main-single-file.lua` and `conf-single-file.lua`

## Files Structure

```
examples/love2d/
├── sentry.lua              # Single-file SDK (complete Sentry functionality)
├── main-single-file.lua    # Love2D main file using single-file SDK
├── conf-single-file.lua    # Love2D configuration
└── README-single-file.md   # This file
```

## Running the Example

### Option 1: Run directly with Love2D

```bash
# Make sure Love2D is installed
love examples/love2d/
```

**Important**: Rename the files to run:
```bash
cd examples/love2d/
mv main-single-file.lua main.lua
mv conf-single-file.lua conf.lua
love .
```

### Option 2: Create a .love file

```bash
cd examples/love2d/
zip -r sentry-love2d-single-file.love sentry.lua main-single-file.lua conf-single-file.lua
love sentry-love2d-single-file.love
```

## What's Different from Multi-File Approach

### Multi-File Approach (Traditional)
- Requires copying entire `build/sentry/` directory (~20+ files)  
- Complex directory structure
- Multiple `require()` statements
- Larger project footprint

### Single-File Approach (New)
- Only requires `sentry.lua` (~21 KB)
- Self-contained - no external dependencies
- Same API - all functions under `sentry` namespace
- Auto-detects Love2D environment
- Easier distribution

## Usage

```lua
local sentry = require("sentry")

-- Initialize (same API as multi-file)
sentry.init({
    dsn = "https://your-key@your-org.ingest.sentry.io/your-project-id"
})

-- All standard functions available
sentry.capture_message("Hello from Love2D!", "info")
sentry.capture_exception({type = "Error", message = "Something went wrong"})

-- Plus logging functions
sentry.logger.info("Info message")
sentry.logger.error("Error message")

-- And tracing functions
local transaction = sentry.start_transaction("game_loop", "Main game loop")
-- ... game logic ...
transaction:finish()
```

## Requirements

- Love2D 11.0+
- HTTPS support for sending events to Sentry
  - The single-file SDK will try to load `lua-https` library
  - Make sure `https.so` is available in your Love2D project

## Configuration

Update the DSN in `main-single-file.lua`:

```lua
sentry.init({
    dsn = "https://your-key@your-org.ingest.sentry.io/your-project-id",
    environment = "love2d-production",
    release = "my-game@1.0.0"
})
```

## Features Demonstrated

The example shows how to:

- ✅ Initialize Sentry with single-file SDK
- ✅ Capture messages and exceptions  
- ✅ Use logging functions (`sentry.logger.*`)
- ✅ Use tracing functions (`sentry.start_transaction`)
- ✅ Add breadcrumbs and context
- ✅ Handle both caught and uncaught errors
- ✅ Clean shutdown with proper resource cleanup

## Controls

- **Click buttons**: Test error capture
- **R key**: Trigger rendering error (caught)
- **F key**: Trigger fatal error (uncaught, will crash)
- **L key**: Test logger and tracing functions
- **ESC**: Clean exit

## Performance

The single-file SDK has the same performance characteristics as the multi-file version:
- Minimal runtime overhead
- Efficient JSON encoding/decoding
- Automatic platform detection
- Built-in error handling
EOF

# Get file sizes for comparison
SINGLE_FILE_SIZE=$(wc -c < "$SINGLE_FILE_SDK")
SINGLE_FILE_SIZE_KB=$((SINGLE_FILE_SIZE / 1024))

echo "✅ Generated Love2D single-file setup"
echo "📊 Single-file SDK size: ${SINGLE_FILE_SIZE_KB} KB"

echo ""
echo "🎉 Love2D single-file setup completed!"
echo ""  
echo "📋 Setup summary:"
echo "  • Single-file SDK copied to: $LOVE2D_DIR/sentry.lua"
echo "  • Example main file: $LOVE2D_DIR/main-single-file.lua"
echo "  • Configuration file: $LOVE2D_DIR/conf-single-file.lua"
echo "  • Documentation: $LOVE2D_DIR/README-single-file.md"
echo ""
echo "🎮 To run the example:"
echo "  1. cd $LOVE2D_DIR"
echo "  2. mv main-single-file.lua main.lua"
echo "  3. mv conf-single-file.lua conf.lua"  
echo "  4. love ."
echo ""
echo "💡 Or create a .love file:"
echo "  1. cd $LOVE2D_DIR"
echo "  2. zip -r demo.love sentry.lua main-single-file.lua conf-single-file.lua"
echo "  3. love demo.love"