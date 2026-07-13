-- Platform-agnostic transport registry with dependency injection.
-- Every transport ships a single, pre-serialized envelope string. `categories`
-- lists the Sentry data categories in the envelope (used for rate limiting).
-- HTTP transports additionally return the response status and headers so the
-- client can apply rate limiting; others return only (ok, message).
local record Transport
   send_envelope: function(self: Transport, payload: string, categories: {string}): boolean, string, number, {string: string}
   configure: function(self: Transport, config: table): Transport
   flush: function(self: Transport)
   close: function(self: Transport)
end

local record TransportFactory
   name: string
   priority: number
   create: function(config: table): Transport
   is_available: function(): boolean
end

local factories: {TransportFactory} = {}

-- Register a transport factory
local function register_transport_factory(factory: TransportFactory)
   table.insert(factories, factory)
   -- Sort by priority (higher priority first)
   table.sort(factories, function(a: TransportFactory, b: TransportFactory): boolean
      return a.priority > b.priority
   end)
end

-- Get the best available transport for the current platform
local function create_transport(config: table): Transport
   for _, factory in ipairs(factories) do
      if factory.is_available() then
         return factory.create(config)
      end
   end
   
   -- Fallback to test transport if nothing else works
   local TestTransport = require("sentry.core.test_transport")
   return TestTransport:configure(config) as Transport
end

-- Get available transport names for debugging
local function get_available_transports(): {string}
   local available = {}
   for _, factory in ipairs(factories) do
      if factory.is_available() then
         table.insert(available, factory.name)
      end
   end
   return available
end

return {
   Transport = Transport,
   TransportFactory = TransportFactory,
   register_transport_factory = register_transport_factory,
   create_transport = create_transport,
   get_available_transports = get_available_transports,
   factories = factories
}