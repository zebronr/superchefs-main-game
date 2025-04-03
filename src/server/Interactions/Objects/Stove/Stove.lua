local module = {}

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local EffectsRemote = Remotes:WaitForChild("Effects")

local InteractionModules = ServerScriptService:WaitForChild("Server"):WaitForChild("Interactions")
local CoreFunctions = ServerScriptService:WaitForChild("Server"):WaitForChild("CoreFunctions")

local Welds = require(CoreFunctions:WaitForChild("Welds"))

local CountertopModule = require(InteractionModules:WaitForChild("Objects"):WaitForChild("Countertop"):WaitForChild("Countertop"))
local CookingToolModule = require(InteractionModules:WaitForChild("Objects"):WaitForChild("CookingTool"):WaitForChild("CookingTool"))

local cookingToolClassesAllowed = {"Pot", "Pan"}

function module.Interact(player, objectCarried, stove)
    local objectOnTopI = Welds.isObjectOnTop(stove)
    CountertopModule.Interact(player, objectCarried, stove)
    local objectOnTopF = Welds.isObjectOnTop(stove)

    if not objectOnTopI and objectOnTopF and objectOnTopF:GetAttribute("objectClass") == "CookingTool" and objectOnTopF:GetAttribute("cookingToolClass") and table.find(cookingToolClassesAllowed, objectOnTopF:GetAttribute("cookingToolClass")) then
        CookingToolModule.ToolEnabled[objectOnTopF] = true
        CookingToolModule.startCooking(objectOnTopF)
    elseif not objectOnTopF and objectOnTopI and objectOnTopI:GetAttribute("objectClass") == "CookingTool" and objectOnTopI:GetAttribute("cookingToolClass") and table.find(cookingToolClassesAllowed, objectOnTopI:GetAttribute("cookingToolClass")) then
        CookingToolModule.stopCooking(objectOnTopI)
        EffectsRemote:FireAllClients("cancel", {o = objectOnTopI})
        CookingToolModule.ToolEnabled[objectOnTopI] = nil
    end
end

return module