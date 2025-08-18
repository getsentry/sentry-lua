describe("Context Filtering", function()
   local Client
   local Scope
   local os_utils
   local original_get_os_info
   
   before_each(function()
      Client = require("sentry.core.client")
      Scope = require("sentry.core.scope")
      os_utils = require("sentry.utils.os")
      
      -- Mock get_os_info function
      original_get_os_info = os_utils.get_os_info
   end)
   
   after_each(function()
      -- Restore original function
      if original_get_os_info then
         os_utils.get_os_info = original_get_os_info
      end
   end)
   
   describe("OS context with nil version", function()
      it("should exclude version field when nil", function()
         -- Mock OS detection to return nil version
         os_utils.get_os_info = function()
            return {name = "TestOS", version = nil}
         end
         
         local client = Client:new({
            dsn = "https://test@sentry.io/123456",
            test_transport = true
         })
         
         -- Check that OS context was set correctly
         assert.is_not_nil(client.scope)
         assert.is_not_nil(client.scope.contexts.os)
         assert.are.equal("TestOS", client.scope.contexts.os.name)
         assert.is_nil(client.scope.contexts.os.version)
      end)
      
      it("should include version field when present", function()
         -- Mock OS detection to return valid version
         os_utils.get_os_info = function()
            return {name = "macOS", version = "15.5"}
         end
         
         local client = Client:new({
            dsn = "https://test@sentry.io/123456", 
            test_transport = true
         })
         
         -- Check that OS context includes version
         assert.are.equal("macOS", client.scope.contexts.os.name)
         assert.are.equal("15.5", client.scope.contexts.os.version)
      end)
      
      it("should not set OS context when detection fails", function()
         -- Mock OS detection to return nil
         os_utils.get_os_info = function()
            return nil
         end
         
         local client = Client:new({
            dsn = "https://test@sentry.io/123456",
            test_transport = true
         })
         
         -- Check that no OS context was set
         assert.is_nil(client.scope.contexts.os)
      end)
   end)
   
   describe("Scope set_context", function()
      local scope
      
      before_each(function()
         scope = Scope:new()
      end)
      
      it("should store context with all fields", function()
         scope:set_context("test", {
            name = "TestContext",
            version = "1.0",
            description = "Test description"
         })
         
         assert.are.equal("TestContext", scope.contexts.test.name)
         assert.are.equal("1.0", scope.contexts.test.version)
         assert.are.equal("Test description", scope.contexts.test.description)
      end)
      
      it("should store context with nil fields", function()
         scope:set_context("test", {
            name = "TestContext",
            version = nil,
            description = "Test description"
         })
         
         assert.are.equal("TestContext", scope.contexts.test.name)
         assert.is_nil(scope.contexts.test.version)
         assert.are.equal("Test description", scope.contexts.test.description)
      end)
      
      it("should overwrite existing context", function()
         scope:set_context("test", {name = "Original"})
         scope:set_context("test", {name = "Updated", version = "2.0"})
         
         assert.are.equal("Updated", scope.contexts.test.name)
         assert.are.equal("2.0", scope.contexts.test.version)
      end)
   end)
   
   describe("Event context application", function()
      local scope
      
      before_each(function()
         scope = Scope:new()
      end)
      
      it("should apply contexts to event", function()
         scope:set_context("os", {name = "TestOS", version = "1.0"})
         scope:set_context("runtime", {name = "lua", version = "5.4"})
         
         local event = {}
         local updated_event = scope:apply_to_event(event)
         
         assert.is_not_nil(updated_event.contexts)
         assert.are.equal("TestOS", updated_event.contexts.os.name)
         assert.are.equal("lua", updated_event.contexts.runtime.name)
      end)
      
      it("should preserve existing event contexts", function()
         scope:set_context("os", {name = "TestOS"})
         
         local event = {
            contexts = {
               existing = {name = "Existing"}
            }
         }
         
         local updated_event = scope:apply_to_event(event)
         
         -- Should have both existing and new contexts
         assert.are.equal("Existing", updated_event.contexts.existing.name)
         assert.are.equal("TestOS", updated_event.contexts.os.name)
      end)
      
      it("should handle empty scope contexts", function()
         local event = {message = "test"}
         local updated_event = scope:apply_to_event(event)
         
         -- Event should be unchanged when scope has no contexts
         assert.are.equal("test", updated_event.message)
         -- Should not add empty contexts object
         -- (depends on implementation - might be nil or empty)
      end)
   end)
end)