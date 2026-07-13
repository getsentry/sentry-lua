local os_utils = require("sentry.utils.os")
local OSInfo = os_utils.OSInfo

local function detect_os(): OSInfo
   -- In Roblox, we can't execute system commands
   -- But we can detect we're in Roblox environment
   local game_g = _G.game as {string: any}
   if game_g and game_g["GetService"] then
      return {
         name = "Roblox",
         version = nil
      }
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