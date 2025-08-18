# Lua Module Coverage Procedures

**This document describes coverage procedures for pure Lua modules using luacov.**  
For C extension module coverage procedures, see @.claude/memories/ldk-c-coverage.md

## Setup and Configuration
- Add `require('luacov')` at the top of test files
- Configure @.luacov file with module names and paths
- Set `deletestats = true` (can be changed to false to keep stats)

### Example @.luacov Configuration
Create a @.luacov file in your project root:
```lua
-- @.luacov configuration file
return {
    -- Enable statistics collection
    statsfile = "luacov.stats.out",
    
    -- Coverage report output file
    reportfile = "luacov.report.out",
    
    -- Delete previous stats before new run (recommended for clean results)
    deletestats = true,
    
    -- Modules to include in coverage (adjust paths to match your project)
    include = {
        "^lua/",           -- Include all modules in lua/ directory
        "^src/",           -- Include modules in src/ directory  
        "mymodule",        -- Include specific module
    },
    
    -- Modules to exclude from coverage
    exclude = {
        "test/",           -- Exclude testcase files
        "spec/",           -- Exclude busted spec files
        "bench/",          -- Exclude benchmark files
        "luacov$",         -- Exclude luacov itself
        "luarocks",        -- Exclude luarocks modules
    },
    
    -- Coverage target (lines must be hit to count as covered)
    -- Target: 95%+ coverage (aim for 100% when practical)
}
```

## Execution
- Run `luarocks make` to install/build project
- Execute tests: `testcase test/module_test.lua`
- Coverage report is automatically generated in `luacov.report.out`

## Verification
- Review coverage report for completeness
- Identify untested code paths  
- Add tests for uncovered areas to achieve target coverage (95%+)

### Reading Coverage Reports
The `luacov.report.out` file shows:
- **Total Coverage**: Overall percentage across all included files
- **File Coverage**: Per-file line coverage statistics
- **Line Details**: Specific lines that were/weren't executed
- **Hit Count**: Number of times each line was executed

Example report excerpt:

```
==============================================================================
mymodule.lua
==============================================================================
 1 : local function helper()
 2 :     return "test"        -- Hit 5 times
 3 : end
 4 : 
*0 : local function unused()  -- Never executed (0 hits)
*0 :     return "unused"
*0 : end
```

Lines marked with `*0` indicate uncovered code that needs testing.

## Configuration Patterns by Project Type

### Simple Module Projects
**Single module**: Include pattern `"^mymodule$"`, exclude test directories (`"test/"` and `"spec/"`)  
**Library projects**: Include `"^lua/"`, exclude test directories and external dependencies  
**Mixed C/Lua**: Include Lua paths only, exclude C extensions (use separate C coverage)  
**Framework choice**: Exclude `"test/"` for testcase or `"spec/"` for busted (or both for mixed projects)

### Advanced Configuration Options
- **`includeuntestedfiles = true`**: Shows files with zero coverage (useful for new codebases)
- **`savestepsize = 100`**: Saves stats every 100 lines (useful for long-running tests)  
- **`codefromstring = true`**: Includes coverage for dynamically loaded code

## Troubleshooting Coverage Issues

### Common Problems
**No coverage data**: Check `require('luacov')` appears before module loading  
**Missing files**: Verify include/exclude patterns match your project structure  
**Zero coverage**: Ensure test files are executing the target code paths  
**Incomplete coverage**: Review exclude patterns - may be too broad

### Performance Considerations
**Large projects**: Use specific include patterns to avoid tracking unnecessary files  
**CI environments**: Set `deletestats = true` to ensure clean runs  
**Development**: Set `deletestats = false` to accumulate coverage across test sessions

## Related Files
- @.claude/memories/ldk-c-coverage.md - Coverage procedures for C extension modules
- @.claude/memories/ldk-technology-stack.md - Installation instructions for luacov and setup
- @.claude/memories/ldk-commands.md - Commands for running tests and coverage
- @.claude/memories/ldk-task-checklist.md - Complete development workflow including coverage
- @.claude/memories/ldk-test-guidelines.md - Writing tests that generate good coverage
- @.claude/memories/ldk-project-structure.md - Directory structure for modules and tests
