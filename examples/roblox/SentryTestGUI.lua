--[[
  Roblox Sentry Testing GUI
  
  Place this script in StarterGui
  
  Creates an interactive GUI for testing Sentry functionality including:
  - Test message capture
  - Error triggering
  - Breadcrumb addition
  - User context updates
  - Tag setting
]]--

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Wait for Sentry test functions to be available
while not _G.SentryTestFunctions do
   wait(0.1)
end

-- Create main GUI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SentryTestGUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- Main frame
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 300, 0, 400)
mainFrame.Position = UDim2.new(0, 10, 0, 10)
mainFrame.BackgroundColor3 = Color3.new(0.1, 0.1, 0.15)
mainFrame.BorderSizePixel = 2
mainFrame.BorderColor3 = Color3.new(0.3, 0.3, 0.4)
mainFrame.Parent = screenGui

-- Add corner rounding
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = mainFrame

-- Title bar
local titleBar = Instance.new("Frame")
titleBar.Name = "TitleBar"
titleBar.Size = UDim2.new(1, 0, 0, 40)
titleBar.Position = UDim2.new(0, 0, 0, 0)
titleBar.BackgroundColor3 = Color3.fromRGB(54, 46, 141) -- Sentry purple
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 8)
titleCorner.Parent = titleBar

-- Title text
local titleText = Instance.new("TextLabel")
titleText.Name = "TitleText"
titleText.Size = UDim2.new(1, -60, 1, 0)
titleText.Position = UDim2.new(0, 10, 0, 0)
titleText.BackgroundTransparency = 1
titleText.Text = "🔧 Sentry Test Panel"
titleText.TextColor3 = Color3.new(1, 1, 1)
titleText.TextScaled = true
titleText.Font = Enum.Font.GothamBold
titleText.Parent = titleBar

-- Close button
local closeButton = Instance.new("TextButton")
closeButton.Name = "CloseButton"
closeButton.Size = UDim2.new(0, 30, 0, 30)
closeButton.Position = UDim2.new(1, -35, 0, 5)
closeButton.BackgroundColor3 = Color3.fromRGB(220, 20, 20)
closeButton.Text = "✕"
closeButton.TextColor3 = Color3.new(1, 1, 1)
closeButton.TextScaled = true
closeButton.Font = Enum.Font.GothamBold
closeButton.BorderSizePixel = 0
closeButton.Parent = titleBar

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 4)
closeCorner.Parent = closeButton

-- Content frame
local contentFrame = Instance.new("Frame")
contentFrame.Name = "ContentFrame"
contentFrame.Size = UDim2.new(1, -20, 1, -60)
contentFrame.Position = UDim2.new(0, 10, 0, 50)
contentFrame.BackgroundTransparency = 1
contentFrame.Parent = mainFrame

-- Status label
local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "StatusLabel"
statusLabel.Size = UDim2.new(1, 0, 0, 30)
statusLabel.Position = UDim2.new(0, 0, 0, 0)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Status: Ready"
statusLabel.TextColor3 = Color3.fromRGB(100, 200, 100)
statusLabel.TextScaled = true
statusLabel.Font = Enum.Font.Gotham
statusLabel.Parent = contentFrame

-- Create buttons
local buttons = {
   {
      name = "TestMessage",
      text = "📨 Send Test Message",
      color = Color3.fromRGB(60, 120, 200),
      action = function()
         _G.SentryTestFunctions.sendTestMessage("Test message from GUI button")
         statusLabel.Text = "Status: Test message sent"
         statusLabel.TextColor3 = Color3.fromRGB(100, 200, 100)
      end
   },
   {
      name = "TestError", 
      text = "❌ Trigger Test Error",
      color = Color3.fromRGB(200, 80, 80),
      action = function()
         _G.SentryTestFunctions.triggerTestError()
         statusLabel.Text = "Status: Test error triggered"
         statusLabel.TextColor3 = Color3.fromRGB(200, 150, 100)
      end
   },
   {
      name = "AddBreadcrumb",
      text = "🍞 Add Breadcrumb",
      color = Color3.fromRGB(120, 180, 60),
      action = function()
         _G.SentryTestFunctions.addTestBreadcrumb()
         statusLabel.Text = "Status: Breadcrumb added"
         statusLabel.TextColor3 = Color3.fromRGB(120, 200, 120)
      end
   },
   {
      name = "UpdateUser",
      text = "👤 Update User Context",
      color = Color3.fromRGB(150, 100, 200),
      action = function()
         _G.SentryTestFunctions.updateUserContext()
         statusLabel.Text = "Status: User context updated"
         statusLabel.TextColor3 = Color3.fromRGB(150, 150, 200)
      end
   },
   {
      name = "SetTag",
      text = "🏷️ Set Test Tag",
      color = Color3.fromRGB(200, 140, 60),
      action = function()
         _G.SentryTestFunctions.setTestTag("gui_test", "button_clicked_" .. os.time())
         statusLabel.Text = "Status: Test tag set"
         statusLabel.TextColor3 = Color3.fromRGB(200, 180, 100)
      end
   }
}

-- Create buttons with layout
for i, buttonData in ipairs(buttons) do
   local button = Instance.new("TextButton")
   button.Name = buttonData.name
   button.Size = UDim2.new(1, 0, 0, 40)
   button.Position = UDim2.new(0, 0, 0, 40 + (i - 1) * 50)
   button.BackgroundColor3 = buttonData.color
   button.Text = buttonData.text
   button.TextColor3 = Color3.new(1, 1, 1)
   button.TextScaled = true
   button.Font = Enum.Font.Gotham
   button.BorderSizePixel = 0
   button.Parent = contentFrame
   
   local buttonCorner = Instance.new("UICorner")
   buttonCorner.CornerRadius = UDim.new(0, 6)
   buttonCorner.Parent = button
   
   -- Button animation and click handling
   button.MouseButton1Click:Connect(function()
      -- Click animation
      local clickTween = TweenService:Create(
         button,
         TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
         {Size = UDim2.new(0.95, 0, 0, 38)}
      )
      local returnTween = TweenService:Create(
         button,
         TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
         {Size = UDim2.new(1, 0, 0, 40)}
      )
      
      clickTween:Play()
      clickTween.Completed:Connect(function()
         returnTween:Play()
      end)
      
      -- Execute action
      pcall(buttonData.action)
   end)
   
   -- Hover effects
   button.MouseEnter:Connect(function()
      local hoverTween = TweenService:Create(
         button,
         TweenInfo.new(0.2, Enum.EasingStyle.Quad),
         {BackgroundColor3 = buttonData.color:lerp(Color3.new(1, 1, 1), 0.2)}
      )
      hoverTween:Play()
   end)
   
   button.MouseLeave:Connect(function()
      local unhoverTween = TweenService:Create(
         button,
         TweenInfo.new(0.2, Enum.EasingStyle.Quad),
         {BackgroundColor3 = buttonData.color}
      )
      unhoverTween:Play()
   end)
end

-- Add instructions text
local instructionsText = Instance.new("TextLabel")
instructionsText.Name = "InstructionsText"
instructionsText.Size = UDim2.new(1, 0, 0, 50)
instructionsText.Position = UDim2.new(0, 0, 1, -60)
instructionsText.BackgroundTransparency = 1
instructionsText.Text = "Click buttons to test Sentry features.\nCheck Studio Output and Sentry dashboard."
instructionsText.TextColor3 = Color3.new(0.7, 0.7, 0.8)
instructionsText.TextScaled = true
instructionsText.Font = Enum.Font.Gotham
instructionsText.TextWrapped = true
instructionsText.Parent = contentFrame

-- Close button functionality
closeButton.MouseButton1Click:Connect(function()
   screenGui:Destroy()
end)

-- Make frame draggable
local dragging = false
local dragStart = nil
local startPos = nil

titleBar.InputBegan:Connect(function(input)
   if input.UserInputType == Enum.UserInputType.MouseButton1 then
      dragging = true
      dragStart = input.Position
      startPos = mainFrame.Position
   end
end)

titleBar.InputChanged:Connect(function(input)
   if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
      local delta = input.Position - dragStart
      mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
   end
end)

titleBar.InputEnded:Connect(function(input)
   if input.UserInputType == Enum.UserInputType.MouseButton1 then
      dragging = false
   end
end)

-- Initial animation
mainFrame.Size = UDim2.new(0, 0, 0, 0)
mainFrame.Position = UDim2.new(0, 150, 0, 200)

local openTween = TweenService:Create(
   mainFrame,
   TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
   {
      Size = UDim2.new(0, 300, 0, 400),
      Position = UDim2.new(0, 10, 0, 10)
   }
)

openTween:Play()

print("🎮 Sentry Test GUI loaded! Use the buttons to test Sentry functionality.")