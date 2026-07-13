-- Async scheduler + isolation scope tests
local sentry = require("sentry")

describe("async scheduler", function()
   it("defers draining until the scheduler runs the drain", function()
      local pending = {}
      local client = sentry.init({
         dsn = "https://t@h/1", test_transport = true,
         scheduler = function(drain) table.insert(pending, drain) end
      })
      sentry.capture_message("deferred")
      assert.equals(0, #client.transport:get_events())  -- deferred, not drained yet

      for _, fn in ipairs(pending) do fn() end
      assert.equals(1, #client.transport:get_events())
   end)

   it("deferred() scheduler runs pending drains on demand", function()
      local scheduler = require("sentry.core.scheduler")
      local sched = scheduler.deferred()
      local client = sentry.init({
         dsn = "https://t@h/1", test_transport = true,
         scheduler = sched.schedule
      })
      sentry.capture_message("a")
      sentry.capture_message("b")
      assert.equals(0, #client.transport:get_events())
      sched.run_pending()
      assert.equals(2, #client.transport:get_events())
   end)
end)

describe("with_isolation_scope", function()
   it("isolates data to the callback", function()
      local client = sentry.init({dsn = "https://t@h/1", test_transport = true})
      sentry.set_tag("k", "outer")
      sentry.with_isolation_scope(function(scope)
         scope:set_tag("k", "inner")
         sentry.capture_message("inside")
      end)
      sentry.capture_message("outside")

      local events = client.transport:get_events()
      assert.equals("inner", events[1].tags.k)
      assert.equals("outer", events[2].tags.k)
   end)
end)
