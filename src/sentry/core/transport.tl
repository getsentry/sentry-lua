local record Transport
   send: function(self: Transport, event: table): boolean, string
   configure: function(self: Transport, config: table): Transport
end

local dsn_utils = require("sentry.utils.dsn")

local record HttpTransport
   endpoint: string
   timeout: number
   headers: {string: string}
   dsn: dsn_utils.DSN
end

function HttpTransport:send(event: table): boolean, string
   local json = require("cjson") as any
   local http = require("socket.http") as any
   local ltn12 = require("ltn12") as any
   
   local body = json.encode(event)
   local response_body: {any} = {}
   
   local _, status = http.request({
      url = self.endpoint,
      method = "POST",
      headers = self.headers,
      source = ltn12.source.string(body),
      sink = ltn12.sink.table(response_body)
   })
   
   if status == 200 then
      return true, "Event sent successfully"
   else
      return false, "Failed to send event: " .. tostring(status)
   end
end

function HttpTransport:configure(config: table): Transport
   local dsn, err = dsn_utils.parse_dsn((config as any).dsn or "")
   if err ~= "" then
      error("Invalid DSN: " .. err)
   end
   
   self.dsn = dsn
   self.endpoint = dsn_utils.build_ingest_url(dsn)
   self.timeout = (config as any).timeout or 30
   self.headers = {
      ["Content-Type"] = "application/json",
      ["User-Agent"] = "sentry-lua/0.0.1",
      ["X-Sentry-Auth"] = dsn_utils.build_auth_header(dsn)
   }
   return self as Transport
end

local transport = {
   HttpTransport = HttpTransport
}

return transport