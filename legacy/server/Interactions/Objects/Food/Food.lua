local module = {}

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CoreFunctions = ServerScriptService:WaitForChild("Server"):WaitForChild("CoreFunctions")
local Actions = CoreFunctions:WaitForChild("Actions")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SoundsRemotes = Remotes:WaitForChild("Sounds")

local PlayRE = SoundsRemotes:WaitForChild("Play")

local ObjectAction = require(Actions:WaitForChild("ObjectAction"))

function module.Interact(player, objectCarried, visibleObject)
    PlayRE:FireAllClients("Interact")
    if not objectCarried and visibleObject then
        ObjectAction.PickupObject(player, visibleObject)
    elseif objectCarried and not visibleObject then
        ObjectAction.DropObject(player)
    elseif objectCarried and objectCarried:GetAttribute("objectClass") == "Food" and visibleObject and visibleObject:GetAttribute("objectClass") == "Food" then
        ObjectAction.DropObject(player)
        ObjectAction.PickupObject(player, visibleObject)
    end
end

return module