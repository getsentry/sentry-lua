---@class sentry.core.scheduler
--- Platform scheduler factories for the async transport. A scheduler is a
--- `function(drain)` that arranges for `drain` to run soon, off the hot path.
--- Pass one as `init({ scheduler = ... })`.

local scheduler = {}

-- OpenResty: defer draining to a zero-delay timer (runs off the request path).
function scheduler.openresty(): function(function())
   return function(drain: function())
      local ngx_g = (_G as {string: any})["ngx"] as {string: any}
      local timer = ngx_g and (ngx_g["timer"] as {string: any})
      if timer and timer["at"] then
         (timer["at"] as function(number, function))(0, function()
            drain()
         end)
      else
         drain()
      end
   end
end

-- Roblox: run the drain on a separate task so it never blocks the caller.
function scheduler.roblox(): function(function())
   return function(drain: function())
      local task = (_G as {string: any})["task"] as {string: any}
      if task and task["spawn"] then
         (task["spawn"] as function(function))(drain)
      else
         drain()
      end
   end
end

-- Generic deferred scheduler: accumulates drains and runs them on demand. Wire
-- `.schedule` as the scheduler and call `.run_pending()` from your loop
-- (e.g. love.update). Returns { schedule, run_pending }.
function scheduler.deferred(): {string: any}
   local pending: {function()} = {}
   return {
      schedule = function(drain: function())
         table.insert(pending, drain)
      end,
      run_pending = function()
         local fns = pending
         pending = {}
         for _, fn in ipairs(fns) do
            fn()
         end
      end
   }
end

return scheduler
