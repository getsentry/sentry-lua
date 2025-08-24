-- Roblox-specific transport using HttpService
local transport_utils = require("sentry.utils.transport")
local dsn_utils = require("sentry.utils.dsn")
local json = require("sentry.utils.json")
local version = require("sentry.version")

local record RobloxTransport
   envelope_endpoint: string
   timeout: number
   envelope_headers: {string: string}
   dsn: dsn_utils.DSN
end

function RobloxTransport:send_envelope(envelope_body: string): boolean, string
   -- Check if we're in Roblox environment
   if not _G.game then
      return false, "Not in Roblox environment"
   end
   
   local success_service, HttpService = pcall(function()
      return (_G.game as any):GetService("HttpService")
   end)
   
   if not success_service or not HttpService then
      return false, "HttpService not available in Roblox"
   end
   
   local success, response = pcall(function()
      return HttpService:PostAsync(self.envelope_endpoint, envelope_body, 
         (_G as any).Enum.HttpContentType.TextPlain, 
         false, -- compress 
         self.envelope_headers
      )
   end)
   
   if success then
      return true, "Envelope sent via Roblox HttpService"
   else
      return false, "Roblox HTTP error: " .. tostring(response)
   end
end

function RobloxTransport:configure(config: table): transport_utils.Transport
   local dsn, err = dsn_utils.parse_dsn((config as any).dsn or "")
   if err then
      error("Invalid DSN: " .. err)
   end
   
   self.dsn = dsn
   self.envelope_endpoint = dsn_utils.build_envelope_url(dsn)
   self.timeout = (config as any).timeout or 30
   self.envelope_headers = {
      ["Content-Type"] = "application/x-sentry-envelope",
      ["User-Agent"] = "sentry-lua-roblox/" .. version,
      ["X-Sentry-Auth"] = dsn_utils.build_auth_header(dsn)
   }
   return self as transport_utils.Transport
end

-- Create factory function
local function create_roblox_transport(config: table): transport_utils.Transport
   local transport = RobloxTransport
   return transport:configure(config)
end

-- Check if Roblox transport is available
local function is_roblox_available(): boolean
   return _G.game and (_G.game as any).GetService ~= nil
end

-- Register this transport factory with high priority for Roblox
transport_utils.register_transport_factory({
   name = "roblox",
   priority = 200, -- Very high priority in Roblox environment  
   create = create_roblox_transport,
   is_available = is_roblox_available
})

return {
   RobloxTransport = RobloxTransport,
   create_roblox_transport = create_roblox_transport,
   is_roblox_available = is_roblox_available
}