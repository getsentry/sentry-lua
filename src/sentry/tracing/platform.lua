---@class sentry.tracing.platform
--- Platform detection and initialization for distributed tracing
--- Automatically selects the appropriate platform implementation

local platform_module = {}

---Detected platform information
local detected_platform = nil
local current_platform = nil

---Detect current platform
---@return string platform_name The detected platform name
function platform_module.detect_platform()
    if detected_platform then
        return detected_platform
    end
    
    -- Check for Roblox environment
    if game and game.GetService then
        detected_platform = "roblox"
        return detected_platform
    end
    
    -- Check for OpenResty/nginx environment
    if ngx and ngx.req then
        detected_platform = "openresty"
        return detected_platform
    end
    
    -- Check for Redis environment (if running inside Redis)
    if redis and redis.call then
        detected_platform = "redis"
        return detected_platform
    end
    
    -- Check for Node.js-like environment (if running with lua-node or similar)
    if process and process.env then
        detected_platform = "nodejs"
        return detected_platform
    end
    
    -- Check Lua version for LuaJIT vs standard Lua
    local lua_version = _VERSION or ""
    if jit and jit.version then
        detected_platform = "luajit"
    elseif lua_version:find("Lua 5") then
        detected_platform = "lua"
    else
        detected_platform = "unknown"
    end
    
    return detected_platform
end

---Get platform implementation module
---@param platform_name string? Override platform detection
---@return table platform_impl Platform implementation module
function platform_module.get_platform_implementation(platform_name)
    platform_name = platform_name or platform_module.detect_platform()
    
    -- Map platform names to implementation modules
    local platform_map = {
        lua = "platforms.lua",
        luajit = "platforms.lua", -- LuaJIT uses same implementation as Lua
        openresty = "platforms.lua", -- OpenResty can use Lua implementation
        roblox = "platforms.noop", -- Not supported yet
        redis = "platforms.noop", -- Not supported yet  
        nodejs = "platforms.noop", -- Not supported yet
        unknown = "platforms.noop" -- Default to no-op
    }
    
    local module_name = platform_map[platform_name] or "platforms.noop"
    
    local success, platform_impl = pcall(require, module_name)
    if not success then
        -- Fallback to no-op implementation
        platform_impl = require("platforms.noop")
    end
    
    return platform_impl
end

---Initialize tracing for the current platform
---@param options table? Platform and tracing options
---@return table platform_impl The initialized platform implementation
function platform_module.init(options)
    options = options or {}
    
    -- Allow platform override
    local platform_name = options.platform or platform_module.detect_platform()
    
    -- Get platform implementation
    current_platform = platform_module.get_platform_implementation(platform_name)
    
    -- Initialize the platform
    current_platform.init(options)
    
    return current_platform
end

---Get current platform implementation
---@return table|nil platform_impl Current platform implementation or nil if not initialized
function platform_module.get_current_platform()
    return current_platform
end

---Check if tracing is supported on current platform
---@return boolean supported True if tracing is supported
function platform_module.is_tracing_supported()
    local platform_name = platform_module.detect_platform()
    return platform_name == "lua" or platform_name == "luajit" or platform_name == "openresty"
end

---Get platform information
---@return table info Platform detection and support information
function platform_module.get_platform_info()
    local platform_name = platform_module.detect_platform()
    local is_supported = platform_module.is_tracing_supported()
    
    local info = {
        detected_platform = platform_name,
        is_supported = is_supported,
        lua_version = _VERSION,
        runtime_info = {}
    }
    
    -- Add runtime-specific information
    if jit then
        info.runtime_info.jit = {
            version = jit.version,
            version_num = jit.version_num
        }
    end
    
    if ngx then
        info.runtime_info.openresty = {
            version = ngx.config and ngx.config.ngx_version
        }
    end
    
    if game then
        info.runtime_info.roblox = {
            version = "detected"
        }
    end
    
    -- Add current platform info if initialized
    if current_platform then
        info.current_platform = current_platform.get_info()
    end
    
    return info
end

---Auto-initialize tracing if supported
---@param options table? Auto-initialization options
---@return boolean initialized True if initialization was successful
function platform_module.auto_init(options)
    if not platform_module.is_tracing_supported() then
        return false
    end
    
    options = options or {}
    options.auto_instrument = options.auto_instrument ~= false -- Default to true
    
    platform_module.init(options)
    return true
end

---Create a tracing-enabled HTTP client
---@param client_type string? Type of HTTP client to create
---@return function|nil http_client HTTP client function or nil if not supported
function platform_module.create_http_client(client_type)
    if not current_platform then
        return nil
    end
    
    return current_platform.create_http_client(client_type)
end

---Create a tracing-enabled HTTP server
---@param server_type string Type of HTTP server to create
---@param config table? Server configuration
---@return table|nil http_server HTTP server object or nil if not supported  
function platform_module.create_http_server(server_type, config)
    if not current_platform then
        return nil
    end
    
    return current_platform.create_http_server(server_type, config)
end

---Instrument an existing HTTP client
---@param client table HTTP client to instrument
---@param client_type string? Type of client
---@return table instrumented_client Instrumented client (unchanged if not supported)
function platform_module.instrument_http_client(client, client_type)
    if not current_platform then
        return client
    end
    
    return current_platform.instrument_http_client(client, client_type)
end

---Instrument an existing HTTP server
---@param server table HTTP server to instrument
---@param server_type string? Type of server
---@return table instrumented_server Instrumented server (unchanged if not supported)
function platform_module.instrument_http_server(server, server_type)
    if not current_platform then
        return server
    end
    
    return current_platform.instrument_http_server(server, server_type)
end

---Create middleware for HTTP frameworks
---@param framework string Framework type
---@return function middleware Middleware function (no-op if not supported)
function platform_module.create_middleware(framework)
    if not current_platform then
        return function(request, response, next)
            if next then return next() end
        end
    end
    
    return current_platform.create_middleware(framework)
end

---Get tracing module (platform-specific or no-op)
---@return table tracing Tracing module
function platform_module.get_tracing()
    if current_platform then
        return current_platform.tracing
    else
        -- Return no-op tracing module
        local noop_platform = require("platforms.noop")
        return noop_platform.tracing
    end
end

return platform_module