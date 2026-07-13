---@class sentry.core.scrubber
--- Default PII / sensitive-data scrubbing. Replaces values stored under
--- sensitive keys with "[Filtered]" throughout the event (extra, contexts,
--- breadcrumb data, request data, stack-frame locals) and, unless
--- send_default_pii is enabled, strips the user's IP address.

-- Substrings matched case-insensitively against keys. Kept deliberately narrow
-- to avoid false positives (e.g. no bare "auth" which would hit "author").
local DEFAULT_DENYLIST: {string} = {
   "password", "passwd", "secret", "token", "api_key", "apikey",
   "access_token", "refresh_token", "authorization", "credentials",
   "credential", "cookie", "csrf", "private_key", "privatekey",
   "ssn", "credit_card", "card_number", "cvv"
}

local FILTERED = "[Filtered]"

-- Lowercase and drop separators so "X-Api-Key", "api_key" and "apikey" all match.
local function normalize(s: string): string
   return (s:lower():gsub("[-_]", ""))
end

local function key_is_sensitive(key: string, denylist: {string}): boolean
   local nk = normalize(key)
   for _, term in ipairs(denylist) do
      if nk:find(normalize(term), 1, true) then
         return true
      end
   end
   return false
end

-- Recursively scrub a table in place, guarding against cycles.
local function scrub_table(t: {any: any}, denylist: {string}, seen: {any: boolean})
   if seen[t] then
      return
   end
   seen[t] = true
   for k, v in pairs(t) do
      if type(k) == "string" and key_is_sensitive(k as string, denylist) then
         t[k] = FILTERED
      elseif type(v) == "table" then
         scrub_table(v as {any: any}, denylist, seen)
      end
   end
end

---Scrub an event in place. Returns the same event for convenience.
---@param event table
---@param options table Client options (reads send_default_pii)
---@return table
local function scrub_event(event: table, options: table): table
   scrub_table(event as {any: any}, DEFAULT_DENYLIST, {})

   -- Do not send the user's IP address unless PII is explicitly enabled.
   local send_pii = options and (options as {string: any})["send_default_pii"]
   if not send_pii then
      local user = (event as {string: any})["user"]
      if type(user) == "table" then
         (user as {string: any})["ip_address"] = nil
      end
   end

   return event
end

return {
   scrub_event = scrub_event,
   DEFAULT_DENYLIST = DEFAULT_DENYLIST,
   FILTERED = FILTERED
}
