local module = {}

local InteractionPrompts = require(script.Parent.Parent:WaitForChild("InteractionPrompt"))

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
    local character = player.Character or player.CharacterAdded:Wait()
    local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

    local objectOffset = object:GetAttribute("holdingOffset") or Vector3.new(0,0,0)
    
    InteractionPrompts.TogglePrompt(object, false)
    changeObjectCarried(player, object)

    local weldConstraint = Instance.new("WeldConstraint")
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
        local object = objectHolder.Part1
        changeObjectCarried(player, nil)
        objectHolder:Destroy()
        object.CanCollide = true
        coroutine.wrap(function() 
            if not dontEnable then
                task.wait(.5)
                InteractionPrompts.TogglePrompt(object, true)
            end
        end)()
    end
end

return module