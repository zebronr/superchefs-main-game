local module = {}

local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local CoreFunctions = ServerScriptService:WaitForChild("Server"):WaitForChild("CoreFunctions")
local Interactions = ServerScriptService:WaitForChild("Server"):WaitForChild("Interactions")
local Objects = Interactions:WaitForChild("Objects")

local DirtyPlateModule = require(Objects:WaitForChild("DirtyPlate"):WaitForChild("DirtyPlate"))
local PlateModule = require(Objects:WaitForChild("Plate"):WaitForChild("Plate"))

local Welds = require(CoreFunctions:WaitForChild("Welds"))
local ObjectAction = require(CoreFunctions:WaitForChild("Actions"):WaitForChild("ObjectAction"))

local Assets = ServerStorage:WaitForChild("Assets")
local DirtyPlate = Assets:WaitForChild("Plates"):WaitForChild("DirtyPlate")
local Plate = Assets:WaitForChild("Plates"):WaitForChild("Plate")

function module.AddPlate(plateTable, delay, dirty)
    task.delay(delay or 1.5, function()
        print("addingPlate!!")
        local clonePlate
        if dirty then
            clonePlate = DirtyPlate:Clone()
        else
            clonePlate = Plate:Clone()
        end

        clonePlate.Parent = workspace["$GAME"]
        
        local objectOnTop = Welds.isObjectOnTop(plateTable)

        if objectOnTop then
            DirtyPlateModule.stackPlates(objectOnTop, clonePlate)
        else
            Welds.PlaceObjectOnTop(clonePlate, plateTable)
        end
    end)
end

function module.Interact(player, objectCarried, plateTable)
    local objectOnTop = Welds.isObjectOnTop(plateTable)

    if objectOnTop and objectOnTop:GetAttribute("objectClass") == "Plate" then
        if objectCarried then
            local highestStack = DirtyPlateModule.findHighestStack(objectOnTop)
            PlateModule.Interact(player, objectCarried, highestStack)
        else
            local highestStack = DirtyPlateModule.takeHighestPlate(objectOnTop, true)
            ObjectAction.PickupObject(player, highestStack)
        end
    elseif objectOnTop and objectOnTop:GetAttribute("objectClass") == "DirtyPlate" then
        Welds.unweldObjectOnTop(plateTable)
        ObjectAction.PickupObject(player, objectOnTop)
    end
end

return module