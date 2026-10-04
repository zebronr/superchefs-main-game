local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Bindables = ReplicatedStorage:WaitForChild("Bindables")

local InteractionsRemotes = Remotes:WaitForChild("Interactions")
local InteractionRequestRE:RemoteEvent = InteractionsRemotes:WaitForChild("InteractionRequest")

local ControlsBindables = Bindables:WaitForChild("Controls")

local UseBE:BindableEvent = ControlsBindables:WaitForChild("Use")
local InteractBE = ControlsBindables:WaitForChild("Interact")

local Shared = ReplicatedStorage:WaitForChild("Modules")
local Configs = Shared:WaitForChild("Configs")
local PlayerValues = require(Shared:WaitForChild("PlayerValues"))
local Controls = require(Configs:WaitForChild("Controls"))

local function Interact()
    InteractionRequestRE:FireServer("Interact", {
        vO = PlayerValues.RetrieveValue(LocalPlayer, "VisibleObject"),
        vON = PlayerValues.RetrieveValue(LocalPlayer, "VisibleObjectNode")
    })
end

local function Use(state)
    InteractionRequestRE:FireServer("Use", {
        vO = PlayerValues.RetrieveValue(LocalPlayer, "VisibleObject"),
        vON = PlayerValues.RetrieveValue(LocalPlayer, "VisibleObjectNode"),
        hS = state
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

UseBE.Event:Connect(function(state)
    Use(state)
end)

InteractBE.Event:Connect(function()
    Interact()
end)