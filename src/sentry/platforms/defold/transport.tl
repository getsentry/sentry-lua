-- Defold transport: queues serialized envelopes for later delivery.
-- Defold apps typically drain the queue from their own update loop.
local transport_utils = require("sentry.utils.transport")
local version = require("sentry.version")

local record DefoldTransport
   endpoint: string
   timeout: number
   headers: {string: string}
   envelope_queue: {string}
end

function DefoldTransport:send_envelope(payload: string, _categories: {string}): boolean, string
   table.insert(self.envelope_queue, payload)
   return true, "Envelope queued for Defold processing"
end

function DefoldTransport:configure(config: table): transport_utils.Transport
   self.endpoint = (config as {string: any}).dsn or ""
   self.timeout = (config as {string: any}).timeout or 30
   self.envelope_queue = {}
   self.headers = {
      ["Content-Type"] = "application/x-sentry-envelope",
      ["User-Agent"] = "sentry-lua-defold/" .. version
   }
   return self as transport_utils.Transport
end

-- Flush queued envelopes (call this from your Defold script)
function DefoldTransport:flush()
   if #self.envelope_queue == 0 then
      return
   end

   for _, _payload in ipairs(self.envelope_queue) do
      -- In Defold, implement HTTP delivery (http.request) or file writing here.
      print("[Sentry] Would send queued envelope")
   end

   self.envelope_queue = {}
end

-- Create factory function
local function create_defold_transport(config: table): transport_utils.Transport
   local transport = DefoldTransport
   return transport:configure(config)
end

-- Check if Defold transport is available (basic check)
local function is_defold_available(): boolean
   -- Disabled by default so it doesn't interfere with other transports.
   return false
end

-- Register this transport factory with low priority
transport_utils.register_transport_factory({
   name = "defold",
   priority = 50, -- Lower priority - specialized use
   create = create_defold_transport,
   is_available = is_defold_available
})

return {
   DefoldTransport = DefoldTransport,
   create_defold_transport = create_defold_transport,
   is_defold_available = is_defold_available
}
