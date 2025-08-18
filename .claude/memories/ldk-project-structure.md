# Lua Project Structure Guidelines

**This document defines the standard directory structure and file organization for Lua projects.**  
For test code guidelines, see @.claude/memories/ldk-test-guidelines.md

## Directory Organization

**Path Structure Principle**: All directories mirror the `require()` module path structure. For `require('foo.bar.baz')`, files are organized as `<directory>/foo/bar/baz.<extension>`.

- **Lua modules**: `lua/**/*.lua`
- **C extensions**: `src/**/*.c`
- **Tests**: `test/**/*_test.lua` (testcase) OR `spec/**/*_spec.lua` (busted) (one-to-one correspondence with modules)
- **Benchmarks**: `bench/**/*_bench.lua` or `test/bench/**/*_bench.lua` (one-to-one correspondence)
- **Documentation**: `doc/` or `docs/`
- **Configuration**: Root level (@.luacheckrc, @.luacov, etc.)

## Module to Test Mapping
- **One-to-one correspondence**: Each module has exactly one test file
- **Path mirroring**: Test file paths mirror the module require path

### testcase framework
- `require('foo.bar.baz')` → `test/foo/bar/baz_test.lua`
- `require('utils.string')` → `test/utils/string_test.lua`  
- `require('parser')` → `test/parser_test.lua`

### busted framework  
- `require('foo.bar.baz')` → `spec/foo/bar/baz_spec.lua`
- `require('utils.string')` → `spec/utils/string_spec.lua`
- `require('parser')` → `spec/parser_spec.lua`

## File Naming Conventions
- **Test files**: `<module_name>_test.lua` (testcase) OR `<module_name>_spec.lua` (busted)
- **Benchmark files**: `<module_name>_bench.lua`
- **Module files**: Use clear, descriptive names matching functionality

## Project Root Files
- @rockspec - LuaRocks specification file
- @Makefile - Build configuration (for C extensions)
- @.luacheckrc - Linting configuration
- @.luacov - Coverage configuration
- @README.md - Project documentation

## Related Files
- @.claude/memories/ldk-test-guidelines.md - Detailed guidelines for test organization and structure
- @.claude/memories/ldk-commands.md - Commands that work with this directory structure
- @.claude/memories/ldk-code-style.md - File naming and organization conventions
- @.claude/memories/ldk-coverage.md - Coverage procedures that follow this structure
- @.claude/memories/ldk-c-coverage.md - C extension structure and coverage
- @.claude/memories/ldk-memory-conventions.md - General file organization principles
