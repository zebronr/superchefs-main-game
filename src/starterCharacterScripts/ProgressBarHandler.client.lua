local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Modules")
local Cache = require(Shared:WaitForChild("Cache"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ProgressBarRemote = Remotes:WaitForChild("ProgressBar")

local Bindables = ReplicatedStorage:WaitForChild("Bindables")
local EffectsBindable = Bindables:WaitForChild("Effects")

local LocalPlayer = Players.LocalPlayer

local Assets = ReplicatedStorage:WaitForChild("Assets")
local ProgressBar = Assets:WaitForChild("ProgressBar")

local functions = {}
local isProgress = Cache.RegisterCache(`{script.Name}_isProgress`)
local Progress = Cache.RegisterCache(`{script.Name}_Progress`)

local function updateProgressBar(progressBar, progress)
    local bar:Frame = progressBar:WaitForChild("BG"):WaitForChild("Clip"):WaitForChild("Bar") 
    bar.Size = UDim2.new((progress/100)*2, bar.Size.X.Offset, bar.Size.Y.Scale, bar.Size.Y.Offset)
end

function functions.ChoppingProgress(parameters)
    local state = parameters.s
    local chopDelay = parameters.cD
    local progressPerChop = parameters.pPC
    local object = parameters.o
    local sentTime = parameters.sT

    Progress[object] = Progress[object] or 0

    if state then
        local travelTime = tick() - sentTime
        local objectProgressBar = object:FindFirstChild("ProgressBar") or ProgressBar:Clone()
        objectProgressBar.Parent = object
        updateProgressBar(objectProgressBar, Progress[object])

        isProgress[object] = true
        local n = 0
        while isProgress[object] and not (Progress[object] >=  100) do
            n+=1
            Progress[object] += progressPerChop
            updateProgressBar(objectProgressBar, Progress[object])
            if n == 1 then --just a lazy way to take the travel time into factor lmao sorry for whoever gon read this
                task.wait(chopDelay-travelTime)
            else
                task.wait(chopDelay)
            end
        end
        if Progress[object] and Progress[object] >= 100 then
            objectProgressBar:Destroy()
            isProgress[object] = nil
            Progress[object] = nil
        end
    else
        isProgress[object] = false
        if parameters.d then
            local objectProgressBar = object:FindFirstChild("ProgressBar")
            if objectProgressBar then objectProgressBar:Destroy() end
        end
    end
end

function functions.CookingProgress(parameters)
    local state = parameters.s
    local progressRate = parameters.pR
    local object = parameters.o
    local sentTime = parameters.sT
    local progressAmount = parameters.pA
    local safeIntervalTime = parameters.sIT
    local alertDuration = parameters.aD

    Progress[object] = progressAmount or Progress[object] or 0

    if state then
        local objectProgressBar = object:FindFirstChild("ProgressBar") or ProgressBar:Clone()
        objectProgressBar.Parent = object
        updateProgressBar(objectProgressBar, Progress[object])

        isProgress[object] = true

        ---TAKE KNOWLEDGE OF TRAVEL TIME FOR MORE SYNCED PROGRESS
        local travelTime = tick() - sentTime
        Progress[object] += travelTime*progressRate
        updateProgressBar(objectProgressBar, Progress[object])

        while isProgress[object] and not (Progress[object] >=  100) do
            local dt = RunService.Heartbeat:Wait()
            Progress[object] += dt*progressRate
            updateProgressBar(objectProgressBar, Progress[object])
        end
        if Progress[object] and Progress[object] >= 100 then
            warn("DONE ON CLIENT")
            objectProgressBar:Destroy()
            isProgress[object] = nil
            Progress[object] = nil

            EffectsBindable:Fire("cookingFinished", {
                s = true,
                o = object,
                sIT = safeIntervalTime,
                aD = alertDuration
            })
        end
    else
        isProgress[object] = false
        if parameters.d then
            local objectProgressBar = object:FindFirstChild("ProgressBar")
            if objectProgressBar then objectProgressBar:Destroy() end
        end
    end
end

function functions.changeProgress(parameters)
    local object = parameters.o
    local progress = parameters.p
    local progressRate = parameters.pR
    local sentTime = parameters.sT
    local travelTime = tick() - sentTime

    Progress[object] = progress + (progressRate*travelTime)
end

ProgressBarRemote.OnClientEvent:Connect(function(request, parameters)
    if functions[request] then
        functions[request](parameters)
    end
end)