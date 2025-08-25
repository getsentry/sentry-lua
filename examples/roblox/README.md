# Roblox Sentry Integration

Example Sentry integration for Roblox games.

## 🚀 Quick Start

**Use the all-in-one file:**

1. **Copy** `sentry-all-in-one.luau` 
2. **Paste** into ServerScriptService as a Script
3. **Update DSN** on line 18
4. **Enable HTTP**: Game Settings → Security → "Allow HTTP Requests"  
5. **Run** the game (F5)

## 📁 Available Files

- **`sentry-all-in-one.luau`** ⭐ **Complete single-file solution**

## 🧪 Testing

Use the standard Sentry API (same as other platforms):

```lua
-- Capture events
sentry.capture_message("Hello Sentry!", "info")
sentry.capture_exception({type = "TestError", message = "Something failed"})

-- Set context  
sentry.set_user({id = "123", username = "Player1"})
sentry.set_tag("level", "5")
sentry.add_breadcrumb({message = "Player moved", category = "navigation"})
```

## ✅ Success Indicators

Your integration is working when you see:

1. **Console Output**:
   ```
   ✅ Event sent successfully!
   📊 Response: {"id":"..."}
   ```

2. **Sentry Dashboard**: Events appear within 30 seconds

3. **Manual Commands Work**: `sentry.capture_message("test")` executes without errors

## 🛠️ Customization

```lua
-- Required: Update your DSN
local SENTRY_DSN = "https://your-key@your-org.ingest.sentry.io/your-project-id"

-- Optional: Customize environment and release
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

-- Add custom tags and breadcrumbs
sentry.set_tag("game_mode", "survival")
sentry.add_breadcrumb({
    message = "Player entered dungeon",
    category = "game_event"
})
```

## 🐛 Troubleshooting

**"HTTP requests not enabled"**  
→ Game Settings → Security → ✅ "Allow HTTP Requests"

**No events in Sentry dashboard**  
→ Wait 10-30 seconds, check correct project, verify DSN

**"attempt to index nil with 'capture_message'"**  
→ Make sure sentry.init() was called successfully first

## 🎉 Ready to Go!

Use `sentry-all-in-one.luau` to get started immediately. Copy, paste, update DSN, and test!

**Happy debugging with Sentry! 🐛→✅**