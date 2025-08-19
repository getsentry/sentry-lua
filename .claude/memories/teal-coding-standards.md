# Teal Coding Standards

## File Type Guidelines

**Use Teal (.tl) for:**
- All code under `src/` directory
- Core SDK implementation files
- Platform-specific modules
- Utility functions and libraries

**Use Lua (.lua) for:**
- Examples under `examples/` directory
- Test files under `spec/` directory
- Build scripts and configuration files
- External integration scripts

## Migration Tasks

When .lua files exist under `src/`, they should be converted to .tl files for:
- Better type safety
- Consistent codebase standards
- Improved developer experience
- Automated type checking in CI

## Implementation

Always check `src/` directory for any .lua files that need conversion to .tl format.