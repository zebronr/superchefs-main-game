local module = {}

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Modules")

local CoreFunctions = ServerScriptService:WaitForChild("Server"):WaitForChild("CoreFunctions")
local Actions = CoreFunctions:WaitForChild("Actions")
local ToggleInteraction = require(Shared:WaitForChild("ToggleInteraction"))

local ObjectAction = require(Actions:WaitForChild("ObjectAction"))

function module.Interact(player, objectCarried, visibleObject)
    if not objectCarried and visibleObject then
        local foodValue = visibleObject:WaitForChild("Food").Value

        local foodClone = foodValue:Clone()
        ToggleInteraction.Set(foodClone, false)
        foodClone.Parent = workspace:WaitForChild("$GAME")

        ObjectAction.PickupObject(player, foodClone)
    end 
end

return module