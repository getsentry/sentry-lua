local transport = require("sentry.core.transport")

local record NginxTransport
   endpoint: string
   timeout: number
   headers: {string: string}
end

function NginxTransport:send(event: table): boolean, string
   local json = require("cjson")
   local httpc = require("resty.http")
   
   if not httpc then
      return false, "resty.http not available - not running in nginx/OpenResty"
   end
   
   local http = httpc:new()
   http:set_timeout(self.timeout * 1000)
   
   local body = json.encode(event)
   
   local res, err = http:request_uri(self.endpoint, {
      method = "POST",
      body = body,
      headers = self.headers
   })
   
   if not res then
      return false, "HTTP request failed: " .. tostring(err)
   end
   
   if res.status == 200 then
      return true, "Event sent successfully"
   else
      return false, "HTTP error: " .. tostring(res.status)
   end
end

function NginxTransport:configure(config: table): transport.Transport
   self.endpoint = config.dsn or ""
   self.timeout = config.timeout or 30
   self.headers = {
      ["Content-Type"] = "application/json",
      ["User-Agent"] = "sentry-lua-nginx/0.0.1"
   }
   return self as transport.Transport
end

local function setup_nginx_integration()
   return NginxTransport
end

return {
   setup_nginx_integration = setup_nginx_integration,
   NginxTransport = NginxTransport
}