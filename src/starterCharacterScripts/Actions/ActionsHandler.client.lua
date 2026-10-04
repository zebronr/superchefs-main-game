local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer

local Bindables = ReplicatedStorage:WaitForChild("Bindables")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local PlayerMobilityBE = Bindables:WaitForChild("PlayerMobility")

local Actions = Remotes:WaitForChild("Actions")
local ActionRequestRE = Actions:WaitForChild("ActionRequest")

local ControlsBindables = Bindables:WaitForChild("Controls")
local ThrowBE = ControlsBindables:WaitForChild("Throw")
local DashBE = ControlsBindables:WaitForChild("Dash")

local Shared = ReplicatedStorage:WaitForChild("Modules")
local Configs = Shared:WaitForChild("Configs")
local PlayerValues = require(Shared:WaitForChild("PlayerValues"))
local Controls = require(Configs:WaitForChild("Controls"))

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    local objectCarried = PlayerValues.RetrieveValue(LocalPlayer, "ObjectCarried")
     
    if objectCarried and input.KeyCode == Controls.Throw then
        ActionRequestRE:FireServer("throw", {localCFrame = objectCarried.CFrame})
    end

    if input.KeyCode == Controls.Dash then
        PlayerMobilityBE:Fire("dash")
    end
end)

ThrowBE.Event:Connect(function()
    local objectCarried = PlayerValues.RetrieveValue(LocalPlayer, "ObjectCarried")
     
    if objectCarried then
        ActionRequestRE:FireServer("throw", {localCFrame = objectCarried.CFrame})
    end
end)

DashBE.Event:Connect(function()
    PlayerMobilityBE:Fire("dash")
end)