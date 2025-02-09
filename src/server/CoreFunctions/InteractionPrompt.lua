local module = {}

function module.TogglePrompt(object, state)
    local objectPrompt = object:WaitForChild("InteractionPrompt")

    objectPrompt.Enabled = state
    objectPrompt:SetAttribute("GloballyEnabled", state)
end

return module