---@class sentry.logger
--- Sentry logging module for structured log capture and transmission

local json = require("sentry.utils.json")
local envelope = require("sentry.utils.envelope") 
local utils = require("sentry.utils")

-- Type definitions for log records
local record LogLevel
    trace: string
    debug: string
    info: string
    warn: string
    error: string
    fatal: string
end

local record Attribute
    value: string | number | boolean | integer
    type: string
end

local record LogRecord
    timestamp: number
    trace_id: string
    level: string
    body: string
    attributes: {string: Attribute}
    severity_number: integer
end

local record LogBuffer
    logs: {LogRecord}
    max_size: integer
    flush_timeout: number
    last_flush: number
end

local record LoggerConfig
    enable_logs: boolean
    before_send_log: function(LogRecord): LogRecord
    max_buffer_size: integer
    flush_timeout: number
    hook_print: boolean
end

-- Log level to severity number mapping
local LOG_LEVELS: LogLevel = {
    trace = "trace",
    debug = "debug", 
    info = "info",
    warn = "warn",
    error = "error",
    fatal = "fatal"
}

local SEVERITY_NUMBERS = {
    trace = 1,
    debug = 5,
    info = 9,
    warn = 13,
    error = 17,
    fatal = 21
}

-- Module state
local logger = {}
local buffer: LogBuffer
local config: LoggerConfig
local original_print: function
local is_initialized = false

-- Initialize the logger with configuration
function logger.init(user_config: LoggerConfig)
    config = {
        enable_logs = user_config and user_config.enable_logs or false,
        before_send_log = user_config and user_config.before_send_log,
        max_buffer_size = user_config and user_config.max_buffer_size or 100,
        flush_timeout = user_config and user_config.flush_timeout or 5.0,
        hook_print = user_config and user_config.hook_print or false
    }
    
    buffer = {
        logs = {},
        max_size = config.max_buffer_size,
        flush_timeout = config.flush_timeout,
        last_flush = os.time()
    }
    
    is_initialized = true
    
    -- Hook into print if requested
    if config.hook_print then
        logger.hook_print()
    end
end

-- Get current trace context for log association
local function get_trace_context(): string, string
    local success, tracing = pcall(require, "sentry.tracing")
    if not success then
        return utils.generate_uuid():gsub("-", ""), nil
    end
    
    local trace_info = tracing.get_current_trace_info()
    if trace_info and trace_info.trace_id then
        return trace_info.trace_id, trace_info.span_id
    end
    
    return utils.generate_uuid():gsub("-", ""), nil
end

-- Get default attributes for a log record
local function get_default_attributes(parent_span_id: string): {string: Attribute}
    local attributes: {string: Attribute} = {}
    
    -- Get SDK info from central location
    local version_success, version = pcall(require, "sentry.version")
    local sdk_version = version_success and version or "unknown"
    
    attributes["sentry.sdk.name"] = {value = "sentry.lua", type = "string"}
    attributes["sentry.sdk.version"] = {value = sdk_version, type = "string"}
    
    -- Get Sentry client context if available
    local sentry_success, sentry = pcall(require, "sentry")
    if sentry_success and sentry._client and sentry._client.config then
        local client_config = sentry._client.config
        
        if client_config.environment then
            attributes["sentry.environment"] = {value = client_config.environment, type = "string"}
        end
        
        if client_config.release then
            attributes["sentry.release"] = {value = client_config.release, type = "string"}
        end
    end
    
    -- Add parent span ID if available
    if parent_span_id then
        attributes["sentry.trace.parent_span_id"] = {value = parent_span_id, type = "string"}
    end
    
    return attributes
end

-- Create a log record
local function create_log_record(level: string, body: string, template: string, params: {any}, extra_attributes: {string: any}): LogRecord
    if not config.enable_logs then
        return nil
    end
    
    local trace_id, parent_span_id = get_trace_context()
    local attributes = get_default_attributes(parent_span_id)
    
    -- Add template and parameters if provided
    if template then
        attributes["sentry.message.template"] = {value = template, type = "string"}
        
        if params then
            for i, param in ipairs(params) do
                local param_key = "sentry.message.parameter." .. tostring(i - 1)
                local param_type = type(param)
                
                if param_type == "number" then
                    if math.floor(param) == param then
                        attributes[param_key] = {value = param, type = "integer"}
                    else
                        attributes[param_key] = {value = param, type = "double"}
                    end
                elseif param_type == "boolean" then
                    attributes[param_key] = {value = param, type = "boolean"}
                else
                    attributes[param_key] = {value = tostring(param), type = "string"}
                end
            end
        end
    end
    
    -- Add extra attributes
    if extra_attributes then
        for key, value in pairs(extra_attributes) do
            local value_type = type(value)
            if value_type == "number" then
                if math.floor(value) == value then
                    attributes[key] = {value = value, type = "integer"}
                else
                    attributes[key] = {value = value, type = "double"}
                end
            elseif value_type == "boolean" then
                attributes[key] = {value = value, type = "boolean"}
            else
                attributes[key] = {value = tostring(value), type = "string"}
            end
        end
    end
    
    local record: LogRecord = {
        timestamp = os.time() + (os.clock() % 1),
        trace_id = trace_id,
        level = level,
        body = body,
        attributes = attributes,
        severity_number = SEVERITY_NUMBERS[level] or 9
    }
    
    return record
end

-- Add a log record to the buffer
local function add_to_buffer(record: LogRecord)
    if not record or not buffer then
        return
    end
    
    -- Apply before_send_log hook if configured
    if config.before_send_log then
        record = config.before_send_log(record)
        if not record then
            return  -- Log was filtered out
        end
    end
    
    table.insert(buffer.logs, record)
    
    -- Check if we need to flush
    local should_flush = false
    
    if #buffer.logs >= buffer.max_size then
        should_flush = true
    elseif buffer.flush_timeout > 0 then
        local current_time = os.time()
        if (current_time - buffer.last_flush) >= buffer.flush_timeout then
            should_flush = true
        end
    end
    
    if should_flush then
        logger.flush()
    end
end

-- Flush the log buffer
function logger.flush()
    if not buffer or #buffer.logs == 0 then
        return
    end
    
    -- Get Sentry client
    local sentry_success, sentry = pcall(require, "sentry")
    if not sentry_success or not sentry._client or not sentry._client.transport then
        -- Clear buffer even if we can't send
        buffer.logs = {}
        buffer.last_flush = os.time()
        return
    end
    
    -- Get version from central location
    local version_success, version = pcall(require, "sentry.version")
    local sdk_version = version_success and version or "unknown"
    
    -- Build log envelope using the proper log format
    local envelope_body = envelope.build_log_envelope(buffer.logs)
    
    -- Send via envelope transport only (no fallback to /store endpoint)
    if sentry._client.transport.send_envelope then
        local success, err = sentry._client.transport:send_envelope(envelope_body)
        if success then
            print("[Sentry] Sent " .. #buffer.logs .. " log records via envelope")
        else
            print("[Sentry] Failed to send log envelope: " .. tostring(err))
        end
    else
        print("[Sentry] No envelope transport available for logs")
    end
    
    -- Clear buffer
    buffer.logs = {}
    buffer.last_flush = os.time()
end

-- Core logging function
local function log(level: string, message: string, template: string, params: {any}, attributes: {string: any})
    if not is_initialized or not config.enable_logs then
        return
    end
    
    local record = create_log_record(level, message, template, params, attributes)
    if record then
        add_to_buffer(record)
    end
end

-- String formatting helper (similar to printf)
local function format_message(template: string, ...: any): string, {any}
    local args = {...}
    local formatted = template
    
    -- Simple %s replacement
    local i = 1
    formatted = formatted:gsub("%%s", function()
        local arg = args[i]
        i = i + 1
        return tostring(arg or "")
    end)
    
    return formatted, args
end

-- Public logging API functions
function logger.trace(message: string, params: {any}, attributes: {string: any})
    if type(message) == "string" and message:find("%%s") and params then
        local formatted, args = format_message(message, table.unpack(params))
        log("trace", formatted, message, args, attributes)
    else
        log("trace", message, nil, nil, attributes or params)
    end
end

function logger.debug(message: string, params: {any}, attributes: {string: any})
    if type(message) == "string" and message:find("%%s") and params then
        local formatted, args = format_message(message, table.unpack(params))
        log("debug", formatted, message, args, attributes)
    else
        log("debug", message, nil, nil, attributes or params)
    end
end

function logger.info(message: string, params: {any}, attributes: {string: any})
    if type(message) == "string" and message:find("%%s") and params then
        local formatted, args = format_message(message, table.unpack(params))
        log("info", formatted, message, args, attributes)
    else
        log("info", message, nil, nil, attributes or params)
    end
end

function logger.warn(message: string, params: {any}, attributes: {string: any})
    if type(message) == "string" and message:find("%%s") and params then
        local formatted, args = format_message(message, table.unpack(params))
        log("warn", formatted, message, args, attributes)
    else
        log("warn", message, nil, nil, attributes or params)
    end
end

function logger.error(message: string, params: {any}, attributes: {string: any})
    if type(message) == "string" and message:find("%%s") and params then
        local formatted, args = format_message(message, table.unpack(params))
        log("error", formatted, message, args, attributes)
    else
        log("error", message, nil, nil, attributes or params)
    end
end

function logger.fatal(message: string, params: {any}, attributes: {string: any})
    if type(message) == "string" and message:find("%%s") and params then
        local formatted, args = format_message(message, table.unpack(params))
        log("fatal", formatted, message, args, attributes)
    else
        log("fatal", message, nil, nil, attributes or params)
    end
end

-- Print hooking functionality
function logger.hook_print()
    if original_print then
        return  -- Already hooked
    end
    
    original_print = print
    
    -- Flag to prevent recursion
    local in_sentry_print = false
    
    _G.print = function(...: any)
        -- Call original print first
        original_print(...)
        
        -- Avoid recursion from Sentry's own print statements
        if in_sentry_print then
            return
        end
        
        if not is_initialized or not config.enable_logs then
            return
        end
        
        in_sentry_print = true
        
        -- Convert arguments to string
        local args = {...}
        local parts = {}
        for i, arg in ipairs(args) do
            parts[i] = tostring(arg)
        end
        local message = table.concat(parts, "\t")
        
        -- Create log record with sentry.origin
        local record = create_log_record("info", message, nil, nil, {
            ["sentry.origin"] = "auto.logging.print"
        })
        
        if record then
            add_to_buffer(record)
        end
        
        in_sentry_print = false
    end
end

function logger.unhook_print()
    if original_print then
        _G.print = original_print
        original_print = nil
    end
end

-- Get current configuration
function logger.get_config(): LoggerConfig
    return config
end

-- Get buffer status for debugging
function logger.get_buffer_status(): {string: any}
    if not buffer then
        return {logs = 0, max_size = 0, last_flush = 0}
    end
    
    return {
        logs = #buffer.logs,
        max_size = buffer.max_size,
        last_flush = buffer.last_flush
    }
end

return logger