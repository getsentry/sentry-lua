# Roblox Sentry Integration Setup Instructions

Follow these step-by-step instructions to set up the Sentry Lua SDK in your Roblox game.

## Prerequisites

1. **Roblox Studio** - Make sure you have Roblox Studio installed and you're logged in
2. **Sentry Account** - You need a Sentry account and project with a valid DSN
3. **HTTP Service Enabled** - Your game must have HTTP requests enabled

## Step-by-Step Setup

### Step 1: Prepare the Sentry SDK

1. **Build the Sentry SDK**:
   ```bash
   cd /path/to/sentry-lua
   make build
   ```

2. **Copy the built Sentry module**:
   - Navigate to the `build/` directory in your sentry-lua project
   - Copy the entire `sentry/` folder

### Step 2: Set Up Roblox Studio

1. **Create a new Place** or open an existing one in Roblox Studio

2. **Enable HTTP Service**:
   - Go to Game Settings (Game → Game Settings)
   - Navigate to Security tab
   - Check "Allow HTTP Requests"
   - Click "Save"

### Step 3: Import Sentry SDK

1. **Add Sentry to ReplicatedStorage**:
   - In the Explorer panel, right-click on "ReplicatedStorage"
   - Select "Insert Object" → "Folder"
   - Rename it to "sentry"
   - Inside this folder, you'll need to recreate the entire Sentry module structure

2. **Create Module Structure**:
   For each `.lua` file in your `build/sentry/` directory, create a corresponding ModuleScript in Roblox:
   
   - Right-click the sentry folder → "Insert Object" → "ModuleScript"
   - Rename it to match the file name (e.g., "init" for `init.lua`)
   - Copy the contents of the corresponding `.lua` file into the ModuleScript
   - Repeat for all subdirectories and files

   **Main structure to create**:
   ```
   ReplicatedStorage
   └── sentry (Folder)
       ├── init (ModuleScript) -- from build/sentry/init.lua
       ├── core (Folder)
       │   ├── client (ModuleScript)
       │   ├── context (ModuleScript)
       │   ├── transport (ModuleScript)
       │   └── ... (other core modules)
       ├── platforms (Folder)
       │   ├── roblox (Folder)
       │   │   ├── transport (ModuleScript)
       │   │   ├── context (ModuleScript)
       │   │   └── ... (other roblox modules)
       │   └── ... (other platform folders)
       ├── utils (Folder)
       │   └── ... (utility modules)
       └── ... (other folders)
   ```

### Step 4: Add Example Scripts

1. **Server Script**:
   - Right-click "ServerScriptService"
   - Insert Object → "Script" (not LocalScript)
   - Rename to "SentryServer"
   - Copy contents from `ServerScript.lua`
   - **Important**: Update the DSN line with your actual Sentry DSN

2. **Client Script**:
   - Navigate to StarterPlayer → StarterPlayerScripts
   - Right-click StarterPlayerScripts
   - Insert Object → "LocalScript"
   - Rename to "SentryClient"
   - Copy contents from `LocalScript.lua`
   - **Important**: Update the DSN line with your actual Sentry DSN

3. **Test GUI** (Optional):
   - Right-click "StarterGui"
   - Insert Object → "LocalScript"
   - Rename to "SentryTestGUI"
   - Copy contents from `SentryTestGUI.lua`

### Step 5: Configure Your DSN

1. **Get your Sentry DSN**:
   - Log into your Sentry dashboard
   - Go to Project Settings → Client Keys (DSN)
   - Copy your DSN URL

2. **Update the scripts**:
   - In both `SentryServer` and `SentryClient` scripts
   - Find the line: `dsn = "https://your-sentry-dsn@sentry.io/your-project-id"`
   - Replace with your actual DSN

### Step 6: Test the Integration

1. **Run the game**:
   - Press F5 or click the "Play" button in Roblox Studio
   - Check the Output window for Sentry initialization messages

2. **Test with GUI** (if you added the test GUI):
   - You should see a "Sentry Test Panel" window
   - Click the buttons to test different Sentry features
   - Check your Sentry dashboard for events

3. **Manual testing**:
   - In the Studio command bar, try:
   ```lua
   _G.SentryTestFunctions.sendTestMessage("Hello from Studio!")
   ```

## Troubleshooting

### "Module not found" errors

- **Issue**: `sentry` module cannot be found
- **Solution**: Make sure the sentry folder is in ReplicatedStorage and all ModuleScript names match exactly

### HTTP requests not working

- **Issue**: Events not appearing in Sentry dashboard
- **Solution**: 
  1. Check that HTTP Service is enabled in Game Settings
  2. Verify your DSN is correct
  3. Make sure you're testing in Play mode, not just in the editor

### Script errors

- **Issue**: Lua errors when running the scripts
- **Solution**:
  1. Make sure all ModuleScripts are properly created
  2. Check that the folder structure matches exactly
  3. Verify all script contents were copied correctly

### Performance issues

- **Issue**: Game running slowly after adding Sentry
- **Solution**:
  1. Reduce breadcrumb frequency
  2. Set appropriate log levels
  3. Consider using client-side only for development

## Advanced Configuration

### Production vs Development

For production games, consider:

1. **Different DSNs** for development vs production
2. **Reduced logging levels** to avoid spam
3. **Error sampling** to manage quotas
4. **User privacy** compliance

### Custom Transport

You can customize the Roblox transport by modifying:
`sentry/platforms/roblox/transport.lua`

### Additional Context

Add game-specific context in your initialization:

```lua
sentry.init({
   dsn = "your-dsn",
   environment = "production",
   tags = {
      game_genre = "Adventure",
      game_version = "1.2.3",
      server_region = "US-East"
   }
})
```

## Next Steps

Once you have the basic integration working:

1. **Add custom error boundaries** around critical game functions
2. **Set up user context** with relevant player information
3. **Create custom breadcrumbs** for important game events
4. **Monitor performance** with timing information
5. **Set up alerts** in Sentry for critical errors

## Support

If you encounter issues:

1. Check the [main README](../../README.md) for general Sentry information
2. Review the Roblox-specific transport code in `src/sentry/platforms/roblox/`
3. Test with the minimal example first before adding to complex games
4. Check Sentry's dashboard for error messages and debugging info