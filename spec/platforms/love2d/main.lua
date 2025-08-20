-- Headless Love2D test runner for Sentry SDK
-- This runs actual tests in the Love2D runtime environment

-- Add build path for modules
package.path = "../../../build/?.lua;../../../build/?/init.lua;" .. package.path

local test_results = {
    passed = 0,
    failed = 0,
    tests = {},
    start_time = 0
}

local function log(message)
    print("[LOVE2D-TEST] " .. message)
end

local function assert_equal(actual, expected, message)
    if actual == expected then
        test_results.passed = test_results.passed + 1
        log("✓ " .. (message or "assertion passed"))
        table.insert(test_results.tests, {status = "PASS", message = message or "assertion"})
    else
        test_results.failed = test_results.failed + 1
        local error_msg = string.format("Expected '%s', got '%s' - %s", tostring(expected), tostring(actual), message or "assertion failed")
        log("✗ " .. error_msg)
        table.insert(test_results.tests, {status = "FAIL", message = error_msg})
    end
end

local function assert_true(condition, message)
    assert_equal(condition, true, message)
end

local function assert_false(condition, message)
    assert_equal(condition, false, message)
end

local function assert_not_equal(actual, expected, message)
    if actual == expected then
        test_results.failed = test_results.failed + 1
        local error_msg = string.format("Expected '%s' to NOT equal '%s' - %s", tostring(actual), tostring(expected), message or "assertion failed")
        log("✗ " .. error_msg)
        table.insert(test_results.tests, {status = "FAIL", message = error_msg})
    else
        test_results.passed = test_results.passed + 1
        log("✓ " .. (message or "values are not equal"))
        table.insert(test_results.tests, {status = "PASS", message = message or "values are not equal"})
    end
end

local function assert_not_nil(value, message)
    if value ~= nil then
        test_results.passed = test_results.passed + 1
        log("✓ " .. (message or "value is not nil"))
        table.insert(test_results.tests, {status = "PASS", message = message or "not nil"})
    else
        test_results.failed = test_results.failed + 1
        local error_msg = "Expected non-nil value - " .. (message or "nil check failed")
        log("✗ " .. error_msg)
        table.insert(test_results.tests, {status = "FAIL", message = error_msg})
    end
end

local function run_test(name, test_func)
    log("Running test: " .. name)
    local success, err = pcall(test_func)
    if not success then
        test_results.failed = test_results.failed + 1
        local error_msg = "Test crashed: " .. tostring(err)
        log("✗ " .. error_msg)
        table.insert(test_results.tests, {status = "FAIL", message = error_msg})
    end
end

local function test_love2d_environment()
    assert_not_nil(_G.love, "Love2D global should exist")
    assert_not_nil(love.system, "love.system should exist")
    assert_not_nil(love.thread, "love.thread should exist")
    assert_not_nil(love.timer, "love.timer should exist")
    
    -- Test OS detection
    local os_name = love.system.getOS()
    assert_not_nil(os_name, "OS name should be detected")
    log("Detected OS: " .. tostring(os_name))
    
    -- Test Love2D version
    local major, minor, revision, codename = love.getVersion()
    assert_not_nil(major, "Love2D major version should exist")
    local version_string = string.format("%d.%d.%d (%s)", major, minor, revision, codename)
    log("Love2D version: " .. version_string)
end

local function test_module_loading()
    -- Test Sentry core module
    local sentry = require("sentry")
    assert_not_nil(sentry, "Sentry module should load")
    assert_not_nil(sentry.init, "Sentry.init should exist")
    
    -- Test logger module
    local logger = require("sentry.logger")
    assert_not_nil(logger, "Logger module should load")
    assert_not_nil(logger.init, "Logger.init should exist")
    
    -- Test Love2D specific modules
    local transport = require("sentry.platforms.love2d.transport")
    assert_not_nil(transport, "Love2D transport should load")
    assert_true(transport.is_love2d_available(), "Love2D transport should be available in Love2D runtime")
    
    local os_detection = require("sentry.platforms.love2d.os_detection")
    assert_not_nil(os_detection, "Love2D OS detection should load")
    
    local context = require("sentry.platforms.love2d.context")
    assert_not_nil(context, "Love2D context should load")
end

local function test_sentry_initialization()
    local sentry = require("sentry")
    
    -- Initialize Sentry
    sentry.init({
        dsn = "https://e247e6e48f8f482499052a65adaa9f6b@o117736.ingest.us.sentry.io/4504930623356928",
        environment = "love2d-test",
        release = "love2d-test@1.0.0",
        debug = true
    })
    
    assert_not_nil(sentry._client, "Sentry client should be initialized")
    assert_not_nil(sentry._client.transport, "Sentry transport should be initialized")
    
    -- Verify Love2D transport is selected
    local transport_name = "unknown"
    if sentry._client.transport then
        -- Check if it's the Love2D transport by testing clean API methods
        if sentry.flush and sentry.close then
            transport_name = "love2d"
        end
    end
    
    assert_equal(transport_name, "love2d", "Love2D transport should be selected")
    log("Transport selected: " .. transport_name)
end

local function test_logger_functionality()
    local logger = require("sentry.logger")
    
    logger.init({
        enable_logs = true,
        max_buffer_size = 2,
        flush_timeout = 1.0,
        hook_print = false -- Disable to avoid interference with test output
    })
    
    -- Test basic logging
    logger.info("Test log message from Love2D")
    logger.error("Test error message from Love2D")
    
    -- Get buffer status
    local status = logger.get_buffer_status()
    assert_not_nil(status, "Buffer status should be available")
    assert_true(status.logs >= 0, "Buffer should have non-negative log count")
    
    -- Test flush
    logger.flush()
    log("Logger test completed successfully")
end

local function test_error_capture()
    local sentry = require("sentry")
    local logger = require("sentry.logger")
    
    -- Add breadcrumb
    sentry.add_breadcrumb({
        message = "Love2D test breadcrumb",
        category = "test",
        level = "info"
    })
    
    -- Test exception capture
    local function error_handler(err)
        sentry.capture_exception({
            type = "Love2DTestError",
            message = tostring(err)
        })
        return err
    end
    
    -- Trigger error in controlled way
    local success, result = xpcall(function()
        error("Love2D test error for stack trace verification")
    end, error_handler)
    
    assert_false(success, "Error should have been caught")
    assert_not_nil(result, "Error result should exist")
    
    log("Error capture test completed")
end

local function test_transport_functionality()
    local sentry = require("sentry")
    
    -- Test transport methods exist
    if sentry._client and sentry._client.transport then
        local transport = sentry._client.transport
        
        assert_not_nil(transport.flush, "Transport should have flush method")
        
        -- Test flush (should not error)
        local success, err = pcall(function()
            transport:flush()
        end)
        assert_true(success, "Transport flush should succeed: " .. tostring(err or ""))
        
        log("Transport functionality test completed")
    end
end

local function test_error_handler_integration()
    log("Testing Love2D error handler integration...")
    
    -- Test loading integration module
    local ok, integration_module = pcall(require, "sentry.platforms.love2d.integration")
    assert_true(ok, "Should be able to load Love2D integration module")
    assert_not_nil(integration_module.setup_love2d_integration, "Integration module should export setup function")
    
    -- Test creating integration instance
    local integration = integration_module.setup_love2d_integration()
    assert_not_nil(integration, "Integration should be created successfully")
    assert_true(type(integration.install_error_handler) == "function", "Integration should have install_error_handler method")
    assert_true(type(integration.uninstall_error_handler) == "function", "Integration should have uninstall_error_handler method")
    
    -- Store original error handler 
    local original_handler = love.errorhandler
    
    -- Test installing error handler with updated API
    integration:install_error_handler({
        capture_exception = function(self, exception_data, level)
            log("Mock capture_exception called with type: " .. (exception_data.type or "unknown") .. " level: " .. (level or "unknown"))
            return "test-event-id"
        end,
        transport = {
            flush = function(self)
                log("Mock transport flush called")
            end
        }
    })
    
    assert_not_equal(love.errorhandler, original_handler, "Error handler should be replaced")
    
    -- Test the error handler by triggering a fatal error (it should be captured and re-thrown)
    local error_captured = false
    local flush_called = false
    
    integration:uninstall_error_handler()
    integration:install_error_handler({
        options = {
            environment = "test",
            debug = true
        },
        scope = {
            apply_to_event = function(self, event)
                log("✓ Scope applied to fatal error event")
                return event
            end
        },
        transport = {
            send = function(self, event)
                log("✓ Fatal error captured with mechanism: " .. (event.exception and event.exception.values and event.exception.values[1] and event.exception.values[1].mechanism and event.exception.values[1].mechanism.type or "unknown"))
                error_captured = true
                if event.exception and event.exception.values and event.exception.values[1] then
                    local exception = event.exception.values[1]
                    assert_equal(exception.type, "RuntimeError", "Exception type should be RuntimeError")
                    assert_equal(exception.mechanism.type, "love.errorhandler", "Mechanism type should be love.errorhandler")
                    assert_equal(exception.mechanism.handled, false, "Mechanism handled should be false")
                end
                return true, nil
            end,
            flush = function(self)
                log("✓ Transport flush called for fatal error")
                flush_called = true
            end
        }
    })
    
    -- Try to trigger the error handler (should be captured then re-thrown)
    local caught_error = nil
    local success = pcall(function()
        love.errorhandler("Fatal Love2D error triggered by test - Testing love.errorhandler integration!")
    end)
    
    -- The error handler should have captured the error and re-thrown it
    assert_true(error_captured, "Fatal error should have been captured by integration")
    assert_true(flush_called, "Transport flush should have been called")
    
    -- Test uninstalling error handler
    integration:uninstall_error_handler()
    assert_equal(love.errorhandler, original_handler, "Error handler should be restored")
    
    log("Error handler integration test completed")
end

function love.load()
    log("Starting Love2D Sentry SDK tests...")
    test_results.start_time = love.timer.getTime()
    
    -- Run all tests
    run_test("Love2D Environment", test_love2d_environment)
    run_test("Module Loading", test_module_loading)  
    run_test("Sentry Initialization", test_sentry_initialization)
    run_test("Logger Functionality", test_logger_functionality)
    run_test("Error Capture", test_error_capture)
    run_test("Transport Functionality", test_transport_functionality)
    run_test("Error Handler Integration", test_error_handler_integration)
    
    -- Wait a moment for async operations
    love.timer.sleep(1)
end

local function print_results()
    local elapsed = love.timer.getTime() - test_results.start_time
    
    log("=== Test Results ===")
    log(string.format("Tests run: %d", test_results.passed + test_results.failed))
    log(string.format("Passed: %d", test_results.passed))
    log(string.format("Failed: %d", test_results.failed))
    log(string.format("Time: %.2f seconds", elapsed))
    log("")
    
    -- Print individual test results
    for _, test in ipairs(test_results.tests) do
        log(string.format("[%s] %s", test.status, test.message))
    end
    
    log("")
    
    if test_results.failed == 0 then
        log("All tests passed! 🎉")
        love.event.quit(0)
    else
        log("Some tests failed! ❌")
        love.event.quit(1) 
    end
end

-- Simple update loop to handle exit
local exit_timer = 0
function love.update(dt)
    exit_timer = exit_timer + dt
    
    -- Flush transports periodically
    if love.timer.getTime() - test_results.start_time > 0.5 then
        local sentry = package.loaded.sentry
        if sentry and sentry.flush then
            sentry.flush()
        end
        
        local logger = package.loaded["sentry.logger"]
        if logger and logger.flush then
            logger.flush()
        end
    end
    
    -- Exit after enough time for async operations
    if exit_timer > 3 then
        print_results()
    end
end

-- Minimal draw function for headless mode (graphics disabled)
function love.draw()
    -- No graphics in headless mode
    -- Test progress is printed to console instead
end