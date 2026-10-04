local module = {}

local ServerScriptService = game:GetService("ServerScriptService")

local CoreFunctions = ServerScriptService:WaitForChild("Server"):WaitForChild("CoreFunctions")
local Actions = CoreFunctions:WaitForChild("Actions")

local Objects = ServerScriptService:WaitForChild("Server"):WaitForChild("Interactions"):WaitForChild("Objects")
local PlateModule = require(Objects:WaitForChild("Plate"):WaitForChild("Plate"))

local ObjectAction = require(Actions:WaitForChild("ObjectAction"))

function module.Interact(player, objectCarried, Trash)
    if objectCarried then
        local objectCarriedClass = objectCarried:GetAttribute("objectClass")

        if objectCarriedClass == "Food" then
            ObjectAction.DropObject(player, true)
            objectCarried:Destroy()
        elseif objectCarriedClass == "Plate" then
            PlateModule.clearPlate(objectCarried)
        end
    end
end

return module