local version = require("sentry.version")

local record DSN
   protocol: string
   public_key: string
   secret_key: string
   host: string
   port: number
   path: string
   project_id: string
end

local function parse_dsn(dsn_string: string): DSN, string
   if not dsn_string or dsn_string == "" then
      return {} as DSN, "DSN is required"
   end
   
   -- Pattern to match DSN with optional secret key
   -- https://public_key:secret_key@host:port/path/project_id
   -- https://public_key@host:port/path/project_id
   local protocol, credentials, host_path = dsn_string:match("^(https?)://([^@]+)@(.+)$")
   
   if not protocol or not credentials or not host_path then
      return {} as DSN, "Invalid DSN format"
   end
   
   -- Parse credentials (public_key or public_key:secret_key)
   local public_key, secret_key = credentials:match("^([^:]+):(.+)$")
   if not public_key then
      public_key = credentials
      secret_key = ""
   end
   
   if not public_key or public_key == "" then
      return {} as DSN, "Invalid DSN format"
   end
   
   -- Parse host and path
   local host, path = host_path:match("^([^/]+)(.*)$")
   if not host or not path or path == "" then
      return {} as DSN, "Invalid DSN format"
   end
   
   -- Extract project ID from path (last numeric segment)
   local project_id = path:match("/([%d]+)$")
   if not project_id then
      return {} as DSN, "Could not extract project ID from DSN"
   end
   
   -- Parse port from host
   local port = 443
   if protocol == "http" then
      port = 80
   end
   
   local host_part, port_part = host:match("^([^:]+):?(%d*)$")
   if host_part then
      host = host_part
      if port_part and port_part ~= "" then
         port = tonumber(port_part) or port
      end
   end
   
   return {
      protocol = protocol,
      public_key = public_key,
      secret_key = secret_key or "",
      host = host,
      port = port,
      path = path,
      project_id = project_id
   }, nil  -- Return nil instead of empty string for no error
end

local function build_ingest_url(dsn: DSN): string
   return string.format("%s://%s/api/%s/store/", 
      dsn.protocol, 
      dsn.host, 
      dsn.project_id)
end

local function build_auth_header(dsn: DSN): string
   local auth_parts = {
      "Sentry sentry_version=7",
      "sentry_key=" .. dsn.public_key,
      "sentry_client=sentry-lua/" .. version
   }
   
   if dsn.secret_key and dsn.secret_key ~= "" then
      table.insert(auth_parts, "sentry_secret=" .. dsn.secret_key)
   end
   
   return table.concat(auth_parts, ", ")
end


return {
   parse_dsn = parse_dsn,
   build_ingest_url = build_ingest_url,
   build_auth_header = build_auth_header,
   DSN = DSN
}