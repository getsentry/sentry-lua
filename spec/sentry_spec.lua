describe("Sentry SDK", function()
   local sentry
   
   before_each(function()
      sentry = require("sentry.init")
   end)
   
   describe("initialization", function()
      it("should require a DSN", function()
         assert.has_error(function()
            sentry.init({})
         end, "Sentry DSN is required")
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
         sentry.set_tag("version", "0.0.3")
         
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