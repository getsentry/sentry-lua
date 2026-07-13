local version = require("sentry.version")
local envelope = require("sentry.utils.envelope")

-- In-memory transport used as the offline fallback and by tests. Captures the
-- raw envelopes and, for convenience, the decoded `event` payloads.
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

function TestTransport:configure(config: table): TestTransport
   self.endpoint = (config as {string: any}).dsn or ""
   self.timeout = (config as {string: any}).timeout or 30
   self.headers = {
      ["Content-Type"] = "application/x-sentry-envelope",
      ["User-Agent"] = "sentry-lua-test/" .. version
   }
   self.envelopes = {}
   self.events = {}
   return self
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

return TestTransport
