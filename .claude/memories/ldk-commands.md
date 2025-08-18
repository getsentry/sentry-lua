# Lua Development Commands

**This document lists common commands used during Lua project development, including build, test, and code quality tools.**  
For detailed testing guidelines, see @.claude/memories/ldk-test-guidelines.md  
For coverage procedures, see @.claude/memories/ldk-coverage.md (Lua) or @.claude/memories/ldk-c-coverage.md (C extensions).

## Installation and Build
- `luarocks make` - Install the project (run this before testing)
- `make` - Build C extensions
- `make clean` - Clean build artifacts

## Testing

### testcase framework
- `testcase test/` - Run all tests (executes all `**/*_test.lua` files in directory)
- `testcase test/<module_name>_test.lua` - Run specific test file
- `testcase test/<directory>/` - Run tests in specific subdirectory

### busted framework
- `busted` - Run all specs in spec/ directory
- `busted spec/<module_name>_spec.lua` - Run specific spec file
- `busted spec/<directory>/` - Run specs in specific subdirectory

## Code Quality
- `luacheck .` - Run linting on Lua files
- `lua-format -i <file.lua>` - Format a Lua file

## Development Best Practices
- Always run `luarocks make` before testing
- Choose either `testcase` (test/) or `busted` (spec/) framework for consistency
- Coverage target: 95%+ (aim for 100% when practical)
- Code comments should be in English
- Follow project's formatting rules (4 spaces, single quotes)

## Quick Reference
```bash
# Complete development cycle
luarocks make                    # Install/build project
testcase test/ # OR busted       # Run all tests
luacheck .                       # Check code style
lua-format -i src/myfile.lua     # Format specific file

# Coverage workflows
require('luacov')                # Add to Lua test files
EXAMPLE_COVERAGE=1 luarocks make  # C extension coverage build
```

## Related Files
- @.claude/memories/ldk-technology-stack.md - Installation instructions for all development tools
- @.claude/memories/ldk-code-style.md - Detailed coding standards and style rules
- @.claude/memories/ldk-test-guidelines.md - Guidelines for writing and organizing tests
- @.claude/memories/ldk-task-checklist.md - Complete development workflow checklist
- @.claude/memories/ldk-coverage.md - Lua module coverage procedures
- @.claude/memories/ldk-c-coverage.md - C extension coverage procedures
- @.claude/memories/ldk-project-structure.md - Project organization and file structure