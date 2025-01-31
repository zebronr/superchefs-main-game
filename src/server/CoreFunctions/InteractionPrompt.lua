local InteractionPrompt = {}

function InteractionPrompt.TogglePrompt(object, state)
    local objectPrompt = object:WaitForChild("InteractionPrompt")

    objectPrompt.Enabled = state
    objectPrompt:SetAttribute("GloballyEnabled", state)
end

return InteractionPrompt