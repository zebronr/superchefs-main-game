local module = {}

local ServerScriptService = game:GetService("ServerScriptService")

local CoreFunctions = ServerScriptService:WaitForChild("Server"):WaitForChild("CoreFunctions")
local Actions = CoreFunctions:WaitForChild("Actions")

local ObjectAction = require(Actions:WaitForChild("ObjectAction"))

function module.Interact(player, objectCarried, visibleObject)
    if not objectCarried and visibleObject then
        ObjectAction.PickupObject(player, visibleObject)
    elseif objectCarried and not visibleObject then
        ObjectAction.DropObject(player)
    elseif objectCarried and objectCarried:GetAttribute("objectClass") == "Food" and visibleObject and visibleObject:GetAttribute("objectClass") == "Food" then
        ObjectAction.DropObject(player)
        ObjectAction.PickupObject(player, visibleObject)
    end
end

return module