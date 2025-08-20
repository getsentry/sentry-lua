# Detailed Roblox Studio Setup Guide

Follow this step-by-step guide to set up Sentry in Roblox Studio.

## Prerequisites Checklist

- [ ] Roblox Studio installed and logged in
- [ ] Built Sentry SDK (`make build` completed successfully)
- [ ] Sentry project created with DSN available
- [ ] HTTP requests enabled in game settings

## Step 1: Build the Sentry SDK

If you haven't already, build the Sentry SDK:

```bash
cd /path/to/sentry-lua
make build
```

This creates compiled Lua files in the `build/` directory.

## Step 2: Prepare Roblox Studio

1. **Open Roblox Studio**
2. **Create a new Baseplate** (or open existing place)
3. **Enable HTTP Service**:
   - Home tab → Game Settings
   - Security tab
   - ✅ Check "Allow HTTP Requests"
   - Save & Publish

## Step 3: Create the Module Structure in ReplicatedStorage

This is the most important step. You need to manually recreate the entire Sentry module structure in Roblox Studio.

### 3.1 Create the Main Sentry Folder

1. In Explorer panel, right-click **ReplicatedStorage**
2. Insert Object → **Folder**
3. Rename to: `sentry`

### 3.2 Create the Main Init Module

1. Right-click the `sentry` folder
2. Insert Object → **ModuleScript**
3. Rename to: `init`
4. Double-click to open
5. **Replace ALL content** with the contents of `build/sentry/init.lua`

### 3.3 Create Core Modules Folder

1. Right-click the `sentry` folder
2. Insert Object → **Folder**
3. Rename to: `core`
4. For each `.lua` file in `build/sentry/core/`:
   - Right-click `core` folder → Insert Object → ModuleScript
   - Rename to match the filename (without .lua extension)
   - Copy the file contents into the ModuleScript

**Core modules to create:**
- `auto_transport`
- `client`
- `context`
- `file_io`
- `file_transport`
- `scope`
- `test_transport`
- `transport`

### 3.4 Create Utils Folder and Modules

1. Right-click `sentry` folder → Insert Object → **Folder** → Rename to: `utils`
2. For each file in `build/sentry/utils/`:
   - Create ModuleScript with matching name
   - Copy contents

**Utils modules to create:**
- `dsn`
- `envelope`
- `http`
- `json`
- `os`
- `runtime`
- `serialize`
- `stacktrace`
- `transport`

### 3.5 Create Platform Modules

1. Right-click `sentry` folder → Insert Object → **Folder** → Rename to: `platforms`
2. Right-click `platforms` folder → Insert Object → **Folder** → Rename to: `roblox`
3. For each file in `build/sentry/platforms/roblox/`:
   - Create ModuleScript in the `roblox` folder
   - Copy contents

**Roblox platform modules to create:**
- `context`
- `file_io`
- `os_detection`
- `transport`

### 3.6 Create Other Required Modules

Create these additional ModuleScripts in the main `sentry` folder:
- `platform_loader`
- `types`
- `utils` (this is different from the utils folder)
- `version`

Create these folders with their init modules:
- `logger` folder with `init` ModuleScript
- `performance` folder with `init` ModuleScript
- `tracing` folder with `init`, `headers`, `propagation` ModuleScripts

## Step 4: Verify Module Installation

1. Create a new Script in ServerScriptService
2. Copy the contents of `TestModuleStructure.lua`
3. Run the game (F5)
4. Check Output panel for results

**Expected output:**
```
🔍 Testing Sentry module installation...
✅ Found sentry folder in ReplicatedStorage
✅ Found init ModuleScript
✅ Successfully loaded sentry module
✅ All expected functions found
🧪 Testing basic module functionality...
✅ Module initialization test passed
🎉 Sentry module is properly installed and ready to use!
```

## Step 5: Add the Example Scripts

Only proceed if Step 4 was successful.

### 5.1 Server Script

1. Right-click **ServerScriptService**
2. Insert Object → **Script** (not LocalScript)
3. Rename to: `SentryServer`
4. Copy contents from `ServerScript.lua`
5. **Update the DSN** on line ~22 with your real Sentry DSN

### 5.2 Client Script

1. Navigate to **StarterPlayer** → **StarterPlayerScripts**
2. Right-click StarterPlayerScripts
3. Insert Object → **LocalScript**
4. Rename to: `SentryClient`
5. Copy contents from `LocalScript.lua`
6. **Update the DSN** on line ~24 with your real Sentry DSN

### 5.3 Test GUI (Optional)

1. Right-click **StarterGui**
2. Insert Object → **LocalScript**
3. Rename to: `SentryTestGUI`
4. Copy contents from `SentryTestGUI.lua`

## Step 6: Test the Integration

1. **Run the game** (F5 or Play button)
2. **Check Output panel** for initialization messages:
   ```
   🔧 Sentry initialized for Roblox server
   🔧 Sentry initialized for Roblox client
   🚀 Roblox Sentry Server Demo ready!
   🚀 Roblox Sentry Client Demo ready!
   ```

3. **Test manual commands** in Command Bar:
   ```lua
   _G.SentryTestFunctions.sendTestMessage("Hello from Studio!")
   ```

4. **Use the Test GUI** if you added it - you should see a purple "Sentry Test Panel"

## Troubleshooting Common Issues

### "Infinite yield possible on ReplicatedStorage:WaitForChild('sentry')"

**Problem**: The sentry folder doesn't exist in ReplicatedStorage
**Solution**: Make sure you created the `sentry` folder exactly as described in Step 3

### "attempt to call a nil value"

**Problem**: Required modules are missing
**Solution**: Check that all ModuleScripts are created and contain the correct code

### "_G.SentryTestFunctions is nil"

**Problem**: The LocalScript hasn't run yet or failed to load
**Solution**: 
1. Make sure the `SentryClient` LocalScript is in StarterPlayerScripts
2. Check Output panel for any error messages
3. Verify all modules load correctly first

### "HTTP requests are not enabled"

**Problem**: HTTP service is disabled
**Solution**: Game Settings → Security → Enable "Allow HTTP Requests"

### No data appearing in Sentry dashboard

**Problem**: Network issues or wrong DSN
**Solution**:
1. Verify your DSN is correct
2. Test with Studio's HTTP service
3. Check Sentry project settings
4. Try running in a published game (not just Studio)

## Manual Module Structure Check

If you're having issues, verify this exact structure exists in ReplicatedStorage:

```
ReplicatedStorage
└── sentry (Folder)
    ├── init (ModuleScript) ← CRITICAL: This must exist
    ├── core (Folder)
    │   ├── auto_transport (ModuleScript)
    │   ├── client (ModuleScript)
    │   ├── context (ModuleScript)
    │   ├── file_io (ModuleScript)
    │   ├── file_transport (ModuleScript)
    │   ├── scope (ModuleScript)
    │   ├── test_transport (ModuleScript)
    │   └── transport (ModuleScript)
    ├── platforms (Folder)
    │   └── roblox (Folder)
    │       ├── context (ModuleScript)
    │       ├── file_io (ModuleScript)
    │       ├── os_detection (ModuleScript)
    │       └── transport (ModuleScript)
    ├── utils (Folder)
    │   ├── dsn (ModuleScript)
    │   ├── envelope (ModuleScript)
    │   ├── http (ModuleScript)
    │   ├── json (ModuleScript)
    │   ├── os (ModuleScript)
    │   ├── runtime (ModuleScript)
    │   ├── serialize (ModuleScript)
    │   ├── stacktrace (ModuleScript)
    │   └── transport (ModuleScript)
    ├── logger (Folder)
    │   └── init (ModuleScript)
    ├── performance (Folder)
    │   └── init (ModuleScript)
    ├── tracing (Folder)
    │   ├── init (ModuleScript)
    │   ├── headers (ModuleScript)
    │   └── propagation (ModuleScript)
    ├── platform_loader (ModuleScript)
    ├── types (ModuleScript)
    ├── utils (ModuleScript) ← Note: different from utils folder
    └── version (ModuleScript)
```

## Need Help?

1. **First**: Run the `TestModuleStructure.lua` script to verify your setup
2. **Check Output**: Look for specific error messages
3. **Verify DSN**: Make sure your Sentry DSN is valid and up to date
4. **Test Gradually**: Start with just the test script, then add other components

Once you see the success messages from the test script, the main integration should work!