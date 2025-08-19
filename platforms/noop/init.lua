---@class platforms.noop
--- No-op platform implementation for unsupported platforms
--- Provides stub implementations that do nothing but don't error

local noop = {}

---Initialize no-op platform (does nothing)
---@param options table? Ignored options
function noop.init(options)
    -- Do nothing - tracing not supported on this platform
end

---No-op enable auto-instrumentation
function noop.enable_auto_instrumentation()
    -- Do nothing
end

---No-op disable auto-instrumentation  
function noop.disable_auto_instrumentation()
    -- Do nothing
end

---No-op HTTP client instrumentation
---@param client table The HTTP client (returned unchanged)
---@param client_type string? Ignored
---@return table client Unchanged client
function noop.instrument_http_client(client, client_type)
    return client
end

---No-op HTTP server instrumentation
---@param server table The HTTP server (returned unchanged)
---@param server_type string? Ignored
---@return table server Unchanged server
function noop.instrument_http_server(server, server_type)
    return server
end

---No-op HTTP client creation
---@param client_type string? Ignored
---@return function noop_client Function that returns empty table
function noop.create_http_client(client_type)
    return function(url, options)
        return {}
    end
end

---No-op HTTP server creation
---@param server_type string Ignored
---@param config table? Ignored
---@return table noop_server Empty server object
function noop.create_http_server(server_type, config)
    return {}
end

---No-op request handler wrapper
---@param handler function The handler (returned unchanged)
---@param extract_headers function? Ignored
---@return function handler Unchanged handler
function noop.wrap_request_handler(handler, extract_headers)
    return handler
end

---No-op middleware creation
---@param framework string Ignored
---@return function noop_middleware Middleware that does nothing
function noop.create_middleware(framework)
    return function(request, response, next)
        if next then
            return next()
        end
    end
end

---Get platform information
---@return table info Platform information indicating no-op mode
function noop.get_info()
    return {
        name = "noop",
        version = "1.0.0",
        auto_instrumentation_enabled = false,
        instrumented_modules = {},
        tracing_active = false,
        supported_libraries = {},
        reason = "Tracing not supported on this platform"
    }
end

---Check if library is available (always false for no-op)
---@param library_name string Ignored
---@return boolean available Always false
function noop.is_library_available(library_name)
    return false
end

---Get recommended HTTP client (always nil for no-op)
---@return string|nil client_type Always nil
function noop.get_recommended_http_client()
    return nil
end

---Get recommended HTTP server (always nil for no-op)
---@return string|nil server_type Always nil
function noop.get_recommended_http_server()
    return nil
end

-- Stub tracing module that does nothing
local noop_tracing = {
    init = function() end,
    continue_trace_from_request = function() return {} end,
    get_request_headers = function() return {} end,
    start_trace = function() return {} end,
    create_child = function() return {} end,
    get_current_trace_info = function() return nil end,
    is_active = function() return false end,
    clear = function() end,
    attach_trace_context_to_event = function(event) return event end,
    wrap_http_request = function(client, url, options) return client(url, options) end,
    wrap_http_handler = function(handler) return handler end,
    generate_ids = function() return {trace_id = "", span_id = ""} end,
    get_envelope_trace_header = function() return nil end
}

-- Stub HTTP modules
local noop_http_client = {
    wrap_generic_client = function(client) return client end,
    luasocket = {
        wrap_http_module = function(module) return module end
    },
    lua_http = {
        wrap_request = function(request) return request end
    },
    auto_wrap = function(module) return module end,
    create_get_function = function() return function() return {} end end,
    create_traced_request = function(make_request) return make_request end,
    create_middleware = function(client) return client end
}

local noop_http_server = {
    wrap_handler = function(handler) return handler end,
    create_generic_middleware = function() return function() end end,
    pegasus = {
        wrap_server = function(server) return server end,
        create_middleware = function() return function() end end
    },
    lua_http_server = {
        wrap_server = function(server) return server end
    },
    openresty = {
        wrap_handler = function(handler) return handler end
    },
    auto_wrap = function(server) return server end,
    create_server = function() return {} end
}

-- Export stub functionality
noop.tracing = noop_tracing
noop.http_client = noop_http_client  
noop.http_server = noop_http_server

return noop