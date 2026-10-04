local module = {}

local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local InteractionsRemotes = Remotes:WaitForChild("Interactions")
local UpdateVisibilityParametersRE = InteractionsRemotes:WaitForChild("UpdateVisibilityParameters")

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
        --print("addingPlate!!")
        local clonePlate
        if dirty then
            clonePlate = DirtyPlate:Clone()
        else
            clonePlate = Plate:Clone()
        end

        clonePlate.Parent = workspace["$GAME"]
        clonePlate:SetAttribute("interactionDisabled", true)
        UpdateVisibilityParametersRE:FireAllClients()
        
        local objectOnTop = Welds.isObjectOnTop(plateTable)

        if objectOnTop then
            local stackCount = DirtyPlateModule.countStack(objectOnTop)
            if stackCount >= 2 then
                local lastHighestStack = DirtyPlateModule.takeHighestPlate(objectOnTop, true)
                DirtyPlateModule.stackPlates(objectOnTop, clonePlate)
                DirtyPlateModule.stackPlates(objectOnTop, lastHighestStack)
            else
                Welds.unweldObjectOnTop(plateTable)
                Welds.PlaceObjectOnTop(clonePlate, plateTable)
                DirtyPlateModule.stackPlates(clonePlate, objectOnTop)
            end
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
        if not objectCarried then
            Welds.unweldObjectOnTop(plateTable)
            ObjectAction.PickupObject(player, objectOnTop)
        elseif objectCarried:GetAttribute("objectClass") == "DirtyPlate" then
            Welds.unweldObjectOnTop(plateTable)
            DirtyPlateModule.stackPlates(objectCarried, objectOnTop)
        end
    end
end

return module