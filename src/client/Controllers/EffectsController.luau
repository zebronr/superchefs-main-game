--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))
local Particles = require(script.Parent.Parent.Util.Particles)

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local CookingConfig = Config.Interaction.Cooking
local Tags = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Tags"))

local EffectsController = {}

type Tracked = {
	Ancestry: RBXScriptConnection,
	Destroying: RBXScriptConnection,
	FirePart: BasePart?,
	FireEmitter: ParticleEmitter?,
	FireAccumulator: number,
	FoamAccumulator: number,
	Smoke: Attachment?,
	SmokeEmitter: ParticleEmitter?,
	SmokeAccumulator: number,
}

local tracked: { [Instance]: Tracked } = {}
local effectClasses = { Tags.CookingTool, Tags.Countertop, Tags.ChoppingBoard, Tags.Stove, Tags.FireExtinguisher }
local fireTemplate: BasePart
local smokeTemplate: BasePart
local burnSmokeTemplate: Attachment
local errorTemplate: Highlight
local random = Random.new()
-- Emitters left Enabled in Workspace (the stove burners): turned off and streamed with :Emit() instead, so low
-- graphics quality draws them the same (see Util/Particles).
local ambient: { [ParticleEmitter]: true } = {}
local directions = {
	Vector3.new(1, 0, 1), Vector3.new(-1, 0, 1),
	Vector3.new(1, 0, -1), Vector3.new(-1, 0, -1),
	Vector3.new(0, 0, -1), Vector3.new(0, 0, 1),
	Vector3.new(-1, 0, 0), Vector3.new(1, 0, 0),
}

local function orderFinish(instance: Instance): ()
	if not instance:IsA("BasePart") or not instance:IsDescendantOf(workspace) then
		return
	end
	for _, direction in directions do
		local smoke = smokeTemplate:Clone()
		smoke.Size = Vector3.new(0.974, 0.452, 0.841)
		smoke.Position = instance.Position
		smoke.Transparency = 0
		smoke.Material = Enum.Material.Neon
		smoke.BrickColor = BrickColor.new("Fossil")
		smoke.Parent = workspace:FindFirstChild("$Temp") or workspace
		TweenService:Create(smoke, TweenInfo.new(1, Enum.EasingStyle.Circular), {
			Position = smoke.Position + direction * random:NextNumber(2.2, 2.7),
			Size = smoke.Size * random:NextNumber(1.7, 2.5),
		}):Play()
		task.delay(0.5, function(): ()
			if smoke.Parent == nil then
				return
			end
			local fade = TweenService:Create(smoke, TweenInfo.new(0.5, Enum.EasingStyle.Cubic), { Transparency = 1 })
			fade.Completed:Once(function(): ()
				smoke:Destroy()
			end)
			fade:Play()
		end)
	end
end

local function objError(instance: Instance): ()
	if not instance:IsDescendantOf(workspace) then
		return
	end
	task.spawn(function(): ()
		local highlight = errorTemplate:Clone()
		highlight.Parent = instance
		for _ = 1, 6 do
			highlight.Enabled = not highlight.Enabled
			task.wait(0.05)
		end
		highlight:Destroy()
	end)
end

local function removeVisuals(state: Tracked): ()
	if state.FirePart ~= nil then
		state.FirePart:Destroy()
		state.FirePart = nil
		state.FireEmitter = nil
	end
	if state.Smoke ~= nil then
		state.Smoke:Destroy()
		state.Smoke = nil
		state.SmokeEmitter = nil
	end
	state.FireAccumulator = 0
	state.FoamAccumulator = 0
	state.SmokeAccumulator = 0
end

local function untrack(instance: Instance): ()
	local state = tracked[instance]
	if state == nil then
		return
	end
	tracked[instance] = nil
	state.Ancestry:Disconnect()
	state.Destroying:Disconnect()
	removeVisuals(state)
end

local function refreshPresence(instance: Instance): ()
	if not instance:IsDescendantOf(workspace) then
		untrack(instance)
	end
end

local function track(instance: Instance): ()
	if tracked[instance] ~= nil or not instance:IsDescendantOf(workspace) then
		return
	end
	local state: Tracked = {
		Ancestry = instance.AncestryChanged:Connect(function(): ()
			refreshPresence(instance)
		end),
		Destroying = instance.Destroying:Connect(function(): ()
			untrack(instance)
		end),
		FirePart = nil,
		FireEmitter = nil,
		FireAccumulator = 0,
		FoamAccumulator = 0,
		Smoke = nil,
		SmokeEmitter = nil,
		SmokeAccumulator = 0,
	}
	tracked[instance] = state
end

local function emit(emitter: ParticleEmitter, accumulator: number, dt: number, rate: number): number
	accumulator += rate * dt
	local count = math.floor(accumulator)
	if count > 0 then
		emitter:Emit(count)
		accumulator -= count
	end
	return accumulator
end

local function updateFire(instance: Instance, state: Tracked, dt: number): ()
	local fire = instance:GetAttribute(CookingConfig.FireAttribute)
	if typeof(fire) == "number" and fire > 0 and instance:IsA("BasePart") then
		if state.FirePart == nil then
			local clone = fireTemplate:Clone()
			-- Off before it enters Workspace, so the ambient watcher leaves it to this function.
			for _, child in clone:GetChildren() do
				if child:IsA("ParticleEmitter") then
					child.Enabled = false
				end
			end
			clone.CFrame = instance.CFrame
			clone.CanCollide = false
			clone.Massless = true
			clone.Parent = instance
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = instance
			weld.Part1 = clone
			weld.Parent = clone
			state.FirePart = clone
			local emitter = clone:FindFirstChildOfClass("ParticleEmitter")
			if emitter ~= nil then
				emitter.Enabled = false
				state.FireEmitter = emitter
			end
		end
		local emitter = state.FireEmitter
		if emitter ~= nil then
			state.FireAccumulator = emit(emitter, state.FireAccumulator, dt, emitter.Rate * fire / 100)
		end
	elseif state.FirePart ~= nil then
		state.FirePart:Destroy()
		state.FirePart = nil
		state.FireEmitter = nil
		state.FireAccumulator = 0
	end
end

-- How smoky a pot is: 0 while it cooks (light steam), rising to 1 over the burn warning, 1 while it burns,
-- nil when it isn't smoking. The second value is true while it only cooks (the gentler steam rate).
local function smokeLevel(instance: Instance): (number?, boolean)
	local fire = instance:GetAttribute(CookingConfig.FireAttribute)
	if typeof(fire) == "number" and fire > 0 then
		return 1, false
	end
	-- Deep Freeze stops the smoke with the cooking.
	if instance:GetAttribute(Config.Skills.Attribute.FrozenAt) ~= nil then
		return nil, false
	end
	local cookedAt = instance:GetAttribute(CookingConfig.CookedAtAttribute)
	if typeof(cookedAt) ~= "number" then
		local cooking = typeof(instance:GetAttribute(CookingConfig.CookStartedAtAttribute)) == "number"
		return if cooking then 0 else nil, cooking
	end
	local warned = workspace:GetServerTimeNow() - cookedAt - CookingConfig.CookSafeTime
	if warned < 0 then
		return 0, true
	end
	return math.min(warned / CookingConfig.CookAlertDuration, 1), false
end

local function updateSmoke(instance: Instance, state: Tracked, dt: number): ()
	local level, steaming = nil, false
	if instance:IsA("BasePart") then
		level, steaming = smokeLevel(instance)
	end
	if level == nil then
		if state.Smoke ~= nil then
			state.Smoke:Destroy()
			state.Smoke = nil
			state.SmokeEmitter = nil
			state.SmokeAccumulator = 0
		end
		return
	end
	local part = instance :: BasePart
	local tuning = Config.UI.BurnSmoke
	if state.Smoke == nil then
		local smoke = burnSmokeTemplate:Clone()
		local emitter = smoke:FindFirstChildOfClass("ParticleEmitter")
		if emitter == nil then
			smoke:Destroy()
			return
		end
		emitter.Enabled = false
		smoke.Parent = part
		state.Smoke = smoke
		state.SmokeEmitter = emitter
	end
	local smoke = state.Smoke :: Attachment
	local emitter = state.SmokeEmitter :: ParticleEmitter
	-- Upright above the pot's top, whichever way the pot is turned; on fire it rises from above the flames and draws
	-- behind them, so it doesn't blot them out.
	local burning = state.FirePart ~= nil
	local height = if burning then tuning.FireHeight else tuning.Height
	smoke.WorldCFrame = CFrame.new(part.Position + Vector3.new(0, part.Size.Y / 2 + height, 0))
	local base = burnSmokeTemplate:FindFirstChildOfClass("ParticleEmitter") :: ParticleEmitter
	emitter.ZOffset = if burning then tuning.FireZOffset else 0
	emitter.Color = ColorSequence.new(if burning then tuning.FireColor else tuning.Color[1]:Lerp(tuning.Color[2], level))
	emitter.Speed = if burning then NumberRange.new(tuning.FireSpeed[1], tuning.FireSpeed[2]) else base.Speed
	emitter.SpreadAngle = if burning then Vector2.new(tuning.FireSpread, tuning.FireSpread) else base.SpreadAngle
	local scale = tuning.Size[1] + (tuning.Size[2] - tuning.Size[1]) * level
	local keypoints = {}
	for _, keypoint in base.Size.Keypoints do
		table.insert(keypoints, NumberSequenceKeypoint.new(keypoint.Time, keypoint.Value * scale, keypoint.Envelope * scale))
	end
	emitter.Size = NumberSequence.new(keypoints)
	local rate = if burning
		then tuning.FireRate
		elseif steaming then tuning.CookingRate
		else tuning.Rate[1] + (tuning.Rate[2] - tuning.Rate[1]) * level
	state.SmokeAccumulator = emit(emitter, state.SmokeAccumulator, dt, rate)
end

local function adoptEmitter(instance: Instance): ()
	if instance:IsA("ParticleEmitter") and instance.Enabled then
		instance.Enabled = false
		ambient[instance] = true
	end
end

local function updateFoam(instance: Instance, state: Tracked, dt: number): ()
	local part = instance:FindFirstChild("Emitter")
	local emitter = if part ~= nil then part:FindFirstChildOfClass("ParticleEmitter") else nil
	if emitter ~= nil then
		emitter.Enabled = false
	end
	if instance:GetAttribute(CookingConfig.SprayingAttribute) ~= true then
		state.FoamAccumulator = 0
		return
	end
	if emitter ~= nil then
		state.FoamAccumulator = emit(emitter, state.FoamAccumulator, dt, emitter.Rate)
	end
end

function EffectsController.Start(_self: typeof(EffectsController)): ()
	local assets = ReplicatedStorage:WaitForChild("Assets")
	local effectAssets = assets:WaitForChild("Effects")
	local fire = effectAssets:WaitForChild("FireEmitter")
	local burnSmoke = effectAssets:WaitForChild("BurnSmoke")
	local smoke = effectAssets:WaitForChild("DashTrail")
	local errorHighlight = assets:WaitForChild("Highlights"):WaitForChild("ErrorHighlight")
	assert(fire:IsA("BasePart"), "FireEmitter must be a BasePart")
	assert(burnSmoke:IsA("Attachment"), "BurnSmoke must be an Attachment")
	assert(smoke:IsA("BasePart"), "DashTrail must be a BasePart")
	assert(errorHighlight:IsA("Highlight"), "ErrorHighlight must be a Highlight")
	fireTemplate = fire
	burnSmokeTemplate = burnSmoke
	smokeTemplate = smoke
	errorTemplate = errorHighlight
	Net.Event("Effect").OnClientEvent:Connect(function(message: unknown, value: unknown): ()
		if message == "OrderFinish" and typeof(value) == "Instance" then
			orderFinish(value)
		elseif message == "ObjError" and typeof(value) == "Instance" then
			objError(value)
		end
	end)
	for _, className in effectClasses do
		local tag = Tags.ClassTag(className)
		CollectionService:GetInstanceAddedSignal(tag):Connect(track)
		CollectionService:GetInstanceRemovedSignal(tag):Connect(untrack)
		for _, instance in CollectionService:GetTagged(tag) do
			track(instance)
		end
	end
	for _, instance in workspace:GetDescendants() do
		adoptEmitter(instance)
	end
	workspace.DescendantRemoving:Connect(function(instance: Instance): ()
		if instance:IsA("ParticleEmitter") and ambient[instance] then
			ambient[instance] = nil
			Particles.Stop(instance)
		end
	end)
	workspace.DescendantAdded:Connect(function(instance: Instance): ()
		adoptEmitter(instance)
		local class = Tags.ClassOf(instance)
		if class ~= nil and table.find(effectClasses, class) ~= nil then
			track(instance)
		end
	end)
	RunService.Heartbeat:Connect(function(dt: number): ()
		for emitter in ambient do
			Particles.Stream(emitter)
		end
		for instance, state in tracked do
			if not instance:IsDescendantOf(workspace) then
				continue
			end
			local class = Tags.ClassOf(instance)
			if class == Tags.CookingTool then
				updateSmoke(instance, state, dt)
			end
			updateFire(instance, state, dt)
			if class == Tags.FireExtinguisher then
				updateFoam(instance, state, dt)
			end
		end
	end)
end

return EffectsController
