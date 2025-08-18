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
   
   local pattern = "^(https?)://([^:@]+):?([^@]*)@([^/]+)(/.*)$"
   local protocol, public_key, secret_key, host, path = dsn_string:match(pattern)
   
   if not protocol then
      pattern = "^(https?)://([^@]+)@([^/]+)(/.*)$"
      protocol, public_key, host, path = dsn_string:match(pattern)
      secret_key = ""
   end
   
   if not protocol or not public_key or not host or not path then
      return {} as DSN, "Invalid DSN format"
   end
   
   local project_id = path:match("/(%d+)$")
   if not project_id then
      return {} as DSN, "Could not extract project ID from DSN"
   end
   
   local port = 443
   if protocol == "http" then
      port = 80
   end
   
   local host_parts = host:split(":")
   if #host_parts > 1 then
      host = host_parts[1]
      port = tonumber(host_parts[2]) or port
   end
   
   return {
      protocol = protocol,
      public_key = public_key,
      secret_key = secret_key,
      host = host,
      port = port,
      path = path,
      project_id = project_id
   }, ""
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
      "sentry_client=sentry-lua/0.0.1"
   }
   
   if dsn.secret_key and dsn.secret_key ~= "" then
      table.insert(auth_parts, "sentry_secret=" .. dsn.secret_key)
   end
   
   return table.concat(auth_parts, ", ")
end

-- Helper function for string split (Lua 5.1 compatible)
function string.split(str: string, delimiter: string): {string}
   local result: {string} = {}
   local pattern = string.format("([^%s]+)", delimiter)
   
   for match in str:gmatch(pattern) do
      table.insert(result, match)
   end
   
   return result
end

return {
   parse_dsn = parse_dsn,
   build_ingest_url = build_ingest_url,
   build_auth_header = build_auth_header,
   DSN = DSN
}