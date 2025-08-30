local module = {}

local ServerScriptService = game:GetService("ServerScriptService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CoreFunctions = ServerScriptService:WaitForChild("Server"):WaitForChild("CoreFunctions")
local Actions = CoreFunctions:WaitForChild("Actions")
local InteractionsModules  = ServerScriptService:WaitForChild("Server"):WaitForChild("Interactions")

local Shared = ReplicatedStorage:WaitForChild("Modules")

local Configs = Shared:WaitForChild("Configs")
local InteractionConfigs = require(Configs:WaitForChild("InteractionConfigs"))

local Welds = require(CoreFunctions:WaitForChild("Welds"))
local ObjectAction = require(Actions:WaitForChild("ObjectAction"))
local ToggleInteraction = require(Shared:WaitForChild("ToggleInteraction"))

function module.Interact(player, objectCarried, countertop)
    --print("COUNTERTOP INTERACT", player, objectCarried, countertop)
    local objectOnTop = Welds.isObjectOnTop(countertop)

    if (objectOnTop and objectOnTop:HasTag("LOCKED")) or countertop:HasTag("LOCKED") or countertop:HasTag("FIRELOCKED") then return end

    if objectCarried then
        if not objectOnTop then
            if player then
                ObjectAction.DropObject(player, true)
            else
                ToggleInteraction.Set(objectCarried, false)
            end
            Welds.PlaceObjectOnTop(objectCarried, countertop)
            CollectionService:AddTag(objectCarried, "projectileInteractionLock")
            return
        elseif objectOnTop then
            if objectCarried:GetAttribute("objectClass") == objectOnTop:GetAttribute("objectClass") then
                if player then
                    Welds.unweldObjectOnTop(countertop)
                    ObjectAction.DropObject(player, true)
                    ObjectAction.PickupObject(player, objectOnTop)
                    Welds.PlaceObjectOnTop(objectCarried, countertop)
                end
                return
            else
                local objectCarried_pL = InteractionConfigs.PriorityLevel[objectCarried:GetAttribute("objectClass")] or 1
                local objectOnTop_pL = InteractionConfigs.PriorityLevel[objectOnTop:GetAttribute("objectClass")] or 1
                    
                local objectToInteractWith = objectOnTop
                local objectToUseForInteraction = objectCarried
                if objectCarried_pL > objectOnTop_pL then
                    objectToInteractWith = objectCarried
                    objectToUseForInteraction = objectOnTop
                end

                --print(objectToInteractWith:GetAttribute("objectClass"))
                local subInteraction = InteractionsModules:WaitForChild("Objects"):FindFirstChild(objectToInteractWith:GetAttribute("objectClass"))
                subInteraction = require(subInteraction:FindFirstChild(subInteraction.Name))
                print(objectToInteractWith)
                subInteraction.Interact(player, objectToUseForInteraction, objectToInteractWith)
                return
            end
        else
            return true
        end
    elseif not objectCarried then
        if objectOnTop then
            Welds.unweldObjectOnTop(countertop)
            if player then 
                ObjectAction.PickupObject(player, objectOnTop)
                CollectionService:RemoveTag(objectOnTop, "projectileInteractionLock")
                return
            end
            return
        end
        return
    end
    return
end

return module