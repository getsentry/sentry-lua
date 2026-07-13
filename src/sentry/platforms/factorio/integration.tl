---@class sentry.platforms.factorio.integration
--- Factorio integration. Attaches the Factorio version and the full active-mod
--- list (with versions) to every event, out of the box.
---
---   local factorio = require("sentry.platforms.factorio.integration")
---   sentry.init({
---     dsn = "...", spool = true,
---     persistence_provider = my_script_output_provider,
---     integrations = { factorio.integration() },
---   })
---
--- Factorio mods run sandboxed with no network access, so envelopes are spooled
--- (e.g. to script-output) and delivered later by the companion uploader.

local context = require("sentry.platforms.factorio.context")

local function apply_context(client: any)
   local ctx = context.get_factorio_context()
   for k, v in pairs(ctx) do
      (client as any):set_context(k, v)
   end

   local game = ctx["game"] as {string: any}
   if game then
      (client as any):set_tag("factorio.version", tostring(game["version"]))
   end
   local mods = ctx["mods"] as {string: any}
   if mods then
      (client as any):set_tag("factorio.mods", tostring(mods["count"]))
   end
end

local function integration(): {string: any}
   return {
      name = "factorio",
      setup = function(client: any)
         apply_context(client)
      end
   }
end

return {
   integration = integration,
   apply_context = apply_context
}
