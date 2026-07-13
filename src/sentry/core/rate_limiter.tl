---@class sentry.core.rate_limiter
--- Client-side rate limiting per the Sentry X-Sentry-Rate-Limits protocol.
---
--- Tracks, per data category, an epoch-ms timestamp until which sending is
--- suppressed. An empty category ("") represents "all categories". State is
--- updated from every response (limits may appear on any status, including 200)
--- and honors HTTP 429 with a Retry-After fallback (default 60s).

local time = require("sentry.utils.time")

local record RateLimiter
   disabled_until: {string: number}   -- category ("" = all) -> epoch ms
   now_fn: function(): number
end

local function trim(s: string): string
   return (s:gsub("^%s*(.-)%s*$", "%1"))
end

-- Case-insensitive header lookup. Returns "" when absent.
local function get_header(headers: {string: string}, name: string): string
   if not headers then
      return ""
   end
   local lname = name:lower()
   for k, v in pairs(headers) do
      if k:lower() == lname then
         return v
      end
   end
   return ""
end

---Create a rate limiter. `now_fn` is injectable for testing (defaults to wall clock).
---@param now_fn function? Returns current epoch ms
---@return RateLimiter
function RateLimiter.new(now_fn: function(): number): RateLimiter
   return setmetatable({
      disabled_until = {},
      now_fn = now_fn or time.now_ms
   }, {__index = RateLimiter}) as RateLimiter
end

---Is any of these data categories currently rate limited?
---@param categories {string}
---@return boolean
function RateLimiter:is_limited(categories: {string}): boolean
   local now = self.now_fn()
   local all = self.disabled_until[""]
   if all and now < all then
      return true
   end
   for _, cat in ipairs(categories or {}) do
      local until_ms = self.disabled_until[cat]
      if until_ms and now < until_ms then
         return true
      end
   end
   return false
end

-- Disable the given categories for `seconds` from now. Empty list = all categories.
-- Keeps the latest (maximum) expiry when limits overlap.
function RateLimiter:_apply(categories: {string}, seconds: number)
   local until_ms = self.now_fn() + seconds * 1000
   if #categories == 0 then
      if until_ms > (self.disabled_until[""] or 0) then
         self.disabled_until[""] = until_ms
      end
      return
   end
   for _, cat in ipairs(categories) do
      if until_ms > (self.disabled_until[cat] or 0) then
         self.disabled_until[cat] = until_ms
      end
   end
end

---Update rate-limit state from an HTTP response.
---@param status number HTTP status code
---@param headers {string: string} Response headers
function RateLimiter:update_from_response(status: number, headers: {string: string})
   local xrl = get_header(headers, "x-sentry-rate-limits")

   if xrl ~= "" then
      -- Comma-separated limits; each is
      --   retry_after : categories(;-list) : scope : reason : namespaces
      for limit in xrl:gmatch("[^,]+") do
         local fields: {string} = {}
         for field in (limit .. ":"):gmatch("(.-):") do
            table.insert(fields, field)
         end
         local seconds = tonumber(trim(fields[1] or "")) or 60
         local categories: {string} = {}
         local cats_str = fields[2] or ""
         for cat in cats_str:gmatch("[^;]+") do
            local c = trim(cat)
            if c ~= "" then
               table.insert(categories, c)
            end
         end
         self:_apply(categories, seconds)
      end
   elseif status == 429 then
      -- No structured header: fall back to Retry-After, default 60s, all categories.
      local retry_after = get_header(headers, "retry-after")
      local seconds: number = 60
      local n = tonumber(trim(retry_after))
      if n then
         seconds = n
      end
      self:_apply({}, seconds)
   end
end

return RateLimiter
