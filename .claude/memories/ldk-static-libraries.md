# Static Library Build System

Comprehensive guide to building and using static libraries (.a files) in Lua C extension projects.

## Overview

The static library system allows you to build reusable C/C++ code into static libraries (.a files) that can be linked into your dynamic Lua modules. This enables code sharing, better organization, and modular development for complex projects.

## Directory Structure

```
project/
├── lib/                    # Static libraries (NEW in v0.2.0)
│   ├── string.c           # → lib/string.a
│   ├── string_helper.c    # → lib/string.a (grouped by prefix)
│   ├── util/
│   │   └── memory.c       # → lib/util/memory.a
│   └── parser/
│       ├── json.c         # → lib/parser/json.a
│       └── json_validator.cpp # → lib/parser/json.a (mixed C/C++)
├── lua/                    # Lua modules (MOVED from lib/)
│   ├── mypackage.lua      # Main module
│   └── mypackage/
│       └── helper.lua     # Sub-module
└── src/                    # Dynamic Lua modules (.so files)
    ├── core.c             # → core.so (can link to lib/*.a)
    └── network.c          # → network.so
```

## Build Process

### 1. Static Library Generation
```bash
# makemk.lua scans lib/ directory
# Groups files by prefix: string.c + string_helper.c → string module
# Generates build targets: lib/string.a, lib/util/memory.a, lib/parser/json.a

lua makemk.lua  # Creates mk/modules.mk with static library targets
```

### 2. Static Library Compilation
```bash
# C files compiled to object files
gcc -c lib/string.c -o lib/string.o
gcc -c lib/string_helper.c -o lib/string_helper.o

# C++ files compiled with appropriate compiler
g++ -c lib/parser/json_validator.cpp -o lib/parser/json_validator.o

# Object files archived into static libraries
ar rcs lib/string.a lib/string.o lib/string_helper.o
ar rcs lib/parser/json.a lib/parser/json.o lib/parser/json_validator.o
```

### 3. Dynamic Module Linking
```bash
# Dynamic modules can reference static libraries via @reflibs: directive
# Example in src/network.c:
# //@reflibs: string util/memory

# Linking resolves static library dependencies automatically
gcc -o src/network.so src/network.o lib/string.a lib/util/memory.a -bundle
```

## Prefix Grouping Rules

Static libraries follow the same prefix grouping rules as dynamic modules:

### Simple Grouping
```
lib/
├── string.c           # Base name: "string"
├── string_helper.c    # Prefix matches: "string_" → grouped with string.c
└── string_utils.c     # Prefix matches: "string_" → grouped with string.c
```
**Result**: Single `lib/string.a` containing all three object files.

### Separate Libraries
```
lib/
├── parser.c           # Base name: "parser"  
├── lexer.c            # Base name: "lexer" (no prefix match)
└── tokenizer.c        # Base name: "tokenizer" (no prefix match)
```
**Result**: Three separate libraries: `lib/parser.a`, `lib/lexer.a`, `lib/tokenizer.a`.

### Nested Directories
```
lib/
├── util/
│   ├── memory.c       # → lib/util/memory.a
│   └── memory_pool.c  # Grouped with memory.c → lib/util/memory.a
└── parser/
    ├── json.c         # → lib/parser/json.a
    └── xml.c          # → lib/parser/xml.a (separate, no prefix match)
```

## Mixed C/C++ Static Libraries

Static libraries can contain both C and C++ object files:

```
lib/parser/
├── json.c             # Compiled with gcc
└── json_validator.cpp # Compiled with g++, adds -lstdc++ to linker flags
```

**Generated makefile target**:
```makefile
lib_parser_json_LINKER = $(CXX)  # Uses C++ linker
lib_parser_json_LDFLAGS = -lstdc++  # Adds C++ standard library
```

Any dynamic module linking to this static library will automatically use the C++ linker.

## Using Static Libraries in Dynamic Modules

### 1. Reference in Source File
Use the `@reflibs:` directive to specify static library dependencies:

```c
// src/network.c
//@reflibs: string util/memory parser/json

#include "string_utils.h"
#include "util/memory.h" 
#include "parser/json.h"

// Network module implementation using static library functions
```

### 2. Automatic Linking
The build system automatically:
- Links specified static libraries: `lib/string.a lib/util/memory.a lib/parser/json.a`
- Inherits static library linker flags (e.g., `-lstdc++` for C++ libraries)
- Ensures proper dependency ordering
- Uses appropriate linker (gcc vs g++)

### 3. Generated Build Target
```makefile
src/network.so: src/network.o lib/string.a lib/util/memory.a lib/parser/json.a
	$(CXX) -o $@ $^ $(LDFLAGS) $(PLATFORM_LDFLAGS) -lstdc++
```

## Advanced Usage Patterns

### Layered Dependencies
```
lib/
├── foundation/
│   └── memory.c       # Base utilities
├── collections/
│   └── string.c       # Uses foundation (via @reflibs: foundation/memory)
└── protocols/
    └── http.c         # Uses both (via @reflibs: foundation/memory collections/string)
```

### Platform-Specific Libraries
```c
// lib/platform/posix.c
//@cppflags: -D_POSIX_C_SOURCE=200809L
//@ldflags: -lpthread

// Platform-specific implementation
```

### Third-Party Integration
```c
// lib/crypto/hash.c  
//@cppflags: -I/usr/local/include
//@ldflags: -L/usr/local/lib -lcrypto -lssl

// OpenSSL wrapper functions
```

## Build Integration

### Generated Makefile Targets
makemk.lua generates targets for each static library:

```makefile
# lib/string static library
lib_string_SRC := lib/string.c lib/string_helper.c
lib_string_OBJS := $(lib_string_SRC:.c=.o)
lib_string_LINKER = $(CC)
lib_string_LDFLAGS = 

lib/string.a: $(lib_string_OBJS)
	@mkdir -p $(@D)
	$(AR) rcs $@ $^
```

### Module Dependencies
Dynamic modules with `@reflibs:` dependencies get:

```makefile
src_network_LDFLAGS = lib/string.a lib/util/memory.a
src/network.so: src/network.o lib/string.a lib/util/memory.a
	$(CC) -o $@ $^ $(LDFLAGS) $(src_network_LDFLAGS)
```

## Best Practices

### Organization
1. **Group related functionality** - Use prefix grouping for related functions
2. **Separate concerns** - Different subdirectories for different domains
3. **Minimize dependencies** - Keep static libraries focused and minimal

### Header Files
1. **Create corresponding headers** - `lib/string.c` → `include/string.h`
2. **Use include guards** - Standard `#ifndef`/`#define`/`#endif` pattern
3. **Document interfaces** - Clear function documentation in headers

### Testing
1. **Unit test static libraries** - Test libraries independently
2. **Integration testing** - Test dynamic modules using static libraries
3. **Coverage analysis** - Use coverage flags for static library code

## Troubleshooting

### Common Issues
- **Undefined symbols**: Static library not properly linked or missing functions
- **Multiple definitions**: Same symbol defined in multiple static libraries
- **Linker errors**: Wrong linker (gcc vs g++) for mixed C/C++ libraries
- **Missing libraries**: @reflibs references non-existent static library

### Debug Commands
```bash
# List contents of static library
ar -t lib/string.a

# Show symbol table
nm lib/string.a

# Verbose build to see linking
make V=1

# Check generated makefile
cat mk/modules.mk
```

### Clean Rebuilds
```bash
# Clean all build artifacts including static libraries
make clean

# Force regeneration of mk/modules.mk
rm -f mk/modules.mk
lua makemk.lua
```

## Migration from v0.1.1

In v0.1.1, the `lib/` directory was used for Lua modules. In v0.2.0+:
- **Lua modules moved**: `lib/` → `lua/`
- **Static libraries added**: New `lib/` directory for C/C++ static libraries
- **Update require paths**: Lua code may need `require('package.module')` updates
- **Update build scripts**: Any custom scripts referencing old `lib/` directory