# Roblox Sentry Integration Demo

This example demonstrates how to integrate the Sentry Lua SDK with Roblox games.

## Features

- **Roblox HTTP Transport**: Uses `HttpService` for sending events to Sentry
- **Error Tracking**: Captures unhandled errors with stack traces
- **Message Capture**: Manual event reporting with custom messages
- **User Context**: Automatic player information collection
- **GUI Interface**: Interactive testing interface with buttons to trigger events
- **Platform Detection**: Automatic Roblox runtime and OS detection

## Installation

### Method 1: Manual Installation (Recommended for Testing)

1. **Copy Sentry SDK Files**:
   - Copy the entire `sentry/` folder from the build directory to your Roblox project
   - Place it in `ReplicatedStorage` so both server and client can access it

2. **Place Example Scripts**:
   - Copy `ServerScript.lua` to `ServerScriptService`
   - Copy `LocalScript.lua` to `StarterPlayer.StarterPlayerScripts`
   - Copy `SentryTestGUI.lua` to `StarterGui`

### Method 2: Roblox Model (Future)

A packaged Roblox model will be available for easy insertion into your games.

## Usage

### Server-Side Integration

```lua
-- ServerScriptService/SentryServer.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local sentry = require(ReplicatedStorage.sentry)

-- Initialize Sentry
sentry.init({
   dsn = "https://your-dsn@sentry.io/project-id",
   environment = "roblox-server",
   release = "1.0.0",
   server_name = "GameServer-" .. game.JobId
})

-- Capture player join events
game.Players.PlayerAdded:Connect(function(player)
   sentry.set_user({
      id = tostring(player.UserId),
      username = player.Name,
      email = nil -- Don't collect emails for privacy
   })
   
   sentry.add_breadcrumb({
      message = "Player joined game",
      level = "info",
      data = {
         player_name = player.Name,
         player_id = player.UserId
      }
   })
end)

-- Wrap error-prone functions
local function dangerousGameFunction()
   -- Game logic that might error
   error("Something went wrong in the game!")
end

-- Automatic error capture
local success, result = sentry.wrap(dangerousGameFunction)
```

### Client-Side Integration

```lua
-- StarterPlayer/StarterPlayerScripts/SentryClient.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local sentry = require(ReplicatedStorage.sentry)

local player = Players.LocalPlayer

-- Initialize Sentry for client
sentry.init({
   dsn = "https://your-dsn@sentry.io/project-id",
   environment = "roblox-client",
   release = "1.0.0"
})

-- Set user context
sentry.set_user({
   id = tostring(player.UserId),
   username = player.Name
})

-- Example: Capture UI errors
local function setupErrorCapture()
   -- Capture GUI errors
   player.PlayerGui.ChildAdded:Connect(function(gui)
      if gui:IsA("ScreenGui") then
         -- Monitor for GUI-related errors
         sentry.add_breadcrumb({
            message = "GUI added",
            data = { gui_name = gui.Name }
         })
      end
   end)
end

setupErrorCapture()
```

## Interactive Testing

The example includes a testing GUI (`SentryTestGUI.lua`) that provides buttons to:

1. **Send Test Message** - Captures a test message with info level
2. **Trigger Test Error** - Deliberately causes an error to test error capture
3. **Add Breadcrumb** - Adds debugging breadcrumbs
4. **Set User Context** - Updates user information
5. **Test Tags** - Demonstrates tag functionality

## Configuration

Update the DSN in the example scripts:

```lua
sentry.init({
   dsn = "YOUR_SENTRY_DSN_HERE", -- Replace with your actual DSN
   environment = "roblox",
   release = "1.0.0",
   tags = {
      game_name = "Your Game Name",
      game_version = "1.0.0"
   }
})
```

## Roblox-Specific Features

- **HttpService Integration**: Automatically uses Roblox's HTTP service
- **Player Context**: Collects player information automatically
- **Game Context**: Includes game ID, place ID, and server information
- **Studio Detection**: Detects when running in Roblox Studio vs live game
- **Privacy Compliance**: Respects Roblox's privacy guidelines

## Troubleshooting

### HTTP Requests Not Working

1. Ensure `HttpService` is enabled in your game settings
2. Check that your Sentry DSN is correct
3. Verify the game has internet access (not applicable in Studio offline mode)

### Module Not Found

1. Ensure the `sentry` module is placed in `ReplicatedStorage`
2. Check that the folder structure matches the expected layout
3. Verify all Lua files are properly named and accessible

### Testing in Studio

The example works in both Roblox Studio (for development) and live games (for production). Studio testing is recommended for initial setup and debugging.

## Security Notes

- Never commit your actual Sentry DSN to public repositories
- Use environment variables or secure configuration for production DSNs
- Be mindful of Roblox's data collection and privacy policies
- Consider different DSNs for development vs production environments