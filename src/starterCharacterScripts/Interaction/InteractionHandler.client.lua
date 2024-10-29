local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Interactions = Remotes:WaitForChild("Interactions")
local InteractionRequest:RemoteEvent = Interactions:WaitForChild("InteractionRequest")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Configs = Modules:WaitForChild("Configs")
local PlayerValues = require(script.Parent:WaitForChild("PlayerValues"))
local Controls = require(Configs:WaitForChild("Controls"))

local function Interact()
    InteractionRequest:FireServer("Interact", {
        visibleObject = PlayerValues.RetrieveValue("VisibleObject"),
        objectCarried = PlayerValues.RetrieveValue("ObjectCarried")
    })
end

local function Use(state)
    InteractionRequest:FireServer("Use", {
        visibleObject = PlayerValues.RetrieveValue("VisibleObject"),
        objectCarried = PlayerValues.RetrieveValue("ObjectCarried"),
        heldState = state
    })
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    if input.KeyCode == Controls.Interact then
        Interact()
    elseif input.KeyCode == Controls.Use then
        Use(true)
    end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    if input.KeyCode == Controls.Use then
        Use(false)
    end
end)