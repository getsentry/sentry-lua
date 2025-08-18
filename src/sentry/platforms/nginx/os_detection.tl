local os_utils = require("sentry.utils.os")
local OSInfo = os_utils.OSInfo

local function detect_os(): OSInfo
   if _G.ngx then
      -- OpenResty/nginx runs on Linux typically, try to get OS info
      local handle = io.popen("uname -s 2>/dev/null")
      if handle then
         local name = handle:read("*a")
         handle:close()
         if name then
            name = name:gsub("\n", "")
            local handle_version = io.popen("uname -r 2>/dev/null")
            if handle_version then
               local version = handle_version:read("*a")
               handle_version:close()
               version = version and version:gsub("\n", "") or ""
               return {
                  name = name,
                  version = version
               }
            end
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