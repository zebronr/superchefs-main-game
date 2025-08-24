local module = {}

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local EffectsRemotes = Remotes:WaitForChild("Effects")
local EffectsRE = EffectsRemotes:WaitForChild("Effects")

local CoreFunctions = ServerScriptService:WaitForChild("Server"):WaitForChild("CoreFunctions")
local Actions = CoreFunctions:WaitForChild("Actions")

local Shared = ReplicatedStorage:WaitForChild("Modules")

local Cache = require(Shared:WaitForChild("Cache"))
local ObjectAction = require(Actions:WaitForChild("ObjectAction"))

module.ProximitySensitive = true

local maxDistance = 13.5
local deductFire = 10

local toolState = Cache.RegisterCache(`{script.Name}_toolState`)

function module.Interact(player, objectCarried, visibleObject)
    if not objectCarried and visibleObject then
        ObjectAction.PickupObject(player, visibleObject)
    elseif objectCarried and not visibleObject then
        ObjectAction.DropObject(player)
    end
end

function module.Use(player, objectCarried, visibleObject, heldState)
    if objectCarried and objectCarried:GetAttribute("objectClass") == "FireExtinguisher" then

        local extinguisher = objectCarried
        local emitter = extinguisher:WaitForChild("Emitter")
        
        if heldState then
            EffectsRE:FireAllClients("FEFoam", {fe = objectCarried, s = true})

            local raycastParams = RaycastParams.new()
            raycastParams.FilterType = Enum.RaycastFilterType.Exclude
            raycastParams.FilterDescendantsInstances = {CollectionService:GetTagged("IGNORE"), extinguisher:GetDescendants()}

            toolState[extinguisher] = true

            while toolState[extinguisher] do
                for y=-3, -5, -1 do
                    for x=-5, 5, 5 do
                        local origin = emitter.CFrame
                        local endPoint = origin * CFrame.new(x,y,-maxDistance)
                        local rayDirection = endPoint.Position - origin.Position
                        local ray = workspace:Raycast(origin.Position, rayDirection)
                        
                        if ray then 
                            if ray.Instance and ray.Instance:FindFirstChild("fireValue") and (ray.Position - origin.Position).Magnitude <= maxDistance then
                                local fire = ray.Instance:WaitForChild("fireValue")
                                fire.Value -= deductFire
                                if fire.Value <= 0 then
                                    fire:Destroy()
                                    ray.Instance:RemoveTag("LOCKED")
                                end
                            end
                        end
                    end
                end
                task.wait(1)
            end
        else
            
            toolState[extinguisher] = nil
            EffectsRE:FireAllClients("FEFoam", {fe = objectCarried, s = false})
        end

    end
end

return module