---@class sentry.utils.config
--- Resolve SDK configuration from explicit options plus environment variables.
--- Explicit (code) configuration always takes precedence over environment vars.

---@param config table Explicit options passed to sentry.init()
---@param getenv function? Environment getter (defaults to os.getenv; injectable for tests)
---@return table resolved
local function resolve(config: table, getenv: function(string): string): table
   -- Sandboxed Lua (WoW, Roblox, Factorio) has no `os.getenv`; fall back to a
   -- stub that yields no env config rather than crashing init.
   local env = getenv or os.getenv or function(_name: string): string return nil end
   local c = (config or {}) as {string: any}

   if not c["dsn"] or c["dsn"] == "" then
      c["dsn"] = env("SENTRY_DSN") or c["dsn"]
   end
   if c["release"] == nil then
      c["release"] = env("SENTRY_RELEASE")
   end
   if c["environment"] == nil then
      c["environment"] = env("SENTRY_ENVIRONMENT")
   end
   if c["debug"] == nil then
      local d = env("SENTRY_DEBUG")
      if d == "1" or d == "true" then
         c["debug"] = true
      end
   end

   return c as table
end

return {
   resolve = resolve
}
