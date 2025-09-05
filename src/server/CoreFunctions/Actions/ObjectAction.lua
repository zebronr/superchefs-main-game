local module = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Modules")

local ToggleInteraction = require(Shared:WaitForChild("ToggleInteraction"))
local Cache = require(Shared:WaitForChild("Cache"))

local networkshipResetDelay = Cache.RegisterCache(`{script.Name}_networkshipResetDelay`)

local pickupZSpace = 2

local function changeObjectCarried(player, value)
    local playerValues = player:WaitForChild("PlayerValues")
    local objectCarried = playerValues:WaitForChild("ObjectCarried")
    objectCarried.Value = value
end

function module.GetValue(player, valueName)
    local playerValues = player:WaitForChild("PlayerValues")
    local objectCarried = playerValues:FindFirstChild(valueName)
    return objectCarried.Value
end

function module.PickupObject(player:Player, object:BasePart)
    if networkshipResetDelay[object] then
        task.cancel(networkshipResetDelay[object])
    end

    local character = player.Character or player.CharacterAdded:Wait()
    local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

    object.Massless = true
    object.Anchored = false
    object:SetNetworkOwner(player)

    local objectOffset = object:GetAttribute("holdingOffset") or Vector3.new(0,0,0)
    
    ToggleInteraction.Set(object, false)
    changeObjectCarried(player, object)

    local weldConstraint:WeldConstraint = Instance.new("WeldConstraint")
    weldConstraint.Name = "ObjectHolder"
    weldConstraint.Parent = humanoidRootPart
    weldConstraint.Part0 = humanoidRootPart

    object.CanCollide = false
    object.CFrame = humanoidRootPart.CFrame * CFrame.new(0,0,-pickupZSpace) * CFrame.Angles(math.rad(objectOffset.X), math.rad(objectOffset.Y), math.rad(objectOffset.Z))

    weldConstraint.Part1 = object
end

function module.DropObject(player:Player, dontEnable)
    local character = player.Character or player.CharacterAdded:Wait()
    local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

    local objectHolder = humanoidRootPart:FindFirstChild("ObjectHolder")
    if objectHolder then
        local object:BasePart = objectHolder.Part1
        changeObjectCarried(player, nil)
        objectHolder:Destroy()

        object.Massless = false
        object.Anchored = false
        object:SetNetworkOwner(player)

        object.CanCollide = true
        task.spawn(function() 
            if not dontEnable then
                task.wait(.5)
                ToggleInteraction.Set(object, true)
            end
        end)
        networkshipResetDelay[object] = task.delay(.5, function()
            local _, _ = pcall(function()
                if object:GetNetworkOwner() == player then
                    object:SetNetworkOwner(nil)
                end
                
                object.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            end)
        end)
    end
end

return module