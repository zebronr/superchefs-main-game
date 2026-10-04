local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local GameRemotes = Remotes:WaitForChild("Game")
local SetGameUIRE = GameRemotes:WaitForChild("SetGameUI")

local GameInfoRemotes = Remotes:WaitForChild("GameInfo")
local ResetRE = GameInfoRemotes:WaitForChild("Reset")

local GameInfoUI = PlayerGui:WaitForChild("GameInfo")
local InstructionsUI = PlayerGui:WaitForChild("Instructions")
local OrderListUI = PlayerGui:WaitForChild("OrderList")
local ReadySetGoUI = PlayerGui:WaitForChild("ReadySetGo")

local InfoFrame = GameInfoUI:WaitForChild("InfoFrame")
local CoinsLabel = InfoFrame:WaitForChild("CoinsFrame"):WaitForChild("TextLabel")

GameInfoUI.Enabled = false
InstructionsUI.Enabled = false
OrderListUI.Enabled = false
ReadySetGoUI.Enabled = false

SetGameUIRE.OnClientEvent:Connect(function(state)
    GameInfoUI.Enabled = state
    OrderListUI.Enabled = state
end)

ResetRE.OnClientEvent:Connect(function()
    CoinsLabel.Text = "0"
end)