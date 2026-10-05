--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local InteractionConfig = Config.Interaction
local CharacterConfig = Config.Character

local AnimationController = {}
local localPlayer = Players.LocalPlayer

local animationIds = {
	Chop = InteractionConfig.ChopAnimationId,
	Wash = InteractionConfig.WashAnimationId,
	Run = CharacterConfig.RunAnimationId,
	Pickup = CharacterConfig.PickupAnimationId,
	Dash = CharacterConfig.DashAnimationId,
} :: { [string]: string }

local character: Model? = nil
local attributeConnection: RBXScriptConnection? = nil
local runningConnection: RBXScriptConnection? = nil
local holderAddedConnection: RBXScriptConnection? = nil
local holderRemovedConnection: RBXScriptConnection? = nil
local heldConnection: RBXScriptConnection? = nil
local tracks: { [string]: AnimationTrack } = {}
local animations: { [string]: Animation } = {}
local playing: AnimationTrack? = nil

local function updatePickup(): ()
	local current = character
	local root = if current then current:FindFirstChild("HumanoidRootPart") else nil
	local holder = if root then root:FindFirstChild("ObjectHolder") else nil
	local track = tracks.Pickup :: AnimationTrack?
	if track == nil then
		return
	end
	if holder ~= nil and holder:IsA("WeldConstraint") and ((holder :: any).Part1 :: BasePart?) ~= nil then
		if not track.IsPlaying then
			track:Play()
		end
	else
		track:Stop()
	end
end

local function watchHolder(): ()
	if heldConnection then
		heldConnection:Disconnect()
		heldConnection = nil
	end
	local current = character
	local root = if current then current:FindFirstChild("HumanoidRootPart") else nil
	local holder = if root then root:FindFirstChild("ObjectHolder") else nil
	if holder ~= nil and holder:IsA("WeldConstraint") then
		heldConnection = holder:GetPropertyChangedSignal("Part1"):Connect(updatePickup)
	end
	updatePickup()
end

local function clear(): ()
	if attributeConnection then
		attributeConnection:Disconnect()
		attributeConnection = nil
	end
	for _, connection in { runningConnection, holderAddedConnection, holderRemovedConnection, heldConnection } do
		if connection then
			connection:Disconnect()
		end
	end
	runningConnection = nil
	holderAddedConnection = nil
	holderRemovedConnection = nil
	heldConnection = nil
	if playing then
		playing:Stop()
		playing = nil
	end
	for _, track in tracks do
		track:Destroy()
	end
	table.clear(tracks)
	character = nil
end

local function update(): ()
	local current = character
	local name = if current then current:GetAttribute(InteractionConfig.ActionAnimationAttribute) else nil
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
		for name, animation in animations do
			tracks[name] = animator:LoadAnimation(animation)
		end
		tracks.Run.Looped = true
		tracks.Pickup.Looped = true
		runningConnection = humanoid.Running:Connect(function(speed: number): ()
			local track = tracks.Run
			if speed > 0 then
				if not track.IsPlaying then
					track:Play()
				end
			else
				track:Stop()
			end
		end)
		local root = nextCharacter:FindFirstChild("HumanoidRootPart")
		if root then
			holderAddedConnection = root.ChildAdded:Connect(function(child: Instance): ()
				if child.Name == "ObjectHolder" then
					watchHolder()
				end
			end)
			holderRemovedConnection = root.ChildRemoved:Connect(function(child: Instance): ()
				if child.Name == "ObjectHolder" then
					watchHolder()
				end
			end)
			watchHolder()
		end
		attributeConnection = nextCharacter:GetAttributeChangedSignal(InteractionConfig.ActionAnimationAttribute):Connect(update)
		update()
	end)
end

function AnimationController.PlayDash(): ()
	local track = tracks.Dash :: AnimationTrack?
	if track ~= nil then
		track:Stop()
		track:Play()
	end
end

function AnimationController.Start(_self: typeof(AnimationController)): ()
	for name, id in animationIds do
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		animations[name] = animation
	end
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
