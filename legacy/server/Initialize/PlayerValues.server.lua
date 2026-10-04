local Players = game:GetService("Players")

Players.PlayerAdded:Connect(function(player)
    local PlayerValuesFolder = Instance.new("Folder")
    PlayerValuesFolder.Name = "PlayerValues"
    PlayerValuesFolder.Parent = player

    local visibleObject = Instance.new("ObjectValue")
    visibleObject.Name = "VisibleObject"
    visibleObject.Parent = PlayerValuesFolder

    local objectCarried = Instance.new("ObjectValue")
    objectCarried.Name = "ObjectCarried"
    objectCarried.Parent = PlayerValuesFolder

    local visibleObjectNode = Instance.new("ObjectValue")
    visibleObjectNode.Name = "VisibleObjectNode"
    visibleObjectNode.Parent = PlayerValuesFolder
end)