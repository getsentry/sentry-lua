# Binary Rock Distribution Guide

This document explains how the Sentry Lua SDK is distributed via binary rocks to solve the Teal compilation issue.

## Problem

The Sentry Lua SDK is written in Teal and compiled to Lua. The rockspec references compiled files in `build/` directory:

```lua
-- sentry-0.0.3-1.rockspec
modules = {
  ["sentry"] = "build/sentry/init.lua",
  -- ...
}
```

When users install via `luarocks install sentry-0.0.3-1.rockspec`, LuaRocks:
1. Clones the Git repository 
2. Expects `build/` files to exist (they don't - only exist after Teal compilation)
3. Installation fails

## Solution: Binary Rocks

We create **binary rocks** (`.rock` files) that contain pre-compiled Lua files.

### Local Development

```bash
# Create binary rock
make rock

# Test installation
make test-rock

# Clean up
rm *.rock sentry-*/
```

### CI/CD Integration

The GitHub Actions workflow in `.github/workflows/test.yml` automatically:
1. Builds the Teal sources (`make build`)
2. Creates binary rock (`luarocks make --pack-binary-rock`) 
3. Uploads rock as artifact

### Release Process

The `.github/workflows/release.yml` includes binary rock creation for releases.

## Distribution Methods

### Method 1: GitHub Releases (Current)
- Binary rocks uploaded to GitHub releases
- Users download and install locally:
  ```bash
  luarocks install sentry-0.0.3-1.all.rock
  ```

### Method 2: Future Options
- Custom LuaRocks server
- Official LuaRocks.org submission (with build-enabled rockspec)

## Compatibility

- **Target**: Lua 5.1 compatibility (`tlconfig.lua`: `gen_target = "5.1"`, `gen_compat = "optional"`)
- **Tested**: Lua 5.1, 5.2, 5.3, 5.4, LuaJIT 2.0, LuaJIT 2.1
- **Platform**: Pure Lua (no native code currently)

## File Structure

```
sentry-0.0.3-1.all.rock (binary rock)
├── lua/sentry/
│   ├── init.lua (compiled from src/sentry/init.tl)
│   ├── core/
│   ├── platforms/
│   └── utils/
├── doc/ (documentation)
└── rock_manifest
```

## Verification

Test the binary rock works:

```bash
# Create and test
make test-rock

# Manual verification
luarocks install --local sentry-0.0.3-1.all.rock
eval "$(luarocks path --local)"
lua -e "local sentry = require('sentry'); print('✅ Success')"
```

## Advantages

✅ **No compilation required** - Users don't need Teal installed  
✅ **Faster installation** - Pre-compiled, no build step  
✅ **Lua 5.1 compatible** - Works across all Lua versions  
✅ **CI automated** - Automatically created in workflows  

## Maintenance

- Binary rocks created automatically in CI for every test run
- Release workflow includes binary rock generation
- `make rock` target for local development
- `.gitignore` excludes `*.rock` and `sentry-*/` from version control

### Security

- All GitHub Actions use pinned commit SHAs (not version tags) for security
- See `.claude/memories/github-actions-security.md` for SHA reference
- Actions are verified and updated following security best practices