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

function TestTransport:configure(config: table): TestTransport
   self.endpoint = (config as any).dsn or ""
   self.timeout = (config as any).timeout or 30
   self.headers = {
      ["Content-Type"] = "application/json",
      ["User-Agent"] = "sentry-lua-test/0.0.1"
   }
   self.events = {}
   return self
end

function TestTransport:get_events(): {table}
   return self.events
end

function TestTransport:clear_events()
   self.events = {}
end

return TestTransport