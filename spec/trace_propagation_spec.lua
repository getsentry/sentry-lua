-- Tests for trace propagation context management
-- Tests the core logic that manages distributed tracing state

local propagation = require("sentry.tracing.propagation")
local headers = require("sentry.tracing.headers")

describe("trace propagation", function()
    before_each(function()
        -- Clear any existing context before each test
        propagation.clear_context()
    end)
    
    after_each(function()
        -- Clean up after each test
        propagation.clear_context()
    end)
    
    describe("context management", function()
        it("should start with no active context", function()
            local context = propagation.get_current_context()
            assert.is_nil(context)
        end)
        
        it("should create new trace context", function()
            local context = propagation.start_new_trace()
            
            assert.is_not_nil(context)
            assert.is_not_nil(context.trace_id)
            assert.is_not_nil(context.span_id)
            assert.is_nil(context.parent_span_id) -- Root span
            assert.are.equal(32, #context.trace_id) -- 128-bit as hex
            assert.are.equal(16, #context.span_id)  -- 64-bit as hex
        end)
        
        it("should set and get current context", function()
            local test_context = {
                trace_id = "75302ac48a024bde9a3b3734a82e36c8",
                span_id = "1000000000000000",
                parent_span_id = nil,
                sampled = true
            }
            
            propagation.set_current_context(test_context)
            local retrieved = propagation.get_current_context()
            
            assert.are.equal(test_context.trace_id, retrieved.trace_id)
            assert.are.equal(test_context.span_id, retrieved.span_id)
            assert.are.equal(test_context.sampled, retrieved.sampled)
        end)
        
        it("should clear context", function()
            propagation.start_new_trace()
            assert.is_not_nil(propagation.get_current_context())
            
            propagation.clear_context()
            assert.is_nil(propagation.get_current_context())
        end)
        
        it("should report tracing as enabled when context exists", function()
            assert.is_false(propagation.is_tracing_enabled())
            
            propagation.start_new_trace()
            assert.is_true(propagation.is_tracing_enabled())
            
            propagation.clear_context()
            assert.is_false(propagation.is_tracing_enabled())
        end)
    end)
    
    describe("trace continuation from headers", function()
        it("should continue trace from sentry-trace header", function()
            local http_headers = {
                ["sentry-trace"] = "75302ac48a024bde9a3b3734a82e36c8-1000000000000000-1"
            }
            
            local context = propagation.continue_trace_from_headers(http_headers)
            
            assert.is_not_nil(context)
            assert.are.equal("75302ac48a024bde9a3b3734a82e36c8", context.trace_id)
            assert.are.equal("1000000000000000", context.parent_span_id) -- Incoming span becomes parent
            assert.is_not_nil(context.span_id) -- New span ID generated
            assert.is_true(context.sampled)
            assert.are.not_equal("1000000000000000", context.span_id) -- Should be new span ID
        end)
        
        it("should continue trace from W3C traceparent header", function()
            local http_headers = {
                ["traceparent"] = "00-75302ac48a024bde9a3b3734a82e36c8-1000000000000000-01"
            }
            
            local context = propagation.continue_trace_from_headers(http_headers)
            
            assert.is_not_nil(context)
            assert.are.equal("75302ac48a024bde9a3b3734a82e36c8", context.trace_id)
            assert.are.equal("1000000000000000", context.parent_span_id)
            assert.is_true(context.sampled)
        end)
        
        it("should prefer sentry-trace over traceparent", function()
            local http_headers = {
                ["sentry-trace"] = "75302ac48a024bde9a3b3734a82e36c8-1000000000000000-1",
                ["traceparent"] = "00-differenttraceid123456789abcdef0-2000000000000000-01"
            }
            
            local context = propagation.continue_trace_from_headers(http_headers)
            
            assert.is_not_nil(context)
            assert.are.equal("75302ac48a024bde9a3b3734a82e36c8", context.trace_id)
            assert.are.equal("1000000000000000", context.parent_span_id)
        end)
        
        it("should handle case-insensitive header names", function()
            local http_headers = {
                ["Sentry-Trace"] = "75302ac48a024bde9a3b3734a82e36c8-1000000000000000-1"
            }
            
            local context = propagation.continue_trace_from_headers(http_headers)
            
            assert.is_not_nil(context)
            assert.are.equal("75302ac48a024bde9a3b3734a82e36c8", context.trace_id)
        end)
        
        it("should parse baggage header", function()
            local http_headers = {
                ["sentry-trace"] = "75302ac48a024bde9a3b3734a82e36c8-1000000000000000-1",
                ["baggage"] = "sentry-environment=production,sentry-release=1.0.0"
            }
            
            local context = propagation.continue_trace_from_headers(http_headers)
            
            assert.is_not_nil(context)
            assert.is_not_nil(context.baggage)
            assert.are.equal("production", context.baggage["sentry-environment"])
            assert.are.equal("1.0.0", context.baggage["sentry-release"])
        end)
        
        it("should start new trace when no valid headers present", function()
            local http_headers = {
                ["some-other-header"] = "value"
            }
            
            local context = propagation.continue_trace_from_headers(http_headers)
            
            assert.is_not_nil(context)
            assert.is_not_nil(context.trace_id)
            assert.is_not_nil(context.span_id)
            assert.is_nil(context.parent_span_id) -- New root trace
        end)
        
        it("should handle invalid sentry-trace header gracefully", function()
            local http_headers = {
                ["sentry-trace"] = "invalid-header-format"
            }
            
            local context = propagation.continue_trace_from_headers(http_headers)
            
            assert.is_not_nil(context)
            assert.is_not_nil(context.trace_id)
            assert.is_nil(context.parent_span_id) -- Falls back to new trace
        end)
    end)
    
    describe("trace header generation", function()
        it("should generate headers for outgoing requests", function()
            local context = propagation.start_new_trace()
            
            local headers_out = propagation.get_trace_headers_for_request("http://example.com")
            
            assert.is_not_nil(headers_out["sentry-trace"])
            assert.is_not_nil(headers_out["sentry-trace"]:match(context.trace_id .. "%-" .. context.span_id))
        end)
        
        it("should include baggage in outgoing headers", function()
            local context = propagation.start_new_trace({
                baggage = {
                    ["sentry-environment"] = "test"
                }
            })
            context.baggage = { ["sentry-environment"] = "test" }
            propagation.set_current_context(context)
            
            local headers_out = propagation.get_trace_headers_for_request("http://example.com")
            
            assert.is_not_nil(headers_out["baggage"])
            assert.is_not_nil(headers_out["baggage"]:match("sentry%-environment=test"))
        end)
        
        it("should return empty headers when no context", function()
            -- No trace context set
            local headers_out = propagation.get_trace_headers_for_request("http://example.com")
            
            assert.are.equal("table", type(headers_out))
            assert.is_nil(headers_out["sentry-trace"])
        end)
    end)
    
    describe("trace propagation targeting", function()
        it("should propagate to all targets with wildcard", function()
            local context = propagation.start_new_trace()
            local options = {
                trace_propagation_targets = {"*"}
            }
            
            local headers1 = propagation.get_trace_headers_for_request("http://example.com", options)
            local headers2 = propagation.get_trace_headers_for_request("https://api.service.com", options)
            
            assert.is_not_nil(headers1["sentry-trace"])
            assert.is_not_nil(headers2["sentry-trace"])
        end)
        
        it("should propagate only to matching targets", function()
            local context = propagation.start_new_trace()
            local options = {
                trace_propagation_targets = {"api.service.com"}
            }
            
            local matching_headers = propagation.get_trace_headers_for_request("https://api.service.com/endpoint", options)
            local non_matching_headers = propagation.get_trace_headers_for_request("https://other.com/endpoint", options)
            
            assert.is_not_nil(matching_headers["sentry-trace"])
            assert.is_nil(non_matching_headers["sentry-trace"])
        end)
        
        it("should not propagate when no targets match", function()
            local context = propagation.start_new_trace()
            local options = {
                trace_propagation_targets = {"specific.domain.com"}
            }
            
            local headers = propagation.get_trace_headers_for_request("https://other.domain.com", options)
            
            assert.is_nil(headers["sentry-trace"])
        end)
        
        it("should propagate to all when no targeting configured", function()
            local context = propagation.start_new_trace()
            local options = {} -- No trace_propagation_targets
            
            local headers = propagation.get_trace_headers_for_request("http://example.com", options)
            
            assert.is_not_nil(headers["sentry-trace"])
        end)
    end)
    
    describe("child context creation", function()
        it("should create child from existing context", function()
            local parent = propagation.start_new_trace()
            
            local child = propagation.create_child_context()
            
            assert.is_not_nil(child)
            assert.are.equal(parent.trace_id, child.trace_id) -- Same trace
            assert.are.equal(parent.span_id, child.parent_span_id) -- Parent's span becomes parent_span_id
            assert.are.not_equal(parent.span_id, child.span_id) -- New span ID
        end)
        
        it("should start new trace when no parent context", function()
            -- No existing context
            local child = propagation.create_child_context()
            
            assert.is_not_nil(child)
            assert.is_not_nil(child.trace_id)
            assert.is_not_nil(child.span_id)
            assert.is_nil(child.parent_span_id) -- Root trace
        end)
    end)
    
    describe("trace context for events", function()
        it("should generate trace context for events", function()
            local context = propagation.start_new_trace()
            
            local event_context = propagation.get_trace_context_for_event()
            
            assert.is_not_nil(event_context)
            assert.are.equal(context.trace_id, event_context.trace_id)
            assert.are.equal(context.span_id, event_context.span_id)
            assert.are.equal(context.parent_span_id, event_context.parent_span_id)
        end)
        
        it("should return nil when no trace context", function()
            local event_context = propagation.get_trace_context_for_event()
            assert.is_nil(event_context)
        end)
    end)
    
    describe("edge cases", function()
        it("should handle nil headers gracefully", function()
            local context = propagation.continue_trace_from_headers(nil)
            assert.is_not_nil(context) -- Should create new trace
        end)
        
        it("should handle empty headers table", function()
            local context = propagation.continue_trace_from_headers({})
            assert.is_not_nil(context) -- Should create new trace
        end)
        
        it("should generate valid trace and span IDs", function()
            local context = propagation.start_new_trace()
            
            assert.is_not_nil(context.trace_id:match("^[0-9a-f]+$"))
            assert.is_not_nil(context.span_id:match("^[0-9a-f]+$"))
            assert.are.equal(32, #context.trace_id)
            assert.are.equal(16, #context.span_id)
        end)
    end)
end)