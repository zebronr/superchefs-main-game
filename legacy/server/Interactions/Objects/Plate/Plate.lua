local module = {}

local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CoreFunctions = ServerScriptService:WaitForChild("Server"):WaitForChild("CoreFunctions")
local Actions = CoreFunctions:WaitForChild("Actions")
local Shared = ReplicatedStorage:WaitForChild("Modules")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SoundsRemotes = Remotes:WaitForChild("Sounds")

local PlayRE = SoundsRemotes:WaitForChild("Play")

local Assets = ServerStorage:WaitForChild("Assets")
local FoodModels = Assets:WaitForChild("Foods")
local PlatedFoods = FoodModels:WaitForChild("PlatedFoods")

local ObjectAction = require(Actions:WaitForChild("ObjectAction"))
local Welds = require(CoreFunctions:WaitForChild("Welds"))
local Cache = require(Shared:WaitForChild("Cache"))
local FoodTree = require(script.Parent:WaitForChild("FoodTree"))

module.PlateContent = Cache.RegisterCache(`{script.Name}_module.PlateContent`)

function module.clearPlate(plate)
    if not module.PlateContent[plate] then return end
    
    module.PlateContent[plate] = nil

    local food = Welds.isObjectOnTop(plate)
    Welds.unweldObjectOnTop(plate)
    food:Destroy()

    for _, foodImage in pairs(plate:WaitForChild("FoodList"):GetChildren()) do
        if foodImage:IsA("Frame") then
            foodImage:Destroy()
        end
    end
end

local function plateFood(plate, food, player)
    local platedFood
    local combination
    
    module.PlateContent[plate] = module.PlateContent[plate] or {}

    if #module.PlateContent[plate] == 0 then
        --print(PlatedFoods:GetChildren(), "plated_"..food.Name)
        platedFood = PlatedFoods:FindFirstChild("plated_"..food.Name)
    elseif #module.PlateContent[plate] >= 1 then
        local cachedContent = table.clone(module.PlateContent[plate])
        table.insert(cachedContent, food.Name)

        combination = FoodTree.CheckCombination(cachedContent)
        if combination then
            platedFood = PlatedFoods:FindFirstChild("plated_"..combination)
        end
    end
    if platedFood then
        PlayRE:FireAllClients("Interact")

        platedFood = platedFood:Clone()
        platedFood.Parent = plate
        platedFood.CanCollide = false

        local foodImage = food:WaitForChild("FoodList")
        foodImage:WaitForChild("Frame").Parent = plate:WaitForChild("FoodList")

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

        module.PlateContent[plate] = {combination or food.Name}
        local foodOnTop = Welds.isObjectOnTop(plate)
        if foodOnTop then
            Welds.unweldObjectOnTop(plate)
            foodOnTop:Destroy()
        end
        Welds.PlaceObjectOnTop(platedFood, plate, platedFood:GetAttribute("yOffset"))

        food:Destroy()
    end
end

local function mixFood(sourcePlate, targetPlate, player)
    local platedFood
    local combination

    local cachedContent = table.clone(module.PlateContent[sourcePlate])
    for _, f in pairs(module.PlateContent[targetPlate]) do
        table.insert(cachedContent, f)
    end

    combination = FoodTree.CheckCombination(cachedContent)
    if combination then
        platedFood = PlatedFoods:FindFirstChild("plated_"..combination)
    end
    if platedFood then
        PlayRE:FireAllClients("Interact")
        
        platedFood = platedFood:Clone()
        platedFood.Parent = targetPlate
        platedFood.CanCollide = false

        local FoodList = sourcePlate:WaitForChild("FoodList")
        for _, foodImage in pairs(FoodList:GetChildren()) do
            if foodImage:IsA("Frame") then
                foodImage.Parent = targetPlate:WaitForChild("FoodList")
            end
        end

        module.clearPlate(sourcePlate)

        module.PlateContent[targetPlate] = {combination}

        Welds.PlaceObjectOnTop(platedFood, targetPlate, platedFood:GetAttribute("yOffset"))
    end
end

function module.Interact(player, objectCarried, visibleObject)
    if not objectCarried and visibleObject then
        PlayRE:FireAllClients("Interact")
        ObjectAction.PickupObject(player, visibleObject)
    elseif objectCarried and not visibleObject then
        PlayRE:FireAllClients("Interact")
        ObjectAction.DropObject(player)
    elseif objectCarried and visibleObject then
        local objectCarriedClass = objectCarried:GetAttribute("objectClass")
        local visibleObjectClass = visibleObject:GetAttribute("objectClass")

        if objectCarriedClass == "Food" and visibleObjectClass == "Plate" then
            --print("PUTTING FOOD ON PLATE")
            plateFood(visibleObject, objectCarried, player)
        elseif objectCarried:GetAttribute("objectClass") == "Plate" and visibleObject:GetAttribute("objectClass") == "Food" then
            plateFood(objectCarried, visibleObject, player)
        elseif objectCarriedClass == "Plate" and visibleObjectClass == "Plate" then
            local oCPlateContent = module.PlateContent[objectCarried]
            local vOPlateContent = module.PlateContent[visibleObject]
            if (oCPlateContent and not vOPlateContent) or (vOPlateContent and not oCPlateContent) then
                PlayRE:FireAllClients("Interact")
                local surface = Welds.unweldFromSurface(visibleObject)
                if surface then
                    ObjectAction.DropObject(player, true)
                    Welds.PlaceObjectOnTop(objectCarried, surface)
                else
                    ObjectAction.DropObject(player)
                end
                ObjectAction.PickupObject(player, visibleObject)
            elseif oCPlateContent and vOPlateContent then
                mixFood(visibleObject, objectCarried, player)
            end
        end
    end
end

return module