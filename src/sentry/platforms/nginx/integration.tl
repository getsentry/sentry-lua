---@class sentry.platforms.nginx.integration
--- OpenResty/nginx integration. OpenResty has no global error hook, so this
--- attaches request context and provides `wrap()` for content handlers.
---
---   local nginx = require("sentry.platforms.nginx.integration")
---   sentry.init({ dsn = "...", integrations = { nginx.integration() } })
---   -- content_by_lua:
---   nginx.wrap(sentry._client, function() ... end)()

local function apply_context(client: any)
   local G = _G as {string: any}
   local ngx = G["ngx"] as {string: any}
   if not ngx then
      return
   end
   (client as any):set_context("runtime", { name = "openresty" })
   local var = ngx["var"] as {string: any}
   if var then
      (client as any):set_context("request", {
         url = var["request_uri"],
         method = var["request_method"]
      })
      if var["server_name"] then
         (client as any):set_tag("server_name", var["server_name"])
      end
   end
end

-- Wrap a content handler so uncaught errors are captured and re-raised.
local function wrap(client: any, fn: function): function
   return function(...: any): any
      local results = { pcall(fn, ...) }
      if not results[1] then
         pcall(function()
            (client as any):capture_exception(results[2], "error", {
               mechanism = { type = "nginx", handled = false }
            })
         end)
         error(results[2])
      end
      return table.unpack and table.unpack(results, 2) or (unpack as function)(results, 2)
   end
end

local function integration(): {string: any}
   return {
      name = "nginx",
      setup = function(client: any)
         apply_context(client)
      end
   }
end

return {
   integration = integration,
   apply_context = apply_context,
   wrap = wrap
}
