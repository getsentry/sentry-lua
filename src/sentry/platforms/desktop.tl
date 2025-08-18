local os_utils = require("sentry.utils.os")
local OSInfo = os_utils.OSInfo

local function detect_os(): OSInfo
   -- Try to detect OS through standard Lua mechanisms
   local handle = io.popen("uname -s 2>/dev/null")
   if handle then
      local name = handle:read("*a")
      handle:close()
      if name then
         name = name:gsub("\n", "")
         if name ~= "" then
            -- Special handling for Darwin -> macOS
            if name == "Darwin" then
               -- Check if this is actually macOS by looking for system version
               local sw_vers = io.popen("sw_vers -productVersion 2>/dev/null")
               if sw_vers then
                  local macos_version = sw_vers:read("*a")
                  sw_vers:close()
                  if macos_version and macos_version:gsub("\n", "") ~= "" then
                     return {
                        name = "macOS",
                        version = macos_version:gsub("\n", "")
                     }
                  end
               end
               -- Fallback to Darwin if sw_vers not available
               name = "Darwin"
            end
            
            -- Get version for non-Darwin systems
            local version_handle = io.popen("uname -r 2>/dev/null")
            if version_handle then
               local version = version_handle:read("*a")
               version_handle:close()
               if version then
                  version = version:gsub("\n", "")
                  return {
                     name = name,
                     version = version
                  }
               end
            end
            
            return {
               name = name,
               version = ""
            }
         end
      end
   end
   
   -- Fallback: try to detect through package.config
   local sep = package.config:sub(1,1)
   if sep == "\\" then
      -- Windows
      local handle_win = io.popen("ver 2>nul")
      if handle_win then
         local output = handle_win:read("*a")
         handle_win:close()
         if output and output:match("Microsoft Windows") then
            local version = output:match("%[Version ([^%]]+)%]")
            return {
               name = "Windows",
               version = version or ""
            }
         end
      end
   end
   
   return nil
end

-- Register this detector
os_utils.register_detector({
   detect = detect_os
})

return {
   detect_os = detect_os
}