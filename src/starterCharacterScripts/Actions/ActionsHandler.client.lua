local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer

local Bindables = ReplicatedStorage:WaitForChild("Bindables")
local PlayerMobilityBE = Bindables:WaitForChild("PlayerMobility")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Actions = Remotes:WaitForChild("Actions")
local ActionRequestRE = Actions:WaitForChild("ActionRequest")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Configs = Modules:WaitForChild("Configs")
local PlayerValues = require(Modules:WaitForChild("PlayerValues"))
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