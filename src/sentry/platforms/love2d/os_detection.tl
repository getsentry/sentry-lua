local os_utils = require("sentry.utils.os")
local OSInfo = os_utils.OSInfo

local function detect_os(): OSInfo
   local love_g = _G.love as {string: any}
   local system = love_g and (love_g["system"] as {string: any})
   if system and system["getOS"] then
      local os_name = (system["getOS"] as function(): string)()
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