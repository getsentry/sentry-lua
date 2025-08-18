# Lua Package Build System Technical Specification

**Complete build system for Lua packages supporting pure Lua modules, C/C++ extensions, static libraries, command scripts, and mixed projects with LuaRocks integration and coverage support.**

## Quick Start

Use the Claude command for interactive setup:
```
/commands/ldk/setup [package-name]
```

This command will:
- Detect your Git repository status
- Set up the complete build system
- Generate customized configuration files
- Create necessary directory structure

## System Overview

### Core Features
- **Complete Lua Package System** - Supports pure Lua modules, C/C++ extensions, static libraries, and command scripts
- **Git Submodule Support** - Automatic initialization and building of git submodules
- **Automatic File Discovery** - Scans `lua/`, `src/`, `lib/`, and `bin/` directories automatically
- **LuaRocks Integration** - Seamless integration with LuaRocks package management
- **Mixed Language Support** - Automatic handling of C and C++ files in same project
- **Static Library Support** - Build and link static libraries from `lib/` directory
- **Source Directives** - In-file configuration for compiler and linker flags
- **Coverage Support** - Build with gcov instrumentation for C/C++ code
- **Module Grouping** - Groups related source files by prefix into single modules
- **Automatic Compiler Selection** - Uses appropriate compiler based on file type

### Build System Components

1. **Makefile** - Main build configuration (generated from template)
2. **makemk.lua** - Module discovery and build rule generation script
3. **rockspec** - LuaRocks package specification (generated from template)
4. **mk/modules.mk** - Auto-generated module definitions (created during build)

## Directory Structure

The build system expects the following project structure:

```
your-project/
├── lua/                    # Pure Lua modules
│   ├── mypackage.lua      # Main module (optional)
│   └── mypackage/         # Sub-modules (optional)
│       └── helper.lua
├── src/                    # C/C++ extensions
│   ├── core.c             # → core.so
│   ├── parser.cpp         # → parser.so  
│   └── utils/             # Nested modules
│       └── helper.c       # → utils/helper.so
├── lib/                    # Static libraries (optional)
│   ├── string.c           # → libstring.a
│   └── util/              
│       └── memory.c       # → libutil_memory.a
└── bin/                    # Command scripts (optional)
    └── mytool.lua         # → executable command
```

## Source File Directives

The build system supports in-file configuration through comment directives:

```c
// example.c
//@cflags: -Wall -Werror -O2
//@ldflags: -lm -lpthread
//@cppflags: -DENABLE_FEATURE
//@reflibs: string util/memory
```

### Available Directives
- **@cflags:** - Additional C compiler flags
- **@cxxflags:** - Additional C++ compiler flags  
- **@cppflags:** - Preprocessor flags (both C and C++)
- **@ldflags:** - Linker flags and external libraries
- **@reflibs:** - Reference internal static libraries from lib/

## Git Submodule Support

The build system provides automatic initialization and building of git submodules for projects that depend on external C/C++ libraries.

### Submodule Auto-Initialization

When using git submodules, the build system can automatically initialize them before building your project:

```bash
# The build system checks for:
# 1. Current directory is git repository root
# 2. .gitmodules file exists
# 3. Uninitialized submodules are present
# Then automatically runs: git submodule update --init --recursive
```

### Submodule Building

To build submodule dependencies, uncomment and customize the relevant lines in your Makefile:

```makefile
submodule-deps:
	# If using git submodules, uncomment the following line to auto-initialize:
	$(MAKE) submodule-init
	
	# Build submodule dependencies with isolated environment:
	env -i \
		PATH="$$PATH" \
		HOME="$$HOME" \
		SHELL="$$SHELL" \
		USER="$$USER" \
		LANG="$$LANG" \
		LC_ALL="$$LC_ALL" \
		$(MAKE) -C deps/somelib OPTION=value target.a
```

### Environment Isolation

Submodule builds use environment isolation to prevent interference from parent project variables:

- **Cleared Variables**: All environment variables are cleared with `env -i`
- **Preserved Variables**: Only essential variables are inherited:
  - `PATH` - For finding tools and compilers
  - `HOME` - For user configuration
  - `SHELL` - For proper shell execution
  - `USER` - For user identification
  - `LANG`, `LC_ALL` - For proper message localization

### Example Workflow

1. **Add Submodule**:
   ```bash
   git submodule add https://github.com/example/somelib.git deps/somelib
   ```

2. **Configure Build**: Uncomment and customize the build commands in `submodule-deps` target

3. **Build Project**: The build system will automatically:
   - Initialize submodules if needed
   - Build submodule dependencies with isolated environment
   - Build main project modules

### Error Handling

The build system provides clear error messages for common issues:

- **Not in git root**: `ERROR: Not in git repository root`
- **Missing .gitmodules**: `ERROR: No .gitmodules file found. Add submodules first with 'git submodule add'`
- **Build failures**: Submodule build errors automatically stop the main build

## Module Types and Compilation

### Pure Lua Package
Only `lua/` directory with `.lua` files - no compilation needed

### C/C++ Extension Package
Source files in `src/` directory:
- **C Files (.c)**: Compiled with `$(CC)` (typically gcc/clang)
- **C++ Files (.cpp)**: Compiled with `$(CXX)` (typically g++/clang++)
- **Output**: Shared libraries (.so files) installed to Lua C module path

### Static Libraries
Source files in `lib/` directory:
- Built as `.a` files for internal linking
- Referenced by C/C++ extensions via `@reflibs:` directive
- Support nested directory structure with prefix grouping

### Mixed Package
Combination of Lua modules, C/C++ extensions, and static libraries

### Command Scripts
Executable Lua scripts in `bin/` directory - installed to system bin path

## Module Grouping Rules

The build system automatically groups related source files:

### Prefix Grouping
Files with common prefix are grouped into single module:
```
src/
├── network.c         → All grouped into network.so
├── network_client.c  → 
└── network_server.cpp → (links with -lstdc++)
```

### Directory Modules
Files in subdirectories create namespaced modules:
```
src/
└── utils/
    ├── string.c      → utils/string.so
    └── memory.c      → utils/memory.so
```

### Static Library Grouping
Similar prefix grouping for static libraries:
```
lib/
├── string.c          → libstring.a
├── string_ops.c      → (grouped into libstring.a)
└── util/
    └── memory.c      → libutil_memory.a
```

## Build Commands

### Basic Operations
```bash
# Build and install package
luarocks make rockspecs/[package]-dev-1.rockspec

# Build with coverage instrumentation
[PACKAGE]_COVERAGE=1 luarocks make

# Clean build artifacts
make clean

# Show build configuration
make show-config

# Initialize git submodules only
make submodule-init

# Build submodule dependencies only
make submodule-deps
```

### Development Workflow
```bash
# Initial setup
/commands/ldk/setup mypackage

# Add git submodules (if needed)
git submodule add https://github.com/example/library.git deps/library

# Configure submodule builds in Makefile's submodule-deps target

# Development cycle
luarocks make          # Build and install package (includes submodules)
make clean             # Clean artifacts (optional)
```

## Coverage Analysis

Enable coverage instrumentation by setting environment variable:
```bash
MYPACKAGE_COVERAGE=1 luarocks make
```

This enables:
- gcov instrumentation for C/C++ code
- Coverage data collection during tests
- Report generation with gcov/lcov tools

## Template Variables

The build system uses these template placeholders:

| Variable | Description | Example |
|----------|-------------|---------|
| `{{PACKAGE_NAME}}` | Package name | mylib |
| `{{PACKAGE_NAME_UPPER}}` | Uppercase for env vars | MYLIB |
| `{{REPO_URL}}` | Repository source URL | https://github.com/user/repo |
| `{{HOMEPAGE_URL}}` | Project homepage | https://github.com/user/repo |
| `{{MAINTAINER}}` | Package maintainer name | John Doe |

## Requirements

### System Requirements
- LuaRocks for Lua package management
- GCC or compatible C compiler
- G++ or compatible C++ compiler (for C++ extensions)
- Standard Unix tools (make, install, find, etc.)

### Compiler Configuration
- **C Compiler**: Uses `$(CC)` from LuaRocks environment
- **C++ Compiler**: Derives from `$(CC)` (gcc→g++, clang→clang++)
- **Flags**: Inherits SDK and platform settings from LuaRocks

## Advanced Features

### Cross-Platform Support
- Automatic detection of platform-specific settings
- Proper library extensions (.so, .dll, .dylib)
- Compatible with macOS, Linux, and BSD systems

### Parallel Builds
Supports parallel compilation with `make -j` for faster builds

### Dynamic Module Discovery
The makemk.lua script automatically:
- Scans source directories for modules
- Generates build rules dynamically
- Handles complex dependency resolution

## Manual Setup Reference

If you need to set up files manually (not recommended), here's the basic process:

1. Copy template files to project root:
   - `.claude/ldk-resources/Makefile` → `Makefile`
   - `.claude/ldk-resources/makemk.lua` → `makemk.lua`
   - `.claude/ldk-resources/template.rockspec` → `rockspecs/[package]-dev-1.rockspec`

2. Replace template variables in copied files:
   - `{{PACKAGE_NAME}}` with your package name
   - `{{PACKAGE_NAME_UPPER}}` with uppercase package name
   - `{{REPO_URL}}` with repository URL
   - `{{HOMEPAGE_URL}}` with project homepage
   - `{{MAINTAINER}}` with maintainer name

3. Create directory structure as needed:
   ```bash
   mkdir -p lua src lib bin rockspecs
   ```

**Note**: Using `/commands/ldk/setup` is strongly recommended as it handles all these steps automatically and correctly.

## Related Documentation

- **Memory Files**: `.claude/memories/ldk-*.md` - Development guidelines and patterns
- **Commands**: `.claude/commands/ldk/` - Interactive setup procedures

## Troubleshooting

### Common Issues

**Module not found after installation**
- Ensure `luarocks make` completed successfully
- Check LUA_PATH and LUA_CPATH environment variables

**C extension compilation fails**
- Verify compiler is installed and accessible
- Check source file directives for syntax errors
- Review compiler output for missing dependencies

**Static library linking errors**
- Ensure referenced libraries exist in lib/ directory
- Check @reflibs: directive spelling and paths
- Verify library source files compile successfully

**Coverage build fails**
- Confirm gcov is installed
- Check that package name environment variable is uppercase
- Verify compiler supports coverage flags

**Git submodule issues**
- Ensure you're in the git repository root directory
- Verify .gitmodules file exists and is properly configured
- Check that submodules are accessible and can be cloned
- Confirm submodule build commands are properly uncommented in Makefile

**Submodule build fails**
- Check that the submodule's build system works independently
- Verify environment isolation isn't preventing required tools access
- Review submodule documentation for specific build requirements

### Getting Help

For issues or questions:
1. Check the memory files in `.claude/memories/` for patterns and guidelines
2. Review this technical specification
3. Use Claude to diagnose and fix issues with your build configuration
