local module = {}

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InteractionModules = ServerScriptService:WaitForChild("Server"):WaitForChild("Interactions")
local Shared = ReplicatedStorage:WaitForChild("Modules")
local Cache = require(Shared:WaitForChild("Cache"))
local FoodTreeModule = require(InteractionModules:WaitForChild("Objects"):WaitForChild("Plate"):WaitForChild("FoodTree"))

local CoreFunctions = ServerScriptService:WaitForChild("Server"):WaitForChild("CoreFunctions")
local Actions = CoreFunctions:WaitForChild("Actions")

local ObjectAction = require(Actions:WaitForChild("ObjectAction"))

local FoodContent = Cache.RegisterCache(`{script.Name}_FoodContent`)

local function startCooking(cookingTool)

end

local function PutFoodInTool(cookingTool, food)
    print(`putting {food.Name} in {cookingTool.Name}`)
end

local function PlateFood(cookingTool, plate)
    print(`plating {cookingTool.Name}`)
end

function module.Interact(player, objectCarried, visibleObject)
    print("INTERACTING WITH COOKING TOOL", objectCarried)
    if not objectCarried and visibleObject then
        ObjectAction.PickupObject(player, visibleObject)
    elseif objectCarried and not visibleObject then
        ObjectAction.DropObject(player)
    elseif objectCarried and visibleObject then
        if objectCarried:GetAttribute("objectClass") == "CookingTool" and visibleObject:GetAttribute("objectClass") == "Food" then
            PutFoodInTool(objectCarried, visibleObject)
        elseif visibleObject:GetAttribute("objectClass") == "CookingTool" and objectCarried:GetAttribute("objectClass") == "Food" then
            PutFoodInTool(visibleObject, objectCarried)
        elseif visibleObject:GetAttribute("objectClass") == "CookingTool" and objectCarried:GetAttribute("objectClass") == "Plate" then
            PlateFood(visibleObject, objectCarried)
        elseif objectCarried:GetAttribute("objectClass") == "CookingTool" and visibleObject:GetAttribute("objectClass") == "Plate" then
            PlateFood(objectCarried, visibleObject)
        end
    end
end

return module