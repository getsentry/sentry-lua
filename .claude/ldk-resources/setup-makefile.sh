#!/bin/bash
# Lua C/C++ Extension Build System Setup Script
# Generates customized Makefile, makemk.lua, and rockspec

set -e

# Check arguments
if [ $# -ne 2 ]; then
    echo "Usage: $0 <package-name> <github-username>"
    echo "Example: $0 mylib johndoe"
    exit 1
fi

PACKAGE_NAME="$1"
GITHUB_USER="$2"

# Check for help flag
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    echo "Usage: $0 <package-name> <github-username>"
    echo "Example: $0 mylib johndoe"
    echo
    echo "Generates customized Lua C/C++ build system files:"
    echo "  - Makefile with coverage support"
    echo "  - makemk.lua module discovery script"
    echo "  - <package>-dev-1.rockspec for LuaRocks"
    exit 0
fi

# Validate inputs
if [ -z "$PACKAGE_NAME" ]; then
    echo "Error: Package name cannot be empty"
    exit 1
fi

if [ -z "$GITHUB_USER" ]; then
    echo "Error: GitHub username cannot be empty"
    exit 1
fi

# Convert package name to uppercase for coverage flags
PACKAGE_NAME_UPPER=$(echo "$PACKAGE_NAME" | tr '[:lower:]' '[:upper:]')

echo "=== Lua Makefile Setup ==="
echo "Package name: $PACKAGE_NAME"
echo "GitHub user:  $GITHUB_USER"
echo "Coverage flag: ${PACKAGE_NAME_UPPER}_COVERAGE"
echo

# Check if we're in the template directory
if [ ! -f ".claude/ldk-resources/Makefile" ]; then
    echo "Error: .claude/ldk-resources/Makefile not found. Make sure you're in the correct directory."
    exit 1
fi

# Check for existing build files
EXISTING_FILES=""
[ -f "Makefile" ] && EXISTING_FILES="$EXISTING_FILES Makefile"
[ -f "makemk.lua" ] && EXISTING_FILES="$EXISTING_FILES makemk.lua"
[ -f "rockspecs/$PACKAGE_NAME-dev-1.rockspec" ] && EXISTING_FILES="$EXISTING_FILES rockspecs/$PACKAGE_NAME-dev-1.rockspec"
[ -f "$PACKAGE_NAME-dev-1.rockspec" ] && EXISTING_FILES="$EXISTING_FILES $PACKAGE_NAME-dev-1.rockspec"

if [ -n "$EXISTING_FILES" ]; then
    echo "Warning: Found existing build files:$EXISTING_FILES"
    echo "These files will be overwritten."
    echo
fi

echo "Generating files..."

# Generate customized Makefile
sed -e "s/{{PACKAGE_NAME}}/$PACKAGE_NAME/g" \
    -e "s/{{PACKAGE_NAME_UPPER}}/$PACKAGE_NAME_UPPER/g" \
    .claude/ldk-resources/Makefile > Makefile
echo "✓ Makefile generated"

# Copy makemk.lua (no customization needed)
cp .claude/ldk-resources/makemk.lua .
echo "✓ makemk.lua copied"

# Create rockspecs directory if it doesn't exist
mkdir -p rockspecs

# Generate customized rockspec in rockspecs directory
sed -e "s/{{PACKAGE_NAME}}/$PACKAGE_NAME/g" \
    -e "s/{{GITHUB_USER}}/$GITHUB_USER/g" \
    .claude/ldk-resources/template.rockspec > "rockspecs/$PACKAGE_NAME-dev-1.rockspec"
echo "✓ rockspecs/$PACKAGE_NAME-dev-1.rockspec generated"

echo
echo "Setup complete! Your C/C++ build system is ready."
echo
echo "Directory structure expected:"
echo "  rockspecs/ - Rockspec files (created)"
echo "  src/       - C/C++ source files (.c, .cpp)"
echo "  lua/       - Lua library files (.lua)"
echo "  bin/       - Command scripts (.lua, optional)"
echo
echo "Usage:"
echo "  luarocks make rockspecs/$PACKAGE_NAME-dev-1.rockspec    # Build and install"
echo "  ${PACKAGE_NAME_UPPER}_COVERAGE=1 luarocks make rockspecs/$PACKAGE_NAME-dev-1.rockspec    # Build with coverage"
echo
echo "Supports:"
echo "  - Pure Lua projects (lua/ only)"
echo "  - Pure C projects (.c files)"
echo "  - Pure C++ projects (.cpp files)"
echo "  - Mixed C/C++ projects"
echo "  - Mixed Lua and C/C++ projects"
echo "  - Automatic compiler selection"
echo "  - File grouping by prefix"
echo "  - Coverage instrumentation"
