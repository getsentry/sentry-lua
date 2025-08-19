---@class sentry.tracing
--- Main tracing module for Sentry Lua SDK
--- Provides distributed tracing functionality with "Tracing without Performance" (TwP) mode by default
--- Handles trace continuation, propagation, and integration with HTTP clients/servers

local tracing = {}

local headers = require("sentry.tracing.headers")
local propagation = require("sentry.tracing.propagation")

-- Re-export core functionality
tracing.headers = headers
tracing.propagation = propagation

---Configuration for tracing behavior
---@class TracingConfig
---@field trace_propagation_targets string[]? URL patterns for trace propagation
---@field include_traceparent boolean? Include W3C traceparent header for OpenTelemetry interop
---@field baggage_keys string[]? Keys to include in baggage propagation

---Initialize tracing for the SDK
---@param config TracingConfig? Optional tracing configuration
function tracing.init(config)
    config = config or {}
    
    -- Store config for later use
    tracing._config = config
    
    -- Initialize propagation context if not already present
    local current = propagation.get_current_context()
    if not current then
        propagation.start_new_trace()
    end
end

---Continue trace from incoming HTTP request headers
---This should be called at the beginning of request handling
---@param request_headers table HTTP headers from incoming request
---@return table trace_context The trace context created/continued
function tracing.continue_trace_from_request(request_headers)
    local context = propagation.continue_trace_from_headers(request_headers)
    
    -- Attach trace context to current scope for events
    local trace_context = propagation.get_trace_context_for_event()
    if trace_context then
        -- In a real implementation, this would integrate with the scope system
        -- sentry.get_current_scope():set_context("trace", trace_context)
    end
    
    return trace_context
end

---Get headers to add to outgoing HTTP requests
---This should be called before making outgoing HTTP requests
---@param target_url string? The URL being requested (for trace propagation targeting)
---@return table headers HTTP headers to add to the request
function tracing.get_request_headers(target_url)
    local config = tracing._config or {}
    
    local options = {
        trace_propagation_targets = config.trace_propagation_targets,
        include_traceparent = config.include_traceparent
    }
    
    return propagation.get_trace_headers_for_request(target_url, options)
end

---Start a new trace manually
---@param options table? Options for the new trace
---@return table trace_context The new trace context
function tracing.start_trace(options)
    local context = propagation.start_new_trace(options)
    return propagation.get_trace_context_for_event()
end

---Create a child span/operation (returns new context but doesn't change current)
---@param options table? Options for the child operation
---@return table child_context The child trace context
function tracing.create_child(options)
    local child_context = propagation.create_child_context(options)
    return {
        trace_id = child_context.trace_id,
        span_id = child_context.span_id,
        parent_span_id = child_context.parent_span_id
    }
end

---Get current trace information for debugging/logging
---@return table? trace_info Current trace information or nil if no active trace
function tracing.get_current_trace_info()
    local context = propagation.get_current_context()
    if not context then
        return nil
    end
    
    return {
        trace_id = context.trace_id,
        span_id = context.span_id,
        parent_span_id = context.parent_span_id,
        sampled = context.sampled,
        is_tracing_enabled = propagation.is_tracing_enabled()
    }
end

---Check if tracing is currently active
---@return boolean active True if tracing context is active
function tracing.is_active()
    return propagation.is_tracing_enabled()
end

---Clear current trace context
function tracing.clear()
    propagation.clear_context()
    tracing._config = nil
end

---Attach trace context to an event (for error reporting, etc.)
---@param event table The event to modify
---@return table event The modified event with trace context
function tracing.attach_trace_context_to_event(event)
    if not event or type(event) ~= "table" then
        return event
    end
    
    local trace_context = propagation.get_trace_context_for_event()
    if trace_context then
        event.contexts = event.contexts or {}
        event.contexts.trace = trace_context
    end
    
    return event
end

---Get dynamic sampling context for envelope headers
---@return table? dsc Dynamic sampling context for envelope header or nil
function tracing.get_envelope_trace_header()
    return propagation.get_dynamic_sampling_context()
end

---High-level wrapper for HTTP client requests with automatic header injection
---@param http_client function HTTP client function that accepts (url, options)
---@param url string The URL to request
---@param options table? Request options (headers will be merged)
---@return any result The result from the HTTP client function
function tracing.wrap_http_request(http_client, url, options)
    if type(http_client) ~= "function" then
        error("http_client must be a function")
    end
    
    options = options or {}
    options.headers = options.headers or {}
    
    -- Add trace headers to the request
    local trace_headers = tracing.get_request_headers(url)
    for key, value in pairs(trace_headers) do
        options.headers[key] = value
    end
    
    -- Call the original HTTP client function
    return http_client(url, options)
end

---High-level wrapper for HTTP server request handling with automatic trace continuation
---@param handler function Request handler function that accepts (request, response)
---@return function wrapped_handler Wrapped handler that continues traces
function tracing.wrap_http_handler(handler)
    if type(handler) ~= "function" then
        error("handler must be a function")
    end
    
    return function(request, response)
        -- Continue trace from request headers
        local request_headers = {}
        
        -- Extract headers from request object (format varies by HTTP library)
        if request and request.headers then
            request_headers = request.headers
        elseif request and request.get_header then
            -- Some libraries use methods to access headers
            request_headers["sentry-trace"] = request:get_header("sentry-trace")
            request_headers["baggage"] = request:get_header("baggage")
            request_headers["traceparent"] = request:get_header("traceparent")
        end
        
        -- Continue the trace
        tracing.continue_trace_from_request(request_headers)
        
        -- Store original context to restore later
        local original_context = propagation.get_current_context()
        
        local success, result = pcall(handler, request, response)
        
        -- Restore original context
        propagation.set_current_context(original_context)
        
        if not success then
            error(result)
        end
        
        return result
    end
end

---Utility function to generate new trace and span IDs
---@return table ids Table with trace_id and span_id
function tracing.generate_ids()
    return {
        trace_id = headers.generate_trace_id(),
        span_id = headers.generate_span_id()
    }
end

return tracing