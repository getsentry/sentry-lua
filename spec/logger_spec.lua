local logger = require("sentry.logger")
local envelope = require("sentry.utils.envelope")
local json = require("sentry.utils.json")

describe("sentry.logger", function()
    
    before_each(function()
        -- Reset logger state
        if logger.unhook_print then
            logger.unhook_print()
        end
        
        -- Clear any existing configuration
        logger.init({
            enable_logs = false,
            hook_print = false
        })
    end)
    
    describe("initialization", function()
        it("should initialize with default config", function()
            logger.init({
                enable_logs = true
            })
            
            local config = logger.get_config()
            assert.is_true(config.enable_logs)
            assert.equals(100, config.max_buffer_size)
            assert.equals(5.0, config.flush_timeout)
            assert.is_false(config.hook_print)
        end)
        
        it("should initialize with custom config", function()
            logger.init({
                enable_logs = true,
                max_buffer_size = 50,
                flush_timeout = 10.0,
                hook_print = true
            })
            
            local config = logger.get_config()
            assert.is_true(config.enable_logs)
            assert.equals(50, config.max_buffer_size)
            assert.equals(10.0, config.flush_timeout)
            assert.is_true(config.hook_print)
        end)
        
        it("should support before_send_log hook", function()
            local hook_called = false
            local modified_body = "modified message"
            
            logger.init({
                enable_logs = true,
                before_send_log = function(log_record)
                    hook_called = true
                    log_record.body = modified_body
                    return log_record
                end
            })
            
            logger.info("original message")
            logger.flush()
            
            assert.is_true(hook_called)
        end)
        
        it("should filter logs when before_send_log returns nil", function()
            logger.init({
                enable_logs = true,
                before_send_log = function(log_record)
                    if log_record.level == "debug" then
                        return nil  -- Filter debug logs
                    end
                    return log_record
                end
            })
            
            logger.debug("This should be filtered")
            logger.info("This should pass through")
            
            local status = logger.get_buffer_status()
            assert.equals(1, status.logs)  -- Only info log should remain
        end)
    end)
    
    describe("logging levels", function()
        before_each(function()
            logger.init({
                enable_logs = true,
                max_buffer_size = 10
            })
        end)
        
        it("should support all log levels", function()
            logger.trace("trace message")
            logger.debug("debug message")
            logger.info("info message")
            logger.warn("warn message")
            logger.error("error message")
            logger.fatal("fatal message")
            
            local status = logger.get_buffer_status()
            assert.equals(6, status.logs)
        end)
        
        it("should not log when disabled", function()
            logger.init({
                enable_logs = false
            })
            
            logger.info("This should not be logged")
            
            local status = logger.get_buffer_status()
            assert.equals(0, status.logs)
        end)
    end)
    
    describe("structured logging", function()
        before_each(function()
            logger.init({
                enable_logs = true,
                max_buffer_size = 10
            })
        end)
        
        it("should handle parameterized messages", function()
            logger.info("User %s performed action %s", {"user123", "login"})
            
            local status = logger.get_buffer_status()
            assert.equals(1, status.logs)
        end)
        
        it("should handle messages with attributes", function()
            logger.info("Order processed", nil, {
                order_id = "order123",
                amount = 99.99,
                success = true
            })
            
            local status = logger.get_buffer_status()
            assert.equals(1, status.logs)
        end)
        
        it("should handle both parameters and attributes", function()
            logger.warn("Payment failed for user %s", {"user456"}, {
                error_code = "DECLINED",
                attempts = 3
            })
            
            local status = logger.get_buffer_status()
            assert.equals(1, status.logs)
        end)
    end)
    
    describe("buffer management", function()
        it("should flush when buffer exceeds max size", function()
            local flush_called = false
            
            logger.init({
                enable_logs = true,
                max_buffer_size = 2
            })
            
            -- Mock flush to detect when it's called
            local original_flush = logger.flush
            logger.flush = function()
                flush_called = true
                original_flush()
            end
            
            logger.info("message 1")
            assert.is_false(flush_called)
            
            logger.info("message 2")
            assert.is_true(flush_called)
        end)
        
        it("should track buffer status correctly", function()
            logger.init({
                enable_logs = true,
                max_buffer_size = 5
            })
            
            local initial_status = logger.get_buffer_status()
            assert.equals(0, initial_status.logs)
            
            logger.info("test message 1")
            logger.info("test message 2")
            
            local status = logger.get_buffer_status()
            assert.equals(2, status.logs)
            assert.equals(5, status.max_size)
        end)
        
        it("should clear buffer after flush", function()
            logger.init({
                enable_logs = true
            })
            
            logger.info("test message")
            local pre_flush_status = logger.get_buffer_status()
            assert.equals(1, pre_flush_status.logs)
            
            logger.flush()
            
            local post_flush_status = logger.get_buffer_status()
            assert.equals(0, post_flush_status.logs)
        end)
    end)
    
    describe("print hooking", function()
        it("should hook print when enabled", function()
            logger.init({
                enable_logs = true,
                hook_print = true
            })
            
            local original_print_type = type(_G.print)
            assert.equals("function", original_print_type)
            
            -- Print hooking changes print function
            logger.hook_print()
            
            print("test message")
            
            local status = logger.get_buffer_status()
            assert.equals(1, status.logs)
        end)
        
        it("should unhook print correctly", function()
            logger.init({
                enable_logs = true,
                hook_print = true
            })
            
            logger.hook_print()
            local hooked_print = _G.print
            
            logger.unhook_print()
            
            -- Should restore original print
            assert.is_not.equals(hooked_print, _G.print)
        end)
        
        it("should handle multiple print arguments", function()
            logger.init({
                enable_logs = true,
                hook_print = true
            })
            
            logger.hook_print()
            
            print("arg1", "arg2", 123, true)
            
            local status = logger.get_buffer_status()
            assert.equals(1, status.logs)
        end)
        
        it("should not create infinite loops", function()
            logger.init({
                enable_logs = true,
                hook_print = true
            })
            
            logger.hook_print()
            
            -- This should not cause infinite recursion
            logger.info("This log might trigger internal print statements")
            
            -- If we get here without stack overflow, the recursion protection works
            assert.is_true(true)
        end)
    end)
    
    describe("trace correlation", function()
        it("should include trace_id when tracing is available", function()
            -- This test would need mock tracing module
            -- For now just verify it doesn't crash without tracing
            logger.init({
                enable_logs = true
            })
            
            logger.info("test message")
            
            local status = logger.get_buffer_status()
            assert.equals(1, status.logs)
        end)
    end)
end)

describe("sentry.utils.envelope log support", function()
    
    describe("build_log_envelope", function()
        it("should create valid log envelope", function()
            local log_records = {
                {
                    timestamp = 1234567890.5,
                    trace_id = "abc123",
                    level = "info",
                    body = "Test message",
                    attributes = {
                        ["test.key"] = {value = "test_value", type = "string"}
                    },
                    severity_number = 9
                }
            }
            
            local envelope_body = envelope.build_log_envelope(log_records)
            
            assert.is_string(envelope_body)
            assert.is_not.equals("", envelope_body)
            
            -- Should contain log envelope structure
            assert.is_truthy(envelope_body:find('"type":"log"'))
            assert.is_truthy(envelope_body:find('"item_count":1'))
            assert.is_truthy(envelope_body:find('items%.log'))
        end)
        
        it("should handle multiple log records", function()
            local log_records = {
                {
                    timestamp = 1234567890.1,
                    trace_id = "trace1",
                    level = "info",
                    body = "Message 1",
                    attributes = {},
                    severity_number = 9
                },
                {
                    timestamp = 1234567890.2,
                    trace_id = "trace2", 
                    level = "error",
                    body = "Message 2",
                    attributes = {},
                    severity_number = 17
                }
            }
            
            local envelope_body = envelope.build_log_envelope(log_records)
            
            assert.is_string(envelope_body)
            assert.is_truthy(envelope_body:find('"item_count":2'))
        end)
        
        it("should return empty string for empty log array", function()
            local envelope_body = envelope.build_log_envelope({})
            assert.equals("", envelope_body)
        end)
        
        it("should return empty string for nil input", function()
            local envelope_body = envelope.build_log_envelope(nil)
            assert.equals("", envelope_body)
        end)
        
        it("should include proper envelope structure", function()
            local log_records = {
                {
                    timestamp = 1234567890.5,
                    trace_id = "abc123",
                    level = "warn",
                    body = "Warning message",
                    attributes = {
                        ["severity"] = {value = "medium", type = "string"},
                        ["count"] = {value = 42, type = "integer"}
                    },
                    severity_number = 13
                }
            }
            
            local envelope_body = envelope.build_log_envelope(log_records)
            
            -- Split envelope into lines
            local lines = {}
            for line in envelope_body:gmatch("[^\n]+") do
                table.insert(lines, line)
            end
            
            -- Should have 3 lines: header, item header, payload
            assert.equals(3, #lines)
            
            -- Parse header
            local header = json.decode(lines[1])
            assert.is_string(header.sent_at)
            
            -- Parse item header
            local item_header = json.decode(lines[2])
            assert.equals("log", item_header.type)
            assert.equals(1, item_header.item_count)
            assert.equals("application/vnd.sentry.items.log+json", item_header.content_type)
            
            -- Parse payload
            local payload = json.decode(lines[3])
            assert.is_table(payload.items)
            assert.equals(1, #payload.items)
            
            local log_item = payload.items[1]
            assert.equals("abc123", log_item.trace_id)
            assert.equals("warn", log_item.level)
            assert.equals("Warning message", log_item.body)
            assert.equals(13, log_item.severity_number)
            assert.is_table(log_item.attributes)
        end)
    end)
end)