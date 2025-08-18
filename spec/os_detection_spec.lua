describe("OS Detection", function()
   local os_utils
   local original_detectors
   
   before_each(function()
      -- Load the OS utils module
      os_utils = require("sentry.utils.os")
      
      -- Save original detectors and clear them for testing
      original_detectors = {}
      for i, detector in ipairs(os_utils.detectors or {}) do
         table.insert(original_detectors, detector)
      end
      
      -- Clear detectors for clean test state
      if os_utils.detectors then
         for i = #os_utils.detectors, 1, -1 do
            table.remove(os_utils.detectors, i)
         end
      end
   end)
   
   after_each(function()
      -- Restore original detectors
      if os_utils.detectors then
         for i = #os_utils.detectors, 1, -1 do
            table.remove(os_utils.detectors, i)
         end
         for _, detector in ipairs(original_detectors) do
            table.insert(os_utils.detectors, detector)
         end
      end
   end)
   
   describe("detector registration", function()
      it("should register a new detector", function()
         local test_detector = {
            detect = function()
               return {name = "TestOS", version = "1.0"}
            end
         }
         
         os_utils.register_detector(test_detector)
         
         -- Verify detector was registered
         local os_info = os_utils.get_os_info()
         assert.are.equal("TestOS", os_info.name)
         assert.are.equal("1.0", os_info.version)
      end)
      
      it("should try detectors in registration order", function()
         local first_detector = {
            detect = function()
               return {name = "FirstOS", version = "1.0"}
            end
         }
         local second_detector = {
            detect = function()
               return {name = "SecondOS", version = "2.0"}
            end
         }
         
         os_utils.register_detector(first_detector)
         os_utils.register_detector(second_detector)
         
         -- Should return result from first successful detector
         local os_info = os_utils.get_os_info()
         assert.are.equal("FirstOS", os_info.name)
      end)
   end)
   
   describe("nil version handling", function()
      it("should handle detector returning nil version", function()
         local detector_with_nil = {
            detect = function()
               return {name = "TestOS", version = nil}
            end
         }
         
         os_utils.register_detector(detector_with_nil)
         
         local os_info = os_utils.get_os_info()
         assert.are.equal("TestOS", os_info.name)
         assert.is_nil(os_info.version)
      end)
      
      it("should handle detector returning no version field", function()
         local detector_no_version = {
            detect = function()
               return {name = "TestOS"}
            end
         }
         
         os_utils.register_detector(detector_no_version)
         
         local os_info = os_utils.get_os_info()
         assert.are.equal("TestOS", os_info.name)
         assert.is_nil(os_info.version)
      end)
   end)
   
   describe("failed detection", function()
      it("should return nil when no detectors are registered", function()
         -- No detectors registered
         local os_info = os_utils.get_os_info()
         assert.is_nil(os_info)
      end)
      
      it("should return nil when all detectors fail", function()
         local failing_detector = {
            detect = function()
               return nil
            end
         }
         
         os_utils.register_detector(failing_detector)
         
         local os_info = os_utils.get_os_info()
         assert.is_nil(os_info)
      end)
      
      it("should handle detector that throws error", function()
         local error_detector = {
            detect = function()
               error("Detection failed!")
            end
         }
         local working_detector = {
            detect = function()
               return {name = "WorkingOS", version = "1.0"}
            end
         }
         
         os_utils.register_detector(error_detector)
         os_utils.register_detector(working_detector)
         
         -- Should skip the error detector and use the working one
         local os_info = os_utils.get_os_info()
         assert.are.equal("WorkingOS", os_info.name)
      end)
   end)
   
   describe("detector interface", function()
      it("should require detect function", function()
         local invalid_detector = {
            -- Missing detect function
         }
         
         -- Register detector without error
         os_utils.register_detector(invalid_detector)
         
         -- But it should fail when trying to use it
         local os_info = os_utils.get_os_info()
         assert.is_nil(os_info)
      end)
      
      it("should handle detector with invalid detect function", function()
         local invalid_detector = {
            detect = "not a function"
         }
         
         os_utils.register_detector(invalid_detector)
         
         local os_info = os_utils.get_os_info()
         assert.is_nil(os_info)
      end)
   end)
end)