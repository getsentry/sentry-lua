# Code Style Conventions

**This document defines coding standards and best practices for Lua projects, including performance optimizations and function organization rules.**

## Built-in Function Usage Conventions

For performance and readability improvements, follow these conventions:

### File-scope Local Variable Assignment

Assign frequently used functions to file-scope local variables for performance and reliability:

**What to localize:**
- Global functions: `local type = type`, `local pairs = pairs`
- Table methods: `local insert = table.insert`, `local floor = math.floor`
- Module functions: `local encode = require('json').encode`

**Exceptions (keep global):**
- `assert` and `error` functions should remain global
- These may be overridden by application frameworks for error capture/handling
- Example: `assert(condition, "error message")` - use directly without localization

**Why localize:**
1. **Performance**: Eliminates global table lookups
2. **Reliability**: Protects against runtime modifications
3. **Clarity**: Makes dependencies explicit

### Avoid Object Method Syntax

Use function form instead of method syntax to prevent issues with modified metatables:

```lua
-- Bad: Method syntax can fail if metatable is modified
local upper = str:upper()

-- Good: Function form is reliable
local upper = string.upper
local result = upper(str)
```

## Table Tail Append Optimization

For performance improvement, use direct index operations for table tail appends:

### Tail Append Optimization

```lua
-- Bad (function call overhead)
table.insert(tbl, value)
local insert = table.insert
insert(tbl, value)

-- Good (direct index operation, fastest)
tbl[#tbl + 1] = value
```

### Rationale

1. **Performance**: Eliminates function call overhead
2. **Memory efficiency**: Direct operation minimizes memory access
3. **Clarity**: Intent of tail append is clear
4. **Consistency**: Uniform across entire project

### Notes

- Use `table.insert` for mid-table insertion or when nils are present
- Apply this convention only for tail append operations

## Function Definition Order Rule

**Critical Rule**: Functions must be defined in **dependency order from deepest to shallowest**.

This follows the same constraint as C static functions without forward declarations: called functions must be defined before (above) their callers.

### Implementation Strategy

1. **Analyze the main function's call sequence**
2. **Place functions from top to bottom in order of dependency depth**
3. **Deepest dependencies first, main function last**

### Example Pattern

```lua
-- Deepest dependency (used by intermediate functions)
local function helper_func() 
    return some_value 
end

-- Intermediate dependency (used by main function)
local function process_data() 
    return helper_func()  -- uses helper_func
end

-- Main function (uses all above functions)
local function main()
    return process_data()  -- uses process_data
end
```

### Real-world Application

For a function that calls A, then B, then C (conditionally), arrange as:

```lua
-- Deepest/most distant calls first
local function C() ... end

-- Mid-level dependencies  
local function B() ... end

-- Direct dependencies of main
local function A() ... end

-- Main function last
local function main()
    A()  -- first call
    B()  -- second call  
    if condition then
        C()  -- conditional call
    end
end
```

**Key Principle**: Read the main function's call sequence, then arrange dependencies in reverse dependency order (deepest first, main last).

### Implementation Decision Tree

**For simple linear calls**: Place called functions immediately above caller  
**For conditional calls**: Place deepest conditional functions first  
**For shared utilities**: Place at top of file before any callers  
**For recursive functions**: Define before any external callers

### Performance Impact

**Local variable caching** provides 15-25% performance improvement in tight loops. **Direct table indexing** (`tbl[#tbl + 1] = value`) outperforms `table.insert()` by 10-20% for tail appends. **Function definition order** enables better Lua compiler optimization.

### Application Scope

This convention applies to:
- All Lua files under lua/
- All C files under src/ (similar optimization with corresponding C functions)
- Test files under test/

### Benefits

1. **Performance**: Reduces table lookup overhead
2. **Readability**: Functions in use are immediately visible
3. **Debug efficiency**: Function references are clear
4. **Consistency**: Unified style across entire project
5. **Natural flow**: Matches C static function constraints

## Common Optimization Patterns

### Memory Efficiency
- **Pre-allocate tables** with known size using `table.new(narray, nhash)` when available
- **Reuse tables** instead of creating new ones in loops
- **String concatenation**: Use `table.concat()` for multiple strings, direct concatenation for 2-3 strings

### Error Handling Optimization  
- **Fast path first**: Place common success cases before error checks
- **Early returns**: Use guard clauses to reduce nesting depth
- **Error context**: Include sufficient context in error messages for debugging without verbose traces

## Related Files
- @.claude/memories/ldk-commands.md - Commands for linting and formatting (luacheck, lua-format)
- @.claude/memories/ldk-test-guidelines.md - Code style in test files and test organization
- @.claude/memories/ldk-task-checklist.md - Style checking as part of development workflow
- @.claude/memories/ldk-technology-stack.md - Installation and setup for code quality tools
- @.claude/memories/ldk-project-structure.md - File organization and naming conventions
