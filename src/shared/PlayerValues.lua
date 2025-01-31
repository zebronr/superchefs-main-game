local PlayerValues = {}

function PlayerValues.ChangeValues(player, valueName, value)
    local PlayerValuesFolder = player:WaitForChild("PlayerValues")
    local valueObject = PlayerValuesFolder:FindFirstChild(valueName)
    if valueObject then
        valueObject.Value = value
    end
end

function PlayerValues.RetrieveValue(player, valueName)
    local PlayerValuesFolder = player:WaitForChild("PlayerValues")
    local valueObject = PlayerValuesFolder:FindFirstChild(valueName)
    if valueObject then
        return valueObject.Value
    end
    return
end

return PlayerValues