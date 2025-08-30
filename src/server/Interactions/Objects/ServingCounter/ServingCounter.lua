local module = {}

local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bindables = ServerStorage:WaitForChild("Bindables")
local CompleteOrderBE = Bindables:WaitForChild("CompleteOrder")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local EffectsRemotes = Remotes:WaitForChild("Effects")
local EffectsRE = EffectsRemotes:WaitForChild("Effects")

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
    elseif objectCarried and objectCarried:GetAttribute("objectClass") == "Food" and string.find(objectCarried.Name, "chopped_") then
        EffectsRE:FireClient(player, "objectNotif", {
            t = "NEEDS PLATE!",
            o = servingCounter
        })
    end
end

return module