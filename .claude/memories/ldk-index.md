# Lua Development Kit Memory Index

Central reference point for all LDK memory files.

## Core Development Memories

@.claude/memories/lua-c-api.md - Lua C API development: luaopen_* functions, stack operations, userdata creation, and proper error handling with lua_error()
@.claude/memories/lua-module-patterns.md - Lua module development patterns: return table exports, require() usage, local vs global scope, and module initialization
@.claude/memories/luarocks-integration.md - LuaRocks build system: rockspec file structure, build dependencies, installation paths, and version management
@.claude/memories/makefile-patterns.md - Makefile development for Lua C extensions: compiler flags, library linking, installation rules, and cross-platform compatibility

## Build System Memories

@.claude/memories/build-system-design.md - Advanced build system architecture: mixed Lua/C/C++ projects, module grouping, and dynamic target generation
@.claude/memories/cross-platform-building.md - Cross-platform build considerations: compiler detection, platform-specific flags, library extensions (.so/.dll), and installation paths
@.claude/memories/ldk-source-directives.md - Source file directive system: @cflags:, @ldflags:, @reflibs:, @cppflags:, @cxxflags: for automatic build configuration in C/C++ source files
@.claude/memories/ldk-static-libraries.md - Static library build system: lib/ directory structure, .a file generation, prefix grouping, mixed C/C++ libraries, and @reflibs: linking

## Project Structure Memories

@.claude/memories/project-layout.md - Standard Lua project structure: src/ for C code, lua/ for Lua modules, spec/ for tests, and proper file organization
@.claude/memories/file-organization.md - File organization best practices: module naming conventions, directory hierarchies, and separation of concerns

## Testing and Quality

@.claude/memories/testing-strategies.md - Testing strategies for Lua projects: busted framework, spec files, C extension testing, and continuous integration setup

## Documentation and Contribution

@.claude/memories/contributing-sync.md - CONTRIBUTING.md and CI workflow synchronization: system dependencies, build requirements, platform matrix, and sync verification checklist
@.claude/memories/github-actions-security.md - GitHub Actions security: always use commit SHAs instead of version tags, with proper version comments for maintenance

## Usage

This index provides targeted access to LDK memory files based on development context.
Reference in CLAUDE.md with: `@.claude/memories/ldk-index.md`
