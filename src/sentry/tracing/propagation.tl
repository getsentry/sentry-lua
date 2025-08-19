---@class sentry.tracing.propagation
--- Core tracing propagation context implementation
--- Implements "Tracing without Performance" (TwP) mode by default
--- Handles trace continuation from incoming headers and propagation to outgoing requests

local record PropagationContext
    trace_id: string
    span_id: string
    parent_span_id: string
    sampled: boolean
    baggage: {string: string}
    dynamic_sampling_context: {string: string}
end


local record TracePropagationOptions
    trace_propagation_targets: {string}
    include_traceparent: boolean
end

local record TraceOptions
    baggage: {string: string}
end

local record Propagation
    create_context: function(trace_data: TraceData, baggage_data: {string: string}): PropagationContext
    populate_dynamic_sampling_context: function(context: PropagationContext)
    get_current_context: function(): PropagationContext
    set_current_context: function(context: PropagationContext)
    continue_trace_from_headers: function(http_headers: {string: string}): PropagationContext
    get_trace_headers_for_request: function(target_url: string, options: TracePropagationOptions): {string: string}
    get_trace_context_for_event: function(): {string: any}
    get_dynamic_sampling_context: function(): {string: string}
    start_new_trace: function(options: TraceOptions): PropagationContext
    clear_context: function()
    create_child_context: function(options: TraceOptions): PropagationContext
    is_tracing_enabled: function(): boolean
    get_current_trace_id: function(): string
    get_current_span_id: function(): string
end

local propagation: Propagation = {}

local record TraceData
    trace_id: string
    span_id: string
    sampled: boolean
end

local headers = require("sentry.tracing.headers")

-- Current propagation context (stored per scope)
local current_context: PropagationContext = nil

---Initialize a new propagation context
---@param trace_data table? Optional incoming trace data from headers
---@param baggage_data table? Optional baggage data
---@return PropagationContext context New propagation context
function propagation.create_context(trace_data: TraceData, baggage_data: {string: string}): PropagationContext
    local context: PropagationContext = {
        trace_id = "",
        span_id = "",
        parent_span_id = nil,
        sampled = nil,
        baggage = {},
        dynamic_sampling_context = {}
    }
    
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
function propagation.populate_dynamic_sampling_context(context: PropagationContext)
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
function propagation.get_current_context(): PropagationContext
    return current_context
end

---Set the current propagation context
---@param context PropagationContext? The propagation context to set
function propagation.set_current_context(context: PropagationContext)
    current_context = context
end

---Continue trace from incoming HTTP headers
---@param http_headers table HTTP headers from incoming request
---@return PropagationContext context New propagation context continuing the trace
function propagation.continue_trace_from_headers(http_headers: {string: string}): PropagationContext
    local trace_info = headers.extract_trace_headers(http_headers)
    
    local trace_data: TraceData = nil
    local baggage_data = trace_info.baggage or {}
    
    -- Priority: sentry-trace > traceparent (W3C)
    if trace_info.sentry_trace then
        local sentry_trace_data = trace_info.sentry_trace
        trace_data = {
            trace_id = sentry_trace_data.trace_id,
            span_id = sentry_trace_data.span_id,
            sampled = sentry_trace_data.sampled
        }
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
function propagation.get_trace_headers_for_request(target_url: string, options: TracePropagationOptions): {string: string}
    local context = propagation.get_current_context()
    if not context then
        return {}
    end
    
    options = options or {}
    local result_headers: {string: string} = {}
    
    -- Check trace propagation targets (simplified - would use real target matching)
    local should_propagate = true
    if options.trace_propagation_targets then
        should_propagate = false
        for _, target in ipairs(options.trace_propagation_targets) do
            if target == "*" then
                -- Wildcard - propagate to all targets
                should_propagate = true
                break
            elseif target_url and target_url:find(target, 1, true) then
                -- Pattern match (supports Lua patterns like example%.com)
                should_propagate = true
                break
            end
        end
    end
    
    if not should_propagate then
        return {}
    end
    
    -- Generate trace data for propagation
    local trace_data: TraceData = {
        trace_id = context.trace_id,
        span_id = context.span_id,
        sampled = context.sampled
    }
    
    -- Inject headers (cast to headers TraceData type)
    local headers_trace_data = {
        trace_id = trace_data.trace_id,
        span_id = trace_data.span_id,
        sampled = trace_data.sampled
    }
    headers.inject_trace_headers(result_headers, headers_trace_data, context.baggage, {
        include_traceparent = options.include_traceparent
    })
    
    return result_headers
end

---Create trace context for attaching to events
---@return table? trace_context Trace context for event.contexts.trace or nil
function propagation.get_trace_context_for_event(): {string: any}
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
function propagation.get_dynamic_sampling_context(): {string: string}
    local context = propagation.get_current_context()
    if not context or not context.dynamic_sampling_context then
        return nil
    end
    
    -- Return copy to avoid mutations
    local dsc: {string: string} = {}
    for k, v in pairs(context.dynamic_sampling_context) do
        dsc[k] = v
    end
    
    return dsc
end

---Start a new trace (reset propagation context)
---@param options table? Options for the new trace
---@return PropagationContext context New propagation context
function propagation.start_new_trace(options: TraceOptions): PropagationContext
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
function propagation.create_child_context(options: TraceOptions): PropagationContext
    local parent_context = propagation.get_current_context()
    if not parent_context then
        -- No parent context, start new trace
        return propagation.start_new_trace(options)
    end
    
    options = options or {}
    
    local child_context: PropagationContext = {
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
function propagation.is_tracing_enabled(): boolean
    local context = propagation.get_current_context()
    return context ~= nil and context.trace_id ~= nil
end

---Get trace ID from current context
---@return string? trace_id Current trace ID or nil
function propagation.get_current_trace_id(): string
    local context = propagation.get_current_context()
    return context and context.trace_id or nil
end

---Get span ID from current context  
---@return string? span_id Current span ID or nil
function propagation.get_current_span_id(): string
    local context = propagation.get_current_context()
    return context and context.span_id or nil
end

return propagation