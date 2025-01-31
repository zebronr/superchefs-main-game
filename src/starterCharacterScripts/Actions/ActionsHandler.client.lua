local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Actions = Remotes:WaitForChild("Actions")
local ActionRequest = Actions:WaitForChild("ActionRequest")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Configs = Modules:WaitForChild("Configs")
local PlayerValues = require(Modules:WaitForChild("PlayerValues"))
local Controls = require(Configs:WaitForChild("Controls"))

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    local objectCarried = PlayerValues.RetrieveValue(LocalPlayer, "ObjectCarried")
     
    if objectCarried and input.KeyCode == Controls.Throw then
        ActionRequest:FireServer("throw", {localCFrame = objectCarried.CFrame})
    end
end)