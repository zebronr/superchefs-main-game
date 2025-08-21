--[[local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer

local Modules = ReplicatedStorage:WaitForChild("Modules")

local PlayerValues = require(Modules:WaitForChild("PlayerValues"))

local Assets = ReplicatedStorage:WaitForChild("Assets")
local VisibilityHighlight = Assets:WaitForChild("VisibilityHighlight")

local function toggleObjectHighlight(prompt, state)
    if prompt.Name ~= "InteractionPrompt" then
        return
    end

    local Object = prompt.Parent

    if not Object then return end
    
    if state and not Object:FindFirstChild("VisibilityHighlight") then
        PlayerValues.ChangeValues(LocalPlayer, "VisibleObject", Object)
        local HighlightClone = VisibilityHighlight:Clone()
        HighlightClone.Parent = Object

        for _, p in pairs(Object:GetDescendants()) do
            if p:IsA("BasePart") then
                local HighlightClone2 = VisibilityHighlight:Clone()
                HighlightClone2.Parent = p
            end
        end
    elseif not state then
        PlayerValues.ChangeValues(LocalPlayer, "VisibleObject", nil)
        local HighlightClone = Object:FindFirstChild("VisibilityHighlight")
        if HighlightClone then
            HighlightClone:Destroy()
        end

        for _, p in pairs(Object:GetDescendants()) do
            if p:IsA("BasePart") then
                local HighlightClone2 = p:FindFirstChild("VisibilityHighlight")
                if HighlightClone2 then
                    HighlightClone2:Destroy()
                end
            end
        end
    end
end

ProximityPromptService.PromptShown:Connect(function(prompt)
    toggleObjectHighlight(prompt, true)
end)

ProximityPromptService.PromptHidden:Connect(function(prompt)
    toggleObjectHighlight(prompt, false)
end)]]--