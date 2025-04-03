local module = {}

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ProgressBarRemote = Remotes:WaitForChild("ProgressBar")

local InteractionModules = ServerScriptService:WaitForChild("Server"):WaitForChild("Interactions")
local Shared = ReplicatedStorage:WaitForChild("Modules")
local CoreFunctions = ServerScriptService:WaitForChild("Server"):WaitForChild("CoreFunctions")
local Actions = CoreFunctions:WaitForChild("Actions")

local Cache = require(Shared:WaitForChild("Cache"))
local FoodTreeModule = require(InteractionModules:WaitForChild("Objects"):WaitForChild("Plate"):WaitForChild("FoodTree"))
local ObjectAction = require(Actions:WaitForChild("ObjectAction"))

local FoodContent = Cache.RegisterCache(`{script.Name}_FoodContent`)
local CookingProgress = Cache.RegisterCache(`{script.Name}_FoodContent`)
local CookedState = Cache.RegisterCache(`{script.Name}_CookedState`)
local CookingState = Cache.RegisterCache(`{script.Name}_CookingState`)
local BurningDelayThreads = Cache.RegisterCache(`{script.Name}_BurningDelayThreads`)
module.ToolEnabled = Cache.RegisterCache(`{script.Name}_ToolEnabled`)

local ProgressRate = 20 -- per second
local SafeTime = 5  
local AlertDuration = 5
local progressDeduction = 50

function module.startCooking(cookingTool)
    if not (FoodContent[cookingTool] and #FoodContent[cookingTool] >= 1) or CookingState[cookingTool] or not module.ToolEnabled[cookingTool] then return end

    if BurningDelayThreads[cookingTool] then
        task.cancel(BurningDelayThreads[cookingTool])
        BurningDelayThreads[cookingTool] = nil
    end

    CookingProgress[cookingTool] = CookingProgress[cookingTool] or 0
    CookingState[cookingTool] = true

    ProgressBarRemote:FireAllClients("CookingProgress", {
        pR = ProgressRate,
        s = true,
        o = cookingTool,
        sT = tick(),
        pA = CookingProgress[cookingTool],
        sIT = SafeTime,
        aD = AlertDuration
    })
    while not (CookingProgress[cookingTool] >= 100) and CookingState[cookingTool] do
        local dt = RunService.Heartbeat:Wait()
        CookingProgress[cookingTool] += dt*ProgressRate
    end
    if CookingProgress[cookingTool] >= 100 then
        warn("DONE ON SERVER!")
        CookedState[cookingTool] = true
        BurningDelayThreads[cookingTool] = task.delay(SafeTime+AlertDuration, function()
            warn("BURNING")
        end)
    end
end 

function module.stopCooking(cookingTool)
    if not CookingState[cookingTool] then return end

    CookingState[cookingTool] = nil
    local delete
    if CookingProgress[cookingTool] >= 100 then delete = true end

    ProgressBarRemote:FireAllClients("CookingProgress", {
        s = false,
        o = cookingTool,
        d = delete
    })
    if BurningDelayThreads[cookingTool] then
        task.cancel(BurningDelayThreads[cookingTool])
        BurningDelayThreads[cookingTool] = nil
    end
end

local function PutFoodInTool(cookingTool, food, player)
    print(`putting {food.Name} in {cookingTool.Name}`)

    local toolClass = script.Parent:WaitForChild("Classes"):FindFirstChild(cookingTool:GetAttribute("cookingToolClass"))
    if toolClass then
        toolClass = require(toolClass)

        FoodContent[cookingTool] = FoodContent[cookingTool] or {}
        
        local cachedContent = table.clone(FoodContent[cookingTool]) 
        table.insert(cachedContent, food.Name)

        warn(cachedContent)

        local combination = FoodTreeModule.CheckCombination(cachedContent, toolClass.Combinations)
        if combination then
            FoodContent[cookingTool] = {combination}

            if player then
                if ObjectAction.GetValue(player, "ObjectCarried"):GetAttribute("objectClass") == "Food" then
                    ObjectAction.DropObject(player, true)
                end
            end
            food.Parent = nil
    
            if toolClass.Display then
                toolClass.Display(cookingTool, FoodContent[cookingTool])
            end
    
            for _, p in pairs(food:GetConnectedParts()) do
                if p ~= food then
                    local w = p:FindFirstChild("objectTopWelder")
                    if w then
                        w:Destroy()
                    end
                end
            end
            food:Destroy()

            if CookingProgress[cookingTool] then
                if CookingProgress[cookingTool] >= progressDeduction then
                    CookingProgress[cookingTool] -= progressDeduction
                else
                    CookingProgress[cookingTool] = 0
                end
                ProgressBarRemote:FireAllClients("changeProgress", {
                    p = CookingProgress[cookingTool],
                    o = cookingTool,
                    sT = tick(),
                    pR = ProgressRate
                })
            end

            module.startCooking(cookingTool)
        end
    end
end

local function PlateFood(cookingTool, plate)
    print(`plating {cookingTool.Name}`)
end

function module.Interact(player, objectCarried, visibleObject)
    if not objectCarried and visibleObject then
        ObjectAction.PickupObject(player, visibleObject)
    elseif objectCarried and not visibleObject then
        ObjectAction.DropObject(player)
    elseif objectCarried and visibleObject then
        if objectCarried:GetAttribute("objectClass") == "CookingTool" and visibleObject:GetAttribute("objectClass") == "Food" then
            PutFoodInTool(objectCarried, visibleObject, player)
        elseif visibleObject:GetAttribute("objectClass") == "CookingTool" and objectCarried:GetAttribute("objectClass") == "Food" then
            PutFoodInTool(visibleObject, objectCarried, player)
        elseif visibleObject:GetAttribute("objectClass") == "CookingTool" and objectCarried:GetAttribute("objectClass") == "Plate" then
            PlateFood(visibleObject, objectCarried)
        elseif objectCarried:GetAttribute("objectClass") == "CookingTool" and visibleObject:GetAttribute("objectClass") == "Plate" then
            PlateFood(objectCarried, visibleObject)
        end
    end
end

return module