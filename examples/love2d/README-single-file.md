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
