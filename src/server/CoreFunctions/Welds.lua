local module = {}

function module.isObjectOnTop(surface)
    if surface:FindFirstChild("objectTopWelder") then
        return surface:FindFirstChild("objectTopWelder").Part1
    end
end

function module.unweldObjectOnTop(surface)
    local objectOnTop = module.isObjectOnTop(surface)
    if objectOnTop then
        surface:WaitForChild("objectTopWelder"):Destroy()
    end
end

function module.PlaceObjectOnTop(object, surface, increment)
    increment = increment or 0

    local objectOffset = - ((object:GetAttribute("weldingOffset") or Vector3.new(0,0,0))) + (surface:GetAttribute("directionOffset") or Vector3.new(0,0,0))

    local objectTopWelder = Instance.new("WeldConstraint")
    objectTopWelder.Name = "objectTopWelder"
    objectTopWelder.Parent = surface
    
    local fObjectCFrame = surface.CFrame * CFrame.Angles(math.rad(objectOffset.X), math.rad(objectOffset.Y), math.rad(objectOffset.Z))
    
    local objectCf = fObjectCFrame
    local objectSize = object.Size
    local objectGlobalY = math.abs(objectCf.UpVector.X * objectSize.X) + math.abs(objectCf.UpVector.Y * objectSize.Y) + math.abs(objectCf.UpVector.Z * objectSize.Z)

    object.CFrame = surface.CFrame * CFrame.new(Vector3.new(0,(surface.Size.Y/2)+(objectGlobalY/2)+increment, 0)) * CFrame.Angles(math.rad(objectOffset.X), math.rad(objectOffset.Y), math.rad(objectOffset.Z))
    objectTopWelder.Part0 = surface
    objectTopWelder.Part1 = object
end

function module.unweldFromSurface(object)
    for _, p in pairs(object:GetConnectedParts()) do
        if p ~= object then
            local w = p:FindFirstChild("objectTopWelder")
            if w and w.Part1 == object then
                w:Destroy()
                return p
            end
        end
    end
end

return module