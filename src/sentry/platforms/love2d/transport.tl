-- LÖVE 2D transport with love.thread HTTP support
local transport_utils = require("sentry.utils.transport")
local json = require("sentry.utils.json")
local version = require("sentry.version")
local dsn_utils = require("sentry.utils.dsn")

local record Love2DTransport
   endpoint: string
   timeout: number
   headers: {string: string}
   event_queue: {table}
   envelope_queue: {string}
   dsn_info: any
   http_thread: any
   http_channel: any
   send: function(self: Love2DTransport, event: table): boolean, string
   send_envelope: function(self: Love2DTransport, envelope_body: string): boolean, string
   configure: function(self: Love2DTransport, config: table): transport_utils.Transport
   flush: function(self: Love2DTransport)
   send_http_request: function(self: Love2DTransport, url: string, body: string)
   close: function(self: Love2DTransport)
end

-- HTTP thread code for Love2D
local http_thread_code = [[
local http = require("socket.http")
local ltn12 = require("ltn12")

local channel_in = love.thread.getChannel("sentry_http_in")
local channel_out = love.thread.getChannel("sentry_http_out")

while true do
   local request = channel_in:pop()
   if request == "quit" then
      break
   elseif request then
      local response_body = {}
      local result, status, headers = http.request{
         url = request.url,
         method = request.method or "POST",
         headers = request.headers,
         source = ltn12.source.string(request.body or ""),
         sink = ltn12.sink.table(response_body)
      }
      
      channel_out:push({
         success = (status >= 200 and status < 300),
         status = status,
         body = table.concat(response_body),
         error = result == nil and "HTTP request failed" or nil
      })
   end
   
   love.timer.sleep(0.001) -- Small sleep to prevent busy waiting
end
]]

function Love2DTransport:send(event: table): boolean, string
   -- Check if we're in LÖVE 2D environment
   if not _G.love then
      return false, "Not in LÖVE 2D environment"
   end
   
   -- Queue the event for async processing
   table.insert(self.event_queue, event)
   
   -- Process queued events immediately if possible
   self:flush()
   
   return true, "Event queued for async sending in LÖVE 2D"
end

function Love2DTransport:send_envelope(envelope_body: string): boolean, string
   -- Check if we're in LÖVE 2D environment
   if not _G.love then
      return false, "Not in LÖVE 2D environment"
   end
   
   -- Queue the envelope for async processing
   table.insert(self.envelope_queue, envelope_body)
   
   -- Process queued envelopes immediately if possible
   self:flush()
   
   return true, "Envelope queued for async sending in LÖVE 2D"
end

function Love2DTransport:configure(config: table): transport_utils.Transport
   local dsn = (config as any).dsn or ""
   self.dsn_info = dsn_utils.parse_dsn(dsn)
   self.endpoint = dsn_utils.build_ingest_url(self.dsn_info)
   self.timeout = (config as any).timeout or 30
   self.event_queue = {}
   self.envelope_queue = {}
   self.headers = {
      ["Content-Type"] = "application/json",
      ["User-Agent"] = "sentry-lua-love2d/" .. version,
      ["X-Sentry-Auth"] = dsn_utils.build_auth_header(self.dsn_info)
   }
   
   -- Initialize HTTP thread for async requests
   if (_G as any).love and ((_G as any).love as any).thread then
      self.http_thread = ((_G as any).love as any).thread.newThread(http_thread_code)
      self.http_channel = {
         input = ((_G as any).love as any).thread.getChannel("sentry_http_in"),
         output = ((_G as any).love as any).thread.getChannel("sentry_http_out")
      }
      (self.http_thread as any):start()
   end
   
   return self as transport_utils.Transport
end

-- Send HTTP request via love.thread
function Love2DTransport:send_http_request(url: string, body: string)
   if not self.http_thread or not self.http_channel then
      -- Fallback to file logging if threads aren't available
      if _G.love and (_G.love as any).filesystem then
         local success = pcall(function()
            (_G.love as any).filesystem.append("sentry-events.log", body .. "\n")
         end)
         if success then
            print("[Sentry] Event logged to file (thread unavailable)")
         else
            print("[Sentry] Failed to log event")
         end
      end
      return
   end
   
   local request = {
      url = url,
      method = "POST",
      headers = self.headers,
      body = body
   }
   
   self.http_channel.input:push(request)
   print("[Sentry] Event queued for HTTP sending")
end

-- Process HTTP responses and flush queued events
function Love2DTransport:flush()
   if not _G.love then
      return
   end
   
   -- Process any HTTP responses
   if self.http_channel then
      local response = self.http_channel.output:pop()
      if response then
         if response.success then
            print("[Sentry] Event sent successfully (status: " .. (response.status or "unknown") .. ")")
         else
            print("[Sentry] Event send failed: " .. (response.error or "Unknown error"))
         end
      end
   end
   
   -- Send queued events
   if #self.event_queue > 0 then
      for _, event in ipairs(self.event_queue) do
         local body = json.encode(event)
         self:send_http_request(self.endpoint, body)
      end
      self.event_queue = {}
   end
   
   -- Send queued envelopes
   if #self.envelope_queue > 0 then
      local envelope_endpoint = dsn_utils.build_envelope_url(self.dsn_info as any)
      for _, envelope_body in ipairs(self.envelope_queue) do
         self:send_http_request(envelope_endpoint, envelope_body)
      end
      self.envelope_queue = {}
   end
end

-- Clean shutdown
function Love2DTransport:close()
   if self.http_thread and self.http_channel then
      self.http_channel.input:push("quit")
      self.http_thread:wait()
   end
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