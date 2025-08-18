local record OSInfo
   name: string
   version: string
end

-- Platform interface that each platform must implement
local record OSDetector
   detect: function(): OSInfo
end

local detectors: {OSDetector} = {}

local function register_detector(detector: OSDetector)
   table.insert(detectors, detector)
end

local function get_os_info(): OSInfo
   -- Try each registered detector until one succeeds
   for _, detector in ipairs(detectors) do
      local success, result = pcall(detector.detect)
      if success and result then
         return result
      end
   end
   
   -- If we can't detect anything, return nil
   return nil
end

return {
   OSInfo = OSInfo,
   OSDetector = OSDetector,
   register_detector = register_detector,
   get_os_info = get_os_info
}