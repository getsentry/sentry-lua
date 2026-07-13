-- Love2D screenshot -> attachment tests (mocked love.graphics)
describe("Love2D screenshot", function()
   before_each(function()
      _G.love = {
         graphics = {
            captureScreenshot = function(cb)
               cb({
                  encode = function(_self, _fmt)
                     return { getString = function() return "PNGBYTES" end }
                  end
               })
            end
         }
      }
   end)

   after_each(function()
      _G.love = nil
   end)

   it("captures a screenshot and attaches it to the next event", function()
      local sentry = require("sentry")
      local screenshot = require("sentry.platforms.love2d.screenshot")
      local envelope = require("sentry.utils.envelope")

      local client = sentry.init({dsn = "https://t@h/1", test_transport = true})
      screenshot.capture(client)
      sentry.capture_message("crash")

      local found
      for _, body in ipairs(client.transport:get_envelopes()) do
         for _, item in ipairs(envelope.parse(body).items) do
            if item.header.type == "attachment" and item.header.filename == "screenshot.png" then
               found = item
            end
         end
      end
      assert.is_not_nil(found)
      assert.equals("image/png", found.header.content_type)
      assert.equals("PNGBYTES", found.payload)
   end)
end)
