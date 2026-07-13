describe("Sentry SDK", function()
   local sentry
   
   before_each(function()
      sentry = require("sentry.init")
   end)
   
   describe("initialization", function()
      it("is a no-op with an empty DSN and does not throw", function()
         local client = sentry.init({})
         assert.is_not_nil(client)
         assert.is_false(client:is_enabled())
         -- Capturing on a disabled client is a safe no-op
         assert.equals("", sentry.capture_message("ignored"))
      end)
      
      it("should initialize with valid config", function()
         local client = sentry.init({
            dsn = "https://test@sentry.io/123456",
            environment = "test",
            test_transport = true
         })
         
         assert.is_not_nil(client)
      end)
   end)
   
   describe("capture_message", function()
      before_each(function()
         sentry.init({
            dsn = "https://test@sentry.io/123456",
            debug = true,
            test_transport = true
         })
      end)
      
      it("should capture a simple message", function()
         local event_id = sentry.capture_message("Test message")
         assert.is_string(event_id)
      end)
      
      it("should capture message with level", function()
         local event_id = sentry.capture_message("Warning message", "warning")
         assert.is_string(event_id)
      end)
      
      it("should fail when not initialized", function()
         sentry.close()
         assert.has_error(function()
            sentry.capture_message("Test")
         end, "Sentry not initialized. Call sentry.init() first.")
      end)
   end)
   
   describe("envelope capture", function()
      local client

      before_each(function()
         client = sentry.init({
            dsn = "https://test@sentry.io/123456",
            environment = "test",
            release = "1.0.0",
            test_transport = true
         })
      end)

      it("captures a message as an event envelope", function()
         sentry.set_tag("k", "v")
         local event_id = sentry.capture_message("hello", "warning")

         local events = client.transport:get_events()
         assert.equals(1, #events)
         assert.equals(event_id, events[1].event_id)
         assert.equals("hello", events[1].message)
         assert.equals("warning", events[1].level)
         assert.equals("test", events[1].environment)
         assert.equals("v", events[1].tags.k)

         -- Exactly one *event* envelope was shipped (a release-health session
         -- envelope is also sent at init because a release is configured).
         local envelope = require("sentry.utils.envelope")
         local event_envs = 0
         for _, body in ipairs(client.transport:get_envelopes()) do
            event_envs = event_envs + #envelope.extract_items(body, "event")
         end
         assert.equals(1, event_envs)
      end)

      it("captures an exception with a stacktrace", function()
         local event_id = sentry.capture_exception({type = "MyError", message = "bad"})

         local events = client.transport:get_events()
         assert.equals(1, #events)
         assert.equals(event_id, events[1].event_id)
         assert.is_not_nil(events[1].exception)
      end)

      it("captures a native string error with a handled mechanism", function()
         local id = sentry.capture_exception("main.lua:42: boom")
         local e = client.transport:get_events()[1]
         assert.equals(id, e.event_id)
         assert.equals("main.lua:42: boom", e.exception.values[1].value)
         assert.equals("Error", e.exception.values[1].type)
         assert.is_true(e.exception.values[1].mechanism.handled)
      end)

      it("marks unhandled exceptions via the mechanism hint", function()
         sentry.capture_exception("crash", "fatal", {
            mechanism = {type = "generic", handled = false}
         })
         local e = client.transport:get_events()[1]
         assert.is_false(e.exception.values[1].mechanism.handled)
      end)

      it("scrubs sensitive data and strips the user IP by default", function()
         sentry.set_extra("password", "hunter2")
         sentry.set_user({id = "u1", ip_address = "9.9.9.9"})
         sentry.capture_message("secrets")

         local e = client.transport:get_events()[1]
         assert.equals("[Filtered]", e.extra.password)
         assert.is_nil(e.user.ip_address)
         assert.equals("u1", e.user.id)
      end)

      it("drains the queue synchronously and flush returns true", function()
         sentry.capture_message("drained")
         assert.equals(0, client.queue:size())
         assert.is_true(sentry.flush(1000))
      end)

      it("close flushes and disables the client", function()
         sentry.capture_message("bye")
         assert.is_true(sentry.close(1000))
         assert.has_error(function()
            sentry.capture_message("after close")
         end, "Sentry not initialized. Call sentry.init() first.")
      end)
   end)

   describe("rate limiting", function()
      it("stops sending a category once the server rate limits it", function()
         local envelope = require("sentry.utils.envelope")
         local mock = {
            sent = {},
            configure = function(self) return self end,
            send_envelope = function(self, payload)
               table.insert(self.sent, payload)
               -- Server accepts the request but signals a rate limit on errors
               return false, "rate limited", 429, {["X-Sentry-Rate-Limits"] = "60:error"}
            end,
         }

         sentry.init({
            dsn = "https://k@h/1",
            transport = mock
         })

         sentry.capture_message("first")   -- sent; response rate-limits "error"
         sentry.capture_message("second")  -- dropped client-side

         -- Only the first error envelope reached the transport; the second was
         -- suppressed by the rate limiter (dropped events are accounted for in
         -- the client_report — see the "client reports" tests).
         local events_sent = 0
         for _, payload in ipairs(mock.sent) do
            events_sent = events_sent + #envelope.extract_items(payload, "event")
         end
         assert.equals(1, events_sent)
      end)
   end)

   describe("client reports", function()
      it("emits a batched client_report after dropping events", function()
         local envelope = require("sentry.utils.envelope")
         local mock = {
            sent = {},
            configure = function(self) return self end,
            send_envelope = function(self, payload)
               table.insert(self.sent, payload)
               -- Rate-limit "error" so the next error is dropped client-side
               return false, "rate limited", 429, {["X-Sentry-Rate-Limits"] = "60:error"}
            end,
         }

         sentry.init({dsn = "https://k@h/1", transport = mock})
         sentry.capture_message("first")   -- sent, triggers the 429 limit
         sentry.capture_message("second")  -- dropped -> ratelimit_backoff
         sentry.flush()

         local report
         for _, payload in ipairs(mock.sent) do
            local reports = envelope.extract_items(payload, "client_report")
            if #reports > 0 then
               report = reports[1]
            end
         end

         assert.is_not_nil(report)
         assert.is_true(#report.discarded_events >= 1)
         assert.equals("ratelimit_backoff", report.discarded_events[1].reason)
         assert.equals("error", report.discarded_events[1].category)
      end)
   end)

   describe("scopes", function()
      local client

      before_each(function()
         client = sentry.init({
            dsn = "https://test@sentry.io/1",
            test_transport = true
         })
      end)

      it("applies isolation tags and fingerprint to events", function()
         sentry.set_tag("iso", "1")
         sentry.set_fingerprint({"my-fp"})
         sentry.capture_message("hi")

         local e = client.transport:get_events()[1]
         assert.equals("1", e.tags.iso)
         assert.same({"my-fp"}, e.fingerprint)
      end)

      it("current scope overrides isolation and is discarded after with_scope", function()
         sentry.set_tag("k", "iso")
         sentry.with_scope(function(scope)
            scope:set_tag("k", "current")
            sentry.capture_message("inside")
         end)
         sentry.capture_message("outside")

         local events = client.transport:get_events()
         assert.equals("current", events[1].tags.k)  -- current wins inside the block
         assert.equals("iso", events[2].tags.k)        -- restored outside
      end)

      it("configure_scope mutates the isolation scope persistently", function()
         sentry.configure_scope(function(scope)
            scope:set_tag("persist", "yes")
         end)
         sentry.capture_message("x")
         assert.equals("yes", client.transport:get_events()[1].tags.persist)
      end)
   end)

   describe("capture options", function()
      it("sample_rate = 0 drops all events", function()
         local client = sentry.init({dsn = "https://t@h/1", test_transport = true, sample_rate = 0})
         sentry.capture_message("dropped")
         assert.equals(0, #client.transport:get_events())
      end)

      it("sample_rate = 1 keeps events", function()
         local client = sentry.init({dsn = "https://t@h/1", test_transport = true, sample_rate = 1})
         sentry.capture_message("kept")
         assert.equals(1, #client.transport:get_events())
      end)

      it("before_breadcrumb can drop a breadcrumb", function()
         local client = sentry.init({
            dsn = "https://t@h/1", test_transport = true,
            before_breadcrumb = function() return nil end
         })
         sentry.add_breadcrumb({message = "x"})
         sentry.capture_message("e")
         local e = client.transport:get_events()[1]
         assert.is_true(e.breadcrumbs == nil or #e.breadcrumbs == 0)
      end)

      it("before_breadcrumb can modify a breadcrumb", function()
         local client = sentry.init({
            dsn = "https://t@h/1", test_transport = true,
            before_breadcrumb = function(bc) bc.message = "modified" return bc end
         })
         sentry.add_breadcrumb({message = "orig"})
         sentry.capture_message("e")
         local e = client.transport:get_events()[1]
         assert.equals("modified", e.breadcrumbs[1].message)
      end)

      it("ignore_errors drops matching events", function()
         local client = sentry.init({
            dsn = "https://t@h/1", test_transport = true,
            ignore_errors = {"spammy"}
         })
         sentry.capture_message("this is spammy noise")
         sentry.capture_message("real problem")
         local events = client.transport:get_events()
         assert.equals(1, #events)
         assert.equals("real problem", events[1].message)
      end)

      it("attach_stacktrace off: messages have no stack trace", function()
         local client = sentry.init({dsn = "https://t@h/1", test_transport = true})
         sentry.capture_message("no trace")
         assert.is_nil(client.transport:get_events()[1].stacktrace)
      end)

      it("attach_stacktrace on: messages carry a stack trace", function()
         local client = sentry.init({dsn = "https://t@h/1", test_transport = true, attach_stacktrace = true})
         sentry.capture_message("with trace")
         assert.is_not_nil(client.transport:get_events()[1].stacktrace)
      end)

      it("runs integrations at init", function()
         local called = false
         sentry.init({
            dsn = "https://t@h/1", test_transport = true,
            integrations = {{name = "x", setup = function() called = true end}}
         })
         assert.is_true(called)
      end)
   end)

   describe("context management", function()
      before_each(function()
         sentry.init({
            dsn = "https://test@sentry.io/123456",
            test_transport = true
         })
      end)
      
      it("should set user context", function()
         sentry.set_user({id = "123", email = "test@example.com"})
         
         -- Capture message should succeed
         local event_id = sentry.capture_message("Test user context")
         assert.is_not_nil(event_id)
      end)
      
      it("should set tags", function()
         sentry.set_tag("environment", "test")
         sentry.set_tag("version", "0.0.6")
         
         -- Capture message should succeed
         local event_id = sentry.capture_message("Test tags")
         assert.is_not_nil(event_id)
      end)
      
      it("should add breadcrumbs", function()
         sentry.add_breadcrumb({
            message = "User clicked button",
            category = "ui",
            level = "info"
         })
         
         -- Capture message should succeed
         local event_id = sentry.capture_message("Test breadcrumbs")
         assert.is_not_nil(event_id)
      end)
   end)
   
   describe("with_scope", function()
      before_each(function()
         sentry.init({
            dsn = "https://test@sentry.io/123456",
            test_transport = true
         })
      end)
      
      it("should isolate scope changes", function()
         sentry.set_tag("global", "value")
         
         local scoped_event_id
         sentry.with_scope(function(scope)
            scope:set_tag("scoped", "temporary")
            scoped_event_id = sentry.capture_message("Scoped message")
         end)
         
         -- Verify scoped message was captured
         assert.is_not_nil(scoped_event_id)
         
         -- Capture another message outside scope
         local global_event_id = sentry.capture_message("Global message")
         assert.is_not_nil(global_event_id)
      end)
   end)
end)