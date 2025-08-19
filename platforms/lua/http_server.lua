---@class platforms.lua.http_server
--- HTTP server integrations for standard Lua with popular HTTP server libraries  
--- Provides automatic trace continuation from incoming request headers

local http_server = {}

local tracing = require("sentry.tracing")

---Pegasus.lua server integration
---@class PegasusIntegration
local pegasus = {}

---Wrap Pegasus server start method with tracing
---@param pegasus_server table The Pegasus server instance
---@return table wrapped_server Wrapped server instance with tracing
function pegasus.wrap_server(pegasus_server)
    if not pegasus_server or not pegasus_server.start then
        error("Invalid Pegasus server - missing start method")
    end
    
    local original_start = pegasus_server.start
    
    pegasus_server.start = function(self, handler_or_callback)
        local wrapped_handler
        
        if type(handler_or_callback) == "function" then
            -- Wrap the callback function
            wrapped_handler = function(request, response)
                -- Extract headers from Pegasus request object
                local request_headers = {}
                
                if request and request.headers then
                    -- Pegasus stores headers in request.headers() function
                    if type(request.headers) == "function" then
                        local headers = request:headers()
                        if headers then
                            for key, value in pairs(headers) do
                                request_headers[key:lower()] = value
                            end
                        end
                    elseif type(request.headers) == "table" then
                        -- Fallback for other servers that use table
                        for key, value in pairs(request.headers) do
                            request_headers[key:lower()] = value
                        end
                    end
                end
                
                -- Continue trace from request
                tracing.continue_trace_from_request(request_headers)
                
                -- Call original handler
                local success, result = pcall(handler_or_callback, request, response)
                
                if not success then
                    error(result)
                end
                
                return result
            end
        else
            wrapped_handler = handler_or_callback
        end
        
        return original_start(self, wrapped_handler)
    end
    
    return pegasus_server
end

---Create a Pegasus middleware function for tracing
---@return function middleware_function Pegasus middleware that continues traces
function pegasus.create_middleware()
    return function(request, response, next)
        -- Extract headers
        local request_headers = {}
        if request and request.headers then
            for key, value in pairs(request.headers) do
                request_headers[key:lower()] = value
            end
        end
        
        -- Continue trace
        tracing.continue_trace_from_request(request_headers)
        
        -- Call next middleware/handler
        if next then
            return next()
        end
    end
end

---lua-http server integration
---@class LuaHttpServerIntegration
local lua_http_server = {}

---Wrap lua-http server listen method with tracing
---@param server table The lua-http server instance
---@return table wrapped_server Wrapped server with tracing
function lua_http_server.wrap_server(server)
    if not server or not server.listen then
        error("Invalid lua-http server - missing listen method")
    end
    
    local original_listen = server.listen
    
    server.listen = function(self, handler)
        local wrapped_handler = function(stream)
            -- lua-http provides headers via stream:get_headers()
            local headers_sequence = stream:get_headers()
            local request_headers = {}
            
            if headers_sequence then
                -- Convert headers sequence to table
                for name, value in headers_sequence:each() do
                    request_headers[name:lower()] = value
                end
            end
            
            -- Continue trace
            tracing.continue_trace_from_request(request_headers)
            
            -- Call original handler
            return handler(stream)
        end
        
        return original_listen(self, wrapped_handler)
    end
    
    return server
end

---OpenResty/nginx-lua integration (for environments that support it)
---@class OpenRestyIntegration
local openresty = {}

---Wrap OpenResty handler with tracing
---@param handler function The OpenResty request handler
---@return function wrapped_handler Handler that continues traces
function openresty.wrap_handler(handler)
    return function(...)
        -- Extract headers from nginx request
        local request_headers = {}
        
        -- Check if we're in OpenResty environment
        if ngx and ngx.req and ngx.req.get_headers then
            local headers = ngx.req.get_headers()
            for key, value in pairs(headers) do
                request_headers[key:lower()] = value
            end
        end
        
        -- Continue trace
        tracing.continue_trace_from_request(request_headers)
        
        -- Call original handler
        return handler(...)
    end
end

---Generic HTTP server middleware creator
---@param extract_headers function Function that extracts headers from request object
---@return function middleware Middleware function for the specific server
function http_server.create_generic_middleware(extract_headers)
    if type(extract_headers) ~= "function" then
        error("extract_headers must be a function")
    end
    
    return function(request, response, next)
        local request_headers = extract_headers(request)
        
        -- Normalize headers to lowercase keys
        local normalized_headers = {}
        if request_headers then
            for key, value in pairs(request_headers) do
                if type(key) == "string" then
                    normalized_headers[key:lower()] = value
                end
            end
        end
        
        -- Continue trace
        tracing.continue_trace_from_request(normalized_headers)
        
        -- Call next if provided (middleware pattern)
        if next and type(next) == "function" then
            return next()
        end
    end
end

---Wrap any server handler function with tracing
---@param handler function The original handler function
---@param extract_headers function Function to extract headers from request
---@return function wrapped_handler Handler with tracing support
function http_server.wrap_handler(handler, extract_headers)
    if type(handler) ~= "function" then
        error("handler must be a function")
    end
    
    extract_headers = extract_headers or function(request)
        -- Default header extraction (works with many libraries)
        if request and request.headers then
            return request.headers
        end
        return {}
    end
    
    return function(request, response, ...)
        local request_headers = extract_headers(request)
        
        -- Normalize headers
        local normalized_headers = {}
        if request_headers then
            for key, value in pairs(request_headers) do
                if type(key) == "string" then
                    normalized_headers[key:lower()] = value
                end
            end
        end
        
        -- Continue trace
        tracing.continue_trace_from_request(normalized_headers)
        
        -- Call original handler
        return handler(request, response, ...)
    end
end

---Auto-detect and wrap server objects
---@param server table The server object to wrap
---@return table wrapped_server Wrapped server with tracing
function http_server.auto_wrap(server)
    if not server then
        return server
    end
    
    -- Detect Pegasus server
    if server.start and server.location then
        return pegasus.wrap_server(server)
    end
    
    -- Detect lua-http server
    if server.listen and server.bind then
        return lua_http_server.wrap_server(server)
    end
    
    -- Return unwrapped if not recognized
    return server
end

---Create a simple HTTP server with tracing support
---@param server_type string Server type ("pegasus", "lua-http")
---@param config table Server configuration
---@return table server Configured server with tracing
function http_server.create_server(server_type, config)
    config = config or {}
    
    if server_type == "pegasus" then
        local pegasus_lib = require("pegasus")
        local server = pegasus_lib:new(config)
        return pegasus.wrap_server(server)
    end
    
    error("Unsupported server type: " .. tostring(server_type))
end

-- Export integration modules
http_server.pegasus = pegasus
http_server.lua_http_server = lua_http_server
http_server.openresty = openresty

return http_server