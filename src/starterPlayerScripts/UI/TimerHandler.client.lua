local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local GameInfoRemotes = Remotes:WaitForChild("GameInfo")
local ResetRE = GameInfoRemotes:WaitForChild("Reset")
local StartTimerRE = GameInfoRemotes:WaitForChild("StartTimer")
local EndTimerRE = GameInfoRemotes:WaitForChild("EndTimer")

local GameInfoUI = PlayerGui:WaitForChild("GameInfo")

local InfoFrame = GameInfoUI:WaitForChild("InfoFrame")
local TimerLabel = InfoFrame:WaitForChild("TimerFrame"):WaitForChild("TextLabel")

local countingDown = false

local function formatTime(s)
    return string.format("%d:%02d", math.floor(s/60), s % 60)
end

ResetRE.OnClientEvent:Connect(function(seconds)
    TimerLabel.Text = formatTime(seconds or 180)
end)

StartTimerRE.OnClientEvent:Connect(function(parameters)
    local seconds = parameters.s
    local sendTime = parameters.sT
    local travelTime = tick() + ReplicatedStorage:GetAttribute("timeOffset") - sendTime

    local totalSeconds = seconds-travelTime
    local remainder = totalSeconds - math.floor(totalSeconds)
    local floor = math.floor(totalSeconds)

    task.wait(remainder)

    countingDown = true
    while countingDown and floor > -1 do
        TimerLabel.Text = formatTime(floor)
        task.wait(1)
        floor -= 1
    end
end)

EndTimerRE.OnClientEvent:Connect(function()
    countingDown = false
end)