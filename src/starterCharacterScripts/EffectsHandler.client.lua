local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local EffectsRemote = Remotes:WaitForChild("Effects")

local Assets = ReplicatedStorage:WaitForChild("Assets")
local ProjectileTrail = Assets:WaitForChild("ProjectileTrail")

local effects = {}

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

EffectsRemote.OnClientEvent:Connect(function(effectType, parameters)
    if effects[effectType] then
        effects[effectType](parameters)
    end
end)