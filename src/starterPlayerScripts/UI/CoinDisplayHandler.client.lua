local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Bindables = ReplicatedStorage:WaitForChild("Bindables")

local EffectsBE = Bindables:WaitForChild("Effects")

local GameInfoRemotes = Remotes:WaitForChild("GameInfo")
local UpdateCoinRE = GameInfoRemotes:WaitForChild("UpdateCoin")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local GameInfoUI = PlayerGui:WaitForChild("GameInfo")
local InfoFrame = GameInfoUI:WaitForChild("InfoFrame")

local CoinsFrame = InfoFrame:WaitForChild("CoinsFrame")
local CoinsLabel = CoinsFrame:WaitForChild("TextLabel")

UpdateCoinRE.OnClientEvent:Connect(function(amount)
    CoinsLabel.Text = amount
    EffectsBE:Fire("spinCoin")
end)