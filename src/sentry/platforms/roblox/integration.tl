---@class sentry.platforms.roblox.integration
--- Roblox integration: attaches place/game context and installs a global error
--- handler via ScriptContext.Error (captures all uncaught script errors).
---
---   local roblox = require("sentry.platforms.roblox.integration")
---   sentry.init({ dsn = "...", integrations = { roblox.integration() } })

local context = require("sentry.platforms.roblox.context")
local persistence = require("sentry.core.persistence")

-- A PersistenceProvider backed by a Roblox DataStore, for experiences where
-- HttpService is disabled. Envelopes are stored as an array under `key`.
local function datastore_provider(datastore: any, key: string): persistence.PersistenceProvider
   local k = key or "sentry_envelopes"

   local function load(): {string}
      local ok, data = pcall(function(): any
         return (datastore as any):GetAsync(k)
      end)
      if ok and data then
         return data as {string}
      end
      return {}
   end

   local function save(list: {string})
      pcall(function()
         (datastore as any):SetAsync(k, list)
      end)
   end

   return {
      append = function(env: string): boolean, string
         local list = load()
         table.insert(list, env)
         save(list)
         return true, ""
      end,
      read_all = function(): {string}
         return load()
      end,
      remove_first = function(n: number)
         local list = load()
         for _ = 1, math.min(n, #list) do
            table.remove(list, 1)
         end
         save(list)
      end,
      clear = function()
         save({})
      end,
      size = function(): number
         return #load()
      end
   }
end

local function apply_context(client: any)
   local ctx = context.get_roblox_context()
   (client as any):set_context("roblox", ctx)

   local c = ctx as {string: any}
   if c["place_id"] then
      (client as any):set_tag("roblox.place_id", tostring(c["place_id"]))
   end
   if c["game_id"] then
      (client as any):set_tag("roblox.game_id", tostring(c["game_id"]))
   end
end

local function install_error_handler(client: any)
   local G = _G as {string: any}
   if not G["game"] then
      return
   end
   local ok, script_context = pcall(function(): any
      return (G["game"] as any):GetService("ScriptContext")
   end)
   if not ok or not script_context then
      return
   end
   pcall(function()
      ((script_context as {string: any})["Error"] as {string: any})["Connect"](
         (script_context as {string: any})["Error"],
         function(message: string, stack: string, _script: any)
            pcall(function()
               (client as any):capture_exception(tostring(message), "error", {
                  mechanism = { type = "roblox.ScriptContext", handled = false },
                  extra = { roblox_stack = stack }
               })
            end)
         end
      )
   end)
end

local function integration(): {string: any}
   return {
      name = "roblox",
      setup = function(client: any)
         apply_context(client)
         install_error_handler(client)
      end
   }
end

return {
   integration = integration,
   apply_context = apply_context,
   datastore_provider = datastore_provider
}
