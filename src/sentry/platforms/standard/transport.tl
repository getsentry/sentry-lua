-- Standard HTTP transport for desktop platforms (Standard Lua, LuaJIT)
local transport_utils = require("sentry.utils.transport")
local dsn_utils = require("sentry.utils.dsn")
local json = require("sentry.utils.json")
local http = require("sentry.utils.http")
local version = require("sentry.version")

local record HttpTransport
   endpoint: string
   timeout: number
   headers: {string: string}
   dsn: dsn_utils.DSN
end

function HttpTransport:send(event: table): boolean, string
   local body = json.encode(event)
   
   local request = {
      url = self.endpoint,
      method = "POST",
      headers = self.headers,
      body = body,
      timeout = self.timeout
   }
   
   local response = http.request(request)
   
   if response.success and response.status == 200 then
      return true, "Event sent successfully"
   else
      local error_msg = response.error or "Failed to send event: " .. tostring(response.status)
      return false, error_msg
   end
end

function HttpTransport:configure(config: table): transport_utils.Transport
   local dsn, err = dsn_utils.parse_dsn((config as any).dsn or "")
   if err then
      error("Invalid DSN: " .. err)
   end
   
   self.dsn = dsn
   self.endpoint = dsn_utils.build_ingest_url(dsn)
   self.timeout = (config as any).timeout or 30
   self.headers = {
      ["Content-Type"] = "application/json",
      ["User-Agent"] = "sentry-lua/" .. version,
      ["X-Sentry-Auth"] = dsn_utils.build_auth_header(dsn)
   }
   return self as transport_utils.Transport
end

-- Create factory function
local function create_http_transport(config: table): transport_utils.Transport
   local transport = HttpTransport
   return transport:configure(config)
end

-- Check if HTTP transport is available
local function is_http_available(): boolean
   return http.available
end

-- Register this transport factory
transport_utils.register_transport_factory({
   name = "standard-http",
   priority = 100, -- High priority for standard environments
   create = create_http_transport,
   is_available = is_http_available
})

return {
   HttpTransport = HttpTransport,
   create_http_transport = create_http_transport,
   is_http_available = is_http_available
}