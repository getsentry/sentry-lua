-- Test transport for capturing envelopes in memory
local transport_utils = require("sentry.utils.transport")
local version = require("sentry.version")
local envelope = require("sentry.utils.envelope")

local record TestTransport
   endpoint: string
   timeout: number
   headers: {string: string}
   envelopes: {string}
   events: {table}
end

function TestTransport:send_envelope(payload: string, _categories: {string}): boolean, string
   table.insert(self.envelopes, payload)
   for _, ev in ipairs(envelope.extract_items(payload, "event")) do
      table.insert(self.events, ev as table)
   end
   return true, "Envelope captured in test transport"
end

function TestTransport:configure(config: table): transport_utils.Transport
   self.endpoint = (config as {string: any}).dsn or ""
   self.timeout = (config as {string: any}).timeout or 30
   self.headers = {
      ["Content-Type"] = "application/x-sentry-envelope",
      ["User-Agent"] = "sentry-lua-test/" .. version
   }
   self.envelopes = {}
   self.events = {}
   return self as transport_utils.Transport
end

function TestTransport:get_events(): {table}
   return self.events
end

function TestTransport:get_envelopes(): {string}
   return self.envelopes
end

function TestTransport:clear_events()
   self.events = {}
   self.envelopes = {}
end

-- Create factory function
local function create_test_transport(config: table): transport_utils.Transport
   local transport = TestTransport
   return transport:configure(config)
end

-- Test transport is always available (good for testing)
local function is_test_available(): boolean
   return true
end

-- Register this transport factory with very low priority (testing only)
transport_utils.register_transport_factory({
   name = "test",
   priority = 1, -- Very low priority - only used when explicitly requested
   create = create_test_transport,
   is_available = is_test_available
})

return {
   TestTransport = TestTransport,
   create_test_transport = create_test_transport,
   is_test_available = is_test_available
}
