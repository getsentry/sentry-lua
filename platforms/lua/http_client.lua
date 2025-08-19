---@class platforms.lua.http_client
--- HTTP client integrations for standard Lua with popular HTTP libraries
--- Provides automatic trace header injection for outgoing requests

local http_client = {}

local tracing = require("sentry.tracing")

---LuaSocket HTTP client integration
---@class LuaSocketIntegration
local luasocket = {}

---Wrap LuaSocket http.request function with tracing
---@param http_module table The LuaSocket http module
---@return table wrapped_module Wrapped http module with tracing
function luasocket.wrap_http_module(http_module)
    if not http_module or not http_module.request then
        error("Invalid LuaSocket http module - missing request function")
    end
    
    local original_request = http_module.request
    
    -- Wrap the request function
    http_module.request = function(url_or_options, body)
        local url, options
        
        -- Handle both forms: request(url, body) and request(options_table)
        if type(url_or_options) == "string" then
            url = url_or_options
            options = { url = url, source = body }
        else
            options = url_or_options or {}
            url = options.url
        end
        
        -- Add trace headers
        if url and tracing.is_active() then
            options.headers = options.headers or {}
            local trace_headers = tracing.get_request_headers(url)
            for key, value in pairs(trace_headers) do
                options.headers[key] = value
            end
        end
        
        -- Call original request function
        if type(url_or_options) == "string" then
            return original_request(options, body)
        else
            return original_request(options)
        end
    end
    
    return http_module
end

---lua-http client integration
---@class LuaHttpIntegration  
local lua_http = {}

---Wrap lua-http request object with tracing
---@param http_request table The lua-http request object
---@return table wrapped_request Wrapped request object with tracing
function lua_http.wrap_request(http_request)
    if not http_request or not http_request.get_headers_as_sequence then
        error("Invalid lua-http request object")
    end
    
    -- Store original go method
    local original_go = http_request.go
    
    http_request.go = function(self, ...)
        -- Add trace headers before sending
        if tracing.is_active() then
            local url = self:get_uri()
            local trace_headers = tracing.get_request_headers(url)
            
            for key, value in pairs(trace_headers) do
                self:append_header(key, value)
            end
        end
        
        return original_go(self, ...)
    end
    
    return http_request
end

---Generic HTTP client wrapper that works with function-based clients
---@param http_client_func function HTTP client function (url, options) -> response
---@return function wrapped_client Wrapped HTTP client with tracing
function http_client.wrap_generic_client(http_client_func)
    return function(url, options)
        return tracing.wrap_http_request(http_client_func, url, options)
    end
end

---LuaSocket integration functions
http_client.luasocket = luasocket

---lua-http integration functions
http_client.lua_http = lua_http

---Auto-detection and wrapping of common HTTP clients
---@param http_module table The HTTP module to wrap
---@return table wrapped_module Wrapped HTTP module
function http_client.auto_wrap(http_module)
    if not http_module then
        return http_module
    end
    
    -- Detect LuaSocket http module
    if http_module.request and type(http_module.request) == "function" then
        return luasocket.wrap_http_module(http_module)
    end
    
    -- Detect lua-http request object
    if http_module.get_headers_as_sequence and http_module.go then
        return lua_http.wrap_request(http_module)
    end
    
    -- Return unwrapped if not recognized
    return http_module
end

---Create a simple HTTP GET function with tracing support
---@param http_lib string? HTTP library to use ("luasocket", "lua-http", or auto-detect)
---@return function get_func HTTP GET function with tracing
function http_client.create_get_function(http_lib)
    http_lib = http_lib or "luasocket"
    
    if http_lib == "luasocket" then
        local http = require("socket.http")
        local wrapped_http = luasocket.wrap_http_module(http)
        
        return function(url, headers)
            local options = {
                url = url,
                headers = headers or {}
            }
            local body, status, response_headers = wrapped_http.request(options)
            return {
                body = body,
                status = status,
                headers = response_headers
            }
        end
    end
    
    error("Unsupported HTTP library: " .. tostring(http_lib))
end

---Create a traced HTTP request function that can be used with any HTTP library
---@param make_request function Function that takes (url, options) and returns response
---@return function traced_request Function with automatic trace header injection
function http_client.create_traced_request(make_request)
    if type(make_request) ~= "function" then
        error("make_request must be a function")
    end
    
    return function(url, options)
        return tracing.wrap_http_request(make_request, url, options)
    end
end

---Middleware function for adding tracing to any HTTP client
---@param client_function function The original HTTP client function
---@param extract_url function? Optional function to extract URL from arguments
---@return function middleware_function Wrapped function with tracing
function http_client.create_middleware(client_function, extract_url)
    if type(client_function) ~= "function" then
        error("client_function must be a function")
    end
    
    extract_url = extract_url or function(args) return args[1] end
    
    return function(...)
        local args = {...}
        local url = extract_url(args)
        
        if url and tracing.is_active() then
            -- Modify headers in the arguments
            -- This is library-specific and would need customization
            local trace_headers = tracing.get_request_headers(url)
            
            -- Try to find headers in arguments
            -- Check if first argument has headers (config object pattern)
            if args[1] and type(args[1]) == "table" and args[1].headers then
                args[1].headers = args[1].headers or {}
                for key, value in pairs(trace_headers) do
                    args[1].headers[key] = value
                end
            -- Check if second argument contains headers (url, options pattern)
            elseif args[2] and type(args[2]) == "table" then
                args[2].headers = args[2].headers or {}
                for key, value in pairs(trace_headers) do
                    args[2].headers[key] = value
                end
            end
        end
        
        return client_function((table.unpack or unpack)(args))
    end
end

return http_client