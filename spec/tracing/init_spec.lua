local tracing = require("sentry.tracing")

describe("sentry.tracing", function()
    before_each(function()
        -- Clear any existing context before each test
        tracing.clear()
    end)
    
    after_each(function()
        -- Clean up after each test  
        tracing.clear()
    end)
    
    describe("init", function()
        it("should initialize tracing with default config", function()
            tracing.init()
            
            assert.equal(true, tracing.is_active())
        end)
        
        it("should initialize tracing with custom config", function()
            local config = {
                trace_propagation_targets = {"example%.com"},
                include_traceparent = true
            }
            
            tracing.init(config)
            
            assert.equal(true, tracing.is_active())
            assert.same(config, tracing._config)
        end)
    end)
    
    describe("continue_trace_from_request", function()
        it("should continue trace from request headers", function()
            local request_headers = {
                ["sentry-trace"] = "1234567890abcdef1234567890abcdef-abcdef1234567890-1"
            }
            
            local trace_context = tracing.continue_trace_from_request(request_headers)
            
            assert.is_not_nil(trace_context)
            assert.equal("1234567890abcdef1234567890abcdef", trace_context.trace_id)
            assert.equal("abcdef1234567890", trace_context.parent_span_id)
        end)
        
        it("should start new trace when no headers", function()
            local request_headers = {}
            
            local trace_context = tracing.continue_trace_from_request(request_headers)
            
            assert.is_not_nil(trace_context)
            assert.is_not_nil(trace_context.trace_id)
            assert.is_nil(trace_context.parent_span_id)
        end)
    end)
    
    describe("get_request_headers", function()
        it("should return empty table when not active", function()
            tracing.clear()
            local headers = tracing.get_request_headers()
            assert.same({}, headers)
        end)
        
        it("should return sentry-trace header when active", function()
            tracing.start_trace()
            
            local headers = tracing.get_request_headers()
            
            assert.is_not_nil(headers["sentry-trace"])
        end)
        
        it("should use config for traceparent inclusion", function()
            tracing.init({include_traceparent = true})
            tracing.start_trace()
            
            local headers = tracing.get_request_headers()
            
            assert.is_not_nil(headers["sentry-trace"])
            assert.is_not_nil(headers["traceparent"])
        end)
        
        it("should respect trace propagation targets from config", function()
            tracing.init({trace_propagation_targets = {"^https://example%.com"}})
            tracing.start_trace()
            
            local headers1 = tracing.get_request_headers("https://other.com")
            local headers2 = tracing.get_request_headers("https://example.com")
            
            assert.same({}, headers1) -- Should not propagate
            assert.is_not_nil(headers2["sentry-trace"]) -- Should propagate
        end)
    end)
    
    describe("start_trace", function()
        it("should start new trace", function()
            local trace_context = tracing.start_trace()
            
            assert.is_not_nil(trace_context)
            assert.is_not_nil(trace_context.trace_id)
            assert.is_not_nil(trace_context.span_id)
            assert.is_nil(trace_context.parent_span_id)
        end)
        
        it("should include options", function()
            local options = {
                baggage = {key1 = "value1"}
            }
            
            local trace_context = tracing.start_trace(options)
            
            -- Note: baggage is stored in propagation context, not returned in trace_context
            assert.is_not_nil(trace_context)
        end)
    end)
    
    describe("create_child", function()
        it("should create child span context", function()
            tracing.start_trace()
            local parent_info = tracing.get_current_trace_info()
            
            local child_context = tracing.create_child()
            
            assert.equal(parent_info.trace_id, child_context.trace_id)
            assert.equal(parent_info.span_id, child_context.parent_span_id)
            assert.is_not_equal(parent_info.span_id, child_context.span_id)
        end)
        
        it("should start new trace when no parent", function()
            local child_context = tracing.create_child()
            
            assert.is_not_nil(child_context.trace_id)
            assert.is_nil(child_context.parent_span_id)
        end)
    end)
    
    describe("get_current_trace_info", function()
        it("should return nil when not active", function()
            tracing.clear()
            
            local trace_info = tracing.get_current_trace_info()
            assert.is_nil(trace_info)
        end)
        
        it("should return trace info when active", function()
            tracing.start_trace()
            
            local trace_info = tracing.get_current_trace_info()
            
            assert.is_not_nil(trace_info)
            assert.is_not_nil(trace_info.trace_id)
            assert.is_not_nil(trace_info.span_id)
            assert.equal(true, trace_info.is_tracing_enabled)
        end)
    end)
    
    describe("is_active", function()
        it("should return false when not active", function()
            tracing.clear()
            assert.equal(false, tracing.is_active())
        end)
        
        it("should return true when active", function()
            tracing.start_trace()
            assert.equal(true, tracing.is_active())
        end)
    end)
    
    describe("attach_trace_context_to_event", function()
        it("should not modify event when not active", function()
            tracing.clear()
            local event = {type = "error", message = "test"}
            
            local modified_event = tracing.attach_trace_context_to_event(event)
            
            assert.equal(event, modified_event)
            assert.is_nil(modified_event.contexts)
        end)
        
        it("should attach trace context when active", function()
            tracing.start_trace()
            local event = {type = "error", message = "test"}
            
            local modified_event = tracing.attach_trace_context_to_event(event)
            
            assert.equal(event, modified_event)
            assert.is_not_nil(modified_event.contexts)
            assert.is_not_nil(modified_event.contexts.trace)
            assert.is_not_nil(modified_event.contexts.trace.trace_id)
        end)
        
        it("should preserve existing contexts", function()
            tracing.start_trace()
            local event = {
                type = "error",
                message = "test",
                contexts = {
                    runtime = {name = "lua", version = "5.4"}
                }
            }
            
            local modified_event = tracing.attach_trace_context_to_event(event)
            
            assert.is_not_nil(modified_event.contexts.runtime)
            assert.is_not_nil(modified_event.contexts.trace)
        end)
        
        it("should handle invalid input", function()
            local result1 = tracing.attach_trace_context_to_event(nil)
            local result2 = tracing.attach_trace_context_to_event("not a table")
            
            assert.is_nil(result1)
            assert.equal("not a table", result2)
        end)
    end)
    
    describe("wrap_http_request", function()
        it("should wrap HTTP request function with trace headers", function()
            tracing.start_trace()
            
            local mock_client = function(url, options)
                return {
                    url = url,
                    headers = options.headers or {}
                }
            end
            
            local result = tracing.wrap_http_request(mock_client, "https://example.com", {
                method = "GET"
            })
            
            assert.equal("https://example.com", result.url)
            assert.is_not_nil(result.headers["sentry-trace"])
        end)
        
        it("should merge with existing headers", function()
            tracing.start_trace()
            
            local mock_client = function(url, options)
                return options.headers
            end
            
            local result = tracing.wrap_http_request(mock_client, "https://example.com", {
                headers = {
                    ["content-type"] = "application/json"
                }
            })
            
            assert.equal("application/json", result["content-type"])
            assert.is_not_nil(result["sentry-trace"])
        end)
        
        it("should error for non-function client", function()
            assert.has_error(function()
                tracing.wrap_http_request("not a function", "https://example.com")
            end, "http_client must be a function")
        end)
    end)
    
    describe("wrap_http_handler", function()
        it("should wrap handler with trace continuation", function()
            local trace_id_captured = nil
            
            local mock_handler = function(request, response)
                trace_id_captured = tracing.get_current_trace_info()
                return "handled"
            end
            
            local wrapped_handler = tracing.wrap_http_handler(mock_handler)
            
            local mock_request = {
                headers = {
                    ["sentry-trace"] = "1234567890abcdef1234567890abcdef-abcdef1234567890-1"
                }
            }
            
            local result = wrapped_handler(mock_request, {})
            
            assert.equal("handled", result)
            assert.is_not_nil(trace_id_captured)
            assert.equal("1234567890abcdef1234567890abcdef", trace_id_captured.trace_id)
        end)
        
        it("should handle requests without trace headers", function()
            local trace_info_captured = nil
            
            local mock_handler = function(request, response)
                trace_info_captured = tracing.get_current_trace_info()
            end
            
            local wrapped_handler = tracing.wrap_http_handler(mock_handler)
            wrapped_handler({headers = {}}, {})
            
            assert.is_not_nil(trace_info_captured) -- Should have started new trace
        end)
        
        it("should handle requests with get_header method", function()
            local trace_id_captured = nil
            
            local mock_handler = function(request, response)
                trace_id_captured = tracing.get_current_trace_info()
            end
            
            local wrapped_handler = tracing.wrap_http_handler(mock_handler)
            
            local mock_request = {
                get_header = function(self, name)
                    if name == "sentry-trace" then
                        return "1234567890abcdef1234567890abcdef-abcdef1234567890-1"
                    end
                    return nil
                end
            }
            
            wrapped_handler(mock_request, {})
            
            assert.is_not_nil(trace_id_captured)
            assert.equal("1234567890abcdef1234567890abcdef", trace_id_captured.trace_id)
        end)
        
        it("should propagate errors from handler", function()
            local mock_handler = function(request, response)
                error("handler error")
            end
            
            local wrapped_handler = tracing.wrap_http_handler(mock_handler)
            
            assert.has_error(function()
                wrapped_handler({headers = {}}, {})
            end)
        end)
        
        it("should error for non-function handler", function()
            assert.has_error(function()
                tracing.wrap_http_handler("not a function")
            end, "handler must be a function")
        end)
    end)
    
    describe("generate_ids", function()
        it("should generate valid trace and span IDs", function()
            local ids = tracing.generate_ids()
            
            assert.is_not_nil(ids.trace_id)
            assert.is_not_nil(ids.span_id)
            assert.equal(32, #ids.trace_id) -- 128-bit as hex
            assert.equal(16, #ids.span_id) -- 64-bit as hex
            assert.is_true(ids.trace_id:match("^[0-9a-f]+$") ~= nil)
            assert.is_true(ids.span_id:match("^[0-9a-f]+$") ~= nil)
        end)
        
        it("should generate unique IDs", function()
            local ids1 = tracing.generate_ids()
            local ids2 = tracing.generate_ids()
            
            assert.is_not_equal(ids1.trace_id, ids2.trace_id)
            assert.is_not_equal(ids1.span_id, ids2.span_id)
        end)
    end)
    
    describe("get_envelope_trace_header", function()
        it("should return nil when not active", function()
            tracing.clear()
            
            local header = tracing.get_envelope_trace_header()
            assert.is_nil(header)
        end)
        
        it("should return DSC when active", function()
            tracing.start_trace()
            
            local header = tracing.get_envelope_trace_header()
            
            assert.is_not_nil(header)
            assert.is_not_nil(header["sentry-trace_id"])
        end)
    end)
end)