# Setup Lua C/C++ Build System: $ARGUMENTS

You will guide the user through setting up a complete Lua C/C++ extension build system for their project.

## ⚠️ CRITICAL SECURITY AND SAFETY CONSTRAINTS

**NEVER perform these actions:**
1. **Do NOT edit or modify files in `@.claude/ldk-resources/`** - These are templates that must remain unchanged
2. **Do NOT access files outside the current project directory** - Stay within the working directory
3. **Do NOT use sed/awk to edit template files directly** - Always copy first, then edit the copy
4. **Do NOT run git commands that modify the repository** - No git init, git add, git commit, git push, etc.
5. **Only use READ-ONLY git commands** - git rev-parse, git remote get-url, git config (for reading only)

**Required workflow for templates:**
1. Copy template file to project directory using `cp @.claude/...`
2. Use Edit tool to modify the copied file (never the original template)

**Prerequisites**: This command requires templates from the LDK resources directory (installed with this toolkit).

## Step 1: Determine Package Name

**If $ARGUMENTS contains a package name:**
1. Extract the package name from $ARGUMENTS
2. Say: "I'll set up build system for package '{package-name}'"
3. Ask: "Continue with this package name? (y/N)"

**If $ARGUMENTS is empty OR user says no:**
1. Ask: "What's your package name? (e.g., mylib)"
2. Wait for user response and store as PACKAGE_NAME

## Step 2: Gather Project Information

**Detect Git status once and store results:**
1. Use Bash to check if current directory is a git repository root:
   `[ "$(git rev-parse --show-toplevel 2>/dev/null)" = "$(pwd)" ] && echo "GIT_REPO" || echo "NOT_GIT"`
2. Store the result and proceed based on the detected status

**If GIT_REPO detected:**
1. Get remote URL: `git remote get-url origin 2>/dev/null || echo "NO_REMOTE"`
2. Get maintainer info (prefer local, fallback to global):
   - `git config --local user.name 2>/dev/null || git config --global user.name 2>/dev/null`
   - `git config --local user.email 2>/dev/null || git config --global user.email 2>/dev/null`
3. Set maintainer information:
   - Use git user.name if available
   - Fallback to username part of email if name not available
   - Default to "Your Name" if nothing available
   - **Note**: Use name only, no email addresses for privacy
4. Use actual remote URL if available, otherwise use placeholder URLs with warning

**If NOT_GIT detected:**
1. Use placeholder URLs: `https://example.com/[PACKAGE_NAME]`
2. Set maintainer to "Your Name" 
3. **IMPORTANT**: Do NOT run any git commands

## Step 3: Check for Existing Build Files

Use the LS tool to check for existing build files:
- Check for: Makefile, makemk.lua, rockspecs/*.rockspec, *.rockspec

**If any build files exist:**
1. List the found files to the user
2. Ask: "Found existing build files. Do you want to overwrite them? This will replace your current build configuration. (y/N)"
3. If user says no, respond: "Setup cancelled. Existing build files preserved." and stop.

## Step 4: Set Up Build System Files

### 4.1 Copy Core Files
Use the Bash tool to:
1. Copy makemk.lua: `cp @.claude/ldk-resources/makemk.lua .`
2. Copy Makefile template: `cp @.claude/ldk-resources/Makefile .`
3. Use Edit tool to customize the copied Makefile (substitute {{PACKAGE_NAME_UPPER}} with actual package name)

### 4.2 Create Rockspec
1. Create rockspecs/ directory
2. Copy template: `cp @.claude/ldk-resources/template.rockspec rockspecs/$PACKAGE_NAME-dev-1.rockspec`
3. Use Edit tool to customize the copied rockspec with substitutions:
   - {{PACKAGE_NAME}} → actual package name
   - {{REPO_URL}} → determined source URL (from Step 2)
   - {{HOMEPAGE_URL}} → determined homepage URL (from Step 2)
   - {{MAINTAINER}} → determined maintainer name (from Step 2)

### 4.3 Generate Smart Summary
**Analyze project context:**
1. Read CLAUDE.md if it exists for project description
2. Check README.md for project overview  
3. Examine existing code structure and file names
4. Consider package name patterns and directory structure

**Generate appropriate summary based on analysis:**
- For web frameworks: "A [lightweight/fast] web framework for Lua"
- For database drivers: "Lua bindings for [database] database"
- For parsers: "A [format] parser/library for Lua"
- For utilities: "[Package name] - [functional description] for Lua"
- Generic fallback: "A Lua library for [inferred purpose]"

**Present summary to user:**
1. Say: "I've analyzed your project and generated this summary: '[GENERATED_SUMMARY]'"
2. Ask: "Use this summary for your rockspec? (Y/n)"
3. If user accepts, use Edit tool to update the copied rockspec with the generated summary
4. If user declines, ask: "Please provide your preferred package description:" and use Edit tool to update with their input

## Step 5: Set Up Project Structure

### 5.1 Check Existing Directories
Use LS tool to check for standard directories and report status:
- ✓ src/ directory exists (for C/C++ extensions)
- ✓ lua/ directory exists (for Lua modules)  
- ✓ lib/ directory exists (for static libraries, optional)
- ✓ bin/ directory exists (for command scripts, optional)

### 5.2 Offer Directory Creation
Ask: "Would you like me to create missing standard directories? (y/N)"

**If yes:**
1. Create src/ and lua/ directories (core directories)
2. Ask separately: "Create lib/ directory for static libraries? (y/N)"
3. Ask separately: "Create bin/ directory for command scripts? (y/N)"
4. Create requested optional directories

## Step 6: Verify and Summarize Setup

**Confirm successful setup:**
1. Use LS to list created build files: Makefile, makemk.lua, rockspecs/
2. Display package configuration summary:
   - Package name
   - Rockspec location
   - Source URL  
   - Homepage URL
   - Generated/custom summary

## Step 7: Provide Final Guidance

**Present completion message:**
"✅ Setup complete! Your build system now supports:
- Pure Lua projects (lua/ directory)
- C/C++ extensions (src/ directory)
- Static libraries (lib/ directory) 
- Mixed-language projects
- Automatic compiler selection
- Source file directives (@cflags:, @ldflags:, @reflibs:, etc.)
- Coverage instrumentation

**Next steps:**
1. **Add your code to the appropriate directories:**
   - Lua modules → `lua/`
   - C/C++ extensions → `src/`
   - Static libraries → `lib/`
   - Command scripts → `bin/`

2. **Use source file directives in C/C++ files for automatic build configuration:**
   ```c
   //@cflags: -Wall -Werror
   //@ldflags: -lm -lpthread  
   //@reflibs: string util/memory
   ```

3. **Build and install your package:**
   ```bash
   luarocks make rockspecs/[PACKAGE_NAME]-dev-1.rockspec
   ```

4. **For coverage analysis:**
   ```bash
   [PACKAGE_NAME_UPPER]_COVERAGE=1 luarocks make
   ```"

**Important notes:**
- If you used placeholder URLs, remind the user to update them in the rockspec
- The build system automatically detects C/C++ files and applies source directives
- See the LDK memory files for detailed usage examples
