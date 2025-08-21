#!/usr/bin/env lua

-- Test source context resolution
package.path = "examples/love2d/?.lua;build-single-file/?.lua;;"

print("=== Source Context Test ===")

-- Load the stacktrace utility directly
local stacktrace_success, stacktrace = pcall(require, "sentry.utils.stacktrace")
if not stacktrace_success then
    print("❌ Could not load stacktrace utility:", stacktrace)
    return
end

print("✅ Stacktrace utility loaded")

-- Test the stacktrace function
print("\n=== Testing stacktrace generation ===")

local function test_function()
    local trace = stacktrace.get_stack_trace(0)
    return trace
end

local function wrapper_function()
    return test_function()
end

-- Generate a stacktrace
local trace = wrapper_function()

print("Stacktrace generated:")
print("Number of frames:", #trace.frames)

for i, frame in ipairs(trace.frames) do
    print(string.format("Frame %d:", i))
    print("  filename:", frame.filename)
    print("  function:", frame["function"])
    print("  lineno:", frame.lineno)
    print("  in_app:", frame.in_app)
    print("  context_line:", frame.context_line and ('"' .. frame.context_line .. '"') or "nil")
    print("  pre_context lines:", frame.pre_context and #frame.pre_context or "nil")
    print("  post_context lines:", frame.post_context and #frame.post_context or "nil")
    print("")
end

-- Test with Love2D main.lua specifically
print("\n=== Testing Love2D main.lua context ===")

-- Change to Love2D directory to simulate Love2D environment
local original_dir = io.popen("pwd"):read("*a"):gsub("\n", "")
print("Original directory:", original_dir)

-- Test reading main.lua directly
local function test_main_lua_context()
    local file_path = "/Users/bruno/git/sentry-lua/examples/love2d/main.lua"
    local line_number = 138
    
    print("Testing file path:", file_path)
    print("Testing line number:", line_number)
    
    local file = io.open(file_path, "r")
    if file then
        print("✅ File can be opened")
        file:close()
        
        -- Test the source context function directly
        local sentry = require("sentry")
        
        -- Try to access the source context function
        -- Since it's internal, let's simulate what it does
        local function get_source_context(filename, line_number)
            if line_number <= 0 then
                return "", {}, {}
            end

            local file = io.open(filename, "r")
            if not file then
                print("❌ Could not open file:", filename)
                return "", {}, {}
            end

            local all_lines = {}
            local line_count = 0
            for line in file:lines() do
                line_count = line_count + 1
                all_lines[line_count] = line
            end
            file:close()

            local context_line = ""
            local pre_context = {}
            local post_context = {}

            if line_number > 0 and line_number <= line_count then
                context_line = all_lines[line_number] or ""
                
                -- Get 5 lines before
                for i = math.max(1, line_number - 5), line_number - 1 do
                    if i >= 1 and i <= line_count then
                        table.insert(pre_context, all_lines[i] or "")
                    end
                end
                
                -- Get 5 lines after
                for i = line_number + 1, math.min(line_count, line_number + 5) do
                    if i >= 1 and i <= line_count then
                        table.insert(post_context, all_lines[i] or "")
                    end
                end
            end

            return context_line, pre_context, post_context
        end
        
        local context_line, pre_context, post_context = get_source_context(file_path, line_number)
        
        print("Context line:", context_line and ('"' .. context_line .. '"') or "nil")
        print("Pre-context lines:", #pre_context)
        print("Post-context lines:", #post_context)
        
        if context_line and context_line ~= "" then
            print("✅ Source context working")
        else
            print("❌ Source context not working")
        end
    else
        print("❌ File cannot be opened")
    end
end

test_main_lua_context()

print("\n=== Test completed ===")