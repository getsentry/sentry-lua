---@class sentry.platforms.defold.integration
--- Defold integration: attaches engine/runtime context and installs a global
--- error handler via sys.set_error_handler.
---
---   local defold = require("sentry.platforms.defold.integration")
---   sentry.init({ dsn = "...", integrations = { defold.integration() } })

local function apply_context(client: any)
   local G = _G as {string: any}
   local sys = G["sys"] as {string: any}
   if sys and sys["get_engine_info"] then
      local ok, info = pcall(sys["get_engine_info"] as function)
      if ok and info then
         (client as any):set_context("runtime", {
            name = "defold",
            version = (info as {string: any})["version"]
         })
      end
   end
end

local function install_error_handler(client: any)
   local G = _G as {string: any}
   local sys = G["sys"] as {string: any}
   if not sys or not sys["set_error_handler"] then
      return
   end
   (sys["set_error_handler"] as function(function(string, string, string)))(
      function(source: string, message: string, traceback: string)
         pcall(function()
            (client as any):capture_exception(tostring(message), "error", {
               mechanism = { type = "defold.error_handler", handled = false },
               extra = { source = source, traceback = traceback }
            })
         end)
      end
   )
end

local function integration(): {string: any}
   return {
      name = "defold",
      setup = function(client: any)
         apply_context(client)
         install_error_handler(client)
      end
   }
end

return {
   integration = integration,
   apply_context = apply_context
}
