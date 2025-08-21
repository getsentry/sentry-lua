# Roblox Sentry Integration

Complete Sentry integration for Roblox games using the single-file SDK.

## 🚀 Quick Start

**Use the single-file SDK example:**

1. **Copy** `sentry.lua` from this directory
2. **Paste** into ServerScriptService as a Script  
3. **Update DSN** (search for "UPDATE THIS WITH YOUR SENTRY DSN")
4. **Enable HTTP**: Game Settings → Security → "Allow HTTP Requests"
5. **Run** the game (F5)

## 📁 Files

- **`sentry.lua`** ⭐ **Complete example with embedded SDK**
- **`README.md`** - This setup guide

## 🧪 Testing

The example demonstrates all major SDK features:

```lua
-- The SDK is automatically available as 'sentry' after running the script
sentry.capture_message("Hello Sentry!", "info")
sentry.capture_exception({type = "TestError", message = "Something failed"})

-- Context setting
sentry.set_user({id = "123", username = "Player1"})
sentry.set_tag("level", "5") 
sentry.add_breadcrumb({message = "Player moved", category = "navigation"})

-- Logging functions (single-file only)
sentry.logger.info("Player connected")
sentry.logger.error("Database connection failed")

-- Tracing functions (single-file only)
local transaction = sentry.start_transaction("game_round", "Match gameplay")
-- ... game logic ...
transaction:finish()
```

## ✅ Success Indicators

Your integration is working when you see:

1. **Console Output**:
   ```
   ✅ Sentry integration ready - SDK 0.0.6
   ✅ Event sent via Roblox HttpService  
   ```

2. **Sentry Dashboard**: Events appear within 30 seconds

3. **Manual Test Works**: `_G.testSentry()` executes without errors

## 🛠️ Customization

```lua
-- Update the DSN at the top of sentry.lua
local SENTRY_DSN = "https://your-key@your-org.ingest.sentry.io/your-project-id"

-- Customize initialization
sentry.init({
    dsn = SENTRY_DSN,
    environment = "production",  -- or "staging", "development"  
    release = "1.2.0"           -- your game version
})

-- Add user context from actual players
game.Players.PlayerAdded:Connect(function(player)
    sentry.set_user({
        id = tostring(player.UserId),
        username = player.Name
    })
end)
```

## 🐛 Troubleshooting  

**"HTTP requests not enabled"**  
→ Game Settings → Security → ✅ "Allow HTTP Requests"

**No events in Sentry dashboard**  
→ Wait 10-30 seconds, check correct project, verify DSN

**"attempt to index nil with 'capture_message'"**  
→ Make sure the script ran successfully and no initialization errors occurred

## 🔧 Advanced Usage

The single-file SDK provides global access in multiple ways:

```lua
-- Direct access (set by the script)
sentry.capture_message("Direct access")

-- Global access
_G.sentry.capture_message("Global access") 

-- Shared access  
shared.sentry.capture_message("Shared access")

-- Test function
_G.testSentry("Test message")
```

## 🎉 Ready to Go!

The `sentry.lua` file contains everything you need. Copy it into Roblox Studio, update your DSN, and start monitoring your game!

**Happy debugging with Sentry! 🐛→✅**