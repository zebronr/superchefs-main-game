local module = {}

function module.Set(object, state)
    object:SetAttribute("interactionDisabled", not state)
end

return module