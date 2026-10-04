local module = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Modules")

local PlayerValues = require(Shared:WaitForChild("PlayerValues"))
local Projectile = require(script.Parent:WaitForChild("Projectile"))
local ObjectAction = require(script.Parent:WaitForChild("ObjectAction"))

local marginOfError = 10

local function verifyThrow(localCFrame, serverCFrame)
    if (localCFrame.Position - serverCFrame.Position).Magnitude <= marginOfError then
        return true
    end
end

function module.ThrowObject(player, localObjectCFrame)
    local objectCarried = PlayerValues.RetrieveValue(player, "ObjectCarried")

    if not objectCarried or objectCarried:GetAttribute("objectClass") ~= "Food" then return end
    if not verifyThrow(localObjectCFrame, objectCarried.CFrame) then return end

    local startingCF = localObjectCFrame
    ObjectAction.DropObject(player, true)
    local endPoint = Projectile.CalculateEndpoint(objectCarried, startingCF)

    Projectile.SimulateProjectile(objectCarried, startingCF, endPoint, player)
end

return module