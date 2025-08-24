local M = nil  -- will cache the chosen adapter

local function detect()
  -- Roblox: DateTime + HttpService/Game presence is a good signal
  if rawget(_G, "DateTime") and rawget(_G, "game") then
    return require("platforms.roblox")
  end

  -- Defold: global 'http' (http.request), 'sys' module, and go module exist
  if rawget(_G, "http") and rawget(_G, "sys") and rawget(_G, "go") then
    return require("platforms.defold")
  end

  -- LÖVE: global 'love' with version
  if rawget(_G, "love") and type(love) == "table" and love._version then
    return require("platforms.love2d")
  end

  -- Fallback to standard Lua
  return require("platforms.lua")
end

local function get()
  if not M then M = detect() end
  return M
end

return setmetatable({}, {
  __index = function(_, k) return get()[k] end, -- proxy functions/fields
  __call  = function() return get() end,        -- allow require(... )() to fetch table
})
