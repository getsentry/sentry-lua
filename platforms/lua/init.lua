---@class platforms.lua
--- Standard Lua and LuaJIT platform implementation for distributed tracing
--- Provides initialization and auto-detection of HTTP libraries

local platform = {}

local tracing = require("sentry.tracing")
local http_client = require("platforms.lua.http_client")
local http_server = require("platforms.lua.http_server")

---Platform configuration
platform.config = {
    name = "lua",
    version = _VERSION or "Unknown",
    auto_instrument = true,
    supported_libraries = {
        http_client = {"socket.http", "http.request"},
        http_server = {"pegasus", "http.server"}
    }
}

---Auto-instrumentation state
local auto_instrumentation_enabled = false
local instrumented_modules = {}

---Initialize platform-specific tracing features
---@param options table? Platform initialization options
function platform.init(options)
    options = options or {}
    
    -- Initialize core tracing
    tracing.init(options.tracing)
    
    -- Enable auto-instrumentation if requested
    if options.auto_instrument ~= false then
        platform.enable_auto_instrumentation()
    end
    
    -- Store platform-specific options
    platform._options = options
end

---Enable automatic instrumentation of HTTP libraries
function platform.enable_auto_instrumentation()
    if auto_instrumentation_enabled then
        return
    end
    
    auto_instrumentation_enabled = true
    
    -- Auto-instrument HTTP client libraries
    platform.auto_instrument_http_clients()
    
    -- Auto-instrument HTTP server libraries  
    platform.auto_instrument_http_servers()
end

---Disable automatic instrumentation
function platform.disable_auto_instrumentation()
    auto_instrumentation_enabled = false
    
    -- Restore original modules if they were instrumented
    for module_name, original_module in pairs(instrumented_modules) do
        package.loaded[module_name] = original_module
    end
    
    instrumented_modules = {}
end

---Auto-instrument HTTP client libraries
function platform.auto_instrument_http_clients()
    -- Instrument LuaSocket HTTP module when required
    local original_require = require
    
    require = function(module_name)
        local module = original_require(module_name)
        
        -- Instrument socket.http when loaded
        if module_name == "socket.http" and module and module.request then
            if not instrumented_modules[module_name] then
                instrumented_modules[module_name] = module
                module = http_client.luasocket.wrap_http_module(module)
                package.loaded[module_name] = module
            end
        end
        
        -- Instrument http.request (lua-http) when loaded
        if module_name == "http.request" and module and module.new then
            if not instrumented_modules[module_name] then
                instrumented_modules[module_name] = module
                
                -- Wrap the constructor to return wrapped request objects
                local original_new = module.new
                module.new = function(...)
                    local request = original_new(...)
                    return http_client.lua_http.wrap_request(request)
                end
                
                package.loaded[module_name] = module
            end
        end
        
        return module
    end
end

---Auto-instrument HTTP server libraries
function platform.auto_instrument_http_servers()
    local original_require = require
    
    require = function(module_name)
        local module = original_require(module_name)
        
        -- Instrument Pegasus when loaded
        if module_name == "pegasus" and module and module.new then
            if not instrumented_modules[module_name] then
                instrumented_modules[module_name] = module
                
                -- Wrap the constructor to return wrapped server objects
                local original_new = module.new
                module.new = function(...)
                    local server = original_new(...)
                    return http_server.pegasus.wrap_server(server)
                end
                
                package.loaded[module_name] = module
            end
        end
        
        return module
    end
end

---Manually instrument an HTTP client
---@param client table The HTTP client object or module
---@param client_type string? Type of client ("luasocket", "lua-http", or auto-detect)
---@return table instrumented_client Instrumented client
function platform.instrument_http_client(client, client_type)
    if not client then
        error("HTTP client is required")
    end
    
    client_type = client_type or "auto"
    
    if client_type == "auto" then
        return http_client.auto_wrap(client)
    elseif client_type == "luasocket" then
        return http_client.luasocket.wrap_http_module(client)
    elseif client_type == "lua-http" then
        return http_client.lua_http.wrap_request(client)
    else
        error("Unsupported HTTP client type: " .. tostring(client_type))
    end
end

---Manually instrument an HTTP server
---@param server table The HTTP server object
---@param server_type string? Type of server ("pegasus", "lua-http", or auto-detect)
---@return table instrumented_server Instrumented server
function platform.instrument_http_server(server, server_type)
    if not server then
        error("HTTP server is required")
    end
    
    server_type = server_type or "auto"
    
    if server_type == "auto" then
        return http_server.auto_wrap(server)
    elseif server_type == "pegasus" then
        return http_server.pegasus.wrap_server(server)
    elseif server_type == "lua-http" then
        return http_server.lua_http_server.wrap_server(server)
    else
        error("Unsupported HTTP server type: " .. tostring(server_type))
    end
end

---Create a traced HTTP client function
---@param client_type string? Type of client to create ("luasocket")
---@return function http_get HTTP GET function with tracing
function platform.create_http_client(client_type)
    client_type = client_type or "luasocket"
    
    return http_client.create_get_function(client_type)
end

---Create a traced HTTP server
---@param server_type string Type of server to create ("pegasus")
---@param config table? Server configuration
---@return table server HTTP server with tracing
function platform.create_http_server(server_type, config)
    return http_server.create_server(server_type, config)
end

---Wrap any function to continue traces from HTTP headers
---@param handler function The handler function to wrap
---@param extract_headers function? Custom header extraction function
---@return function wrapped_handler Handler with trace continuation
function platform.wrap_request_handler(handler, extract_headers)
    return http_server.wrap_handler(handler, extract_headers)
end

---Create middleware for popular frameworks
---@param framework string Framework type ("pegasus", "generic")
---@return function middleware Middleware function
function platform.create_middleware(framework)
    if framework == "pegasus" then
        return http_server.pegasus.create_middleware()
    elseif framework == "generic" then
        return http_server.create_generic_middleware(function(request)
            return request.headers or {}
        end)
    else
        error("Unsupported framework: " .. tostring(framework))
    end
end

---Get platform information
---@return table info Platform information
function platform.get_info()
    return {
        name = platform.config.name,
        version = platform.config.version,
        auto_instrumentation_enabled = auto_instrumentation_enabled,
        instrumented_modules = (function()
            local keys = {}
            for k, _ in pairs(instrumented_modules) do
                table.insert(keys, k)
            end
            return keys
        end)(),
        tracing_active = tracing.is_active(),
        supported_libraries = platform.config.supported_libraries
    }
end

---Check if a specific HTTP library is available
---@param library_name string Name of the library to check
---@return boolean available True if library is available
function platform.is_library_available(library_name)
    local success, _ = pcall(require, library_name)
    return success
end

---Get recommended HTTP client for this platform
---@return string|nil client_type Recommended HTTP client type or nil if none available
function platform.get_recommended_http_client()
    if platform.is_library_available("socket.http") then
        return "luasocket"
    elseif platform.is_library_available("http.request") then
        return "lua-http"
    end
    
    return nil
end

---Get recommended HTTP server for this platform
---@return string|nil server_type Recommended HTTP server type or nil if none available
function platform.get_recommended_http_server()
    if platform.is_library_available("pegasus") then
        return "pegasus"
    elseif platform.is_library_available("http.server") then
        return "lua-http"
    end
    
    return nil
end

-- Export core functionality for convenience
platform.tracing = tracing
platform.http_client = http_client
platform.http_server = http_server

return platform