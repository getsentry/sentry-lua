-- LÖVE 2D transport with HTTP and file fallback
local transport_utils = require("sentry.utils.transport")
local json = require("sentry.utils.json")
local version = require("sentry.version")
local dsn_utils = require("sentry.utils.dsn")
local http = require("sentry.utils.http")
local FileTransport = require("sentry.core.file_transport")

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
   _write_to_file: function(self: Love2DTransport, data: string, data_type: string)
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

-- Process queued events and envelopes
-- File fallback for Love2D SSL/TLS issues
function Love2DTransport:_write_to_file(data: string, data_type: string)
   local timestamp = os.date("%Y%m%d_%H%M%S")
   local filename = string.format("sentry_%s_%s.txt", data_type, timestamp)
   
   -- Use Love2D's filesystem if available
   local love_global = rawget(_G, "love")
   if love_global and love_global.filesystem then
      local success, err = pcall(love_global.filesystem.write, filename, data)
      if success then
         print("[Sentry] " .. data_type .. " written to " .. filename .. " (Love2D filesystem)")
      else
         print("[Sentry] Failed to write " .. data_type .. " to Love2D filesystem: " .. tostring(err))
      end
   else
      -- Fallback to standard IO
      local file = io.open(filename, "w")
      if file then
         file:write(data)
         file:close()
         print("[Sentry] " .. data_type .. " written to " .. filename .. " (standard IO)")
      else
         print("[Sentry] Failed to write " .. data_type .. " to file")
      end
   end
end

function Love2DTransport:flush()
   local love_global = rawget(_G, "love")
   if not love_global then
      return
   end
   
   -- Send queued events
   if #self.event_queue > 0 then
      for _, event in ipairs(self.event_queue) do
         local body = json.encode(event)
         local request = {
            url = self.endpoint,
            method = "POST",
            headers = self.headers,
            body = body,
            timeout = self.timeout
         }
         
         local response = http.request(request)
         
         if response.success and response.status == 200 then
            print("[Sentry] Event sent successfully (status: " .. response.status .. ")")
         else
            print("[Sentry] Event HTTP send failed, falling back to file transport: " .. (response.error or ("Status: " .. tostring(response.status))))
            -- Fallback to file transport for Love2D SSL/TLS issues
            self:_write_to_file(body, "event")
         end
      end
      self.event_queue = {}
   end
   
   -- Send queued envelopes
   if #self.envelope_queue > 0 then
      for _, envelope_body in ipairs(self.envelope_queue) do
         local request = {
            url = self.envelope_endpoint,
            method = "POST",
            headers = self.envelope_headers,
            body = envelope_body,
            timeout = self.timeout
         }
         
         local response = http.request(request)
         
         if response.success and response.status == 200 then
            print("[Sentry] Envelope sent successfully (status: " .. response.status .. ")")
         else
            print("[Sentry] Envelope HTTP send failed, falling back to file transport: " .. (response.error or ("Status: " .. tostring(response.status))))
            -- Fallback to file transport for Love2D SSL/TLS issues
            self:_write_to_file(envelope_body, "envelope")
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