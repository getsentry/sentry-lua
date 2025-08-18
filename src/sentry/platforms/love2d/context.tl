-- LÖVE 2D specific context information
local function get_love2d_context(): table
   local context = {}
   
   if _G.love then
      local love = _G.love as any
      context.love_version = love.getVersion and table.concat({love.getVersion()}, ".") or "unknown"
      
      if love.graphics then
         local w, h = love.graphics.getDimensions()
         context.screen = {
            width = w,
            height = h
         }
      end
      
      if love.system then
         context.os = love.system.getOS()
      end
   end
   
   return context
end

return {
   get_love2d_context = get_love2d_context
}