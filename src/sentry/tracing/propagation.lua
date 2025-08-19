---@class sentry.tracing.propagation
--- Core tracing propagation context implementation
--- Implements "Tracing without Performance" (TwP) mode by default
--- Handles trace continuation from incoming headers and propagation to outgoing requests

local propagation = {}

local headers = require("sentry.tracing.headers")
local utils = require("sentry.utils")

---@class PropagationContext
---@field trace_id string The trace ID (32 hex characters)
---@field span_id string The current span ID (16 hex characters)  
---@field parent_span_id string? The parent span ID
---@field sampled boolean? The sampling decision (nil = deferred)
---@field baggage table? Baggage data for additional context
---@field dynamic_sampling_context table? Dynamic sampling context

---Default propagation context (used when no trace is active)
---@type PropagationContext
local default_context = {
    trace_id = nil,
    span_id = nil,
    parent_span_id = nil,
    sampled = nil,
    baggage = {},
    dynamic_sampling_context = {}
}

-- Current propagation context (stored per scope)
local current_context = nil

---Initialize a new propagation context
---@param trace_data table? Optional incoming trace data from headers
---@param baggage_data table? Optional baggage data
---@return PropagationContext context New propagation context
function propagation.create_context(trace_data, baggage_data)
    local context = {}
    
    if trace_data then
        -- Continue incoming trace
        context.trace_id = trace_data.trace_id
        context.parent_span_id = trace_data.span_id
        context.span_id = headers.generate_span_id() -- Generate new span ID
        context.sampled = trace_data.sampled
    else
        -- Start new trace (TwP mode - defer sampling decision)
        context.trace_id = headers.generate_trace_id()
        context.span_id = headers.generate_span_id()
        context.parent_span_id = nil
        context.sampled = nil -- Deferred sampling decision
    end
    
    context.baggage = baggage_data or {}
    context.dynamic_sampling_context = {}
    
    -- Populate dynamic sampling context lazily
    propagation.populate_dynamic_sampling_context(context)
    
    return context
end

---Populate dynamic sampling context (DSC) for the trace
---@param context PropagationContext The propagation context to populate
function propagation.populate_dynamic_sampling_context(context)
    if not context or not context.trace_id then
        return
    end

    local dsc = context.dynamic_sampling_context
    
    -- Add trace ID to DSC
    dsc["sentry-trace_id"] = context.trace_id
    
    -- Add public key (would come from SDK configuration)
    -- dsc["sentry-public_key"] = sdk_config.public_key
    
    -- Add environment if available
    -- dsc["sentry-environment"] = sdk_config.environment
    
    -- Add release if available  
    -- dsc["sentry-release"] = sdk_config.release
    
    -- Note: We don't add sentry-sampled in TwP mode since sampling is deferred
    -- This will be added when regular tracing (with spans) is enabled
end

---Get the current propagation context
---@return PropagationContext? context Current propagation context or nil
function propagation.get_current_context()
    return current_context
end

---Set the current propagation context
---@param context PropagationContext? The propagation context to set
function propagation.set_current_context(context)
    current_context = context
end

---Continue trace from incoming HTTP headers
---@param http_headers table HTTP headers from incoming request
---@return PropagationContext context New propagation context continuing the trace
function propagation.continue_trace_from_headers(http_headers)
    local trace_info = headers.extract_trace_headers(http_headers)
    
    local trace_data = nil
    local baggage_data = trace_info.baggage or {}
    
    -- Priority: sentry-trace > traceparent (W3C)
    if trace_info.sentry_trace then
        trace_data = trace_info.sentry_trace
    elseif trace_info.traceparent then
        -- Parse W3C traceparent: 00-{trace_id}-{span_id}-{flags}
        local version, trace_id, span_id, flags = trace_info.traceparent:match("^([0-9a-fA-F][0-9a-fA-F])%-([0-9a-fA-F]+)%-([0-9a-fA-F]+)%-([0-9a-fA-F][0-9a-fA-F])$")
        if version == "00" and trace_id and span_id and #trace_id == 32 and #span_id == 16 then
            trace_data = {
                trace_id = trace_id,
                span_id = span_id,
                sampled = (tonumber(flags, 16) or 0) > 0 and true or nil
            }
        end
    end
    
    local context = propagation.create_context(trace_data, baggage_data)
    propagation.set_current_context(context)
    
    return context
end

---Get trace headers for outgoing HTTP requests  
---@param target_url string? Optional target URL for trace propagation targeting
---@param options table? Options for header generation
---@return table headers HTTP headers to add to outgoing request
function propagation.get_trace_headers_for_request(target_url, options)
    local context = propagation.get_current_context()
    if not context then
        return {}
    end
    
    options = options or {}
    local result_headers = {}
    
    -- Check trace propagation targets (simplified - would use real target matching)
    local should_propagate = true
    if options.trace_propagation_targets then
        should_propagate = false
        for _, target in ipairs(options.trace_propagation_targets) do
            if target_url and target_url:match(target) then
                should_propagate = true
                break
            end
        end
    end
    
    if not should_propagate then
        return {}
    end
    
    -- Generate trace data for propagation
    local trace_data = {
        trace_id = context.trace_id,
        span_id = context.span_id,
        sampled = context.sampled
    }
    
    -- Inject headers
    headers.inject_trace_headers(result_headers, trace_data, context.baggage, {
        include_traceparent = options.include_traceparent
    })
    
    return result_headers
end

---Create trace context for attaching to events
---@return table? trace_context Trace context for event.contexts.trace or nil
function propagation.get_trace_context_for_event()
    local context = propagation.get_current_context()
    if not context or not context.trace_id then
        return nil
    end
    
    return {
        trace_id = context.trace_id,
        span_id = context.span_id,
        parent_span_id = context.parent_span_id,
        -- Note: In TwP mode, we don't have actual span data like op, description, etc.
    }
end

---Get dynamic sampling context for envelope headers
---@return table? dsc Dynamic sampling context or nil
function propagation.get_dynamic_sampling_context()
    local context = propagation.get_current_context()
    if not context or not context.dynamic_sampling_context then
        return nil
    end
    
    -- Return copy to avoid mutations
    local dsc = {}
    for k, v in pairs(context.dynamic_sampling_context) do
        dsc[k] = v
    end
    
    return dsc
end

---Start a new trace (reset propagation context)
---@param options table? Options for the new trace
---@return PropagationContext context New propagation context
function propagation.start_new_trace(options)
    options = options or {}
    
    local context = propagation.create_context(nil, options.baggage)
    propagation.set_current_context(context)
    
    return context
end

---Clear current propagation context
function propagation.clear_context()
    current_context = nil
end

---Create a child context (for creating child spans/operations)
---@param options table? Options for the child context
---@return PropagationContext context New child propagation context
function propagation.create_child_context(options)
    local parent_context = propagation.get_current_context()
    if not parent_context then
        -- No parent context, start new trace
        return propagation.start_new_trace(options)
    end
    
    options = options or {}
    
    local child_context = {
        trace_id = parent_context.trace_id,
        span_id = headers.generate_span_id(), -- New span ID for child
        parent_span_id = parent_context.span_id,
        sampled = parent_context.sampled,
        baggage = parent_context.baggage,
        dynamic_sampling_context = parent_context.dynamic_sampling_context
    }
    
    return child_context
end

---Check if tracing is enabled (has active trace context)
---@return boolean enabled True if tracing context is active
function propagation.is_tracing_enabled()
    local context = propagation.get_current_context()
    return context ~= nil and context.trace_id ~= nil
end

---Get trace ID from current context
---@return string? trace_id Current trace ID or nil
function propagation.get_current_trace_id()
    local context = propagation.get_current_context()
    return context and context.trace_id or nil
end

---Get span ID from current context  
---@return string? span_id Current span ID or nil
function propagation.get_current_span_id()
    local context = propagation.get_current_context()
    return context and context.span_id or nil
end

return propagation