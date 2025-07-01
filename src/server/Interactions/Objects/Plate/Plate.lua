local module = {}

local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CoreFunctions = ServerScriptService:WaitForChild("Server"):WaitForChild("CoreFunctions")
local Actions = CoreFunctions:WaitForChild("Actions")
local Shared = ReplicatedStorage:WaitForChild("Modules")

local Assets = ServerStorage:WaitForChild("Assets")
local FoodModels = Assets:WaitForChild("Foods")
local PlatedFoods = FoodModels:WaitForChild("PlatedFoods")

local ObjectAction = require(Actions:WaitForChild("ObjectAction"))
local Welds = require(CoreFunctions:WaitForChild("Welds"))
local Cache = require(Shared:WaitForChild("Cache"))
local FoodTree = require(script.Parent:WaitForChild("FoodTree"))

local PlateContent = Cache.RegisterCache(`{script.Name}_PlateContent`)

local function plateFood(plate, food, player)
    local platedFood

    PlateContent[plate] = PlateContent[plate] or {}

    if #PlateContent[plate] == 0 then
        --print(PlatedFoods:GetChildren(), "plated_"..food.Name)
        platedFood = PlatedFoods:FindFirstChild("plated_"..food.Name)
    elseif #PlateContent[plate] >= 1 then
        local cachedContent = table.clone(PlateContent[plate])
        table.insert(cachedContent, food.Name)

        local combination = FoodTree.CheckCombination(cachedContent)
        if combination then
            platedFood = PlatedFoods:FindFirstChild("plated_"..combination)
        end
    end
    if platedFood then
        platedFood = platedFood:Clone()
        platedFood.Parent = plate

        local foodImage = food:WaitForChild("FoodList")
        foodImage:WaitForChild("ImageLabel").Parent = plate:WaitForChild("FoodList")

        if player then
            if ObjectAction.GetValue(player, "ObjectCarried"):GetAttribute("objectClass") == "Food" then
                ObjectAction.DropObject(player, true)
            end
        end

        for _, p in pairs(food:GetConnectedParts()) do
            if p ~= food then
                local w = p:FindFirstChild("objectTopWelder")
                if w then
                    w:Destroy()
                end
            end
        end

        food.Parent = nil

        PlateContent[plate] = {food.Name}
        local foodOnTop = Welds.isObjectOnTop(plate)
        if foodOnTop then
            Welds.unweldObjectOnTop(plate)
            foodOnTop:Destroy()
        end
        Welds.PlaceObjectOnTop(platedFood, plate, platedFood:GetAttribute("yOffset"))

        food:Destroy()
    end
end

function module.Interact(player, objectCarried, visibleObject)
    if not objectCarried and visibleObject then
        ObjectAction.PickupObject(player, visibleObject)
    elseif objectCarried and not visibleObject then
        ObjectAction.DropObject(player)
    elseif objectCarried and visibleObject then
        if objectCarried:GetAttribute("objectClass") == "Food" and visibleObject:GetAttribute("objectClass") == "Plate" then
            --print("PUTTING FOOD ON PLATE")
            plateFood(visibleObject, objectCarried, player)
        elseif objectCarried:GetAttribute("objectClass") == "Plate" and visibleObject:GetAttribute("objectClass") == "Food" then
            plateFood(objectCarried, visibleObject, player)
        end
    end
end

return module