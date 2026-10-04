local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer

local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local ReadySetGoUI = PlayerGui:WaitForChild("ReadySetGo")
local ReadyFrame = ReadySetGoUI:WaitForChild("Ready")
local SetFrame = ReadySetGoUI:WaitForChild("Set")
local GoFrame = ReadySetGoUI:WaitForChild("Go")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local EffectsRemotes = Remotes:WaitForChild("Effects")
local ReadySetGoRE = EffectsRemotes:WaitForChild("ReadySetGo")

ReadySetGoRE.OnClientEvent:Connect(function()
    ReadySetGoUI.Enabled = true

    ReadyFrame.Visible = true
    task.wait(1)
    ReadyFrame.Visible = false
    SetFrame.Visible = true
    task.wait(1)
    SetFrame.Visible = false
    GoFrame.Visible = true
    task.wait(1)
    GoFrame.Visible = false
end)