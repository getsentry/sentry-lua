# Roblox Sentry Integration

Example Sentry integration for Roblox games.

## 🚀 Quick Start (Recommended)

**Use the all-in-one file for easiest setup:**

1. **Copy** `sentry-all-in-one.lua` 
2. **Paste** into ServerScriptService as a Script
3. **Update DSN** on line 16
4. **Enable HTTP**: Game Settings → Security → "Allow HTTP Requests"
5. **Run** the game (F5)

## 📁 Available Files

### Production Files
- **`sentry-all-in-one.lua`** ⭐ **Complete single-file solution (recommended)**
- **`sentry-roblox-sdk.lua`** - Reusable SDK module  
- **`clean-example.lua`** - Example using the SDK module

### Development Files  
- **`simple-studio-test.sh`** - macOS setup helper

### Legacy Files (for reference)
- `simple-sentry-test.lua` - Original working implementation
- `quick-test-script.lua` - First attempt (has security issues)

## 🎯 Integration Options

### Option 1: All-in-One (Easiest)
Perfect for testing and simple games.
```lua
-- Just copy sentry-all-in-one.lua into your Script
-- Everything included: SDK + example + test functions
```

### Option 2: Modular Approach
Better for complex games with organized code.
```lua
-- 1. Place sentry-roblox-sdk.lua in ReplicatedStorage as ModuleScript "SentrySDK"
-- 2. Use clean-example.lua as a starting point
-- 3. Customize for your game
```

## 🧪 Testing

All files include built-in test functions:

```lua
-- All-in-one version:
_G.SentryAllInOne.sendMessage("Hello!")
_G.SentryAllInOne.triggerError()

-- Clean example version:
_G.CleanSentryTest.sendMessage("Hello!")
_G.CleanSentryTest.triggerError()
```

## ✅ Success Indicators

Your integration is working when you see:

1. **Console Output**:
   ```
   ✅ Event sent successfully!
   📊 Response: {"id":"..."}
   ```

2. **Sentry Dashboard**: Events appear within 30 seconds at https://sentry.io/

3. **Manual Commands Work**: Test functions execute without errors

## 🛠️ Customization

Update these values in your integration:

```lua
-- Required
local SENTRY_DSN = "your-sentry-dsn-here"

-- Optional  
sentry.init({
    dsn = SENTRY_DSN,
    environment = "production",  -- or "staging", "development"
    release = "1.2.0"           -- your game version
})

-- Add user context
sentry.set_user({
    id = tostring(player.UserId),
    username = player.Name
})

-- Add custom tags
sentry.set_tag("game_mode", "survival")
sentry.set_tag("level", "5")

-- Add breadcrumbs for debugging
sentry.add_breadcrumb({
    message = "Player entered dungeon",
    category = "game_event",
    data = {dungeon_id = "dark_forest"}
})
```

## 🐛 Troubleshooting

### Common Issues

**"Header Content-Type is not allowed"**
- Fixed in current versions ✅

**"_G.SentryTest is nil"**
- Wait a few seconds after game starts
- Or use the built-in test functions directly

**"HTTP requests not enabled"**  
- Game Settings → Security → ✅ "Allow HTTP Requests"

**No events in Sentry dashboard**
- Wait 10-30 seconds for events to appear
- Check you're looking at the correct project
- Verify DSN is correct
- Test with manual functions

### Getting Help

1. Use `sentry-all-in-one.lua` for easiest testing
2. Check `FINAL_TEST_GUIDE.md` for detailed instructions  
3. Run the macOS helper: `./simple-studio-test.sh`

## 🎉 Ready to Go!

The Roblox integration is production-ready. Use `sentry-all-in-one.lua` to get started immediately, then customize for your specific game needs.

**Happy debugging with Sentry! 🐛→✅**