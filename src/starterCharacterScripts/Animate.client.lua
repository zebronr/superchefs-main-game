local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Modules")
local AnimationsModule = require(Shared:WaitForChild("Animations"))
local animations = AnimationsModule.animations

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
--local PlayAnimation = Remotes:WaitForChild("PlayAnimation")

local Bindables = ReplicatedStorage:WaitForChild("Bindables")
local PlayerMobility = Bindables:WaitForChild("PlayerMobility")

local LocalPlayer = Players.LocalPlayer
local PlayerValues = LocalPlayer:WaitForChild("PlayerValues")
local ObjectCarried:ObjectValue = PlayerValues:WaitForChild("ObjectCarried")

local Character = script.Parent
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
local Humanoid = Character:WaitForChild("Humanoid")

local animationLock = false

local preloaded_choppingAnimation = Instance.new("Animation")
preloaded_choppingAnimation.AnimationId = animations.chop
preloaded_choppingAnimation = Humanoid.Animator:LoadAnimation(preloaded_choppingAnimation)

local preLoadedAnimations = {}

for i, animation in pairs(animations) do
	local animationInstance = Instance.new("Animation")
	animationInstance.AnimationId = animation
	animationInstance.Name = i
	animationInstance.Parent = script
end

for _, animation in pairs(script:GetChildren()) do
	if animation:IsA("Animation") then
		local track = Humanoid.Animator:LoadAnimation(animation)
		preLoadedAnimations[animation.Name] = track
	end
end

local function LockCharacter(bool)
	if bool then
		Humanoid.WalkSpeed = 0
	else
		Humanoid.WalkSpeed = 16
	end
end

local function playAnimation(animation, bool, looped, overwriteLock, overwritespeed)
	if not animationLock or overwriteLock then
		if bool then
			overwritespeed = overwritespeed or 1
			local track = preLoadedAnimations[animation]
			track.Looped = looped
			track:Play()
			track:AdjustSpeed(overwritespeed)
			track.Stopped:Wait()
		else
			local track = preLoadedAnimations[animation]
			track:Stop()
		end
	end
end

local running = false
Humanoid.Running:Connect(function(speed)
	if speed > 0 and not running then
		running = true
		playAnimation("run", true, true)
	elseif speed <= 0 and running then
		running = false
		playAnimation("run", false)
	end
end)

ObjectCarried.Changed:Connect(function(value)
	if value then
		playAnimation("pickup", true, true)
	else
		playAnimation("pickup", false)
	end
end)

--[[PlayAnimation.OnClientEvent:Connect(function(animation, bool, looped, overwritespeed)
	for _, track in pairs(Humanoid.Animator:GetPlayingAnimationTracks()) do
		track:Stop()
	end
	animationLock = true
	playAnimation(animation, bool, looped, true, overwritespeed)
	animationLock = false
end)]]--

PlayerMobility.Event:Connect(function(mobType)
	print(mobType)
	if mobType == "dash" then
		playAnimation("dash", true)
	end
end)