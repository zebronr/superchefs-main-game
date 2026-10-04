local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local CharacterRemotes = Remotes:WaitForChild("Character")
local LoadAnimationRE = CharacterRemotes:WaitForChild("LoadAnimations")
local PlayAnimationRE = CharacterRemotes:WaitForChild("PlayAnimation")
local StopAnimationRE = CharacterRemotes:WaitForChild("StopAnimation")

local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local Animator:Animator = Humanoid:WaitForChild("Animator")

local areAnimationsLoaded = false
local loadedAnims = {}

local animations = {
    Chop = "74695809221721"
}

LoadAnimationRE.OnClientEvent:Connect(function()
    if areAnimationsLoaded then return end

    for animName, animID in pairs(animations) do
        local animationTrack = Instance.new("Animation")
        animationTrack.AnimationId = "rbxassetid://"..tostring(animID)

        loadedAnims[animName] = Animator:LoadAnimation(animationTrack)
    end
end)

PlayAnimationRE.OnClientEvent:Connect(function(name, looped)
    if not loadedAnims[name] then return end

    loadedAnims[name].Looped = looped
    loadedAnims[name]:Play()
end)

StopAnimationRE.OnClientEvent:Connect(function(name)
    if not loadedAnims[name] then return end

    loadedAnims[name]:Stop()
end)