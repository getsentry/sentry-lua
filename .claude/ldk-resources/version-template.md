# Version Management: $ARGUMENTS
# INSTALL_VERSION=development
# INSTALL_COMMIT=HEAD
# INSTALL_DATE=Not installed via INSTALL.md
# REPOSITORY=https://github.com/mah0x211/claude-lua-devkit.git

You will manage the claude-lua-devkit installation version.

## Step 1: Parse Arguments

Parse $ARGUMENTS:
- IF empty or "current": Show current version information
- IF "list" or "ls": Show available remote versions
- IF "update": Update to latest version using remote INSTALL.md
- IF "update [version]": Update to specific version
- IF "help": Show usage information

## Step 2: Execute Command Based on Arguments

### Show Current Version (default, "current")

Extract version information from this command file:
```bash
CURRENT_VERSION=$(grep "^# INSTALL_VERSION=" "$0" | cut -d'=' -f2)
CURRENT_COMMIT=$(grep "^# INSTALL_COMMIT=" "$0" | cut -d'=' -f2)
CURRENT_DATE=$(grep "^# INSTALL_DATE=" "$0" | cut -d'=' -f2-)
CURRENT_REPO=$(grep "^# REPOSITORY=" "$0" | cut -d'=' -f2-)
```

Display version information nicely:
```
claude-lua-devkit Version Information:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Version:      $CURRENT_VERSION
Commit:       $CURRENT_COMMIT
Installed:    $CURRENT_DATE
Repository:   $CURRENT_REPO
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### List Remote Versions ("list", "ls")

Say: "Fetching available versions from GitHub..."

```bash
# Create temporary directory for version check
mkdir -p .tmp
git clone --bare https://github.com/mah0x211/claude-lua-devkit.git .tmp/version-check 2>/dev/null
```

IF clone successful:
```bash
cd .tmp/version-check
git tag -l 'v*' | sort -V
cd ../..
rm -rf .tmp/version-check
```

Display available versions:
```
Available claude-lua-devkit versions:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[list of versions]
master (development)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

To update: /commands/ldk/version update [version]
Example:   /commands/ldk/version update v1.0.0
```

IF clone failed:
Say: "Failed to fetch version information. Please check your internet connection."

### Update Installation ("update", "update [version]")

IF specific version provided:
- Say: "Updating to version [version]..."
- Set target version for installation

IF no version provided:
- Say: "Updating to latest version..."
- Set target to master/latest

Execute update using remote INSTALL.md:
Say: "Executing update using remote installation procedure..."

```bash
# Fetch and execute remote INSTALL.md
curl -s https://raw.githubusercontent.com/mah0x211/claude-lua-devkit/master/INSTALL.md > .tmp/remote-install.md 2>/dev/null
```

IF fetch successful:
- Say: "✓ Downloaded latest installation procedure"
- Say: "Following remote installation steps for update..."
- Execute the installation steps from the remote INSTALL.md
- The remote installer will detect existing installation and handle update

IF fetch failed:
Say: "Failed to download remote installer. Please check your internet connection or try manual update."

### Show Help ("help")

Display usage information:
```
claude-lua-devkit Version Management

Usage: /commands/ldk/version [command]

Commands:
  (no args)     Show current version information
  current       Show current version information
  list          List available remote versions
  ls            List available remote versions (alias)
  update        Update to latest version
  update <ver>  Update to specific version (e.g., v1.0.0)
  help          Show this help message

Examples:
  /commands/ldk/version
  /commands/ldk/version list
  /commands/ldk/version update
  /commands/ldk/version update v1.0.0

The update command uses the remote INSTALL.md for safe upgrading.
```

## Step 3: Completion Message

After successful command execution:
- IF showing version: No additional message needed
- IF listing versions: Say "Use '/commands/ldk/version update [version]' to update"
- IF updating: Say "Update complete! Version information updated."
- IF help: No additional message needed