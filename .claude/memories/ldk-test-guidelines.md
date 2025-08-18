# Test Code Guidelines

**This document provides comprehensive guidelines for writing and organizing test code in Lua projects.**  
For project structure details, see @.claude/memories/ldk-project-structure.md  
For coverage procedures, see @.claude/memories/ldk-coverage.md (Lua) or @.claude/memories/ldk-c-coverage.md (C extensions).

## General Principles
- Write clean, maintainable test code that is easy to understand and modify
- Each test function should focus on a single aspect of functionality
- Use descriptive function names that clearly indicate what is being tested
- Keep tests concise while maintaining thorough coverage
- Follow the AAA pattern: Arrange, Act, Assert

## Helper Functions and Shared Utilities
- Create reusable helper functions for common test setup patterns
- Place shared helpers in `test/helpers/` directory for cross-test reuse
- Use parameter-driven helpers instead of repetitive manual code
- Name helper functions clearly to indicate their purpose
- Example: `create_samples(name, times)` instead of `create_mock_samples_with_time_data()`
- Export helpers as modules: `return { create_samples = create_samples, generate_times = generate_times }`

## Test Organization and Structure
- **One test file per module**: Each module should have exactly one corresponding test file
- **Mirror module structure**: Test file paths should mirror the module require path
  - Module: `require('foo.bar.baz')` → Test: `test/foo/bar/baz_test.lua`
  - Module: `require('utils.string')` → Test: `test/utils/string_test.lua`
  - Module: `require('utils')` → Test: `test/utils_test.lua`
- Use consistent directory structure that matches the source code organization
- Use descriptive test file names with `_test.lua` suffix
- Organize test functions logically within files (basic cases first, edge cases last)
- Create subdirectories as needed to match the module hierarchy

## Data Generation and Test Data
- Use helper functions for generating test data consistently
- Parameterize data generation to avoid hardcoded loops
- Example: `generate_times(base_ms, count, variance)` for time arrays
- Keep data generation functions simple and focused
- Use factories for complex object creation
- Prefer deterministic test data over random data when possible

## Test Categories and Coverage
- **Unit Tests**: Test individual functions/modules in isolation
- **Integration Tests**: Test interaction between components
- **Edge Case Tests**: Test boundary conditions and error scenarios
- **Performance Tests**: Verify performance characteristics when needed
- Aim for high code coverage but focus on meaningful test scenarios
- Test both positive and negative cases (success and failure paths)

## Test Independence and Isolation
- Each test should be independent and not rely on other tests
- Use setup/teardown functions when needed for test isolation
- Avoid shared mutable state between tests
- Mock external dependencies to ensure test reliability
- Use fresh data/objects for each test to prevent interference

## Assertion Best Practices
- Use specific assertions that clearly indicate what is being tested
- Provide meaningful error messages in assertions
- Test one concept per assertion when possible
- Group related assertions logically
- Use custom assertion helpers for complex validations

## Error Testing and Exception Handling
- Test both success and failure cases appropriately
- Use pcall for testing expected errors with clear assertions
- Example: `assert(not ok, 'Should error with single sample')`
- Verify error messages contain expected information
- Test error conditions thoroughly, not just happy paths

## Test Naming Conventions
- **Test Files**: Follow the pattern `<module_path>_test.lua` where module_path mirrors the require path
  - `require('foo.bar.baz')` → `test/foo/bar/baz_test.lua`
  - Always use `_test.lua` suffix for test files
- **Test Functions**: Use descriptive names that explain the scenario
  - Format: `testcase.what_is_being_tested_and_expected_outcome()`
  - Examples: `basic_two_samples()`, `single_sample_error()`, `zero_mean_edge_case()`
- Group related tests with consistent naming patterns
- Avoid generic names like `test1()` or `basic_test()`
- Test function names should be self-documenting

## Code Quality and Maintainability
- Keep tests DRY (Don't Repeat Yourself) through good helper functions
- Make tests resilient to minor implementation changes
- Use table-driven tests for multiple similar scenarios where appropriate
- Regularly review and refactor test code for clarity and efficiency
- Write self-documenting code that reduces need for comments

## Performance Considerations
- Minimize redundant operations in test setup
- Use appropriate sample sizes for test reliability vs speed
- Reuse test data where possible without compromising test isolation
- Consider test execution time in CI/CD pipelines
- Use test doubles (mocks/stubs) to improve test speed

## Lua-Specific Guidelines
- Follow project's Lua formatting rules (4 spaces, single quotes)
- Use ipairs/pairs appropriately for table iteration
- Leverage Lua's table features for clean test data structures
- Use local variables appropriately to avoid global pollution
- Handle Lua-specific error patterns with pcall/xpcall

## Test Documentation
- Write clear comments for complex test scenarios
- Document test intentions when behavior is not obvious
- Include references to requirements or specifications being tested
- Explain the reasoning behind specific test data choices
- Document known limitations or assumptions in tests

## Continuous Improvement
- Monitor test execution metrics (speed, flakiness)
- Regular test code reviews focusing on clarity and coverage
- Remove or update obsolete tests when requirements change
- Refactor tests when they become difficult to maintain
- Share testing patterns and practices across the team

## Quick Reference

### Test File Structure

#### testcase framework
```lua
-- test/module_name_test.lua
-- require('luacov') -- for coverage

local testcase = require('testcase')
local module = require('module_name')

function testcase.basic_functionality()
    -- Basic positive test case
end
```

#### busted framework  
```lua
-- spec/module_name_spec.lua
require('luacov')  -- for coverage

local module = require('module_name')

describe('module_name', function()
    it('should handle basic functionality', function()
        -- Basic positive test case
    end)
end)
```

### Test Organization Patterns

**Module testing**: One test file per module, mirroring require path structure  
**Integration testing**: Separate `integration/` subdirectory for multi-module tests  
**Performance testing**: Use `bench/` subdirectory with `_bench.lua` suffix  
**Error testing**: Group error conditions at end of test file for clarity  
**Framework choice**: Use either `test/` (testcase) or `spec/` (busted) consistently across project

### Effective Test Structure Principles

**Setup hierarchy**: Global setup → per-test setup → test execution → cleanup  
**Data generation**: Create reusable factories for complex test objects  
**Assertion strategy**: One primary assertion per test function, supporting assertions for context  
**Test naming**: Descriptive names indicating input conditions and expected outcomes

### Coverage Target
- **Target**: 95%+ (aim for 100% when practical)
- Focus on meaningful test scenarios over just line coverage

### Framework Documentation References
- **testcase**: Refer to https://github.com/mah0x211/lua-testcase for advanced testing patterns
- **busted**: Refer to https://github.com/lunarmodules/busted for BDD-style testing and mocking features

## Related Files
- @.claude/memories/ldk-commands.md - Commands for running tests (`testcase test/`)
- @.claude/memories/ldk-project-structure.md - Test file organization and naming conventions
- @.claude/memories/ldk-coverage.md - Coverage analysis for Lua test files
- @.claude/memories/ldk-c-coverage.md - Coverage for C extension testing
- @.claude/memories/ldk-task-checklist.md - Testing as part of development workflow
- @.claude/memories/ldk-code-style.md - Code style rules that apply to test files
- @.claude/memories/ldk-technology-stack.md - testcase framework installation and setup