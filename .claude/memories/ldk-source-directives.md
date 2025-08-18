# Source File Directives for Lua C Extensions

Comprehensive guide to using comment directives in C/C++ source files for automatic build configuration.

## Overview

Source file directives allow you to specify compiler and linker flags directly in your C/C++ source files using specially formatted comments. The makemk.lua script automatically parses these directives and applies them during compilation and linking.

## Directive Syntax

All directives use the format: `//@directive: value`

- Must be in comment blocks (single-line `//` or multi-line `/* */`)
- Case-insensitive directive names
- Must appear before any actual code (before first non-comment, non-preprocessor line)
- Each directive can only appear once per file

## Available Directives

### @cppflags: - Preprocessor Flags
Used for C/C++ preprocessor directives, include paths, and macro definitions.

```c
//@cppflags: -DDEBUG -DVERSION=1.0 -Iinclude -I/usr/local/include

#include <stdio.h>
// rest of code...
```

**Common usage:**
- `-DMACRO_NAME` - Define preprocessor macros
- `-DMACRO=value` - Define macros with values
- `-Ipath` - Add include directories
- `-I/absolute/path` - Absolute include paths

### @cflags: - C Compiler Flags
Specific flags for C compilation (*.c files).

```c
//@cflags: -Wall -Werror -std=c11 -pedantic

#include <stdio.h>
int main() { return 0; }
```

**Common usage:**
- `-Wall` - Enable all warnings
- `-Werror` - Treat warnings as errors
- `-std=c11` - Set C standard version
- `-pedantic` - Strict standard compliance
- `-O2`, `-O3` - Optimization levels

### @cxxflags: - C++ Compiler Flags
Specific flags for C++ compilation (*.cpp files).

```cpp
//@cxxflags: -std=c++17 -Wall -Wextra

#include <iostream>
int main() { return 0; }
```

**Common usage:**
- `-std=c++11/14/17/20` - C++ standard version
- `-Wall -Wextra` - Extended warnings
- `-fno-exceptions` - Disable exceptions
- `-fno-rtti` - Disable RTTI

### @ldflags: - Linker Flags
Flags passed to the linker for library linking and linker options.

```c
//@ldflags: -lm -lpthread -L/usr/local/lib -lcurl

#include <math.h>
#include <pthread.h>
// code using math and pthread functions...
```

**Common usage:**
- `-lname` - Link against library (e.g., `-lm` for math library)
- `-Lpath` - Add library search path
- `-Wl,option` - Pass options directly to linker
- `-framework name` - Link macOS frameworks

### @reflibs: - Static Library References
References to static libraries built in the lib/ directory.

```c
//@reflibs: string util/memory

#include "string_utils.h"
#include "util/memory.h"
// code that uses functions from lib/string.a and lib/util/memory.a
```

**Usage:**
- Space-separated list of library names
- `string` → links against `lib/string.a`
- `util/memory` → links against `lib/util/memory.a`
- Automatically handles dependency ordering

## Multi-Line Comments

Directives work in both single-line and multi-line comments:

```c
/*
 * @cppflags: -DDEBUG -Iinclude
 * @cflags: -Wall -Werror
 * @ldflags: -lm -lpthread
 * @reflibs: string util/memory
 */

#include <stdio.h>
// rest of code...
```

## Complex Example

Real-world example combining multiple directives:

```c
/*
 * Network module with PostgreSQL and cURL dependencies
 * @cppflags: -DUSE_POSTGRESQL -DUSE_CURL -DUSE_ZLIB
 * @cflags: -Wall -Werror -std=c11
 * @ldflags: -lpq -lcurl -lz
 * @reflibs: string util/memory
 */

#include <stdio.h>
#include <libpq-fe.h>
#include <curl/curl.h>
#include "string_utils.h"
#include "util/memory.h"

// Network module implementation...
```

This generates a module that:
- Defines macros for PostgreSQL, cURL, and zlib support
- Uses strict C11 compilation
- Links against PostgreSQL, cURL, and zlib system libraries
- Links against project's string and util/memory static libraries

## Error Handling

### Duplicate Directive Error
```c
//@cflags: -Wall
//@cflags: -Werror  // ERROR: Duplicate directive
```

### Invalid Placement
```c
#include <stdio.h>  // Code started
//@cflags: -Wall     // ERROR: Too late, must come before code
```

## Integration with Build System

1. **makemk.lua** scans all .c/.cpp files in src/ directory
2. Parses directives from file headers
3. Groups files by prefix into modules
4. Generates appropriate build targets with merged flags
5. **Makefile** executes the generated build rules

## Best Practices

1. **Place directives at file top** - Before any includes or code
2. **Use consistent formatting** - One directive per line for readability
3. **Document complex flags** - Add comments explaining unusual flags
4. **Group related directives** - Keep related flags together
5. **Test incrementally** - Add one directive at a time when debugging

## Troubleshooting

### Common Issues
- **Directive not found**: Check spelling and placement before code
- **Compilation errors**: Verify flag syntax and library availability
- **Linking failures**: Ensure referenced libraries exist and are in library paths
- **@reflibs not working**: Verify static library exists in lib/ directory

### Debug Output
Run `lua makemk.lua` directly to see directive parsing output and any errors.