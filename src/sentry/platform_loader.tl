-- Platform loader: automatically loads available platform detectors
-- This file tries to load platform-specific modules that register themselves

local function load_platforms()
   local platform_modules = {
      "sentry.platforms.desktop",
      "sentry.platforms.roblox",
      "sentry.platforms.love2d",
      "sentry.platforms.nginx"
   }
   
   for _, module_name in ipairs(platform_modules) do
      pcall(require, module_name)
   end
end

-- Load platforms immediately
load_platforms()

return {
   load_platforms = load_platforms
}