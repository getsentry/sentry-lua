-- LÖVE 2D transport with queued events
local transport_utils = require("sentry.utils.transport")
local json = require("sentry.utils.json")

local record Love2DTransport
   endpoint: string
   timeout: number
   headers: {string: string}
   event_queue: {table}
end

function Love2DTransport:send(event: table): boolean, string
   -- Check if we're in LÖVE 2D environment
   if not _G.love then
      return false, "Not in LÖVE 2D environment"
   end
   
   -- Queue the event for later processing
   table.insert(self.event_queue, event)
   
   return true, "Event queued for async sending in LÖVE 2D"
end

function Love2DTransport:configure(config: table): transport_utils.Transport
   self.endpoint = (config as any).dsn or ""
   self.timeout = (config as any).timeout or 30
   self.event_queue = {}
   self.headers = {
      ["Content-Type"] = "application/json",
      ["User-Agent"] = "sentry-lua-love2d/0.0.1"
   }
   return self as transport_utils.Transport
end

-- Flush queued events (call this from your game loop)
function Love2DTransport:flush()
   if #self.event_queue == 0 then
      return
   end
   
   for _, event in ipairs(self.event_queue) do
      local body = json.encode(event)
      
      -- In LÖVE 2D, we would use love.thread for async HTTP requests
      -- For now, just print the event data or write to file as fallback
      print("[Sentry] Would send event: " .. ((event as any).event_id or "unknown"))
      if _G.love and (_G.love as any).filesystem then
         -- Write to a file in LÖVE 2D
         local success = pcall(function()
            (_G.love as any).filesystem.append("sentry-events.log", body .. "\n")
         end)
         if not success then
            print("[Sentry] Failed to write event to file")
         end
      end
   end
   
   self.event_queue = {}
end

-- Create factory function
local function create_love2d_transport(config: table): transport_utils.Transport
   local transport = Love2DTransport
   return transport:configure(config)
end

-- Check if LÖVE 2D transport is available
local function is_love2d_available(): boolean
   return _G.love ~= nil
end

-- Register this transport factory with high priority for LÖVE 2D
transport_utils.register_transport_factory({
   name = "love2d",
   priority = 180, -- High priority in LÖVE 2D environment
   create = create_love2d_transport,
   is_available = is_love2d_available
})

return {
   Love2DTransport = Love2DTransport,
   create_love2d_transport = create_love2d_transport,
   is_love2d_available = is_love2d_available
}