local propagation = require("sentry.tracing.propagation")

describe("sentry.tracing.propagation", function()
    before_each(function()
        -- Clear any existing context before each test
        propagation.clear_context()
    end)
    
    after_each(function()
        -- Clean up after each test
        propagation.clear_context()
    end)
    
    describe("create_context", function()
        it("should create new context without incoming trace data", function()
            local context = propagation.create_context()
            
            assert.is_not_nil(context.trace_id)
            assert.is_not_nil(context.span_id)
            assert.is_nil(context.parent_span_id)
            assert.is_nil(context.sampled) -- Deferred sampling in TwP mode
            assert.same({}, context.baggage)
        end)
        
        it("should continue context from incoming trace data", function()
            local incoming_trace = {
                trace_id = "1234567890abcdef1234567890abcdef",
                span_id = "abcdef1234567890",
                sampled = true
            }
            
            local context = propagation.create_context(incoming_trace)
            
            assert.equal("1234567890abcdef1234567890abcdef", context.trace_id)
            assert.equal("abcdef1234567890", context.parent_span_id) -- Incoming span becomes parent
            assert.is_not_nil(context.span_id) -- New span ID generated
            assert.is_not_equal("abcdef1234567890", context.span_id) -- Should be different
            assert.equal(true, context.sampled)
        end)
        
        it("should include baggage data", function()
            local baggage_data = {
                key1 = "value1",
                key2 = "value2"
            }
            
            local context = propagation.create_context(nil, baggage_data)
            
            assert.equal("value1", context.baggage.key1)
            assert.equal("value2", context.baggage.key2)
        end)
    end)
    
    describe("get_current_context and set_current_context", function()
        it("should return nil when no context is set", function()
            assert.is_nil(propagation.get_current_context())
        end)
        
        it("should store and retrieve context", function()
            local context = propagation.create_context()
            propagation.set_current_context(context)
            
            local retrieved = propagation.get_current_context()
            assert.equal(context, retrieved)
        end)
        
        it("should clear context", function()
            local context = propagation.create_context()
            propagation.set_current_context(context)
            
            propagation.clear_context()
            assert.is_nil(propagation.get_current_context())
        end)
    end)
    
    describe("continue_trace_from_headers", function()
        it("should continue trace from sentry-trace header", function()
            local http_headers = {
                ["sentry-trace"] = "1234567890abcdef1234567890abcdef-abcdef1234567890-1"
            }
            
            local context = propagation.continue_trace_from_headers(http_headers)
            
            assert.equal("1234567890abcdef1234567890abcdef", context.trace_id)
            assert.equal("abcdef1234567890", context.parent_span_id)
            assert.equal(true, context.sampled)
            
            -- Should also set as current context
            assert.equal(context, propagation.get_current_context())
        end)
        
        it("should continue trace from W3C traceparent header", function()
            local http_headers = {
                ["traceparent"] = "00-1234567890abcdef1234567890abcdef-abcdef1234567890-01"
            }
            
            local context = propagation.continue_trace_from_headers(http_headers)
            
            assert.equal("1234567890abcdef1234567890abcdef", context.trace_id)
            assert.equal("abcdef1234567890", context.parent_span_id)
            assert.equal(true, context.sampled)
        end)
        
        it("should prioritize sentry-trace over traceparent", function()
            local http_headers = {
                ["sentry-trace"] = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-bbbbbbbbbbbbbbbb-0",
                ["traceparent"] = "00-1234567890abcdef1234567890abcdef-abcdef1234567890-01"
            }
            
            local context = propagation.continue_trace_from_headers(http_headers)
            
            -- Should use sentry-trace values
            assert.equal("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", context.trace_id)
            assert.equal("bbbbbbbbbbbbbbbb", context.parent_span_id)
            assert.equal(false, context.sampled)
        end)
        
        it("should include baggage data", function()
            local http_headers = {
                ["sentry-trace"] = "1234567890abcdef1234567890abcdef-abcdef1234567890-1",
                ["baggage"] = "key1=value1,key2=value2"
            }
            
            local context = propagation.continue_trace_from_headers(http_headers)
            
            assert.equal("value1", context.baggage.key1)
            assert.equal("value2", context.baggage.key2)
        end)
        
        it("should start new trace when no trace headers present", function()
            local http_headers = {
                ["content-type"] = "application/json"
            }
            
            local context = propagation.continue_trace_from_headers(http_headers)
            
            assert.is_not_nil(context.trace_id)
            assert.is_not_nil(context.span_id)
            assert.is_nil(context.parent_span_id)
            assert.is_nil(context.sampled) -- Deferred sampling
        end)
    end)
    
    describe("get_trace_headers_for_request", function()
        it("should return empty table when no current context", function()
            local headers = propagation.get_trace_headers_for_request()
            assert.same({}, headers)
        end)
        
        it("should generate sentry-trace header", function()
            local context = propagation.create_context({
                trace_id = "1234567890abcdef1234567890abcdef",
                span_id = "abcdef1234567890",
                sampled = true
            })
            propagation.set_current_context(context)
            
            local headers = propagation.get_trace_headers_for_request()
            
            assert.is_not_nil(headers["sentry-trace"])
            assert.is_true(headers["sentry-trace"]:find("1234567890abcdef1234567890abcdef") ~= nil)
        end)
        
        it("should include baggage header when baggage exists", function()
            local context = propagation.create_context(nil, {
                key1 = "value1",
                key2 = "value2"
            })
            propagation.set_current_context(context)
            
            local headers = propagation.get_trace_headers_for_request()
            
            assert.is_not_nil(headers["baggage"])
            assert.is_true(headers["baggage"]:find("key1=value1") ~= nil)
        end)
        
        it("should include traceparent when requested", function()
            local context = propagation.create_context({
                trace_id = "1234567890abcdef1234567890abcdef",
                span_id = "abcdef1234567890",
                sampled = true
            })
            propagation.set_current_context(context)
            
            local headers = propagation.get_trace_headers_for_request(nil, {
                include_traceparent = true
            })
            
            assert.is_not_nil(headers["traceparent"])
            assert.is_true(headers["traceparent"]:find("1234567890abcdef1234567890abcdef") ~= nil)
        end)
        
        it("should respect trace propagation targets", function()
            local context = propagation.create_context()
            propagation.set_current_context(context)
            
            local headers = propagation.get_trace_headers_for_request("https://example.com", {
                trace_propagation_targets = {"notexample%.com"}
            })
            
            assert.same({}, headers) -- Should not propagate to non-matching targets
        end)
        
        it("should propagate to matching targets", function()
            local context = propagation.create_context()
            propagation.set_current_context(context)
            
            local headers = propagation.get_trace_headers_for_request("https://example.com", {
                trace_propagation_targets = {"example%.com"}
            })
            
            assert.is_not_nil(headers["sentry-trace"]) -- Should propagate to matching targets
        end)
    end)
    
    describe("get_trace_context_for_event", function()
        it("should return nil when no context", function()
            local trace_context = propagation.get_trace_context_for_event()
            assert.is_nil(trace_context)
        end)
        
        it("should return trace context for events", function()
            local context = propagation.create_context({
                trace_id = "1234567890abcdef1234567890abcdef",
                span_id = "abcdef1234567890",
                sampled = true
            })
            propagation.set_current_context(context)
            
            local trace_context = propagation.get_trace_context_for_event()
            
            assert.equal("1234567890abcdef1234567890abcdef", trace_context.trace_id)
            assert.equal("abcdef1234567890", trace_context.parent_span_id) -- Parent from incoming
            assert.is_not_nil(trace_context.span_id)
        end)
    end)
    
    describe("start_new_trace", function()
        it("should start new trace and set as current", function()
            local context = propagation.start_new_trace()
            
            assert.is_not_nil(context.trace_id)
            assert.is_not_nil(context.span_id)
            assert.is_nil(context.parent_span_id)
            assert.is_nil(context.sampled) -- Deferred sampling
            
            assert.equal(context, propagation.get_current_context())
        end)
        
        it("should include baggage options", function()
            local options = {
                baggage = {
                    key1 = "value1"
                }
            }
            
            local context = propagation.start_new_trace(options)
            
            assert.equal("value1", context.baggage.key1)
        end)
    end)
    
    describe("create_child_context", function()
        it("should create child from current context", function()
            local parent_context = propagation.create_context({
                trace_id = "1234567890abcdef1234567890abcdef",
                span_id = "abcdef1234567890",
                sampled = true
            })
            propagation.set_current_context(parent_context)
            
            local child_context = propagation.create_child_context()
            
            assert.equal(parent_context.trace_id, child_context.trace_id) -- Same trace ID
            assert.equal(parent_context.span_id, child_context.parent_span_id) -- Parent span ID
            assert.is_not_equal(parent_context.span_id, child_context.span_id) -- Different span ID
            assert.equal(parent_context.sampled, child_context.sampled) -- Same sampling decision
        end)
        
        it("should start new trace when no parent context", function()
            local child_context = propagation.create_child_context()
            
            assert.is_not_nil(child_context.trace_id)
            assert.is_not_nil(child_context.span_id)
            assert.is_nil(child_context.parent_span_id)
        end)
    end)
    
    describe("utility functions", function()
        describe("is_tracing_enabled", function()
            it("should return false when no context", function()
                assert.equal(false, propagation.is_tracing_enabled())
            end)
            
            it("should return true when context exists", function()
                local context = propagation.create_context()
                propagation.set_current_context(context)
                
                assert.equal(true, propagation.is_tracing_enabled())
            end)
        end)
        
        describe("get_current_trace_id", function()
            it("should return nil when no context", function()
                assert.is_nil(propagation.get_current_trace_id())
            end)
            
            it("should return trace ID when context exists", function()
                local context = propagation.create_context({
                    trace_id = "1234567890abcdef1234567890abcdef",
                    span_id = "abcdef1234567890"
                })
                propagation.set_current_context(context)
                
                assert.equal("1234567890abcdef1234567890abcdef", propagation.get_current_trace_id())
            end)
        end)
        
        describe("get_current_span_id", function()
            it("should return nil when no context", function()
                assert.is_nil(propagation.get_current_span_id())
            end)
            
            it("should return span ID when context exists", function()
                local context = propagation.create_context()
                propagation.set_current_context(context)
                
                local span_id = propagation.get_current_span_id()
                assert.is_not_nil(span_id)
                assert.equal(16, #span_id) -- Should be 16 hex characters
            end)
        end)
    end)
    
    describe("get_dynamic_sampling_context", function()
        it("should return nil when no context", function()
            assert.is_nil(propagation.get_dynamic_sampling_context())
        end)
        
        it("should return DSC when context exists", function()
            local context = propagation.create_context()
            propagation.set_current_context(context)
            
            local dsc = propagation.get_dynamic_sampling_context()
            
            assert.is_not_nil(dsc)
            assert.equal(context.trace_id, dsc["sentry-trace_id"])
        end)
        
        it("should return copy of DSC to avoid mutations", function()
            local context = propagation.create_context()
            propagation.set_current_context(context)
            
            local dsc1 = propagation.get_dynamic_sampling_context()
            local dsc2 = propagation.get_dynamic_sampling_context()
            
            assert.is_not_equal(dsc1, dsc2) -- Should be different table instances
            assert.same(dsc1, dsc2) -- But with same content
        end)
    end)
end)