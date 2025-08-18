-- Roblox-specific context information
local function get_roblox_context(): table
   local context = {}
   
   if _G.game then
      local game = _G.game as any
      context.game_id = game.GameId
      context.place_id = game.PlaceId
      context.job_id = game.JobId
   end
   
   if _G.game and (_G.game as any).Players and (_G.game as any).Players.LocalPlayer then
      local player = (_G.game as any).Players.LocalPlayer
      context.player = {
         name = player.Name,
         user_id = player.UserId
      }
   end
   
   return context
end

return {
   get_roblox_context = get_roblox_context
}