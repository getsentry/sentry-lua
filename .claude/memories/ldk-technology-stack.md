# Technology Stack

**This document outlines the core technologies and tools used in Lua projects.**  
For development commands using these tools, see @.claude/memories/ldk-commands.md

## Core Language and Runtime

- **Language**: Lua (5.1.5+) with C extensions for performance-critical parts
  - **Required Version**: Lua 5.1.5 (mandatory for LuaJIT compatibility)
  - **Recommended**: Lua 5.3 or 5.4 for improved performance when LuaJIT not required
  - **Platform Support**: Cross-platform (Linux, macOS, Windows)
  - **LuaJIT Support**: All code must be compatible with LuaJIT's Lua 5.1.5 implementation

## Build System and Package Management

- **Package Manager**: luarocks
  - **Prerequisite**: luarocks must be installed and functional
  - **Version**: 3.0+ recommended for better dependency resolution
  - **Usage**: Manages Lua packages and dependencies

- **Build System**: @Makefile with luarocks integration
  - **Purpose**: Compiles C extensions and manages build artifacts
  - **Requirements**: GCC or compatible C compiler for C extensions
  - **Integration**: `luarocks make` automatically invokes @Makefile for C components

## Testing Framework

Choose one testing framework for your project:

### Option 1: lua-testcase
- **Installation**: `luarocks install testcase`
- **Directory**: `test/` with `*_test.lua` files
- **Usage**: `testcase test/` runs all tests recursively
- **Assertions**: Uses lua-assert for expressive test assertions
- **Reference**: For detailed usage, refer to https://github.com/mah0x211/lua-testcase

### Option 2: busted  
- **Installation**: `luarocks install busted`
- **Directory**: `spec/` with `*_spec.lua` files
- **Usage**: `busted` runs all specs in spec/ directory
- **Features**: BDD-style testing with describe/it syntax
- **Reference**: For detailed usage, refer to https://github.com/lunarmodules/busted

## Code Quality Tools

- **Linting**: luacheck
  - **Installation**: `luarocks install luacheck`
  - **Purpose**: Static analysis and style checking for Lua code
  - **Configuration**: @.luacheckrc file in project root
  - **Usage**: `luacheck .` for project-wide linting

- **Formatting**: lua-format
  - **Installation**: `luarocks install lua-format` or platform-specific package managers
  - **Purpose**: Automatic code formatting for consistency
  - **Standards**: 4 spaces indentation, single quotes preferred
  - **Usage**: `lua-format -i <file.lua>` for in-place formatting

## Coverage Tools

- **Lua Module Coverage**: luacov
  - **Installation**: `luarocks install luacov`
  - **Purpose**: Line coverage analysis for pure Lua code
  - **Configuration**: @.luacov file for coverage settings
  - **Output**: `luacov.report.out` with detailed coverage report

- **C Extension Coverage**: lcov/gcov
  - **Installation**: 
    - **Ubuntu/Debian**: `apt-get install lcov`
    - **CentOS/RHEL**: `yum install lcov` or `dnf install lcov`
    - **macOS**: `brew install lcov`
  - **Purpose**: Line coverage analysis for C extension code
  - **Requirements**: GCC with `--coverage` flag support
  - **Output**: HTML coverage reports via `genhtml`

## Development Dependencies

- **C Compiler**: GCC 4.8+ or Clang 3.5+
  - **Purpose**: Required for building C extensions
  - **Features**: Must support `--coverage` flag for coverage analysis
  
- **Make**: GNU Make 3.8+
  - **Purpose**: Build automation for C extensions
  - **Platform**: Available on most Unix-like systems

## Development Tools Installation

**Prerequisites**: Lua 5.1.5+ and luarocks must be installed via your preferred method (version managers, package managers, or source compilation).

### Tool Installation via luarocks
```bash
# Choose one testing framework
luarocks install testcase  # OR luarocks install busted

# Essential development tools
luarocks install luacheck
luarocks install luacov  
luarocks install lua-format

# Platform-specific coverage tools
# Ubuntu/Debian: apt-get install lcov
# macOS: brew install lcov  
# CentOS/RHEL: yum install lcov
```

## Version Compatibility

- **Lua 5.1.5**: Required minimum - ensures LuaJIT compatibility
- **Lua 5.2**: Compatible but avoid 5.2-specific features for LuaJIT support
- **Lua 5.3**: Recommended for pure Lua projects - integer support, better performance  
- **Lua 5.4**: Latest features but may not be LuaJIT compatible
- **LuaJIT**: Primary target runtime - significant performance benefits, industry standard

## Integration Notes

- All tools integrate through luarocks package manager
- C extensions require proper compiler toolchain setup
- Coverage tools require specific build flags for accurate reporting
- Testing framework expects specific file naming conventions (`*_test.lua` for testcase, `*_spec.lua` for busted)
- **LuaJIT Compatibility**: All code must run on both standard Lua 5.1.5 and LuaJIT without modification

## Quick Reference
```bash
# Prerequisites: Lua 5.1.5+ and luarocks must be installed

# Choose testing framework and install tools
luarocks install testcase  # OR luarocks install busted
luarocks install luacheck
luarocks install luacov
luarocks install lua-format

# Coverage tools (platform-specific)
# macOS: brew install lcov
# Ubuntu/Debian: apt-get install lcov  
# CentOS/RHEL: yum install lcov
```

## Related Files
- @.claude/memories/ldk-commands.md - How to use these tools in daily development
- @.claude/memories/ldk-coverage.md - Using luacov for Lua module coverage
- @.claude/memories/ldk-c-coverage.md - Using lcov/gcov for C extension coverage
- @.claude/memories/ldk-task-checklist.md - Tool usage as part of development workflow
- @.claude/memories/ldk-code-style.md - Standards enforced by luacheck and lua-format
- @.claude/memories/ldk-test-guidelines.md - Using testcase framework effectively
