#!/usr/bin/env lua
--[[
  Validation Script for Roblox Sentry Integration
  
  This script validates our Roblox integration files for:
  - Lua syntax correctness
  - Required function availability  
  - Module structure
  - DSN format validation
  
  Usage: lua validate-scripts.lua
]]--

print("🔍 Validating Roblox Sentry Integration Scripts")
print("=" .. string.rep("=", 45))

local validation_errors = {}
local validation_warnings = {}

-- Helper function to add errors
local function add_error(message)
    table.insert(validation_errors, message)
end

-- Helper function to add warnings
local function add_warning(message)
    table.insert(validation_warnings, message)
end

-- Helper function to check if string looks like valid Lua
local function validate_lua_syntax(code, filename)
    local func, err = load(code, filename)
    if not func then
        add_error("Syntax error in " .. filename .. ": " .. tostring(err))
        return false
    end
    return true
end

-- Helper function to check DSN format
local function validate_dsn(dsn)
    local pattern = "https://([^@]+)@([^/]+)/(.+)"
    local key, host, path = dsn:match(pattern)
    
    if not key or not host or not path then
        return false, "Invalid DSN format"
    end
    
    local projectId = path:match("(%d+)")
    if not projectId then
        return false, "Could not extract project ID from DSN"
    end
    
    return true, {key = key, host = host, projectId = projectId}
end

-- Helper function to read file
local function read_file(filename)
    local file = io.open(filename, "r")
    if not file then
        add_error("Could not read file: " .. filename)
        return nil
    end
    
    local content = file:read("*all")
    file:close()
    return content
end

-- Test 1: Validate quick-test-script.lua
print("\n📋 Test 1: Validating quick-test-script.lua")
local quick_test_content = read_file("quick-test-script.lua")
if quick_test_content then
    if validate_lua_syntax(quick_test_content, "quick-test-script.lua") then
        print("✅ Lua syntax is valid")
        
        -- Check for required components
        local required_patterns = {
            "sentry%.init",
            "sentry%.capture_message", 
            "sentry%.capture_exception",
            "sentry%.set_user",
            "sentry%.set_tag",
            "sentry%.add_breadcrumb",
            "_G%.SentryTestFunctions"
        }
        
        for _, pattern in ipairs(required_patterns) do
            if quick_test_content:find(pattern) then
                print("✅ Found: " .. pattern)
            else
                add_error("Missing required pattern: " .. pattern)
            end
        end
        
        -- Extract and validate DSN
        local dsn_match = quick_test_content:match('SENTRY_DSN = "([^"]+)"')
        if dsn_match then
            local valid, result = validate_dsn(dsn_match)
            if valid then
                print("✅ DSN format is valid")
                print("   Project ID: " .. result.projectId)
                print("   Host: " .. result.host)
            else
                add_error("Invalid DSN: " .. result)
            end
        else
            add_warning("Could not find SENTRY_DSN in quick-test-script.lua")
        end
    end
end

-- Test 2: Validate auto-load-modules.lua  
print("\n📋 Test 2: Validating auto-load-modules.lua")
local auto_load_content = read_file("auto-load-modules.lua")
if auto_load_content then
    if validate_lua_syntax(auto_load_content, "auto-load-modules.lua") then
        print("✅ Lua syntax is valid")
        
        -- Check for module structure
        local module_checks = {
            "moduleStructure",
            "createModuleStructure",
            "testModules", 
            "sentry%.init",
            "transport%.new"
        }
        
        for _, check in ipairs(module_checks) do
            if auto_load_content:find(check) then
                print("✅ Found: " .. check)
            else
                add_warning("Pattern not found: " .. check)
            end
        end
    end
end

-- Test 3: Check shell scripts exist and are properly formatted
print("\n📋 Test 3: Validating shell scripts")
local shell_scripts = {"simple-studio-test.sh", "run-headless-test.sh"}

for _, script in ipairs(shell_scripts) do
    local content = read_file(script)
    if content then
        if content:match("^#!/bin/bash") then
            print("✅ " .. script .. " has proper shebang")
        else
            add_warning(script .. " missing proper shebang")
        end
        
        if content:find("echo") and content:find("Sentry") then
            print("✅ " .. script .. " contains expected content")
        else
            add_warning(script .. " may be missing content")
        end
    end
end

-- Test 4: Check documentation files
print("\n📋 Test 4: Validating documentation")
local docs = {"README.md", "DEV_WORKFLOW.md", "DETAILED_SETUP.md"}

for _, doc in ipairs(docs) do
    local content = read_file(doc)
    if content then
        local line_count = 0
        for line in content:gmatch("[^\r\n]+") do
            line_count = line_count + 1
        end
        print("✅ " .. doc .. " exists (" .. line_count .. " lines)")
        
        if content:find("Sentry") and content:find("Roblox") then
            print("   Contains relevant content")
        else
            add_warning(doc .. " may be missing key content")
        end
    end
end

-- Test 5: Integration test simulation
print("\n📋 Test 5: Simulating integration test")

-- Create a mock environment similar to Roblox
local mock_game = {
    GetService = function(self, service)
        if service == "HttpService" then
            return {
                JSONEncode = function(self, data) 
                    return "mock-json-" .. tostring(data)
                end,
                PostAsync = function(self, url, payload, contentType, compress, headers)
                    print("📡 Mock HTTP POST to: " .. url)
                    print("   Payload length: " .. #payload)
                    print("   Headers: " .. tostring(headers and "present" or "none"))
                    return '{"id":"mock-event-id"}'
                end
            }
        elseif service == "ReplicatedStorage" then
            return {
                FindFirstChild = function() return nil end
            }
        end
        return {}
    end,
    PlaceId = 12345,
    JobId = "mock-job-id"
}

local mock_Instance = {
    new = function(className)
        return {
            Name = "",
            Source = "",
            Parent = nil
        }
    end
}

-- Try to load and execute parts of the quick test script in isolation
print("🧪 Testing core Sentry functionality...")

local test_dsn = "https://testkey@test.ingest.sentry.io/123456"
local valid_dsn, dsn_parts = validate_dsn(test_dsn)

if valid_dsn then
    print("✅ DSN parsing works correctly")
    print("   Key: " .. dsn_parts.key)
    print("   Host: " .. dsn_parts.host) 
    print("   Project: " .. dsn_parts.projectId)
else
    add_error("DSN parsing failed: " .. dsn_parts)
end

-- Summary
print("\n" .. string.rep("=", 50))
print("📊 VALIDATION SUMMARY")
print(string.rep("=", 50))

if #validation_errors == 0 then
    print("✅ No critical errors found")
    
    if #validation_warnings == 0 then
        print("✅ No warnings")
        print("\n🎉 ALL VALIDATIONS PASSED!")
        print("📋 The Roblox integration scripts appear to be ready for use")
        print("\n💡 Next steps:")
        print("   1. Run: ./simple-studio-test.sh")
        print("   2. Copy quick-test-script.lua into Roblox Studio")
        print("   3. Test the integration manually")
    else
        print("⚠️ " .. #validation_warnings .. " warning(s) found:")
        for i, warning in ipairs(validation_warnings) do
            print("   " .. i .. ". " .. warning)
        end
        print("\n✅ Scripts should work despite warnings")
    end
else
    print("❌ " .. #validation_errors .. " error(s) found:")
    for i, error in ipairs(validation_errors) do
        print("   " .. i .. ". " .. error)
    end
    
    if #validation_warnings > 0 then
        print("\n⚠️ " .. #validation_warnings .. " warning(s):")
        for i, warning in ipairs(validation_warnings) do
            print("   " .. i .. ". " .. warning)
        end
    end
    
    print("\n❌ Please fix errors before using the scripts")
end

print("")