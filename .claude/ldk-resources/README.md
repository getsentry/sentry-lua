# Lua Resources Directory

**Template files and configuration resources for Lua development tools.**

## Purpose

The `ldk-resources/` directory contains Lua-specific template files, configuration examples, and other resources that can be copied and customized for Lua development tools. These files are referenced by setup commands in the `commands/ldk/` directory.

## Available Resources

### Lua Package Build System
- **Files**: `Makefile`, `makemk.lua`, `template.rockspec`, `setup-makefile.sh`
- **Purpose**: Complete Lua package build system supporting pure Lua modules, C/C++ extensions, git submodules, and mixed projects
- **Features**: Automatic file discovery, LuaRocks integration, submodule support, environment isolation
- **Setup**: Use Claude command `/commands/ldk/setup [package] [user]` for setup
- **Documentation**: See `BUILD_SYSTEM_GUIDE.md` for detailed information

## Design Philosophy

- **Resource-Focused** - Contains only files and templates
- **Copy-and-Customize** - Templates provide starting points
- **Lua-Specific** - Optimized for Lua development workflows
- **Version-Controlled** - Templates evolve with best practices

## Usage Pattern

1. Identify needed resources from available templates
2. Follow setup commands in `commands/ldk/` directory
3. Copy template files to your project
4. Customize templates for your specific project needs
5. Maintain local customizations as needed

## Relationship to Commands

- **`commands/ldk/`** - How to use these resources (procedures)
- **`ldk-resources/`** - What to use (template files)
- **`memories/`** - Why and when to use tools (guidelines)

This separation keeps template files organized and easily accessible while maintaining clear setup procedures.