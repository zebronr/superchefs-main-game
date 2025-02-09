local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Modules")
local Cache = require(Shared:WaitForChild("Cache"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ProgressBarRemote = Remotes:WaitForChild("ProgressBar")

local LocalPlayer = Players.LocalPlayer

local Assets = ReplicatedStorage:WaitForChild("Assets")
local ProgressBar = Assets:WaitForChild("ProgressBar")

local effects = {}
local isProgress = Cache.RegisterCache(`{script.Name}_isProgress`)
local Progress = Cache.RegisterCache(`{script.Name}_Progress`)

local function updateProgressBar(progressBar, progress)
    local bar:Frame = progressBar:WaitForChild("BG"):WaitForChild("Clip"):WaitForChild("Bar") 
    bar.Size = UDim2.new((progress/100)*2, bar.Size.X.Offset, bar.Size.Y.Scale, bar.Size.Y.Offset)
end

function effects.ChoppingProgress(parameters)
    local state = parameters.s
    local chopDelay = parameters.cD
    local progressPerChop = parameters.pPC
    local object = parameters.o

    if (state and not (chopDelay and progressPerChop and object)) or (not state and not object) then return end

    Progress[object] = Progress[object] or 0

    if state then
        local objectProgressBar = object:FindFirstChild("ProgressBar") or ProgressBar:Clone()
        objectProgressBar.Parent = object
        updateProgressBar(objectProgressBar, Progress[object])

        isProgress[object] = true
        while isProgress[object] and not (Progress[object] >=  100) do
            Progress[object] += progressPerChop
            updateProgressBar(objectProgressBar, Progress[object])
            task.wait(chopDelay)
        end
        if Progress[object] and Progress[object] >= 100 then
            objectProgressBar:Destroy()
            isProgress[object] = nil
            Progress[object] = nil
        end
    else
        isProgress[object] = false
    end
end

function effects.CookingProgress(parameters)

end

ProgressBarRemote.OnClientEvent:Connect(function(request, parameters)
    if effects[request] then
        effects[request](parameters)
    end
end)