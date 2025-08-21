local module = {}

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CoreFunctions = ServerScriptService:WaitForChild("Server"):WaitForChild("CoreFunctions")
local Actions = CoreFunctions:WaitForChild("Actions")
local Shared = ReplicatedStorage:WaitForChild("Modules")

local ToggleInteraction = require(Shared:WaitForChild("ToggleInteraction"))
local Welds = require(CoreFunctions:WaitForChild("Welds"))
local ObjectAction = require(Actions:WaitForChild("ObjectAction"))

function module.findHighestStack(origin)
    local current = origin
    local belowTop = nil

    while true do
        local above = Welds.isObjectOnTop(current)
        if not above then
            break
        end
        belowTop = current
        current = above
    end

    return current, belowTop
end

function module.countStack(origin)
    local count = 1
    local current = origin

    while true do
        local above = Welds.isObjectOnTop(current)
        if not above then
            break
        end
        count += 1
        current = above
    end

    return count
end

function module.takeHighestPlate(origin, unweld)
    local highest, _ = module.findHighestStack(origin)

    if unweld then
        Welds.unweldFromSurface(highest)
        origin.Parent = workspace:WaitForChild("$GAME")
    end

    return highest
end

function module.stackPlates(origin, newPlate)
    local highestStack = module.findHighestStack(origin)

    ToggleInteraction.Set(newPlate, false)

    newPlate.Parent = origin

    Welds.PlaceObjectOnTop(newPlate, highestStack)
end

function module.Interact(player, objectCarried, visibleObject)
    if not objectCarried and visibleObject then
        ObjectAction.PickupObject(player, visibleObject)
    elseif objectCarried and not visibleObject then
        ObjectAction.DropObject(player)
    elseif objectCarried and objectCarried:GetAttribute("objectClass") == "DirtyPlate" and visibleObject and visibleObject:GetAttribute("objectClass") == "DirtyPlate" then
        module.stackPlates(objectCarried, visibleObject)
    end
end

return module