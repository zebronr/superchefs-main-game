local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")

local _Modules = ReplicatedStorage:WaitForChild("Modules")
local PlayerValues = require(script.Parent:WaitForChild("PlayerValues"))

local Assets = ReplicatedStorage:WaitForChild("Assets")
local VisibilityHighlight = Assets:WaitForChild("VisibilityHighlight")

local function toggleObjectHighlight(prompt, state)
    if prompt.Name ~= "InteractionPrompt" then
        return
    end

    local Object = prompt.Parent
    if state and not Object:FindFirstChild("VisibilityHighlight") then
        PlayerValues.ChangeValues("VisibleObject", Object)
        local HighlightClone = VisibilityHighlight:Clone()
        HighlightClone.Parent = Object
    elseif not state then
        PlayerValues.ChangeValues("VisibleObject", nil)
        local HighlightClone = Object:FindFirstChild("VisibilityHighlight")
        if HighlightClone then
            HighlightClone:Destroy()
        end
    end
end

ProximityPromptService.PromptShown:Connect(function(prompt)
    toggleObjectHighlight(prompt, true)
end)

ProximityPromptService.PromptHidden:Connect(function(prompt)
    toggleObjectHighlight(prompt, false)
end)