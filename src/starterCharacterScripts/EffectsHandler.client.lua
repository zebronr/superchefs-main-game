local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local EffectsRemote = Remotes:WaitForChild("Effects")

local Bindables = ReplicatedStorage:WaitForChild("Bindables")
local EffectsBindable = Bindables:WaitForChild("Effects")

local Assets = ReplicatedStorage:WaitForChild("Assets")
local ProjectileTrail = Assets:WaitForChild("ProjectileTrail")
local CookingFinished = Assets:WaitForChild("CookingFinished")
local BurningWarning = Assets:WaitForChild("BurningWarning")

local effects = {}

local effectThreads = {}

local debris = {}

function effects.ProjectileTrail(parameters)
    local root = parameters.r
    local state = parameters.s

    if state then
        local ProjectileTrailClone = ProjectileTrail:Clone()
        ProjectileTrailClone.Parent = root
        
        local a0:Attachment = Instance.new("Attachment")
        local a1:Attachment = Instance.new("Attachment")
        a0.Parent = root
        a1.Parent = root

        a0.Position = Vector3.new(-1,0,0)
        a1.Position = Vector3.new(1,0,0)

        debris[ProjectileTrailClone] = {a0,a1}

        ProjectileTrailClone.Attachment0 = a0
        ProjectileTrailClone.Attachment1 = a1
    else
        local ProjectileTrailClone = root:FindFirstChild("ProjectileTrail")
        if ProjectileTrailClone then
            for _, d in pairs(debris[ProjectileTrailClone]) do
                d:Destroy()
            end
            debris[ProjectileTrailClone] = nil
            task.wait(.5)
            ProjectileTrailClone:Destroy()
        end
    end
end

function effects.burningWarning(parameters)
    local object = parameters.o
    local alertDuration = parameters.aD
    local state = parameters.s

    if state then
        local uiClone = BurningWarning:Clone()
        local image = uiClone:WaitForChild("Image")
        uiClone.Parent = object

        local toggleSpeed = 0.5
        local startTime = tick()
        
        effectThreads[object] = task.spawn(function()
            while tick() - startTime < alertDuration do
                image.Visible = not image.Visible
                task.wait(toggleSpeed)
                toggleSpeed = math.max(0.05, toggleSpeed * 0.8)
            end
            print("Burning on client")
            uiClone:Destroy()
        end)
    else
        local uiClone = object:FindFirstChild("BurningWarning")
        if uiClone then
            uiClone:Destroy()
        end
    end
end

function effects.cookingFinished(parameters)
    local object = parameters.o
    local safeIntervalTime = parameters.sIT
    local alertDuration = parameters.aD
    local state = parameters.s

    if state then
        local uiClone = CookingFinished:Clone()
        local image = uiClone:WaitForChild("Image")
        image.TextTransparency = 1
        uiClone.Parent = object

        local in1 = TweenService:Create(image, TweenInfo.new(.3), {TextTransparency = 0})
        local out1 = TweenService:Create(image, TweenInfo.new(.3), {TextTransparency = 1})

        local start1 = tick()

        task.wait(.1)
        in1:Play()
        in1.Completed:Wait()
        task.wait(2.5)
        out1:Play()
        task.wait(safeIntervalTime-(.3+.1+2.5))

        effects.burningWarning({
            s = true,
            o = object,
            aD = alertDuration
        })
    else
        local uiClone = object:FindFirstChild("CookingFinished")
        if uiClone then
            uiClone:Destroy()
        end
    end
end

function effects.cancel(parameters)
    local deleteables = {effects.cookingFinished, effects.burningWarning}
    for _, f in pairs(deleteables) do
        f({
            o = parameters.o,
            s = false
        })
    end

    for _, t in pairs(effectThreads) do
        task.cancel(t)
    end
end

EffectsRemote.OnClientEvent:Connect(function(effectType, parameters)
    if effects[effectType] then
        effects[effectType](parameters)
    end
end)

EffectsBindable.Event:Connect(function(effectType, parameters)
    if effects[effectType] then
        effects[effectType](parameters)
    end
end)