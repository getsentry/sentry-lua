local M = nil  -- will cache the chosen adapter

local function detect()
    -- OpenResty: ngx present with config
---@diagnostic disable-next-line: undefined-global
    if rawget(_G, "ngx") and ngx and ngx.config then
    return require("platforms.openresty")
    end
    -- Roblox: DateTime + HttpService/Game presence is a good signal
    if rawget(_G, "DateTime") and rawget(_G, "game") then
    return require("platforms.roblox")
    end

    -- Defold: global 'http' (http.request), 'sys' module, and go module exist
    if rawget(_G, "http") and rawget(_G, "sys") and rawget(_G, "go") then
    return require("platforms.defold")
    end

    -- LÖVE: global 'love' with version
    ---@diagnostic disable-next-line: undefined-global
    if rawget(_G, "love") and type(love) == "table" and love._version then
    return require("platforms.love2d")
    end

    -- Fallback to standard Lua
    return require("platforms.lua")
end

local function debug(err)
    print("Failed loading platform: " .. err)
---@diagnostic disable-next-line: undefined-global
    print(_VERSION, jit and jit.version or "no-jit")
    print("cwd:", (io.popen and io.popen("pwd"):read("*l")) or "")
    print("package.path =", package.path)
    print("package.cpath =", package.cpath)

    local ok1, ssl = pcall(require, "ssl")
    print("require ssl =", ok1, ok1 and (ssl._VERSION or "") or ssl)

    local ok2, https = pcall(require, "ssl.https")
    print("require ssl.https =", ok2, ok2 and "ok" or https)
end

local function get()
    if not M then 
        local ok, val = xpcall(detect, debug)
        if not ok then error("failed to load Sentry") end
        M = val
    end
    assert(M.http_post, "http_post missing on " .. M.name)
    assert(M.timestamp, "timestamp missing on " .. M.name)
    return M
end

return setmetatable({}, {
    __index = function(_, k) return get()[k] end, -- proxy functions/fields
    __call  = function() return get() end,        -- allow require(... )() to fetch table
})
