local sentry = require("sentry.init")

ngx.say("Testing Sentry SDK with nginx/OpenResty integration...")

local sentry_client = sentry.init({
   dsn = "https://test@sentry.io/123456",
   environment = "docker-nginx-test",
   debug = true
})

ngx.say("✓ Sentry initialized")

sentry.set_tag("platform", "nginx")
sentry.set_tag("server", ngx.var.server_name or "localhost")
sentry.set_extra("request_uri", ngx.var.request_uri)
sentry.set_extra("user_agent", ngx.var.http_user_agent)

sentry.add_breadcrumb({
   message = "HTTP request received",
   category = "http",
   level = "info",
   data = {
      method = ngx.var.request_method,
      uri = ngx.var.request_uri
   }
})

local event_id = sentry.capture_message("Hello from nginx integration!", "info")
ngx.say("✓ Message captured: " .. event_id)

local success, err = pcall(function()
   error("Test nginx error")
end)

if not success then
   local exception_id = sentry.capture_exception({
      type = "NginxTestError",
      message = err
   })
   ngx.say("✓ Exception captured: " .. exception_id)
end

ngx.say("✓ nginx integration test completed successfully!")