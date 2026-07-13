---@class sentry.platforms.love2d.screenshot
--- Capture a Love2D screenshot and attach it to the next event.
---
--- Note: love.graphics.captureScreenshot is asynchronous (it completes after the
--- next present), so on a hard crash the frame may not be captured in time. Call
--- capture() proactively (e.g. each frame into a rolling attachment, or right
--- before risky work) for reliable screenshots.

---Capture the current frame and attach it as `screenshot.png`.
---@param client any The Sentry client
---@param on_done function? Called with a boolean success flag when done
local function capture(client: any, on_done: function(boolean))
   local G = _G as {string: any}
   local love = G["love"] as {string: any}
   local graphics = love and (love["graphics"] as {string: any})
   if not graphics or not graphics["captureScreenshot"] then
      if on_done then on_done(false) end
      return
   end

   (graphics["captureScreenshot"] as function(function(any)))(function(imagedata: any)
      local ok = pcall(function()
         local filedata = (imagedata as {string: any}):encode("png")
         local bytes = (filedata as {string: any}):getString()
         (client as any):add_attachment("screenshot.png", bytes, "image/png", "event.attachment")
      end)
      if on_done then
         on_done(ok)
      end
   end)
end

return {
   capture = capture
}
