local os_utils = require("sentry.utils.os")
local OSInfo = os_utils.OSInfo

local function detect_os(): OSInfo
   if _G.love and (_G.love as any).system then
      local os_name = (_G.love as any).system.getOS()
      if os_name then
         return {
            name = os_name,
            version = nil
         }
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