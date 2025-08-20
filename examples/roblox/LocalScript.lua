--[[
  Roblox Sentry Client-Side Integration Example
  
  Place this script in StarterPlayer.StarterPlayerScripts
  
  This script demonstrates client-side Sentry integration including:
  - UI error tracking
  - Client-specific context
  - User interaction monitoring
  - Local error capture
]]--

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

-- Wait for Sentry to be available
local sentry = require(ReplicatedStorage:WaitForChild("sentry"))

-- Initialize Sentry for client
sentry.init({
   dsn = "https://e247e6e48f8f482499052a65adaa9f6b@o117736.ingest.us.sentry.io/4504930623356928", -- Replace with your actual DSN
   environment = "roblox-client",
   release = "0.0.6",
   tags = {
      game_name = "Sentry Demo Game",
      game_version = "1.0.0",
      place_id = tostring(game.PlaceId),
      is_studio = RunService:IsStudio() and "true" or "false",
      platform = "roblox"
   }
})

print("🔧 Sentry initialized for Roblox client")

-- Set initial user context
sentry.set_user({
   id = tostring(player.UserId),
   username = player.Name
})

-- Wait for RemoteEvents
local remoteEvents = ReplicatedStorage:WaitForChild("SentryRemoteEvents")
local testMessageRemote = remoteEvents:WaitForChild("TestMessage")
local testErrorRemote = remoteEvents:WaitForChild("TestError")

-- Client-side error testing function
local function dangerousClientFunction()
   wait(0.5) -- Simulate some work
   
   -- Generate a random client error for testing
   local errorTypes = {
      "UI rendering failed",
      "Input handling error",
      "Animation system crash",
      "Sound playback failure",
      "Local data corruption"
   }
   
   local randomError = errorTypes[math.random(#errorTypes)]
   error("Client Error: " .. randomError)
end

-- GUI monitoring
local function setupGUIMonitoring()
   local playerGui = player:WaitForChild("PlayerGui")
   
   -- Monitor GUI additions
   playerGui.ChildAdded:Connect(function(gui)
      if gui:IsA("ScreenGui") then
         sentry.add_breadcrumb({
            message = "ScreenGui added",
            category = "ui",
            data = {
               gui_name = gui.Name,
               enabled = gui.Enabled
            }
         })
      end
   end)
   
   -- Monitor GUI removals
   playerGui.ChildRemoved:Connect(function(gui)
      if gui:IsA("ScreenGui") then
         sentry.add_breadcrumb({
            message = "ScreenGui removed",
            category = "ui",
            data = {
               gui_name = gui.Name
            }
         })
      end
   end)
end

-- Input monitoring
local function setupInputMonitoring()
   UserInputService.InputBegan:Connect(function(input, gameProcessed)
      if not gameProcessed then
         sentry.add_breadcrumb({
            message = "User input detected",
            category = "input",
            level = "debug",
            data = {
               input_type = tostring(input.UserInputType),
               key_code = input.KeyCode and tostring(input.KeyCode) or nil
            }
         })
      end
   end)
end

-- Character monitoring
local function setupCharacterMonitoring()
   local function onCharacterAdded(character)
      sentry.add_breadcrumb({
         message = "Character spawned",
         category = "character",
         data = {
            character_name = character.Name
         }
      })
      
      -- Monitor character health
      local humanoid = character:WaitForChild("Humanoid")
      humanoid.HealthChanged:Connect(function(health)
         if health <= 0 then
            sentry.add_breadcrumb({
               message = "Character died",
               category = "character",
               level = "warning",
               data = {
                  last_health = health,
                  character_name = character.Name
               }
            })
            
            sentry.capture_message("Player character died", "warning")
         end
      end)
   end
   
   if player.Character then
      onCharacterAdded(player.Character)
   end
   
   player.CharacterAdded:Connect(onCharacterAdded)
end

-- Performance monitoring
local function setupPerformanceMonitoring()
   spawn(function()
      while true do
         wait(30) -- Every 30 seconds
         
         local fps = math.floor(1 / RunService.Heartbeat:Wait())
         
         sentry.add_breadcrumb({
            message = "Performance check",
            category = "performance",
            level = "debug",
            data = {
               fps = fps,
               memory_usage = collectgarbage("count")
            }
         })
         
         -- Alert on low FPS
         if fps < 30 then
            sentry.capture_message("Low FPS detected: " .. fps .. " FPS", "warning")
         end
      end
   end)
end

-- Utility functions for testing
_G.SentryTestFunctions = {
   sendTestMessage = function(message)
      local testMessage = message or "Test message from client at " .. os.time()
      testMessageRemote:FireServer(testMessage)
      sentry.capture_message("Local test: " .. testMessage, "info")
   end,
   
   triggerTestError = function()
      testErrorRemote:FireServer()
      
      -- Also test local error capture
      local success, result = sentry.wrap(dangerousClientFunction, function(err)
         warn("⚠️ Client error caught:", err)
         return "Client error handled"
      end)
      
      if not success then
         print("❌ Client function failed:", result)
      end
   end,
   
   addTestBreadcrumb = function()
      sentry.add_breadcrumb({
         message = "Manual test breadcrumb",
         category = "test",
         level = "info",
         data = {
            timestamp = os.time(),
            player = player.Name,
            test_type = "manual_breadcrumb"
         }
      })
      print("🍞 Test breadcrumb added")
   end,
   
   updateUserContext = function()
      sentry.set_user({
         id = tostring(player.UserId),
         username = player.Name,
         extra = {
            account_age = player.AccountAge,
            membership_type = tostring(player.MembershipType),
            locale = player.LocaleId
         }
      })
      print("👤 User context updated")
   end,
   
   setTestTag = function(key, value)
      key = key or "test_tag"
      value = value or "test_value_" .. os.time()
      sentry.set_tag(key, value)
      print("🏷️ Tag set:", key, "=", value)
   end
}

-- Initialize all monitoring systems
setupGUIMonitoring()
setupInputMonitoring()
setupCharacterMonitoring()
setupPerformanceMonitoring()

print("🚀 Roblox Sentry Client Demo ready!")
print("🎮 Use _G.SentryTestFunctions to test functionality")

-- Initial client test
spawn(function()
   wait(3)
   sentry.capture_message("Roblox client initialized successfully", "info")
   print("✅ Sentry client integration test complete")
end)