--[[
  Roblox Sentry Server-Side Integration Example
  
  Place this script in ServerScriptService
  
  This script demonstrates server-side Sentry integration including:
  - Player join/leave tracking
  - Server-side error capture
  - Game event monitoring
  - Automatic context setting
]]--

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Load Sentry SDK
local sentry = require(ReplicatedStorage:WaitForChild("sentry"))

-- Initialize Sentry for server
sentry.init({
   dsn = "https://e247e6e48f8f482499052a65adaa9f6b@o117736.ingest.us.sentry.io/4504930623356928", -- Replace with your actual DSN
   environment = "roblox-server",
   release = "0.0.6",
   server_name = "GameServer-" .. game.JobId,
   tags = {
      game_name = "Sentry Demo Game",
      game_version = "1.0.0",
      place_id = tostring(game.PlaceId),
      is_studio = RunService:IsStudio() and "true" or "false"
   }
})

print("🔧 Sentry initialized for Roblox server")

-- Player management
local function setupPlayerTracking()
   -- Track player joins
   Players.PlayerAdded:Connect(function(player)
      sentry.set_user({
         id = tostring(player.UserId),
         username = player.Name,
         -- Note: Don't collect email or other personal info for privacy
      })
      
      sentry.add_breadcrumb({
         message = "Player joined server",
         level = "info",
         category = "player",
         data = {
            player_name = player.Name,
            player_id = tostring(player.UserId),
            account_age = player.AccountAge,
            membership_type = tostring(player.MembershipType)
         }
      })
      
      sentry.capture_message("Player joined: " .. player.Name, "info")
      print("📊 Player joined:", player.Name)
   end)
   
   -- Track player leaves
   Players.PlayerRemoving:Connect(function(player)
      sentry.add_breadcrumb({
         message = "Player left server",
         level = "info",
         category = "player",
         data = {
            player_name = player.Name,
            player_id = tostring(player.UserId),
            session_time = os.time() - (player:GetAttribute("JoinTime") or os.time())
         }
      })
      
      print("📤 Player left:", player.Name)
   end)
end

-- Example error-prone function for testing
local function dangerousServerFunction()
   wait(1) -- Simulate some work
   
   -- Generate a random error for testing
   local errorTypes = {
      "Database connection failed",
      "Invalid player data",
      "Network timeout",
      "Memory allocation error",
      "Critical game state corruption"
   }
   
   local randomError = errorTypes[math.random(#errorTypes)]
   error("Server Error: " .. randomError)
end

-- Wrapper for safe function execution
local function safeExecute(func, errorMessage)
   local success, result = sentry.wrap(func, function(err)
      warn("⚠️ Caught error:", err)
      sentry.set_tag("error_context", errorMessage or "unknown")
      return "Error handled gracefully"
   end)
   
   if not success then
      print("❌ Function failed:", result)
   else
      print("✅ Function succeeded:", result)
   end
   
   return success, result
end

-- Create RemoteEvents for client communication
local remoteEvents = Instance.new("Folder")
remoteEvents.Name = "SentryRemoteEvents"
remoteEvents.Parent = ReplicatedStorage

local testMessageRemote = Instance.new("RemoteEvent")
testMessageRemote.Name = "TestMessage"
testMessageRemote.Parent = remoteEvents

local testErrorRemote = Instance.new("RemoteEvent")
testErrorRemote.Name = "TestError"
testErrorRemote.Parent = remoteEvents

-- Handle remote events from clients
testMessageRemote.OnServerEvent:Connect(function(player, message)
   sentry.set_user({
      id = tostring(player.UserId),
      username = player.Name
   })
   
   sentry.add_breadcrumb({
      message = "Client requested test message",
      category = "remote_event",
      data = {
         player_name = player.Name,
         message = message
      }
   })
   
   sentry.capture_message("Client test message from " .. player.Name .. ": " .. message, "info")
   print("📨 Test message from", player.Name .. ":", message)
end)

testErrorRemote.OnServerEvent:Connect(function(player)
   sentry.set_user({
      id = tostring(player.UserId),
      username = player.Name
   })
   
   sentry.add_breadcrumb({
      message = "Client requested test error",
      category = "remote_event",
      data = {
         player_name = player.Name
      }
   })
   
   print("🧪 Testing server error for", player.Name)
   safeExecute(dangerousServerFunction, "client_requested_test")
end)

-- Periodic server health check
spawn(function()
   while true do
      wait(60) -- Every minute
      
      local playerCount = #Players:GetPlayers()
      
      sentry.add_breadcrumb({
         message = "Server health check",
         category = "system",
         level = "debug",
         data = {
            player_count = playerCount,
            memory_usage = collectgarbage("count"),
            uptime = os.time(),
            place_id = tostring(game.PlaceId)
         }
      })
      
      -- Capture server metrics
      if playerCount > 0 then
         sentry.set_tag("player_count", tostring(playerCount))
         sentry.capture_message("Server health: " .. playerCount .. " players online", "debug")
      end
   end
end)

-- Example of monitoring game events
local function monitorGameEvents()
   -- Monitor workspace changes
   workspace.ChildAdded:Connect(function(child)
      if child:IsA("Model") and child.Name ~= "Camera" then
         sentry.add_breadcrumb({
            message = "Object added to workspace",
            category = "game_event",
            data = {
               object_name = child.Name,
               object_type = child.ClassName
            }
         })
      end
   end)
end

-- Initialize all systems
setupPlayerTracking()
monitorGameEvents()

print("🚀 Roblox Sentry Server Demo ready!")
print("👥 Waiting for players to join...")

-- Test server functionality on startup
spawn(function()
   wait(5) -- Wait for everything to initialize
   
   sentry.capture_message("Roblox server started successfully", "info")
   print("✅ Sentry server integration test complete")
end)