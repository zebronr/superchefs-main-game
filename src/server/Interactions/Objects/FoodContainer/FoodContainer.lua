local module = {}

local ServerScriptService = game:GetService("ServerScriptService")

local CoreFunctions = ServerScriptService:WaitForChild("Server"):WaitForChild("CoreFunctions")
local Actions = CoreFunctions:WaitForChild("Actions")

local ObjectAction = require(Actions:WaitForChild("ObjectAction"))

function module.Interact(player, objectCarried, visibleObject)
    if not objectCarried and visibleObject then
        local foodValue = visibleObject:WaitForChild("Food").Value

        local foodClone = foodValue:Clone()
        foodClone:WaitForChild("InteractionPrompt").Enabled = false
        foodClone.Parent = workspace:WaitForChild("$GAME")

        ObjectAction.PickupObject(player, foodClone)
    end 
end

return module