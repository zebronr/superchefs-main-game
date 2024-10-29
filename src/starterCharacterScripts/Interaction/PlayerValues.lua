PlayerValues = {}

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local PlayerValuesFolder = LocalPlayer:WaitForChild("PlayerValues", 60)

function PlayerValues.ChangeValues(valueName, value)
    local valueObject = PlayerValuesFolder:FindFirstChild(valueName)
    if valueObject then
        valueObject.Value = value
    end
end

function PlayerValues.RetrieveValue(valueName)
    local valueObject = PlayerValuesFolder:FindFirstChild(valueName)
    if valueObject then
        return valueObject.Value
    end
    return
end

return PlayerValues