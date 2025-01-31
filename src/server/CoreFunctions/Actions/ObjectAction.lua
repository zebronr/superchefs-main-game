local ObjectAction = {}

local InteractionPrompts = require(script.Parent.Parent:WaitForChild("InteractionPrompt"))

local pickupZSpace = 2

local function changeObjectCarried(player, value)
    local playerValues = player:WaitForChild("PlayerValues")
    local objectCarried = playerValues:WaitForChild("ObjectCarried")
    objectCarried.Value = value
end

function ObjectAction.GetValue(player, valueName)
    local playerValues = player:WaitForChild("PlayerValues")
    local objectCarried = playerValues:FindFirstChild(valueName)
    return objectCarried.Value
end

function ObjectAction.PickupObject(player:Player, object:BasePart)
    local character = player.Character or player.CharacterAdded:Wait()
    local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
    
    InteractionPrompts.TogglePrompt(object, false)
    changeObjectCarried(player, object)

    local weldConstraint = Instance.new("WeldConstraint")
    weldConstraint.Name = "ObjectHolder"
    weldConstraint.Parent = humanoidRootPart
    weldConstraint.Part0 = humanoidRootPart

    object.CanCollide = false
    object.CFrame = humanoidRootPart.CFrame * CFrame.new(0,0,-pickupZSpace)

    weldConstraint.Part1 = object
end

function ObjectAction.DropObject(player:Player, dontEnable)
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

return ObjectAction