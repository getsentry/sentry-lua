local sentry = require("sentry.init")

-- Initialize Sentry for nginx/OpenResty environment
sentry.init({
   dsn = "https://your-dsn@sentry.io/project-id",
   environment = "nginx",
   debug = true
})

-- Set nginx-specific context
sentry.set_tag("platform", "nginx")
sentry.set_tag("server", ngx.var.server_name or "localhost")

sentry.set_extra("request_method", ngx.var.request_method)
sentry.set_extra("request_uri", ngx.var.request_uri)
sentry.set_extra("remote_addr", ngx.var.remote_addr)

-- Add request breadcrumb
sentry.add_breadcrumb({
   message = "HTTP request received",
   category = "http",
   level = "info",
   data = {
      method = ngx.var.request_method,
      uri = ngx.var.request_uri,
      user_agent = ngx.var.http_user_agent
   }
})

-- Example: Capture successful request
sentry.capture_message("Request processed successfully", "info")

-- Example: Error handling in nginx
local function process_request()
   -- Simulate request processing
   if not ngx.var.arg_user_id then
      error("Missing required parameter: user_id")
   end
   
   -- Process request...
   ngx.say("Hello, user " .. ngx.var.arg_user_id)
end

local success, err = pcall(process_request)
if not success then
   sentry.capture_exception({
      type = "RequestError",
      message = err
   })
   
   ngx.status = 400
   ngx.say("Bad Request")
end