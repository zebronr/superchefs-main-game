local module = {}

local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local Bindables = ServerStorage:WaitForChild("Bindables")
local CompleteOrderBE = Bindables:WaitForChild("CompleteOrder")

local CoreFunctions = ServerScriptService:WaitForChild("Server"):WaitForChild("CoreFunctions")
local Objectaction = require(CoreFunctions:WaitForChild("Actions"):WaitForChild("ObjectAction"))

local Objects = ServerScriptService:WaitForChild("Server"):WaitForChild("Interactions"):WaitForChild("Objects")
local PlateModule = require(Objects:WaitForChild("Plate"):WaitForChild("Plate"))

function module.Interact(player, objectCarried, servingCounter)
    if objectCarried and objectCarried:GetAttribute("objectClass") == "Plate" then
        if PlateModule.PlateContent[objectCarried] and PlateModule.PlateContent[objectCarried][1] then
            local plateContent = PlateModule.PlateContent[objectCarried][1]
            CompleteOrderBE:Fire(player, plateContent)
            Objectaction.DropObject(player, true)
            objectCarried:Destroy()
        end
    end
end

return module