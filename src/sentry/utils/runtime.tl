-- Runtime detection utility for different Lua environments

local record RuntimeInfo
   name: string
   version: string
   description: string
end

local function detect_standard_lua(): RuntimeInfo
   -- Standard Lua runtime
   local version = _VERSION or "Lua (unknown version)"
   return {
      name = "Lua",
      version = version:match("Lua (%d+%.%d+)") or version,
      description = version
   }
end

local function detect_luajit(): RuntimeInfo
   -- LuaJIT detection
   if jit and jit.version then
      return {
         name = "LuaJIT", 
         version = jit.version:match("LuaJIT (%S+)") or jit.version,
         description = jit.version
      }
   end
   return nil
end

local function detect_roblox(): RuntimeInfo
   -- Roblox Luau detection
   if game and game.GetService then
      -- Roblox environment detected
      local version = "Unknown"
      -- Try to get version info if available
      if version and version ~= "" then
         return {
            name = "Luau",
            version = version,
            description = "Roblox Luau " .. version
         }
      else
         return {
            name = "Luau", 
            description = "Roblox Luau"
         }
      end
   end
   return nil
end

local function detect_defold(): RuntimeInfo
   -- Defold detection
   if sys and sys.get_engine_info then
      local engine_info = sys.get_engine_info()
      return {
         name = "defold",
         version = engine_info.version or "unknown",
         description = "Defold " .. (engine_info.version or "unknown")
      }
   end
   return nil
end

local function detect_love2d(): RuntimeInfo
   -- Love2D detection
   if love and love.getVersion then
      local major, minor, revision, codename = love.getVersion()
      local version = string.format("%d.%d.%d", major, minor, revision)
      return {
         name = "love2d",
         version = version,
         description = "LÖVE " .. version .. " (" .. (codename or "") .. ")"
      }
   end
   return nil
end

local function detect_openresty(): RuntimeInfo
   -- OpenResty/ngx_lua detection  
   if ngx and ngx.var then
      local version = "unknown"
      if ngx.config and ngx.config.ngx_lua_version then
         version = ngx.config.ngx_lua_version
      end
      return {
         name = "OpenResty",
         version = version,
         description = "OpenResty/ngx_lua " .. version
      }
   end
   return nil
end

local function get_runtime_info(): RuntimeInfo
   -- Try to detect specific environments first
   local detectors = {
      detect_roblox,
      detect_defold, 
      detect_love2d,
      detect_openresty,
      detect_luajit
   }
   
   for _, detector in ipairs(detectors) do
      local result = detector()
      if result then
         return result
      end
   end
   
   -- Fall back to standard Lua
   return detect_standard_lua()
end

local runtime = {
   get_runtime_info = get_runtime_info,
   RuntimeInfo = RuntimeInfo
}

return runtime