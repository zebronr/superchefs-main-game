local module = {}

function module.GetPrompt(object)
    local prompt = object:FindFirstChild("InteractionPrompt")
    return prompt
end

function module.TogglePrompt(object, state)
    local prompt = module.GetPrompt(object)

    prompt.Enabled = state
    prompt:SetAttribute("GloballyEnabled", state)
end

return module