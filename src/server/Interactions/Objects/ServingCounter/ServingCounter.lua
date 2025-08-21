local module = {}

local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local Bindables = ServerStorage:WaitForChild("Bindables")
local CompleteOrderBE = Bindables:WaitForChild("CompleteOrder")

local Objects = ServerScriptService:WaitForChild("Server"):WaitForChild("Interactions"):WaitForChild("Objects")
local PlateModule = require(Objects:WaitForChild("Plate"):WaitForChild("Plate"))

function module.Interact(player, objectCarried, servingCounter)
    if objectCarried and objectCarried:GetAttribute("objectClass") == "Plate" then
        if PlateModule.PlateContent[objectCarried] and PlateModule.PlateContent[objectCarried][1] then
            local plateContent = PlateModule.PlateContent[objectCarried][1]
            CompleteOrderBE:Fire(player, plateContent)
        end
    end
end

return module