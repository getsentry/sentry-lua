local transport = require("sentry.core.transport")
local os_utils = require("sentry.utils.os")
local OSInfo = os_utils.OSInfo

local record RobloxTransport
   endpoint: string
   timeout: number
   headers: {string: string}
end

function RobloxTransport:send(event: table): boolean, string
   local json = require("cjson")
   local HttpService = game:GetService("HttpService")
   
   if not HttpService then
      return false, "HttpService not available in Roblox"
   end
   
   local body = json.encode(event)
   
   local success, response = pcall(function()
      return HttpService:PostAsync(self.endpoint, body, Enum.HttpContentType.ApplicationJson)
   end)
   
   if success then
      return true, "Event sent via Roblox HttpService"
   else
      return false, "Roblox HTTP error: " .. tostring(response)
   end
end

function RobloxTransport:configure(config: table): transport.Transport
   self.endpoint = config.dsn or ""
   self.timeout = config.timeout or 30
   self.headers = {
      ["Content-Type"] = "application/json",
      ["User-Agent"] = "sentry-lua-roblox/0.0.1"
   }
   return self as transport.Transport
end

local function get_roblox_context(): table
   local context = {}
   
   if game then
      context.game_id = game.GameId
      context.place_id = game.PlaceId
      context.job_id = game.JobId
   end
   
   if game and game.Players and game.Players.LocalPlayer then
      local player = game.Players.LocalPlayer
      context.player = {
         name = player.Name,
         user_id = player.UserId
      }
   end
   
   return context
end

local function detect_os(): OSInfo
   -- In Roblox, we can't execute system commands
   -- But we can detect we're in Roblox environment
   if _G.game and _G.game.GetService then
      return {
         name = "Roblox",
         version = ""
      }
   end
   return nil
end

-- Register this detector
os_utils.register_detector({
   detect = detect_os
})

local function setup_roblox_integration()
   return RobloxTransport, get_roblox_context
end

return {
   setup_roblox_integration = setup_roblox_integration,
   RobloxTransport = RobloxTransport,
   get_roblox_context = get_roblox_context,
   detect_os = detect_os
}