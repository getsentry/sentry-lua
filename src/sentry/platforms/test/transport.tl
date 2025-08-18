-- Test transport for capturing events in memory
local transport_utils = require("sentry.utils.transport")
local version = require("sentry.version")

local record TestTransport
   endpoint: string
   timeout: number
   headers: {string: string}
   events: {table}
end

function TestTransport:send(event: table): boolean, string
   table.insert(self.events, event)
   return true, "Event captured in test transport"
end

function TestTransport:configure(config: table): transport_utils.Transport
   self.endpoint = (config as any).dsn or ""
   self.timeout = (config as any).timeout or 30
   self.headers = {
      ["Content-Type"] = "application/json",
      ["User-Agent"] = "sentry-lua-test/" .. version
   }
   self.events = {}
   return self as transport_utils.Transport
end

function TestTransport:get_events(): {table}
   return self.events
end

function TestTransport:clear_events()
   self.events = {}
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