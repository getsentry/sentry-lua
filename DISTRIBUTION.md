# LuaRocks Distribution Guide

This document explains how the Sentry Lua SDK is distributed via LuaRocks with automatic Teal compilation.

## Overview

The Sentry Lua SDK is written in Teal and compiled to Lua. The rockspec uses a `command` build type to automatically compile Teal sources during installation:

```lua
-- sentry-0.0.4-1.rockspec
build = {
   type = "command",
   build_command = "make build",
   install_command = "mkdir -p $(LUADIR)/sentry && cp -r build/sentry/* $(LUADIR)/sentry/",
   -- ...
}
```

When users install via `luarocks install sentry/sentry`, LuaRocks:
1. Clones the Git repository at the specified tag
2. Runs `make build` to compile Teal sources to Lua
3. Installs the compiled Lua modules

## Solution: Command-Based Build

We use LuaRocks' `command` build type with automatic Teal compilation.

### Local Development

```bash
# Test rockspec installation
make test-rockspec

# Build from source
make build

# Install locally for development
luarocks make --local
```

### CI/CD Integration

The GitHub Actions workflow in `.github/workflows/test.yml` automatically:
1. Installs Teal compiler and dependencies
2. Builds the Teal sources (`make build`)
3. Tests rockspec installation (`make test-rockspec`)

### Release Process

The release process:
1. Creates a git tag matching the version
2. The rockspec references this tag in the `source.tag` field
3. LuaRocks.org can install directly from the git repository

## Distribution Methods

### Method 1: LuaRocks.org (Recommended - macOS/Linux)
```bash
# Install from LuaRocks.org (requires Unix-like system for Teal compilation)
luarocks install sentry/sentry
```
**Note:** Use `sentry/sentry` (not just `sentry`) as the plain `sentry` package is owned by someone else.

### Method 2: Direct Download (Cross-platform)
For Windows or systems without make/compiler support:
1. Download the latest `sentry-lua-sdk-publish.zip` from GitHub Releases
2. Extract and add to your Lua path
3. No compilation required - contains pre-built Lua files

### Method 3: Git Source (Development)
```bash
# Install from specific version (Unix-like systems only)
git clone https://github.com/getsentry/sentry-lua.git
cd sentry-lua
make build
luarocks make --local
```

## Compatibility

- **Target**: Lua 5.1 compatibility (`tlconfig.lua`: `gen_target = "5.1"`, `gen_compat = "optional"`)
- **Tested**: Lua 5.1, 5.2, 5.3, 5.4, LuaJIT 2.0, LuaJIT 2.1
- **Platform**: Pure Lua (no native code currently)

## Build Process

```
Git Repository:
├── src/sentry/           (Teal sources)
│   ├── init.tl
│   ├── core/
│   ├── platforms/
│   └── utils/
├── Makefile              (Build system)
└── sentry-0.0.4-1.rockspec

After `make build`:
├── build/sentry/         (Compiled Lua)
│   ├── init.lua
│   ├── core/
│   ├── platforms/
│   └── utils/

After `make publish`:
├── sentry-lua-sdk-publish.zip (Direct download package)
    ├── build/sentry/     (Pre-compiled Lua files)
    ├── examples/         (Usage examples)
    ├── README.md
    └── CHANGELOG.md
```

## Verification

Test the rockspec installation works:

```bash
# Test rockspec installation
make test-rockspec

# Manual verification
luarocks make --local
eval "$(luarocks path --local)"
lua -e "local sentry = require('sentry'); print('✅ Success')"
```

## Advantages

✅ **Automatic compilation** - Teal sources compiled during installation
✅ **Standard LuaRocks** - Uses official LuaRocks distribution methods
✅ **Git tag-based** - Proper versioning with git tags
✅ **Lua 5.1 compatible** - Works across all Lua versions
✅ **CI tested** - Installation process tested in CI  

## Maintenance

- Rockspec tested automatically in CI across multiple Lua versions (5.1, 5.2, 5.3, 5.4, LuaJIT)
- Separate GitHub Actions workflow tests clean system installation
- `make test-rockspec` target for local testing with existing dependencies  
- `make test-rockspec-clean` target for testing on clean systems (installs Teal automatically)
- Version bumping updates both rockspec version and git tag

### Security

- All GitHub Actions use pinned commit SHAs (not version tags) for security
- See `.claude/memories/github-actions-security.md` for SHA reference
- Actions are verified and updated following security best practices