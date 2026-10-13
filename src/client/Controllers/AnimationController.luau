--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local SkillEffects = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("SkillEffects"))
local SkillController = require(script.Parent.SkillController)
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
local runStepConnection: RBXScriptConnection? = nil
-- The humanoid's last Running speed: the run animation plays while it's above 0, the root really moves (Running
-- can stay stale after a teleport) and no superskill stops it.
local runSpeed = 0
local holderAddedConnection: RBXScriptConnection? = nil
local holderRemovedConnection: RBXScriptConnection? = nil
local heldConnection: RBXScriptConnection? = nil
local tracks: { [string]: AnimationTrack } = {}
local animations: { [string]: Animation } = {}
local playing: AnimationTrack? = nil
-- The local player's predicted action (Name nil = a predicted stop), shown until the server's attribute agrees or
-- it times out and rolls back.
local prediction: { Name: string?, At: number }? = nil
-- A one-shot action played over everything else until an os.clock() time (the catch swing's arm).
local override: { Name: string, Until: number }? = nil

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
	for _, connection in { runningConnection, runStepConnection, holderAddedConnection, holderRemovedConnection, heldConnection } do
		if connection then
			connection:Disconnect()
		end
	end
	runningConnection = nil
	runStepConnection = nil
	runSpeed = 0
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
	prediction = nil
	override = nil
end

-- The local player's action: the prediction while it is pending, else the server's ActionAnimation attribute.
local function currentAction(): string?
	local current = Players.LocalPlayer.Character
	local value = if current then current:GetAttribute(InteractionConfig.ActionAnimationAttribute) else nil
	local server = if typeof(value) == "string" then value else nil
	local pending = prediction
	if pending ~= nil then
		if pending.Name == server or os.clock() - pending.At > InteractionConfig.ActionPredictTimeout then
			prediction = nil
		else
			return pending.Name
		end
	end
	return server
end

local function update(): ()
	local current = override
	if current ~= nil and os.clock() >= current.Until then
		override = nil
		current = nil
	end
	local name = if character == nil then nil elseif current ~= nil then current.Name else currentAction()
	local nextTrack = if name ~= nil then tracks[name] else nil
	if playing ~= nextTrack then
		if playing then
			playing:Stop()
		end
		playing = nextTrack
		if nextTrack then
			nextTrack.Looped = true
			nextTrack:Play()
		end
	end
	-- Chopping and washing play faster while Hustle speeds the work up (the knife and sponge visibly hurry).
	if playing ~= nil and (name == "Chop" or name == "Wash") then
		local speed = SkillEffects.WorkMultiplier(character)
		if playing.Speed ~= speed then
			playing:AdjustSpeed(speed)
		end
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
			runSpeed = speed
		end)
		local root = nextCharacter:FindFirstChild("HumanoidRootPart")
		-- Every frame, so a superskill turning the run animation off (or back on) takes effect at once.
		runStepConnection = RunService.Heartbeat:Connect(function(): ()
			local track: AnimationTrack? = tracks.Run
			if track == nil then
				return
			end
			local velocity = if root ~= nil and root:IsA("BasePart") then root.AssemblyLinearVelocity else Vector3.zero
			local moving = Vector3.new(velocity.X, 0, velocity.Z).Magnitude > CharacterConfig.RunAnimationMinSpeed
			local run = runSpeed > 0 and moving and not SkillController.RunAnimationStopped()
			if run and not track.IsPlaying then
				track:Play()
			elseif not run and track.IsPlaying then
				track:Stop()
			end
		end)
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

-- The local player's current action, predicted or confirmed.
function AnimationController.Action(): string?
	return currentAction()
end

-- Shows the local player's action (or, with nil, its end) at once, before the server confirms it.
function AnimationController.Predict(name: string?): ()
	prediction = { Name = name, At = os.clock() }
	update()
end

-- Plays `name` on the local character until the os.clock() time `untilClock`, over its current action.
function AnimationController.PlayUntil(name: string, untilClock: number): ()
	override = { Name = name, Until = untilClock }
	update()
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
	-- Settles predictions that the server confirmed or that timed out.
	RunService.Heartbeat:Connect(update)
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
