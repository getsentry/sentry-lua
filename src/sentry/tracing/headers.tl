---@class sentry.tracing.headers
--- Core functionality for parsing and generating Sentry distributed tracing headers
--- Implements sentry-trace header format: {trace_id}-{span_id}-{sampled}
--- Supports both incoming trace continuation and outgoing trace propagation

local record TraceData
    trace_id: string
    span_id: string
    sampled: boolean
end


local record TraceInfo
    sentry_trace: TraceData
    baggage: {string: string}
    traceparent: string
end

local record InjectOptions
    include_traceparent: boolean
end

local record Headers
    parse_sentry_trace: function(header_value: string): TraceData
    generate_sentry_trace: function(trace_data: TraceData): string
    parse_baggage: function(header_value: string): {string: string}
    generate_baggage: function(baggage_data: {string: string}): string
    generate_trace_id: function(): string
    generate_span_id: function(): string
    extract_trace_headers: function(http_headers: {string: string}): TraceInfo
    inject_trace_headers: function(http_headers: {string: string}, trace_data: TraceData, baggage_data: {string: string}, options: InjectOptions)
end

local headers: Headers = {}

local utils = require("sentry.utils")

-- Constants for header parsing and validation
local TRACE_ID_LENGTH: number = 32 -- 128-bit trace ID as hex string
local SPAN_ID_LENGTH: number = 16  -- 64-bit span ID as hex string

---Parse sentry-trace header value
---@param header_value string? The sentry-trace header value
---@return table|nil trace_data Parsed trace data with trace_id, span_id, and sampled fields
function headers.parse_sentry_trace(header_value: string): TraceData
    if not header_value or type(header_value) ~= "string" then
        return nil
    end

    -- Remove whitespace
    local trimmed = header_value:match("^%s*(.-)%s*$")
    if not trimmed then
        return nil
    end
    header_value = trimmed
    
    if #header_value == 0 then
        return nil
    end

    -- Split by dashes: {trace_id}-{span_id}-{sampled}
    local parts: {string} = {}
    for part in header_value:gmatch("[^%-]+") do
        table.insert(parts, part)
    end

    -- Must have at least trace_id and span_id
    if #parts < 2 then
        return nil
    end

    local trace_id = parts[1]
    local span_id = parts[2]
    local sampled = parts[3] -- Optional

    -- Validate trace_id (32 hex characters)
    if not trace_id or #trace_id ~= TRACE_ID_LENGTH then
        return nil
    end
    
    if not trace_id:match("^[0-9a-fA-F]+$") then
        return nil
    end

    -- Validate span_id (16 hex characters)
    if not span_id or #span_id ~= SPAN_ID_LENGTH then
        return nil
    end
    
    if not span_id:match("^[0-9a-fA-F]+$") then
        return nil
    end

    -- Parse sampled flag (optional)
    local parsed_sampled: boolean = nil
    if sampled then
        if sampled == "1" then
            parsed_sampled = true
        elseif sampled == "0" then
            parsed_sampled = false
        else
            -- Invalid sampled value, ignore it (defer sampling decision)
            parsed_sampled = nil
        end
    end

    return {
        trace_id = trace_id:lower(), -- Normalize to lowercase
        span_id = span_id:lower(),
        sampled = parsed_sampled
    }
end

---Generate sentry-trace header value from trace data
---@param trace_data table Trace data with trace_id, span_id, and optional sampled fields
---@return string|nil header_value The sentry-trace header value or nil if invalid input
function headers.generate_sentry_trace(trace_data: TraceData): string
    if not trace_data or type(trace_data) ~= "table" then
        return nil
    end

    local trace_id = trace_data.trace_id
    local span_id = trace_data.span_id
    local sampled = trace_data.sampled

    -- Validate required fields
    if not trace_id or not span_id then
        return nil
    end

    -- Validate trace_id format
    if type(trace_id) ~= "string" or #trace_id ~= TRACE_ID_LENGTH then
        return nil
    end
    
    if not trace_id:match("^[0-9a-fA-F]+$") then
        return nil
    end

    -- Validate span_id format
    if type(span_id) ~= "string" or #span_id ~= SPAN_ID_LENGTH then
        return nil
    end
    
    if not span_id:match("^[0-9a-fA-F]+$") then
        return nil
    end

    -- Build header value
    local header_value = trace_id:lower() .. "-" .. span_id:lower()

    -- Add sampled flag if specified
    if sampled == true then
        header_value = header_value .. "-1"
    elseif sampled == false then
        header_value = header_value .. "-0"
    end
    -- If sampled is nil, defer sampling decision (no sampled flag)

    return header_value
end

---Parse baggage header value
---Baggage format: key1=value1,key2=value2,key3=value3;property=value
---@param header_value string? The baggage header value
---@return table baggage_data Parsed baggage data as key-value pairs
function headers.parse_baggage(header_value: string): {string: string}
    local baggage_data: {string: string} = {}
    
    if not header_value or type(header_value) ~= "string" then
        return baggage_data
    end

    -- Remove whitespace
    local trimmed = header_value:match("^%s*(.-)%s*$")
    if not trimmed then
        return baggage_data
    end
    header_value = trimmed
    
    if #header_value == 0 then
        return baggage_data
    end

    -- Split by comma to get individual baggage items
    for item in header_value:gmatch("[^,]+") do
        local trimmed_item = item:match("^%s*(.-)%s*$") -- Trim whitespace
        if trimmed_item then
            item = trimmed_item
        end
        
        -- Split by semicolon to separate key=value from properties
        local key_value_part = item:match("([^;]*)")
        if key_value_part then
            local trimmed_kvp = key_value_part:match("^%s*(.-)%s*$")
            if trimmed_kvp then
                key_value_part = trimmed_kvp
            end
            
            -- Split key=value
            local key, value = key_value_part:match("^([^=]+)=(.*)$")
            if key and value then
                local trimmed_key = key:match("^%s*(.-)%s*$") -- Trim key
                local trimmed_value = value:match("^%s*(.-)%s*$") -- Trim value
                
                -- URL decode if needed (basic implementation)
                if trimmed_key and trimmed_value and #trimmed_key > 0 then
                    baggage_data[trimmed_key] = trimmed_value
                end
            end
        end
    end

    return baggage_data
end

---Generate baggage header value from baggage data
---@param baggage_data table Baggage data as key-value pairs
---@return string|nil header_value The baggage header value or nil if empty
function headers.generate_baggage(baggage_data: {string: string}): string
    if not baggage_data or type(baggage_data) ~= "table" then
        return nil
    end

    local items: {string} = {}
    for key, value in pairs(baggage_data) do
        if type(key) == "string" and type(value) == "string" then
            -- Basic URL encoding for special characters
            local encoded_value = value:gsub("([,;=%%])", function(c: string): string
                return string.format("%%%02X", string.byte(c))
            end)
            
            table.insert(items, key .. "=" .. encoded_value)
        end
    end

    if #items == 0 then
        return nil
    end

    return table.concat(items, ",")
end

---Generate random trace ID (128-bit as 32 hex characters)
---@return string trace_id Random trace ID
function headers.generate_trace_id(): string
    local uuid_result = utils.generate_uuid():gsub("-", "")
    return uuid_result
end

---Generate random span ID (64-bit as 16 hex characters)  
---@return string span_id Random span ID
function headers.generate_span_id(): string
    local uuid_result = utils.generate_uuid():gsub("-", ""):sub(1, 16)
    return uuid_result
end

---Extract trace propagation headers from HTTP headers table
---@param http_headers table HTTP headers as key-value pairs (case-insensitive lookup)
---@return table trace_info Extracted trace information
function headers.extract_trace_headers(http_headers: {string: string}): TraceInfo
    if not http_headers or type(http_headers) ~= "table" then
        return {}
    end

    -- Case-insensitive header lookup
    local function get_header(name: string): string
        local name_lower = name:lower()
        for key, value in pairs(http_headers) do
            if type(key) == "string" and key:lower() == name_lower then
                return value
            end
        end
        return nil
    end

    local trace_info: TraceInfo = {}

    -- Extract sentry-trace header
    local sentry_trace = get_header("sentry-trace")
    if sentry_trace then
        trace_info.sentry_trace = headers.parse_sentry_trace(sentry_trace)
    end

    -- Extract baggage header
    local baggage = get_header("baggage")
    if baggage then
        trace_info.baggage = headers.parse_baggage(baggage)
    end

    -- Extract traceparent header (W3C Trace Context)
    local traceparent = get_header("traceparent")
    if traceparent then
        trace_info.traceparent = traceparent
    end

    return trace_info
end

---Inject trace propagation headers into HTTP headers table
---@param http_headers table HTTP headers table to modify
---@param trace_data table Trace data with trace_id, span_id, and optional sampled
---@param baggage_data table? Optional baggage data
---@param options table? Options for header injection
function headers.inject_trace_headers(http_headers: {string: string}, trace_data: TraceData, baggage_data: {string: string}, options: InjectOptions)
    if not http_headers or type(http_headers) ~= "table" then
        return
    end

    if not trace_data or type(trace_data) ~= "table" then
        return
    end

    options = options or {}

    -- Inject sentry-trace header
    local sentry_trace = headers.generate_sentry_trace(trace_data)
    if sentry_trace then
        http_headers["sentry-trace"] = sentry_trace
    end

    -- Inject baggage header if provided
    if baggage_data then
        local baggage = headers.generate_baggage(baggage_data)
        if baggage then
            http_headers["baggage"] = baggage
        end
    end

    -- Inject traceparent header if requested (for OpenTelemetry interop)
    if options.include_traceparent and trace_data.trace_id and trace_data.span_id then
        -- W3C traceparent format: 00-{trace_id}-{span_id}-{flags}
        local flags = "00" -- Default flags
        if trace_data.sampled == true then
            flags = "01"
        end
        
        http_headers["traceparent"] = "00-" .. trace_data.trace_id .. "-" .. trace_data.span_id .. "-" .. flags
    end
end

return headers