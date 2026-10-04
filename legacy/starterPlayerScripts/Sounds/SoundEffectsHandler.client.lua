local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SoundsRemotes = Remotes:WaitForChild("Sounds")

local PlayRE = SoundsRemotes:WaitForChild("Play")
local StopRE = SoundsRemotes:WaitForChild("Stop")

local SoundEffects = SoundService:WaitForChild("SoundEffects")

PlayRE.OnClientEvent:Connect(function(soundName, looped)
    local s = SoundEffects:FindFirstChild(soundName)
    if s then
        s:Play()
        s.Looped = looped
    end
end)

StopRE.OnClientEvent:Connect(function(soundName)
    local s = SoundEffects:FindFirstChild(soundName)
    if s then
        s:Stop()
    end
end)