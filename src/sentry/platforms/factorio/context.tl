---@class sentry.platforms.factorio.context
--- Rich, out-of-the-box context for Factorio mods: the Factorio version (from
--- the `base` mod) and the full list of active mods with their versions.

---Build the Factorio context map (keyed by Sentry context name).
---@return {string: any} contexts
local function get_factorio_context(): {string: any}
   local G = _G as {string: any}
   local contexts: {string: any} = {}

   contexts["runtime"] = { name = "factorio-lua", version = _VERSION }

   local script_g = G["script"] as {string: any}
   local active = script_g and (script_g["active_mods"] as {string: string})
   if active then
      local mods: {any} = {}
      local base_version: string = nil
      for name, ver in pairs(active) do
         table.insert(mods, { name = name, version = ver })
         if name == "base" then
            base_version = ver
         end
      end
      contexts["mods"] = { count = #mods, active = mods }
      -- The `base` mod version is the Factorio game version.
      contexts["game"] = { name = "Factorio", version = base_version }
   end

   return contexts
end

return {
   get_factorio_context = get_factorio_context
}
