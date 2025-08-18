# C Module Coverage Procedures

**This document describes coverage procedures specifically for C extension modules using lcov/gcov tools.**  
For pure Lua module coverage procedures, see @.claude/memories/ldk-coverage.md

## Build with Coverage Support
- Use project-specific environment variable to enable --coverage flag during build
- Example: `EXAMPLE_COVERAGE=1 luarocks make`
- This enables compiler coverage instrumentation for C extensions

## Test Execution
- Run tests normally after coverage-enabled build: `testcase test/module_test.lua`
- DO NOT add `require('luacov')` to test files for C modules

## Coverage Report Generation
Create a coverage generation script (e.g., `covgen.sh`) with content similar to:

```bash
#!/bin/bash
# Generate coverage report for C modules

set -e

# Check if src directory exists
if [ ! -d "./src" ]; then
    echo "Warning: src directory not found. Skipping coverage generation."
    exit 0
fi

# Check if .gcno files exist in src directory
if ! find ./src -name "*.gcno" | grep -q .; then
    echo "Warning: No .gcno files found in src directory. Skipping coverage generation."
    echo "Note: To generate coverage data, compile and link with --coverage flag"
    echo "      Compile: gcc -c --coverage module.c"
    echo "      Link:    gcc --coverage -o module.so module.o -shared"
    exit 0
fi

echo "Generating coverage report..."

# Clean previous coverage data
if [ -d "coverage" ]; then
    echo "Removing previous coverage report..."
    rm -rf coverage
fi

# Get absolute path of src directory (resolves symlinks)
SRC_ABS_PATH=$(cd ./src && pwd)

# Generate coverage data
lcov --capture --directory ./src --output-file coverage.info --ignore-errors gcov,source

# Check if coverage data was generated successfully
if [ ! -f "coverage.info" ]; then
    echo "Error: Failed to generate coverage.info"
    exit 1
fi

# Extract only files from project's src directory
lcov --extract coverage.info "${SRC_ABS_PATH}/*" --output-file coverage.info --ignore-errors source

# Generate HTML report
genhtml coverage.info --output-directory coverage --title "Project Coverage Report"

# Check if HTML report was generated successfully
if [ ! -d "coverage" ] || [ ! -f "coverage/index.html" ]; then
    echo "Error: Failed to generate HTML coverage report"
    exit 1
fi

echo "Coverage report generated successfully!"
echo "HTML report: $(pwd)/coverage/index.html"
echo ""
echo "Coverage summary:"
lcov --summary coverage.info
```

## Usage
- Make script executable: `chmod +x covgen.sh`
- Generate report: `./covgen.sh`
- View HTML report in `coverage/index.html`

## Platform-Specific Troubleshooting

### macOS Issues
**Command not found**: Use `brew install lcov` if Homebrew installation failed  
**Permission denied**: Check Xcode Command Line Tools installation with `xcode-select --install`  
**Coverage data missing**: Verify GCC usage instead of Clang by setting `CC=gcc` in environment

### Linux Issues  
**Ubuntu/Debian**: Install `build-essential` package if GCC missing  
**CentOS/RHEL**: Use `yum groupinstall "Development Tools"` for complete toolchain  
**Generic Linux**: Ensure `--coverage` flag support with `gcc --help | grep coverage`

### Build Integration Problems
**No .gcno files**: Verify @Makefile uses `--coverage` flag in both CFLAGS and LDFLAGS  
**Partial coverage**: Check all C source files compile with coverage enabled  
**Clean builds**: Remove `.gcda` files between runs to avoid stale data

## Notes
- Requires lcov/gcov tools to be installed
- Coverage data is collected during test execution
- Clean build artifacts between coverage runs if needed
- **Coverage Target**: 95%+ (aim for 100% when practical)

## Related Files
- @.claude/memories/ldk-coverage.md - Coverage procedures for pure Lua modules
- @.claude/memories/ldk-technology-stack.md - Installation instructions for lcov/gcov tools
- @.claude/memories/ldk-commands.md - Common development commands including build
- @.claude/memories/ldk-task-checklist.md - Complete development workflow including coverage
- @.claude/memories/ldk-test-guidelines.md - Guidelines for writing testable C extension code
- @.claude/memories/ldk-project-structure.md - Directory structure for C extensions and tests