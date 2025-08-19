local tracing = require("sentry.tracing")
local http_client = require("platforms.lua.http_client")
local http_server = require("platforms.lua.http_server")

describe("HTTP Integration Tests", function()
    before_each(function()
        tracing.clear()
    end)
    
    after_each(function()
        tracing.clear()
    end)
    
    describe("HTTP Client Integration", function()
        describe("wrap_generic_client", function()
            it("should add trace headers to outgoing requests", function()
                tracing.start_trace()
                
                local mock_client = function(url, options)
                    return {
                        url = url,
                        headers_sent = options.headers or {}
                    }
                end
                
                local wrapped_client = http_client.wrap_generic_client(mock_client)
                local result = wrapped_client("https://example.com", {method = "GET"})
                
                assert.equal("https://example.com", result.url)
                assert.is_not_nil(result.headers_sent["sentry-trace"])
            end)
            
            it("should not add headers when tracing is inactive", function()
                tracing.clear()
                
                local mock_client = function(url, options)
                    return {headers_sent = options.headers or {}}
                end
                
                local wrapped_client = http_client.wrap_generic_client(mock_client)
                local result = wrapped_client("https://example.com")
                
                assert.is_nil(result.headers_sent["sentry-trace"])
            end)
        end)
        
        describe("luasocket integration", function()
            it("should wrap LuaSocket http module", function()
                local mock_http = {
                    request = function(url_or_options, body)
                        if type(url_or_options) == "string" then
                            return "response", 200, {}
                        else
                            return "response", 200, url_or_options.headers or {}
                        end
                    end
                }
                
                tracing.start_trace()
                local wrapped_http = http_client.luasocket.wrap_http_module(mock_http)
                
                -- Test string URL format
                local body, status, headers = wrapped_http.request("https://example.com")
                assert.equal("response", body)
                assert.equal(200, status)
                
                -- Test options table format  
                local body2, status2, headers2 = wrapped_http.request({
                    url = "https://example.com",
                    headers = {}
                })
                assert.equal("response", body2)
                assert.is_not_nil(headers2["sentry-trace"])
            end)
            
            it("should error for invalid http module", function()
                assert.has_error(function()
                    http_client.luasocket.wrap_http_module({})
                end)
            end)
        end)
        
        describe("lua-http integration", function()
            it("should wrap lua-http request object", function()
                local headers_added = {}
                
                local mock_request = {
                    get_headers_as_sequence = function() return {} end,
                    get_uri = function() return "https://example.com" end,
                    append_header = function(self, key, value)
                        headers_added[key] = value
                    end,
                    go = function(self)
                        return "response"
                    end
                }
                
                tracing.start_trace()
                local wrapped_request = http_client.lua_http.wrap_request(mock_request)
                local result = wrapped_request:go()
                
                assert.equal("response", result)
                assert.is_not_nil(headers_added["sentry-trace"])
            end)
            
            it("should error for invalid request object", function()
                assert.has_error(function()
                    http_client.lua_http.wrap_request({})
                end, "Invalid lua-http request object")
            end)
        end)
        
        describe("create_traced_request", function()
            it("should create traced request function", function()
                local mock_request = function(url, options)
                    return {
                        url = url,
                        headers = options and options.headers or {}
                    }
                end
                
                tracing.start_trace()
                local traced_request = http_client.create_traced_request(mock_request)
                local result = traced_request("https://example.com", {method = "GET"})
                
                assert.equal("https://example.com", result.url)
                assert.is_not_nil(result.headers["sentry-trace"])
            end)
            
            it("should error for non-function input", function()
                assert.has_error(function()
                    http_client.create_traced_request("not a function")
                end, "make_request must be a function")
            end)
        end)
        
        describe("create_middleware", function()
            it("should create middleware that adds trace headers", function()
                tracing.start_trace()
                
                local original_function = function(url, options)
                    return {
                        url = url,
                        headers = options and options.headers or {}
                    }
                end
                
                local middleware = http_client.create_middleware(original_function)
                local result = middleware("https://example.com", {headers = {}})
                
                assert.equal("https://example.com", result.url)
                assert.is_not_nil(result.headers["sentry-trace"])
            end)
            
            it("should use custom URL extractor", function()
                tracing.start_trace()
                
                local original_function = function(config)
                    return {
                        url = config.target,
                        headers = config.headers or {}
                    }
                end
                
                local extract_url = function(args)
                    return args[1].target
                end
                
                local middleware = http_client.create_middleware(original_function, extract_url)
                local result = middleware({
                    target = "https://example.com",
                    headers = {}
                })
                
                assert.is_not_nil(result.headers["sentry-trace"])
            end)
            
            it("should error for non-function client", function()
                assert.has_error(function()
                    http_client.create_middleware("not a function")
                end, "client_function must be a function")
            end)
        end)
    end)
    
    describe("HTTP Server Integration", function()
        describe("wrap_handler", function()
            it("should continue trace from request headers", function()
                local trace_info_captured = nil
                
                local handler = function(request, response)
                    trace_info_captured = tracing.get_current_trace_info()
                    return "handled"
                end
                
                local wrapped_handler = http_server.wrap_handler(handler)
                
                local mock_request = {
                    headers = {
                        ["sentry-trace"] = "1234567890abcdef1234567890abcdef-abcdef1234567890-1"
                    }
                }
                
                local result = wrapped_handler(mock_request, {})
                
                assert.equal("handled", result)
                assert.is_not_nil(trace_info_captured)
                assert.equal("1234567890abcdef1234567890abcdef", trace_info_captured.trace_id)
            end)
            
            it("should start new trace when no headers present", function()
                local trace_info_captured = nil
                
                local handler = function(request, response)
                    trace_info_captured = tracing.get_current_trace_info()
                end
                
                local wrapped_handler = http_server.wrap_handler(handler)
                wrapped_handler({headers = {}}, {})
                
                assert.is_not_nil(trace_info_captured)
                assert.is_not_nil(trace_info_captured.trace_id)
                assert.is_nil(trace_info_captured.parent_span_id) -- New trace
            end)
            
            it("should use custom header extractor", function()
                local trace_info_captured = nil
                
                local handler = function(request, response)
                    trace_info_captured = tracing.get_current_trace_info()
                end
                
                local extract_headers = function(request)
                    return request.custom_headers or {}
                end
                
                local wrapped_handler = http_server.wrap_handler(handler, extract_headers)
                
                local mock_request = {
                    custom_headers = {
                        ["sentry-trace"] = "1234567890abcdef1234567890abcdef-abcdef1234567890-1"
                    }
                }
                
                wrapped_handler(mock_request, {})
                
                assert.equal("1234567890abcdef1234567890abcdef", trace_info_captured.trace_id)
            end)
            
            it("should error for non-function handler", function()
                assert.has_error(function()
                    http_server.wrap_handler("not a function")
                end, "handler must be a function")
            end)
        end)
        
        describe("create_generic_middleware", function()
            it("should create middleware that continues traces", function()
                local trace_info_captured = nil
                
                local next_func = function()
                    trace_info_captured = tracing.get_current_trace_info()
                    return "next called"
                end
                
                local extract_headers = function(request)
                    return request.headers
                end
                
                local middleware = http_server.create_generic_middleware(extract_headers)
                
                local mock_request = {
                    headers = {
                        ["sentry-trace"] = "1234567890abcdef1234567890abcdef-abcdef1234567890-1"
                    }
                }
                
                local result = middleware(mock_request, {}, next_func)
                
                assert.equal("next called", result)
                assert.equal("1234567890abcdef1234567890abcdef", trace_info_captured.trace_id)
            end)
            
            it("should normalize header keys to lowercase", function()
                local trace_info_captured = nil
                
                local next_func = function()
                    trace_info_captured = tracing.get_current_trace_info()
                end
                
                local extract_headers = function(request)
                    return request.headers
                end
                
                local middleware = http_server.create_generic_middleware(extract_headers)
                
                local mock_request = {
                    headers = {
                        ["SENTRY-TRACE"] = "1234567890abcdef1234567890abcdef-abcdef1234567890-1"
                    }
                }
                
                middleware(mock_request, {}, next_func)
                
                assert.equal("1234567890abcdef1234567890abcdef", trace_info_captured.trace_id)
            end)
            
            it("should error for non-function extract_headers", function()
                assert.has_error(function()
                    http_server.create_generic_middleware("not a function")
                end, "extract_headers must be a function")
            end)
        end)
        
        describe("pegasus integration", function()
            it("should wrap pegasus server start method", function()
                local handler_called_with = nil
                
                local mock_server = {
                    start = function(self, handler)
                        handler_called_with = handler
                        return "server started"
                    end
                }
                
                local user_handler = function(request, response)
                    return "user handler result"
                end
                
                local wrapped_server = http_server.pegasus.wrap_server(mock_server)
                local result = wrapped_server:start(user_handler)
                
                assert.equal("server started", result)
                assert.is_not_nil(handler_called_with)
                assert.is_function(handler_called_with)
                assert.is_not_equal(user_handler, handler_called_with) -- Should be wrapped
            end)
            
            it("should create middleware for pegasus", function()
                local trace_info_captured = nil
                
                local middleware = http_server.pegasus.create_middleware()
                
                local next_func = function()
                    trace_info_captured = tracing.get_current_trace_info()
                end
                
                local mock_request = {
                    headers = {
                        ["sentry-trace"] = "1234567890abcdef1234567890abcdef-abcdef1234567890-1"
                    }
                }
                
                middleware(mock_request, {}, next_func)
                
                assert.equal("1234567890abcdef1234567890abcdef", trace_info_captured.trace_id)
            end)
        end)
    end)
    
    describe("End-to-End Integration", function()
        it("should propagate trace from server to client", function()
            -- Simulate incoming request with trace
            local incoming_headers = {
                ["sentry-trace"] = "1234567890abcdef1234567890abcdef-abcdef1234567890-1",
                ["baggage"] = "key1=value1,key2=value2"
            }
            
            -- Continue trace in server
            tracing.continue_trace_from_request(incoming_headers)
            
            -- Make outgoing request from server
            local outgoing_headers = tracing.get_request_headers("https://downstream.com")
            
            -- Verify trace propagation
            assert.is_not_nil(outgoing_headers["sentry-trace"])
            assert.is_not_nil(outgoing_headers["baggage"])
            
            -- Parse outgoing trace header
            local trace_data = tracing.headers.parse_sentry_trace(outgoing_headers["sentry-trace"])
            
            -- Should have same trace ID but different span ID
            assert.equal("1234567890abcdef1234567890abcdef", trace_data.trace_id)
            assert.is_not_equal("abcdef1234567890", trace_data.span_id) -- New span ID
            assert.equal(true, trace_data.sampled) -- Preserve sampling decision
        end)
        
        it("should create complete trace context for events", function()
            -- Start with incoming trace
            local incoming_headers = {
                ["sentry-trace"] = "1234567890abcdef1234567890abcdef-abcdef1234567890-1"
            }
            
            tracing.continue_trace_from_request(incoming_headers)
            
            -- Create error event
            local event = {
                type = "error",
                message = "Something went wrong"
            }
            
            -- Attach trace context
            local event_with_trace = tracing.attach_trace_context_to_event(event)
            
            -- Verify trace context
            assert.is_not_nil(event_with_trace.contexts)
            assert.is_not_nil(event_with_trace.contexts.trace)
            assert.equal("1234567890abcdef1234567890abcdef", event_with_trace.contexts.trace.trace_id)
            assert.equal("abcdef1234567890", event_with_trace.contexts.trace.parent_span_id)
            assert.is_not_nil(event_with_trace.contexts.trace.span_id)
        end)
        
        it("should handle TwP mode correctly", function()
            -- Start new trace (TwP mode - no spans, just trace propagation)
            tracing.start_trace()
            
            -- Get headers for outgoing request
            local headers = tracing.get_request_headers()
            
            -- Parse the trace header
            local trace_data = tracing.headers.parse_sentry_trace(headers["sentry-trace"])
            
            -- In TwP mode, sampled should be nil (deferred)
            assert.is_nil(trace_data.sampled)
            
            -- Should still propagate trace ID and span ID
            assert.is_not_nil(trace_data.trace_id)
            assert.is_not_nil(trace_data.span_id)
        end)
    end)
end)