--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Interaction"))

local AnimationController = {}
local localPlayer = Players.LocalPlayer

local animationIds = {
	Chop = Config.ChopAnimationId,
} :: { [string]: string }

local character: Model? = nil
local attributeConnection: RBXScriptConnection? = nil
local tracks: { [string]: AnimationTrack } = {}
local animations: { Animation } = {}
local playing: AnimationTrack? = nil

local function clear(): ()
	if attributeConnection then
		attributeConnection:Disconnect()
		attributeConnection = nil
	end
	if playing then
		playing:Stop()
		playing = nil
	end
	for _, track in tracks do
		track:Destroy()
	end
	table.clear(tracks)
	for _, animation in animations do
		animation:Destroy()
	end
	table.clear(animations)
	character = nil
end

local function update(): ()
	local current = character
	local name = if current then current:GetAttribute(Config.ActionAnimationAttribute) else nil
	local nextTrack = if typeof(name) == "string" then tracks[name] else nil
	if playing == nextTrack then
		return
	end
	if playing then
		playing:Stop()
	end
	playing = nextTrack
	if nextTrack then
		nextTrack.Looped = true
		nextTrack:Play()
	end
end

local function setup(nextCharacter: Model): ()
	clear()
	character = nextCharacter
	task.spawn(function(): ()
		local humanoid = nextCharacter:WaitForChild("Humanoid", 10)
		if character ~= nextCharacter or humanoid == nil or not humanoid:IsA("Humanoid") then
			return
		end
		local animator = humanoid:WaitForChild("Animator", 10)
		if character ~= nextCharacter or animator == nil or not animator:IsA("Animator") then
			return
		end
		for name, id in animationIds do
			local animation = Instance.new("Animation")
			animation.AnimationId = id
			table.insert(animations, animation)
			tracks[name] = animator:LoadAnimation(animation)
		end
		attributeConnection = nextCharacter:GetAttributeChangedSignal(Config.ActionAnimationAttribute):Connect(update)
		update()
	end)
end

function AnimationController.Start(_self: typeof(AnimationController)): ()
	localPlayer.CharacterAdded:Connect(setup)
	localPlayer.CharacterRemoving:Connect(function(removing: Model): ()
		if character == removing then
			clear()
		end
	end)
	if localPlayer.Character then
		setup(localPlayer.Character)
	end
end

return AnimationController
