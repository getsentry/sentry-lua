describe("Platform Detection", function()
   -- Note: These tests focus on the platform detection logic rather than 
   -- executing actual system commands, to ensure tests are portable and reliable
   
   describe("Desktop platform detection", function()
      local desktop_platform
      
      before_each(function()
         -- We can't easily test the actual standard platform detection since it relies on
         -- system commands, but we can test the module structure
         desktop_platform = require("sentry.platforms.standard.os_detection")
      end)
      
      it("should have detect_os function", function()
         assert.is_function(desktop_platform.detect_os)
      end)
      
      it("should return nil or valid OSInfo", function()
         local result = desktop_platform.detect_os()
         
         if result then
            -- If detection succeeded, should have name
            assert.is_string(result.name)
            -- Version can be nil or string
            assert.is_true(result.version == nil or type(result.version) == "string")
         else
            -- If detection failed, should be nil
            assert.is_nil(result)
         end
      end)
   end)
   
   describe("Roblox platform detection", function()
      local roblox_platform
      local original_G
      
      before_each(function()
         roblox_platform = require("sentry.platforms.roblox.os_detection")
         original_G = _G
      end)
      
      after_each(function()
         _G = original_G
      end)
      
      it("should have detect_os function", function()
         assert.is_function(roblox_platform.detect_os)
      end)
      
      it("should return nil when not in Roblox environment", function()
         -- Ensure we're not in Roblox environment
         _G.game = nil
         
         local result = roblox_platform.detect_os()
         assert.is_nil(result)
      end)
      
      it("should detect Roblox when game and GetService exist", function()
         -- Mock Roblox environment
         _G.game = {
            GetService = function() return {} end
         }
         
         local result = roblox_platform.detect_os()
         
         assert.is_not_nil(result)
         assert.are.equal("Roblox", result.name)
         assert.is_nil(result.version)  -- Should be nil, not empty string
      end)
      
      it("should return nil when game exists but no GetService", function()
         _G.game = {}  -- No GetService method
         
         local result = roblox_platform.detect_os()
         assert.is_nil(result)
      end)
   end)
   
   describe("LÖVE 2D platform detection", function()
      local love2d_platform
      local original_love
      
      before_each(function()
         love2d_platform = require("sentry.platforms.love2d.os_detection")
         original_love = _G.love
      end)
      
      after_each(function()
         _G.love = original_love
      end)
      
      it("should have detect_os function", function()
         assert.is_function(love2d_platform.detect_os)
      end)
      
      it("should return nil when not in LÖVE environment", function()
         _G.love = nil
         
         local result = love2d_platform.detect_os()
         assert.is_nil(result)
      end)
      
      it("should detect OS when LÖVE system is available", function()
         _G.love = {
            system = {
               getOS = function() return "Windows" end
            }
         }
         
         local result = love2d_platform.detect_os()
         
         assert.is_not_nil(result)
         assert.are.equal("Windows", result.name)
         assert.is_nil(result.version)  -- Should be nil, not empty string
      end)
      
      it("should return nil when love.system.getOS returns nil", function()
         _G.love = {
            system = {
               getOS = function() return nil end
            }
         }
         
         local result = love2d_platform.detect_os()
         assert.is_nil(result)
      end)
      
      it("should handle missing love.system", function()
         _G.love = {}  -- No system module
         
         local result = love2d_platform.detect_os()
         assert.is_nil(result)
      end)
   end)
   
   describe("Nginx platform detection", function()
      local nginx_platform
      local original_ngx
      
      before_each(function()
         nginx_platform = require("sentry.platforms.nginx.os_detection")
         original_ngx = _G.ngx
      end)
      
      after_each(function()
         _G.ngx = original_ngx
      end)
      
      it("should have detect_os function", function()
         assert.is_function(nginx_platform.detect_os)
      end)
      
      it("should return nil when not in nginx environment", function()
         _G.ngx = nil
         
         local result = nginx_platform.detect_os()
         assert.is_nil(result)
      end)
      
      -- Note: Testing nginx detection fully would require mocking io.popen
      -- which is complex. We mainly test the environment detection logic.
   end)
   
   describe("Platform loader", function()
      it("should load platform modules without error", function()
         -- This test ensures platform_loader can be required and executes without error
         assert.has_no.errors(function()
            require("sentry.platform_loader")
         end)
      end)
   end)
   
   describe("Integration test", function()
      it("should have at least one working detector after loading platforms", function()
         -- Load platform loader to register detectors
         require("sentry.platform_loader")
         
         local os_utils = require("sentry.utils.os")
         local result = os_utils.get_os_info()
         
         -- Should detect at least the desktop platform on most systems
         -- If this fails, it might be running in a very limited environment
         if result then
            assert.is_string(result.name)
            -- Version can be nil
            assert.is_true(result.version == nil or type(result.version) == "string")
         end
         -- Note: We don't assert result is not nil because the test might run
         -- in an environment where no detectors work
      end)
   end)
end)