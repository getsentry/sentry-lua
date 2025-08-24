# Development Scripts

This directory contains development automation scripts for the Sentry Lua SDK.

## dev.lua

A cross-platform Lua script that replaces traditional Makefile functionality, ensuring compatibility across Windows, macOS, and Linux.

### Usage

```bash
# Show help
lua scripts/dev.lua help

# Install all dependencies
lua scripts/dev.lua install

# Run tests
lua scripts/dev.lua test

# Run tests with coverage (generates luacov.report.out)
lua scripts/dev.lua coverage

# Run linter
lua scripts/dev.lua lint

# Check code formatting
lua scripts/dev.lua format-check

# Format code
lua scripts/dev.lua format

# Test rockspec installation
lua scripts/dev.lua test-rockspec

# Clean build artifacts
lua scripts/dev.lua clean

# Run full CI pipeline
lua scripts/dev.lua ci
```

### Requirements

- Lua (5.1+)
- LuaRocks
- For formatting: StyLua (`cargo install stylua`)

### Cross-Platform Commands

The script automatically detects the platform and uses appropriate commands:

- **Windows**: Uses `dir`, `rmdir`, `xcopy`
- **Unix/Linux/macOS**: Uses `ls`, `rm`, `cp`

This ensures the same script works across all development environments without modification.

### CI Integration

The `ci` command runs the complete pipeline:
1. Linting with luacheck
2. Format checking with StyLua  
3. Test suite with busted
4. Coverage reporting with luacov

This matches what runs in GitHub Actions, allowing developers to run the same checks locally.