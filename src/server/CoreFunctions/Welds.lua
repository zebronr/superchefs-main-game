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

    local objectTopWelder = Instance.new("WeldConstraint")
    objectTopWelder.Name = "objectTopWelder"
    objectTopWelder.Parent = surface
    
    object.CFrame = CFrame.new(surface.Position + Vector3.new(0,(surface.Size.Y/2)+(object.Size.Y/2)+increment, 0))
    objectTopWelder.Part0 = surface
    objectTopWelder.Part1 = object
end

function module.unweldFromSurface(object)
    for _, p in pairs(object:GetConnectedParts()) do
        if p ~= object then
            local w = p:FindFirstChild("objectTopWelder")
            if w and w.Part1 == object then
                w:Destroy()
            end
        end
    end
end

return module