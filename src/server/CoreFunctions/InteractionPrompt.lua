local module = {}

function module.TogglePrompt(object, state)
    local objectPrompt = object:WaitForChild("InteractionPrompt")

    objectPrompt.Enabled = state
end

return module