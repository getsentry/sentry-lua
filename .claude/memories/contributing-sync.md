# CONTRIBUTING.md and CI Workflow Synchronization

Critical memory: CONTRIBUTING.md and GitHub Actions workflows must remain synchronized.

## Sync Requirements

### Files to Keep in Sync
- `/CONTRIBUTING.md` - Developer documentation
- `/.github/workflows/test.yml` - CI pipeline
- `/Makefile` - Build system (install target)
- `/sentry-lua-*.rockspec` - LuaRocks dependencies

### Critical Sync Points

#### System Dependencies
**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install -y libssl-dev
```

**macOS:**
```bash
brew install openssl
export OPENSSL_DIR=$(brew --prefix openssl)
```

**Windows:**
- SSL support built-in
- MSVC build tools (ilammy/msvc-dev-cmd@v1) - setup before Lua installation

#### Lua Environment
- **Version**: Lua 5.4 (required)
- **Package Manager**: LuaRocks

#### LuaRocks Dependencies (must match Makefile install target)
1. `busted` - Testing framework
2. `tl` - Teal compiler  
3. `lua-cjson` - JSON library
4. `luasocket` - HTTP client
5. `luasec` - SSL/TLS support
6. `luacov` - Code coverage
7. `luacov-reporter-lcov` - Coverage reporting
8. `tealdoc` - Documentation (install-all only)

#### Build Commands
- `make install` - Install dependencies
- `make build` - Build project
- `make test` - Run tests
- `make coverage-report` - Tests with coverage (Linux/macOS)
- `make clean` - Clean build artifacts

#### Platform Matrix
- **Ubuntu Latest** - Full testing + coverage + Codecov
- **macOS Latest** - Full testing + coverage
- **Windows Latest** - Basic testing only (no coverage)

## Update Process

When changing build requirements:

1. **Update GitHub Actions workflow** (`.github/workflows/test.yml`)
2. **Update CONTRIBUTING.md** to match
3. **Update Makefile** if dependencies change
4. **Update rockspec** if runtime dependencies change
5. **Test locally** on your platform
6. **Verify CI passes** on all platforms

## Last Sync Verification

Always verify these elements match across files:
- [ ] System dependency installation commands
- [ ] Lua version requirement
- [ ] LuaRocks package list and versions
- [ ] Make targets used in CI
- [ ] Platform-specific considerations
- [ ] Build and test command sequences

## Usage in Development

When updating project requirements:
1. Check this memory file first
2. Update all sync points simultaneously  
3. Test the full workflow locally
4. Verify CI pipeline succeeds

This prevents contributor confusion and CI failures from documentation drift.