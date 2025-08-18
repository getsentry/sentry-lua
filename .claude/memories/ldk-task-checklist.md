# Development Task Checklist

**This document provides a comprehensive checklist for development tasks, ensuring quality and consistency across the project.**  
For specific commands, see @.claude/memories/ldk-commands.md  
For code style details, see @.claude/memories/ldk-code-style.md

When completing a coding task, always:

## 1. Before Starting
- Run build/installation commands to ensure environment is set up
- Read relevant documentation in project documentation directory
- Check existing code patterns in similar files

## 2. During Development
- Follow project's code style conventions (indentation, naming)
- Write clear comments for complex logic
- Use established design patterns for new components
- Implement proper error handling patterns

## 3. After Implementation
- Run linting tools to check for code quality issues
- Format code according to project standards
- Write comprehensive tests with appropriate coverage
- Run test suite to ensure all tests pass
- Achieve coverage target: 95%+ (aim for 100% when practical)

## 4. Final Checks
- If native code was modified, ensure proper resource management
- Update relevant documentation if API changed
- Run coverage reports if project uses them
- Ensure no debug prints or temporary code remains
- Verify no restricted commands are used (if applicable)

## Quality Standards
- Always verify tests pass before considering task complete
- Follow existing patterns and conventions in the codebase
- Maintain consistency with project architecture and design

## Quick Reference Checklist
- [ ] `luarocks make` (setup environment)  
- [ ] Read docs and check existing patterns
- [ ] Follow code style conventions
- [ ] Write comprehensive tests
- [ ] `testcase test/` OR `busted` (run tests)
- [ ] `luacheck .` (check code quality)
- [ ] Achieve 95%+ coverage target
- [ ] Update docs if API changed
- [ ] Clean up debug code

## Related Files
- @.claude/memories/ldk-commands.md - Specific commands for each checklist step
- @.claude/memories/ldk-code-style.md - Style rules and formatting standards
- @.claude/memories/ldk-test-guidelines.md - Guidelines for comprehensive test writing
- @.claude/memories/ldk-coverage.md - Lua coverage procedures for checklist step
- @.claude/memories/ldk-c-coverage.md - C extension coverage procedures
- @.claude/memories/ldk-technology-stack.md - Tool setup and installation requirements
- @.claude/memories/ldk-project-structure.md - Project organization and file conventions