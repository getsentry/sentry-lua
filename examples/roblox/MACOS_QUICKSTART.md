# macOS Roblox Sentry QuickStart Guide

This guide is optimized for macOS development with Roblox Studio.

## 🚀 Instant Setup (Recommended)

### Step 1: Copy-Paste Solution
1. **Open Roblox Studio**
2. **Create new Baseplate** 
3. **Enable HTTP**: Game Settings → Security → ✅ "Allow HTTP Requests"
4. **Add Script**: Right-click ServerScriptService → Insert Object → Script
5. **Copy ALL contents** of `quick-test-script.lua` into the script
6. **Update DSN** on line 16 with your Sentry project DSN
7. **Run game** (F5)

### Step 2: Verify Success
Look for this output in the Studio console:
```
🚀 Starting Roblox Sentry Quick Test
✅ Sentry initialized successfully
📨 Capturing message: Quick test message from Roblox Studio [info]
🌐 Sending to Sentry: https://o117736.ingest.us.sentry.io/...
✅ Event sent successfully!
🎉 QUICK TEST COMPLETED SUCCESSFULLY!
```

### Step 3: Manual Testing
In the Command Bar, run:
```lua
_G.SentryTestFunctions.sendTestMessage("Hello from macOS!")
_G.SentryTestFunctions.triggerTestError()
```

## 🔄 Development Workflow

### Fast Iteration Loop
```bash
# Terminal 1: Auto-rebuild on changes
cd sentry-lua
while sleep 2; do make build 2>/dev/null && echo "✅ Built at $(date)"; done

# Studio: Stop/start game to reload modules (Shift+F5, then F5)
```

### Using the Shell Helper
```bash
cd examples/roblox
chmod +x simple-studio-test.sh
./simple-studio-test.sh
```

This opens Studio and provides step-by-step guidance.

## 📁 Key Files (macOS/Linux only)

- **`quick-test-script.lua`** ⭐ **Main testing script**
- **`auto-load-modules.lua`** - Development auto-loader
- **`simple-studio-test.sh`** - macOS setup helper
- **`validate-scripts.lua`** - Syntax validation
- **`DEV_WORKFLOW.md`** - Complete development guide

## 🧪 Validation

Run the validation script to check everything works:
```bash
cd examples/roblox
lua validate-scripts.lua
```

Expected output:
```
🔍 Validating Roblox Sentry Integration Scripts
✅ No critical errors found
🎉 ALL VALIDATIONS PASSED!
```

## 🎯 What Works Now

✅ **Instant Setup**: Copy-paste script with full Sentry integration  
✅ **Real HTTP Transport**: Sends actual events to your Sentry dashboard  
✅ **Comprehensive Testing**: Messages, errors, users, tags, breadcrumbs  
✅ **Development Tools**: Auto-loader and validation scripts  
✅ **macOS Optimized**: Shell scripts work perfectly on macOS  
✅ **No Manual Module Creation**: Everything is automated  

## 💡 Troubleshooting

### "HTTP requests not enabled"
**Solution**: Game Settings → Security → ✅ "Allow HTTP Requests"

### "Failed to send event"
**Solutions**:
1. Check DSN format: `https://key@host.ingest.sentry.io/projectid`
2. Verify network connectivity
3. Check Sentry project exists and is active

### "Module not found"
**Solution**: The quick-test-script creates all modules automatically. If you see this error, the script may have failed to run completely.

### No events in Sentry dashboard
**Solutions**:
1. Wait 10-30 seconds for events to appear
2. Check Sentry project is correct
3. Verify DSN is from the right project
4. Test with the manual test functions

## 🎉 Success Indicators

Your integration is working when you see:

1. **Studio Output**:
   ```
   ✅ Sentry initialized successfully
   ✅ Event sent successfully!
   ```

2. **Sentry Dashboard**: New events appear within 30 seconds

3. **Manual Tests Work**:
   ```lua
   _G.SentryTestFunctions.sendTestMessage("Success!")
   ```

4. **No Console Errors**: Clean output with success messages

## 🚀 Next Steps

Once basic integration works:

1. **Customize for your game**: Update DSN, environment, tags
2. **Add to your scripts**: Integrate error capture in game logic  
3. **Set up user context**: Capture player information
4. **Monitor performance**: Add transaction tracking
5. **Create alerts**: Set up Sentry notifications

## 📞 Need Help?

1. **Check `DEV_WORKFLOW.md`** for comprehensive development guide
2. **Run validation script** to check for issues
3. **Use shell helper** for guided setup
4. **Test with quick-test-script** for immediate feedback

The macOS workflow is now streamlined and reliable! 🎯