local Countertop = {}

local ServerScriptService = game:GetService("ServerScriptService")
local CoreFunctions = ServerScriptService:WaitForChild("Server"):WaitForChild("CoreFunctions")
local Actions = CoreFunctions:WaitForChild("Actions")
local InteractionsModules  = ServerScriptService:WaitForChild("Server"):WaitForChild("Interactions")

local Welds = require(CoreFunctions:WaitForChild("Welds"))
local ObjectAction = require(Actions:WaitForChild("ObjectAction"))
local InteractionPrompt = require(CoreFunctions:WaitForChild("InteractionPrompt"))

function Countertop.Use(player, objectCarried, countertop, heldState)
    print("Countertop", heldState)
end

function Countertop.Interact(player, objectCarried, countertop)
    print("COUNTERTOP INTERACT", player, objectCarried, countertop)
    local objectOnTop = Welds.isObjectOnTop(countertop)
    if objectCarried then
        if not objectOnTop then
            if player then
                ObjectAction.DropObject(player, true)
            else
                InteractionPrompt.TogglePrompt(objectCarried, false)
            end
            Welds.PlaceObjectOnTop(objectCarried, countertop)
        elseif objectOnTop then
            if player then
                if objectCarried:GetAttribute("objectClass") == objectOnTop:GetAttribute("objectClass") then
                    Welds.unweldObjectOnTop(countertop)
                    ObjectAction.DropObject(player, true)
                    Welds.PlaceObjectOnTop(objectCarried, countertop)
                    ObjectAction.PickupObject(player, objectOnTop)
                else
                    local objectCarried_pL = objectCarried:GetAttribute("interactionPriority") or 1
                    local objectOnTop_pL = objectOnTop:GetAttribute("interactionPriority") or 1
                    
                    local objectToInteractWith = objectOnTop
                    local objectToUseForInteraction = objectCarried
                    if objectCarried_pL > objectOnTop_pL then
                        objectToInteractWith = objectCarried
                        objectToUseForInteraction = objectOnTop
                    end

                    print(objectToInteractWith:GetAttribute("objectClass"))
                    local subInteraction = InteractionsModules:WaitForChild("Objects"):FindFirstChild(objectToInteractWith:GetAttribute("objectClass"))
                    subInteraction = require(subInteraction:FindFirstChild(subInteraction.Name))

                    subInteraction.Interact(player, objectToUseForInteraction, objectToInteractWith)
                end
            else
                return true
            end
        end
    elseif not objectCarried then
        if objectOnTop then
            Welds.unweldObjectOnTop(countertop)
            if player then 
                ObjectAction.PickupObject(player, objectOnTop)
            end
        end
    end
end

return Countertop