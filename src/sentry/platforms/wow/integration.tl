---@class sentry.platforms.wow.integration
--- World of Warcraft integration. Use out of the box:
---
---   local wow = require("sentry.platforms.wow.integration")
---   sentry.init({
---     dsn = "...", spool = true,
---     persistence_provider = wow.saved_variables_provider(MyAddonDB), -- or (MyAddonDB, 128) to cap
---     integrations = { wow.integration() },
---   })
---
--- The companion `sentry.uploader` drains the spool and calls `remove_first(n)`
--- to drop delivered envelopes, so re-runs never re-send what already went out.
---
--- It attaches rich game/addon context, tags for quick filtering, and installs a
--- global error handler. WoW addons cannot make HTTP calls, so envelopes are
--- spooled to SavedVariables and delivered later by the companion uploader.

local context = require("sentry.platforms.wow.context")
local persistence = require("sentry.core.persistence")

-- A PersistenceProvider backed by a SavedVariables table (persisted by the game
-- across sessions). Declare `## SavedVariables: MyAddonDB` in your addon .toc.
--
-- `max_records` bounds how many envelopes may pile up between uploader runs
-- (SavedVariables is loaded fully into memory at login, so an unbounded spool
-- would grow the addon's load cost forever). Oldest envelopes are evicted past
-- the cap, mirroring `persistence.file_provider`. Defaults to 1000; pass a
-- smaller value for addons that only care about recent crashes.
local function saved_variables_provider(db: {string: any}, max_records: number): persistence.PersistenceProvider
   db["envelopes"] = (db["envelopes"] as {string}) or {}
   local store = db["envelopes"] as {string}
   local cap = max_records or 1000
   return {
      append = function(env: string): boolean, string
         table.insert(store, env)
         while #store > cap do
            table.remove(store, 1)
         end
         return true, ""
      end,
      read_all = function(): {string}
         return store
      end,
      remove_first = function(n: number)
         for _ = 1, math.min(n, #store) do
            table.remove(store, 1)
         end
      end,
      clear = function()
         for i = #store, 1, -1 do
            store[i] = nil
         end
      end,
      size = function(): number
         return #store
      end
   }
end

local function apply_context(client: any)
   local ctx = context.get_wow_context()
   for k, v in pairs(ctx) do
      (client as any):set_context(k, v)
   end

   local game = ctx["game"] as {string: any}
   if game then
      (client as any):set_tag("wow.version", tostring(game["version"]))
      (client as any):set_tag("wow.build", tostring(game["build"]))
   end
   local addons = ctx["addons"] as {string: any}
   if addons then
      (client as any):set_tag("wow.addons", tostring(addons["count"]))
   end
   local culture = ctx["culture"] as {string: any}
   if culture then
      (client as any):set_tag("wow.locale", tostring(culture["locale"]))
   end
end

local function install_error_handler(client: any)
   local G = _G as {string: any}
   if not G["seterrorhandler"] then
      return
   end
   local original: any = nil
   if G["geterrorhandler"] then
      local ok, h = pcall(G["geterrorhandler"] as function)
      if ok then
         original = h
      end
   end
   (G["seterrorhandler"] as function(function(string)))(function(msg: string)
      pcall(function()
         (client as any):capture_exception(tostring(msg), "error", {
            mechanism = { type = "wow.seterrorhandler", handled = false }
         })
      end)
      if original then
         (original as function(string))(msg)
      end
   end)
end

local function integration(): {string: any}
   return {
      name = "wow",
      setup = function(client: any)
         apply_context(client)
         install_error_handler(client)
      end
   }
end

return {
   integration = integration,
   apply_context = apply_context,
   saved_variables_provider = saved_variables_provider
}
