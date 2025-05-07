local module = {}

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local EffectsRemote = Remotes:WaitForChild("Effects")

local CoreFunctions = ServerScriptService:WaitForChild("Server"):WaitForChild("CoreFunctions")
local Actions = CoreFunctions:WaitForChild("Actions")

local ObjectAction = require(Actions:WaitForChild("ObjectAction"))

module.ProximitySensitive = true

local State = {}

function module.Interact(player, objectCarried, visibleObject)
    if not objectCarried and visibleObject then
        ObjectAction.PickupObject(player, visibleObject)
    elseif objectCarried and not visibleObject then
        ObjectAction.DropObject(player)
    end
end

function module.Use(player, objectCarried, visibleObject, heldState)
    if objectCarried and objectCarried:GetAttribute("objectClass") == "FireExtinguisher" then

        warn(heldState)
        if heldState then
            EffectsRemote:FireAllClients("FEFoam", {fe = objectCarried, s = true})
        else
            EffectsRemote:FireAllClients("FEFoam", {fe = objectCarried, s = false})
        end

    end
end

return module