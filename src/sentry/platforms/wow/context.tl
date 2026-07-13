---@class sentry.platforms.wow.context
--- Rich, out-of-the-box context for World of Warcraft addons: game version and
--- build, client locale, and the full list of installed addons with versions.
--- All lookups are defensive so this works on Retail, Classic and PTR.

-- Enumerate installed addons with name + version + loaded state. Supports both
-- the modern C_AddOns namespace (Retail) and the legacy globals (Classic).
local function get_addons(G: {string: any}): {any}
   local c = G["C_AddOns"] as {string: any}
   local get_num = (c and c["GetNumAddOns"]) or G["GetNumAddOns"]
   local get_info = (c and c["GetAddOnInfo"]) or G["GetAddOnInfo"]
   local get_meta = (c and c["GetAddOnMetadata"]) or G["GetAddOnMetadata"]
   local is_loaded = (c and c["IsAddOnLoaded"]) or G["IsAddOnLoaded"]

   if not get_num or not get_info then
      return nil
   end

   local n = (get_num as function(): number)()
   local addons: {any} = {}
   for i = 1, n do
      local name = (get_info as function(number): string)(i)
      if name then
         local entry: {string: any} = { name = name }
         if get_meta then
            local ok, v = pcall(get_meta as function, name, "Version")
            if ok and v then
               entry["version"] = v
            end
         end
         if is_loaded then
            local ok2, loaded = pcall(is_loaded as function, name)
            if ok2 then
               entry["loaded"] = loaded and true or false
            end
         end
         table.insert(addons, entry)
      end
   end
   return addons
end

---Build the WoW context map (keyed by Sentry context name).
---@return {string: any} contexts
local function get_wow_context(): {string: any}
   local G = _G as {string: any}
   local contexts: {string: any} = {}

   if G["GetBuildInfo"] then
      local v, build, date, toc = (G["GetBuildInfo"] as function(): (string, string, string, number))()
      contexts["game"] = {
         name = "World of Warcraft",
         version = v,
         build = build,
         build_date = date,
         toc_version = toc
      }
   end

   contexts["runtime"] = { name = "wow-lua", version = _VERSION }

   if G["GetLocale"] then
      contexts["culture"] = { locale = (G["GetLocale"] as function(): string)() }
   end

   if G["GetRealmName"] then
      local ok, realm = pcall(G["GetRealmName"] as function)
      if ok and realm then
         contexts["server"] = { realm = realm }
      end
   end

   local addons = get_addons(G)
   if addons then
      contexts["addons"] = { count = #addons, loaded = addons }
   end

   return contexts
end

return {
   get_wow_context = get_wow_context,
   get_addons = get_addons
}
