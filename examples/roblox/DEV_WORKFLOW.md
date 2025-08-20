# Roblox Sentry Development Workflow

This guide provides multiple approaches for developing and testing Sentry integration with Roblox, including both automated and manual workflows.

## 🚀 Quick Start Options

### Option 1: Automated Module Loading (Recommended for Development)

Use the auto-loader script to automatically set up Sentry modules in Studio:

1. **Build the SDK**:
   ```bash
   cd sentry-lua
   make build
   ```

2. **Use Auto-Loader**:
   - Open Roblox Studio
   - Create new Baseplate or open existing project
   - Copy `auto-load-modules.lua` into ServerScriptService as a Script
   - Run the game (F5)
   - Check Output panel for success messages

3. **Test Functionality**:
   ```lua
   -- In Studio Command Bar:
   _G.SentryTestFunctions.sendTestMessage("Hello from auto-loader!")
   _G.SentryTestFunctions.triggerTestError()
   ```

### Option 2: Headless Testing (Platform Dependent)

For automated testing without Studio GUI:

**Windows**:
```cmd
cd examples/roblox
run-headless-test.bat
```

**macOS/Linux**:
```bash
cd examples/roblox
./run-headless-test.sh
```

⚠️ **Note**: Headless mode support varies by platform and may not work consistently.

### Option 3: Manual Setup (Most Reliable)

Follow the detailed manual setup process described in `DETAILED_SETUP.md`.

## 🔄 Development Workflow

### Typical Development Loop

1. **Make Changes** to Sentry SDK source code
2. **Rebuild**: `make build`  
3. **Test Changes** using one of the methods above
4. **Check Sentry Dashboard** for events
5. **Iterate**

### Fast Development with Auto-Loader

The auto-loader provides the fastest development cycle:

```bash
# Terminal 1: Watch for changes and rebuild
cd sentry-lua
while true; do
  make build
  echo "Build completed at $(date)"
  sleep 5
done

# Terminal 2: Test in Studio
# 1. Keep Studio open with auto-loader script
# 2. After each build, stop and restart the game (Shift+F5, then F5)
# 3. Test your changes immediately
```

## 🧪 Testing Strategies

### 1. Basic Functionality Test
```lua
-- Test message capture
_G.SentryTestFunctions.sendTestMessage("Basic functionality test")

-- Test error capture  
_G.SentryTestFunctions.triggerTestError()
```

### 2. User Context Testing
```lua
local sentry = require(game.ReplicatedStorage.sentry)

sentry.set_user({
   id = tostring(game.Players.LocalPlayer.UserId),
   username = game.Players.LocalPlayer.Name
})

sentry.capture_message("User context test", "info")
```

### 3. Breadcrumb Testing
```lua
local sentry = require(game.ReplicatedStorage.sentry)

sentry.add_breadcrumb({
   message = "Player clicked button",
   category = "ui",
   level = "info",
   data = {button_name = "TestButton"}
})

sentry.capture_message("Breadcrumb test completed", "info")
```

### 4. Error Handling Testing
```lua
local sentry = require(game.ReplicatedStorage.sentry)

local function riskyFunction()
   error("This is a test error for development")
end

local success, result = sentry.wrap(riskyFunction, function(err)
   print("Error handled gracefully:", err)
   return "Fallback result"
end)
```

## 📊 Monitoring and Debugging

### Studio Output Messages

Look for these indicators:

**Successful Setup**:
```
✅ Sentry module loaded successfully
🔧 Sentry initializing...
   DSN: ***configured***
   Environment: roblox-auto-loader-test
   Platform: roblox
✅ Sentry initialized successfully
📨 Capturing message: Auto-loader test message
🚀 Sending event to Sentry...
✅ Event sent to Sentry
```

**Common Issues**:
```
❌ Sentry not initialized - call sentry.init() first
⚠️ HTTP requests may not be enabled
❌ Failed to send event: HTTP 403 (Forbidden)
❌ Invalid DSN format
```

### Sentry Dashboard

Check your Sentry project dashboard for:
- **Issues**: Captured errors and exceptions
- **Performance**: Transaction traces (if enabled)
- **Releases**: Version tracking
- **User Feedback**: User context and sessions

### Debug Mode

Enable debug mode for verbose logging:

```lua
sentry.init({
   dsn = "your-dsn-here",
   debug = true,  -- Enable debug logging
   environment = "development"
})
```

## 🔧 Troubleshooting

### Module Loading Issues

**Problem**: `Infinite yield possible on 'ReplicatedStorage:WaitForChild("sentry")'`
**Solution**: Ensure sentry folder exists in ReplicatedStorage with all required modules

**Problem**: `attempt to call a nil value`
**Solution**: Check that all ModuleScripts are properly created and contain valid code

### Network Issues

**Problem**: Events not appearing in Sentry
**Solutions**:
1. Verify HTTP requests are enabled: Game Settings → Security → "Allow HTTP Requests"
2. Check DSN format and validity
3. Test with a simple HTTP request to verify connectivity
4. Check Studio's network restrictions

### Development Environment

**Problem**: Changes not reflected after rebuild
**Solutions**:
1. Stop and restart the game (Shift+F5, then F5)
2. Check that `make build` completed successfully
3. Verify auto-loader is using the latest modules
4. Clear Studio's module cache by restarting Studio

## 🎯 Performance Considerations

### Development vs Production

**Development Setup**:
- Use auto-loader for rapid iteration
- Enable debug logging
- Use separate Sentry project for dev events
- Test with fewer players/NPCs

**Production Setup**:
- Use manual module setup for stability
- Disable debug logging
- Use production Sentry project
- Consider event sampling for high-traffic games

### Optimization Tips

1. **Batch Events**: Group related events together
2. **Limit Breadcrumbs**: Keep breadcrumb history reasonable (default: 100)
3. **Conditional Logging**: Only send detailed events for important errors
4. **Async Operations**: Use spawn() for non-critical Sentry operations

## 📁 File Reference

- `auto-load-modules.lua` - Automatic module loader for development
- `dev-test.lua` - Comprehensive test suite
- `run-headless-test.bat` - Windows headless test runner
- `run-headless-test.sh` - macOS/Linux headless test runner
- `TestModuleStructure.lua` - Module verification script
- `DETAILED_SETUP.md` - Manual setup instructions

## 🔄 Integration with CI/CD

### GitHub Actions Example

```yaml
name: Test Roblox Integration

on: [push, pull_request]

jobs:
  test-roblox:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v3
      - name: Build Sentry SDK
        run: make build
      - name: Run Roblox Tests
        run: |
          cd examples/roblox
          run-headless-test.bat
        env:
          SENTRY_DSN: ${{ secrets.SENTRY_DSN }}
```

### Local Git Hooks

Add to `.git/hooks/pre-commit`:
```bash
#!/bin/bash
echo "Testing Roblox integration..."
cd examples/roblox
make build && ./run-headless-test.sh
```

## 🎉 Success Metrics

Your development workflow is working well when:

✅ Build-test cycle takes less than 30 seconds  
✅ Events appear in Sentry dashboard within 10 seconds  
✅ Error capture works reliably  
✅ User context is properly set  
✅ Breadcrumbs provide useful debugging info  
✅ No performance impact on game frame rate  

Happy developing! 🚀