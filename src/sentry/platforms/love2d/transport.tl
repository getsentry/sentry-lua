-- LÖVE 2D transport with lua-https support
local transport_utils = require("sentry.utils.transport")
local json = require("sentry.utils.json")
local version = require("sentry.version")
local dsn_utils = require("sentry.utils.dsn")

local record Love2DTransport
   endpoint: string
   envelope_endpoint: string
   timeout: number
   headers: {string: string}
   envelope_headers: {string: string}
   event_queue: {table}
   envelope_queue: {string}
   dsn_info: any
   send: function(self: Love2DTransport, event: table): boolean, string
   send_envelope: function(self: Love2DTransport, envelope_body: string): boolean, string
   configure: function(self: Love2DTransport, config: table): transport_utils.Transport
   flush: function(self: Love2DTransport)
   close: function(self: Love2DTransport)
end

function Love2DTransport:send(event: table): boolean, string
   -- Check if we're in LÖVE 2D environment
   local love_global = rawget(_G, "love")
   if not love_global then
      return false, "Not in LÖVE 2D environment"
   end
   
   -- Queue the event for processing
   table.insert(self.event_queue, event)
   
   -- Process immediately in Love2D main thread
   self:flush()
   
   return true, "Event queued for sending in LÖVE 2D"
end

function Love2DTransport:send_envelope(envelope_body: string): boolean, string
   -- Check if we're in LÖVE 2D environment
   local love_global = rawget(_G, "love")
   if not love_global then
      return false, "Not in LÖVE 2D environment"
   end
   
   -- Queue the envelope for processing
   table.insert(self.envelope_queue, envelope_body)
   
   -- Process immediately in Love2D main thread
   self:flush()
   
   return true, "Envelope queued for sending in LÖVE 2D"
end

function Love2DTransport:configure(config: table): transport_utils.Transport
   local dsn = (config as any).dsn or ""
   self.dsn_info = dsn_utils.parse_dsn(dsn)
   self.endpoint = dsn_utils.build_ingest_url(self.dsn_info)
   self.envelope_endpoint = dsn_utils.build_envelope_url(self.dsn_info)
   self.timeout = (config as any).timeout or 30
   self.event_queue = {}
   self.envelope_queue = {}
   self.headers = {
      ["Content-Type"] = "application/json",
      ["User-Agent"] = "sentry-lua-love2d/" .. version,
      ["X-Sentry-Auth"] = dsn_utils.build_auth_header(self.dsn_info)
   }
   self.envelope_headers = {
      ["Content-Type"] = "application/x-sentry-envelope",
      ["User-Agent"] = "sentry-lua-love2d/" .. version,
      ["X-Sentry-Auth"] = dsn_utils.build_auth_header(self.dsn_info)
   }
   
   return self as transport_utils.Transport
end

-- Process queued events and envelopes using lua-https
function Love2DTransport:flush()
   local love_global = rawget(_G, "love")
   if not love_global then
      return
   end
   
   -- Try to load lua-https module
   local https_ok, https = pcall(require, "https")
   if not https_ok then
      print("[Sentry] lua-https module not available: " .. tostring(https))
      return
   end
   
   -- Send queued events
   if #self.event_queue > 0 then
      for _, event in ipairs(self.event_queue) do
         local body = json.encode(event)
         
         local status = https.request(self.endpoint, {
            method = "POST",
            headers = self.headers,
            data = body
         })
         
         if status == 200 then
            print("[Sentry] Event sent successfully (status: " .. status .. ")")
         else
            print("[Sentry] Event send failed to " .. self.endpoint .. " (status: " .. tostring(status) .. ")")
         end
      end
      self.event_queue = {}
   end
   
   -- Send queued envelopes
   if #self.envelope_queue > 0 then
      for _, envelope_body in ipairs(self.envelope_queue) do
         local status = https.request(self.envelope_endpoint, {
            method = "POST", 
            headers = self.envelope_headers,
            data = envelope_body
         })
         
         if status == 200 then
            print("[Sentry] Envelope sent successfully (status: " .. status .. ")")
         else
            print("[Sentry] Envelope send failed to " .. self.envelope_endpoint .. " (status: " .. tostring(status) .. ")")
         end
      end
      self.envelope_queue = {}
   end
end

-- Clean shutdown
function Love2DTransport:close()
   -- Final flush before closing
   self:flush()
end

-- Create factory function
local function create_love2d_transport(config: table): transport_utils.Transport
   local transport = Love2DTransport
   return transport:configure(config)
end

-- Check if LÖVE 2D transport is available
local function is_love2d_available(): boolean
   return rawget(_G, "love") ~= nil
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