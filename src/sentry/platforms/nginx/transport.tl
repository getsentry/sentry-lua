-- Nginx/OpenResty transport using resty.http
local transport_utils = require("sentry.utils.transport")
local dsn_utils = require("sentry.utils.dsn")
local json = require("sentry.utils.json")
local http = require("sentry.utils.http")
local version = require("sentry.version")

local record NginxTransport
   envelope_endpoint: string
   timeout: number
   envelope_headers: {string: string}
   dsn: dsn_utils.DSN
end

function NginxTransport:send_envelope(envelope_body: string): boolean, string
   local request = {
      url = self.envelope_endpoint,
      method = "POST",
      headers = self.envelope_headers,
      body = envelope_body,
      timeout = self.timeout
   }
   
   local response = http.request(request)
   
   if response.success and response.status == 200 then
      return true, "Envelope sent successfully"
   else
      local error_msg = response.error or "HTTP error: " .. tostring(response.status)
      return false, error_msg
   end
end

function NginxTransport:configure(config: table): transport_utils.Transport
   local dsn, err = dsn_utils.parse_dsn((config as any).dsn or "")
   if err then
      error("Invalid DSN: " .. err)
   end
   
   self.dsn = dsn
   self.envelope_endpoint = dsn_utils.build_envelope_url(dsn)
   self.timeout = (config as any).timeout or 30
   self.envelope_headers = {
      ["Content-Type"] = "application/x-sentry-envelope",
      ["User-Agent"] = "sentry-lua-nginx/" .. version,
      ["X-Sentry-Auth"] = dsn_utils.build_auth_header(dsn)
   }
   return self as transport_utils.Transport
end

-- Create factory function
local function create_nginx_transport(config: table): transport_utils.Transport
   local transport = NginxTransport
   return transport:configure(config)
end

-- Check if nginx transport is available
local function is_nginx_available(): boolean
   return _G.ngx ~= nil
end

-- Register this transport factory with high priority for nginx
transport_utils.register_transport_factory({
   name = "nginx",
   priority = 190, -- High priority in nginx/OpenResty environment
   create = create_nginx_transport,
   is_available = is_nginx_available
})

return {
   NginxTransport = NginxTransport,
   create_nginx_transport = create_nginx_transport,
   is_nginx_available = is_nginx_available
}