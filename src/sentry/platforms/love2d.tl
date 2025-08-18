local transport = require("sentry.core.transport")
local os_utils = require("sentry.utils.os")
local OSInfo = os_utils.OSInfo

local record Love2DTransport
   endpoint: string
   timeout: number
   headers: {string: string}
   event_queue: {table}
end

function Love2DTransport:send(event: table): boolean, string
   if not love or not love.thread then
      return false, "LÖVE 2D not available"
   end
   
   table.insert(self.event_queue, event)
   
   return true, "Event queued for async sending"
end

function Love2DTransport:configure(config: table): transport.Transport
   self.endpoint = config.dsn or ""
   self.timeout = config.timeout or 30
   self.event_queue = {}
   self.headers = {
      ["Content-Type"] = "application/json",
      ["User-Agent"] = "sentry-lua-love2d/0.0.1"
   }
   return self as transport.Transport
end

function Love2DTransport:flush()
   if #self.event_queue == 0 then
      return
   end
   
   local json = require("cjson")
   local https = require("https")
   
   for i, event in ipairs(self.event_queue) do
      local body = json.encode(event)
      
      local success = pcall(function()
         https.request(self.endpoint, {
            method = "POST",
            headers = self.headers,
            data = body
         })
      end)
      
      if success then
         print("[Sentry] Event sent: " .. event.event_id)
      else
         print("[Sentry] Failed to send event: " .. event.event_id)
      end
   end
   
   self.event_queue = {}
end

local function get_love2d_context(): table
   local context = {}
   
   if love then
      context.love_version = love.getVersion and table.concat({love.getVersion()}, ".") or "unknown"
      
      if love.graphics then
         local w, h = love.graphics.getDimensions()
         context.screen = {
            width = w,
            height = h
         }
      end
      
      if love.system then
         context.os = love.system.getOS()
      end
   end
   
   return context
end

local function detect_os(): OSInfo
   if love and love.system then
      local os_name = love.system.getOS()
      if os_name then
         return {
            name = os_name,
            version = ""
         }
      end
   end
   return nil
end

-- Register this detector
os_utils.register_detector({
   detect = detect_os
})

local function setup_love2d_integration()
   return Love2DTransport, get_love2d_context
end

return {
   setup_love2d_integration = setup_love2d_integration,
   Love2DTransport = Love2DTransport,
   get_love2d_context = get_love2d_context,
   detect_os = detect_os
}