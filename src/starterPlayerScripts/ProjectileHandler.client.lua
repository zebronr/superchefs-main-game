local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ProjectileRemotes = Remotes:WaitForChild("Projectile")
local SimulateProjectileRequest = ProjectileRemotes:WaitForChild("SimulateProjectile")

local requestTypes = {}

local simulation = {}

function requestTypes.simulate(parameters)
    local Projectile = parameters.p
    local startingCF = parameters.sCF
    local startingPosition = startingCF.Position
    local endPosition = parameters.eP
    local height = parameters.h
    local midPosition = startingPosition:Lerp(endPosition, .5) + Vector3.new(0,height,0)
    local speed = parameters.s
    local sentTime = parameters.sT
    local travelTime = tick() - sentTime

    local totalDistance = (startingPosition - midPosition).Magnitude + (midPosition - endPosition).Magnitude
    local totalTime = totalDistance / speed

    local t = 0 + travelTime

    simulation[Projectile] = RunService.Heartbeat:Connect(function(deltaTime)
        t += deltaTime / totalTime

        local a = startingPosition:Lerp(midPosition, t)
        local b = midPosition:Lerp(endPosition, t)
        local x = a:Lerp(b,t)

        local newCFrame = CFrame.new(x) * (startingCF - startingCF.Position)
        Projectile.CFrame = newCFrame

        if t >= 1 then
            simulation[Projectile]:Disconnect()
        end
    end)
end

function requestTypes.fall(parameters)
    local Projectile = parameters.p
    local FloorPosition = parameters.e
    local State = parameters.t
    local startingCF = parameters.sCF
    local gravity = parameters.g
    local collisionPoint = parameters.cP
    local sentTime = parameters.sT

    if State then
        local travelTime = tick() - sentTime
        local f = 0 + travelTime

        local totalDistance = (Projectile.Position-FloorPosition).Magnitude
        local totalTime = totalDistance / gravity

        simulation[Projectile] = RunService.Heartbeat:Connect(function(deltaTime)
            f += deltaTime / totalTime
            local y = collisionPoint.Position:Lerp(FloorPosition, f)
            local newCFrame = CFrame.new(y) * (startingCF - startingCF.Position)
            Projectile.CFrame = newCFrame
        end)
    else
        if simulation[Projectile] then
            simulation[Projectile]:Disconnect()
        end
    end
end

function requestTypes.stop(parameters)
    local Projectile = parameters.p
    if simulation[Projectile] then
        simulation[Projectile]:Disconnect()
    end
end

SimulateProjectileRequest.OnClientEvent:Connect(function(reqType, parameters)
    if requestTypes[reqType] then
        requestTypes[reqType](parameters)
    end
end)