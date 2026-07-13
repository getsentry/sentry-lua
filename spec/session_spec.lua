-- Release-health session tests
local sentry = require("sentry")
local envelope = require("sentry.utils.envelope")

local function sessions(client)
   local out = {}
   for _, body in ipairs(client.transport:get_envelopes()) do
      for _, s in ipairs(envelope.extract_items(body, "session")) do
         out[#out + 1] = s
      end
   end
   return out
end

describe("release health sessions", function()
   it("starts an init session when a release is set", function()
      local client = sentry.init({
         dsn = "https://t@h/1", test_transport = true,
         release = "1.0.0", environment = "prod"
      })
      local s = sessions(client)
      assert.equals(1, #s)
      assert.is_true(s[1].init)
      assert.equals("ok", s[1].status)
      assert.equals("1.0.0", s[1].attrs.release)
      assert.equals("prod", s[1].attrs.environment)
   end)

   it("does not start a session without a release", function()
      local client = sentry.init({dsn = "https://t@h/1", test_transport = true})
      assert.equals(0, #sessions(client))
   end)

   it("can be disabled with auto_session_tracking = false", function()
      local client = sentry.init({
         dsn = "https://t@h/1", test_transport = true,
         release = "1.0.0", auto_session_tracking = false
      })
      assert.equals(0, #sessions(client))
   end)

   it("counts handled errors and exits cleanly on close", function()
      local client = sentry.init({dsn = "https://t@h/1", test_transport = true, release = "1.0.0"})
      sentry.capture_exception("boom")            -- handled error
      sentry.close()

      local s = sessions(client)
      -- init session + final (exited) session
      local final = s[#s]
      assert.equals("exited", final.status)
      assert.is_true(final.errors >= 1)
      assert.is_false(final.init)
   end)

   it("marks the session crashed on an unhandled exception", function()
      local client = sentry.init({dsn = "https://t@h/1", test_transport = true, release = "1.0.0"})
      sentry.capture_exception("fatal", "fatal", {mechanism = {type = "generic", handled = false}})

      local s = sessions(client)
      local crashed = false
      for _, sess in ipairs(s) do
         if sess.status == "crashed" then crashed = true end
      end
      assert.is_true(crashed)
   end)

   it("mark_unhandled_as_crash=false keeps unhandled errors as errored, not crashed", function()
      -- WoW semantics: the client catches the Lua error and keeps running.
      local client = sentry.init({dsn = "https://t@h/1", test_transport = true, release = "1.0.0",
         mark_unhandled_as_crash = false})
      sentry.capture_exception("boom", "error", {mechanism = {type = "generic", handled = false}})
      sentry.close()

      local s = sessions(client)
      for _, sess in ipairs(s) do
         assert.not_equal("crashed", sess.status)
      end
      local final = s[#s]
      assert.equals("exited", final.status)   -- errored session, exits cleanly
      assert.is_true(final.errors >= 1)
   end)

   it("report_previous_session re-emits a persisted run as crashed with the same sid", function()
      local client = sentry.init({dsn = "https://t@h/1", test_transport = true, release = "1.0.0"})
      sentry.report_previous_session(
         {sid = "prev-123", started = "2026-07-12T00:00:00Z", errors = 2}, "crashed")

      local crashed
      for _, sess in ipairs(sessions(client)) do
         if sess.sid == "prev-123" then crashed = sess end
      end
      assert.is_truthy(crashed)
      assert.equals("crashed", crashed.status)
      assert.equals(2, crashed.errors)
      assert.is_false(crashed.init)
   end)

   it("get_session_snapshot returns the live session for persistence", function()
      sentry.init({dsn = "https://t@h/1", test_transport = true, release = "1.0.0"})
      local snap = sentry.get_session_snapshot()
      assert.is_truthy(snap.sid)
      assert.equals("ok", snap.status)
   end)
end)
