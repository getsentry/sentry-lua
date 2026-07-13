-- Attachment tests
local sentry = require("sentry")
local envelope = require("sentry.utils.envelope")

local function attachments_in(client)
   local out = {}
   for _, body in ipairs(client.transport:get_envelopes()) do
      local parsed = envelope.parse(body)
      for _, item in ipairs(parsed.items) do
         if item.header.type == "attachment" then
            out[#out + 1] = {header = item.header, payload = item.payload}
         end
      end
   end
   return out
end

describe("attachments", function()
   it("rides in the same envelope as the event", function()
      local client = sentry.init({dsn = "https://t@h/1", test_transport = true})
      sentry.add_attachment("debug.txt", "hello world", "text/plain")
      sentry.capture_message("with attachment")

      local atts = attachments_in(client)
      assert.equals(1, #atts)
      assert.equals("debug.txt", atts[1].header.filename)
      assert.equals("text/plain", atts[1].header.content_type)
      assert.equals("event.attachment", atts[1].header.attachment_type)
      assert.equals("hello world", atts[1].payload)
      assert.equals(11, atts[1].header.length)
   end)

   it("drops attachments larger than max_attachment_size", function()
      local client = sentry.init({dsn = "https://t@h/1", test_transport = true, max_attachment_size = 4})
      sentry.add_attachment("big.bin", "toolong", "application/octet-stream")
      sentry.capture_message("oversized")

      assert.equals(0, #attachments_in(client))
   end)
end)
