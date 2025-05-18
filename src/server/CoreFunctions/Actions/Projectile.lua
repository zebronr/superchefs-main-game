local module = {}

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Prompts = require(Modules:WaitForChild("Prompts"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ProjectileRemotes = Remotes:WaitForChild("Projectile")
local SimulateProjectileClient = ProjectileRemotes:WaitForChild("SimulateProjectile")
local EffectsRemote = Remotes:WaitForChild("Effects")

local InteractionRemotes = Remotes:WaitForChild("Interactions")
local InteractionRequestFunction = InteractionRemotes:WaitForChild("InteractionRequestFunction")

local distance = 30
local height = 7
local speed = 45
local gravity = 20

local function _testPart(pos, color)
    local testPart = Instance.new("Part")
    testPart.BrickColor = color
    testPart.Size = Vector3.new(1,1,1)
    testPart.Position = pos
    testPart.CanCollide = false
    testPart.CanTouch = false
    testPart.CanQuery = false
    testPart.Parent = workspace
end

local function stopProjectile(Projectile, newCFrame)
    Projectile.CFrame = newCFrame
    Projectile.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
    Projectile.Anchored = false
    Prompts.TogglePrompt(Projectile, true)
    EffectsRemote:FireAllClients("ProjectileTrail", {
        s = false,
        r = Projectile
    })
end

local function checkCollision(objectCFrame, player, projectile)
    local character = player.Character or player.CharacterAdded:Wait()
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {character, projectile, CollectionService:GetTagged("projectileInteractionLock")}

    local startingPoint = objectCFrame.Position
    for y = -45, 45, 45 do
        local endPoint = (objectCFrame * CFrame.new(0,y,-100)).Position
        local direction = endPoint - startingPoint
        local raycast = workspace:Raycast(startingPoint, direction, params)
        if raycast then
            if (raycast.Position-objectCFrame.Position).Magnitude <= 3 then
                return true
            end
        end
    end
end

local function checkFloor(projectile, objectCFrame)
    --[[local startingPoint = objectCFrame.Position
    local endPoint = (objectCFrame * CFrame.new(0,-100,0)).Position
    local direction = endPoint - startingPoint
    local raycast = workspace:Raycast(startingPoint, direction)
    if raycast then
        if (raycast.Position-objectCFrame.Position).Magnitude <= projectile.Size.Y/2 + .05 then
            return true
        end
    end]]--
end

local function getSurface(objectCFrame)
    local startingPoint = objectCFrame.Position
    local endPoint = (objectCFrame * CFrame.new(0,-100,0)).Position
    local direction = endPoint - startingPoint
    local raycast = workspace:Raycast(startingPoint, direction)
    if raycast then
        return raycast.Position
    end
end

local function checkInteraction(objectCFrame)
    local startingPoint = objectCFrame.Position
    local endPoint = (objectCFrame * CFrame.new(0,-100,0)).Position
    local direction = endPoint - startingPoint
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances = CollectionService:GetTagged("throwInteractable")
    local raycast = workspace:Raycast(startingPoint, direction, params)
    if raycast and raycast.Instance:GetAttribute("objectClass") then
        return raycast.Instance
    end
end

function module.CalculateEndpoint(projectile, startingCF)
    local endPoint = startingCF * CFrame.new(0,0, -distance)

    local origin = endPoint.Position
    local raycastEndpoint = origin - Vector3.new(0,100,0)
    local raycastDirection = raycastEndpoint - origin

    local floorRaycast = workspace:Raycast(origin, raycastDirection)
    
    if floorRaycast then
        endPoint = CFrame.new(floorRaycast.Position + Vector3.new(0,projectile.Size.Y/2,0))
    end

    return endPoint
end

function module.SimulateProjectile(Projectile, startingCF:CFrame, endPoint, player)
    local startingPosition = startingCF.Position    
    local endPosition = endPoint.Position
    local midPosition = startingPosition:Lerp(endPosition, .5) + Vector3.new(0,height,0)

    local t = 0

    local totalDistance = (startingPosition - midPosition).Magnitude + (midPosition - endPosition).Magnitude
    local totalTime = totalDistance / speed

    Projectile.Anchored = true

    SimulateProjectileClient:FireAllClients("simulate", {
        sCF = startingCF,
        eP = endPosition,
        s = speed,
        h = height,
        p = Projectile,
        sT = tick()
    })

    EffectsRemote:FireAllClients("ProjectileTrail", {
        s = true,
        r = Projectile
    })

    local serverSimulation
    serverSimulation = RunService.Heartbeat:Connect(function(deltaTime)
        t += deltaTime / totalTime

        local a = startingPosition:Lerp(midPosition, t)
        local b = midPosition:Lerp(endPosition, t)
        local x = a:Lerp(b,t)

        local newCFrame = CFrame.new(x) * (startingCF - startingCF.Position)
        local collision = checkCollision(newCFrame, player, Projectile)
        local floor = checkFloor(Projectile, newCFrame)

        if t >= 1 or collision or floor then
            --print(collision, floor)
            serverSimulation:Disconnect()

            local interactionFailed
            local interactionObject

            if collision or floor then
                interactionObject = checkInteraction(newCFrame)
            end

            SimulateProjectileClient:FireAllClients("stop", {
                p = Projectile
            })

            if collision then
                local surface = getSurface(newCFrame)
                if surface then
                    local floorPosition = surface + Vector3.new(0,Projectile.Size.Y/2,0)

                    local collisionPoint = newCFrame
    
                    SimulateProjectileClient:FireAllClients("fall", {
                        p = Projectile,
                        e = floorPosition,
                        sCF = startingCF,
                        g = gravity,
                        t = true,
                        cP = collisionPoint,
                        sT = tick()
                    })
                    local fallSimulation 
    
                    local totalDistance = (newCFrame.Position-floorPosition).Magnitude
                    local totalTime = totalDistance / gravity
    
                    local f = 0
                    fallSimulation = RunService.Heartbeat:Connect(function(deltaTime)
                        f += deltaTime / totalTime
                        local y = collisionPoint.Position:Lerp(floorPosition, f)
                        newCFrame = CFrame.new(y) * (startingCF - startingCF.Position)
                        
                        if f >= 1 then
                            fallSimulation:Disconnect()
                            SimulateProjectileClient:FireAllClients("fall", {
                                p = Projectile,
                                t = false
                            })
                            stopProjectile(Projectile, newCFrame)
                            if interactionObject then
                                interactionFailed = InteractionRequestFunction:Invoke(nil, "Interact", {
                                    oC = Projectile,
                                    vO = interactionObject
                                })
                                if not interactionFailed then
                                    return
                                end
                            end
                        end
                    end)
                else
                    stopProjectile(Projectile, newCFrame)
                end
            else
                stopProjectile(Projectile, newCFrame)
            end
        end
    end)
end

return module