# Contributing to Sentry Lua SDK

Thank you for your interest in contributing to the Sentry Lua SDK! This guide will help you get started with development.

## Development Requirements

### System Dependencies

The following system dependencies are required depending on your platform:

#### Ubuntu/Debian
```bash
sudo apt-get update
sudo apt-get install -y libssl-dev
```

#### macOS
```bash
brew install openssl
```

#### Windows
SSL support is typically built-in with recent Lua installations.
MSVC build tools are automatically configured in CI for Lua compilation.

### Lua Environment

- **Lua 5.4** (required)
- **LuaRocks** (package manager)

### Development Dependencies

Install all development dependencies with:

```bash
make install
```

This will install:
- `busted` - Testing framework
- `tl` - Teal language compiler
- `lua-cjson` - JSON library
- `luasocket` - HTTP client
- `luasec` - SSL/TLS support
- `luacov` - Code coverage
- `luacov-reporter-lcov` - Coverage reporting

### Documentation Dependencies (Optional)

For building documentation:

```bash
make install-all
```

This additionally installs:
- `tealdoc` - Documentation generator (requires LuaFileSystem)

## Building the Project

### Compile Teal to Lua

```bash
make build
```

This automatically:
1. Creates all necessary build directories
2. Discovers all `.tl` files in `src/sentry/`
3. Compiles them to corresponding `.lua` files in `build/sentry/`

### Clean Build Artifacts

```bash
make clean
```

## Testing

### Run Basic Tests

```bash
make test
```

### Run Tests with Coverage

```bash
make coverage-report
```

This generates:
- `luacov.report.out` - Detailed coverage report
- `coverage.info` - LCOV format for external tools

### Test Coverage Requirements

- New features should include comprehensive tests
- Maintain or improve existing code coverage
- All tests must pass on Linux, macOS, and Windows

## Code Style and Quality

### Teal Language

This project is written in [Teal](https://github.com/teal-language/tl), a typed dialect of Lua.

- Use proper type annotations
- Follow existing code patterns
- Maintain type safety across platform modules

### Linting

```bash
make lint        # Strict linting (may fail on external modules)
make lint-soft   # Permissive linting (warnings ignored)
```

### Code Organization

```
src/sentry/
├── init.tl              # Main SDK entry point
├── version.tl           # Centralized version (auto-updated)
├── types.tl             # Type definitions
├── core/                # Core SDK functionality
├── utils/               # Utility functions
└── platforms/           # Platform-specific implementations
    ├── standard/        # Standard Lua/LuaJIT
    ├── nginx/           # OpenResty/nginx
    ├── roblox/          # Roblox game platform
    ├── love2d/          # LÖVE 2D game engine
    ├── defold/          # Defold game engine
    ├── redis/           # Redis Lua scripting
    └── test/            # Test transport
```

## Platform Support

The SDK supports multiple Lua environments:

- **Standard Lua** (5.1+) and LuaJIT
- **nginx/OpenResty** - Web server scripting
- **Roblox** - Game development platform
- **LÖVE 2D** - Game engine
- **Defold** - Game engine
- **Redis** - Lua scripting in Redis

### Adding New Platforms

1. Create `src/sentry/platforms/newplatform/`
2. Implement required transport modules
3. Add platform detection in `src/sentry/platform_loader.tl`
4. Add comprehensive tests

## Documentation

### Generate Documentation

```bash
make docs
```

Generates HTML documentation in `docs/` directory.

### Serve Documentation Locally

```bash
make serve-docs
```

Starts local server at http://localhost:8000

## Version Management

### Centralized Versioning

The project uses a centralized version system:

- **Single source**: `src/sentry/version.tl`
- **Auto-imported**: All transports reference this version
- **Auto-updated**: Bump scripts modify only this file

### Version Bumping

Version updates are handled by automated scripts:

```bash
# Bump to new version (example: 0.0.2)
pwsh scripts/bump-version.ps1 0.0.2
# or
./scripts/bump-version.sh dummy 0.0.2
```

**Do not manually update version numbers in individual files.**

## Continuous Integration

### GitHub Actions Matrix

The CI runs on:
- **Ubuntu Latest** (Linux)
- **macOS Latest**  
- **Windows Latest**

### CI Requirements

All contributions must:
1. **Build successfully** on all platforms
2. **Pass all tests** on all platforms  
3. **Maintain code coverage** (Linux/macOS only)
4. **Follow code style** guidelines

### Local CI Simulation

Test your changes across platforms by running the same commands as CI:

```bash
make install    # Install dependencies
make build      # Build project
make coverage-report  # Run tests with coverage (Linux/macOS)
# or
make test       # Run basic tests (Windows)
```

## Submitting Changes

### Pull Request Process

1. **Fork** the repository
2. **Create** a feature branch from `main`
3. **Make** your changes following this guide
4. **Test** locally on your platform
5. **Submit** a pull request

### Pull Request Requirements

- [ ] All CI checks pass (Linux, macOS, Windows)
- [ ] Tests cover new functionality
- [ ] Code follows existing patterns
- [ ] Documentation updated if needed
- [ ] Version not manually modified

### Commit Messages

Use clear, descriptive commit messages:

```
Add Redis Lua scripting transport support

- Implement RedisTransport class
- Add Redis-specific configuration
- Include comprehensive tests
- Update platform loader
```

## Getting Help

- **Issues**: Report bugs or request features via GitHub Issues
- **Discussions**: Join community discussions on GitHub
- **Documentation**: Refer to generated docs and existing code

## Development Environment Sync

> **⚠️ Important**: This CONTRIBUTING.md must stay synchronized with `.github/workflows/test.yml`. When updating build requirements or dependencies, update both files.

### Current Sync Points
- System dependencies (SSL libraries)
- Lua version requirements  
- LuaRocks dependencies
- Build and test commands
- Platform-specific considerations

Last synced: [Current date] with GitHub Actions workflow v1.0