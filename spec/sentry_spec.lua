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
         -- Test would verify user is set in next event
      end)
      
      it("should set tags", function()
         sentry.set_tag("environment", "test")
         sentry.set_tag("version", "0.0.1")
         -- Test would verify tags are included in next event
      end)
      
      it("should add breadcrumbs", function()
         sentry.add_breadcrumb({
            message = "User clicked button",
            category = "ui",
            level = "info"
         })
         -- Test would verify breadcrumb is included in next event
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
         
         sentry.with_scope(function(scope)
            scope:set_tag("scoped", "temporary")
            -- Within scope: should have both tags
         end)
         
         -- Outside scope: should only have global tag
      end)
   end)
end)