---@class sentry.utils.time
--- Best-effort wall-clock helpers, used for flush timeouts. Uses luasocket's
--- high-resolution clock when available and falls back to 1s-granularity
--- os.time() otherwise.

-- Resolve luasocket's high-resolution clock once, if present. The require is
-- wrapped so the type checker does not require the optional module to exist.
local socket_gettime: function(): number
do
   local ok, sock = pcall(function(): any
      -- Non-literal module name so the type checker does not require the
      -- optional module to exist at lint time.
      local mod = "socket"
      return require(mod)
   end)
   if ok and sock then
      local gt = (sock as {string: any})["gettime"]
      if gt then
         socket_gettime = gt as function(): number
      end
   end
end

---Current wall-clock time in milliseconds.
---@return number ms
local function now_ms(): number
   if socket_gettime then
      return socket_gettime() * 1000
   end
   return os.time() * 1000
end

return {
   now_ms = now_ms
}
