--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Interaction")).Cooking
local Tags = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Tags"))

local EffectsController = {}

type Tracked = {
	Ancestry: RBXScriptConnection,
	Destroying: RBXScriptConnection,
	CookingFinished: BillboardGui?,
	BurningWarning: BillboardGui?,
	FirePart: BasePart?,
	FireEmitter: ParticleEmitter?,
	FireAccumulator: number,
	FoamAccumulator: number,
}

local tracked: { [Instance]: Tracked } = {}
local finishedTemplate: BillboardGui
local warningTemplate: BillboardGui
local fireTemplate: BasePart

local function removeVisuals(state: Tracked): ()
	if state.CookingFinished ~= nil then
		state.CookingFinished:Destroy()
		state.CookingFinished = nil
	end
	if state.BurningWarning ~= nil then
		state.BurningWarning:Destroy()
		state.BurningWarning = nil
	end
	if state.FirePart ~= nil then
		state.FirePart:Destroy()
		state.FirePart = nil
		state.FireEmitter = nil
	end
	state.FireAccumulator = 0
	state.FoamAccumulator = 0
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
		CookingFinished = nil,
		BurningWarning = nil,
		FirePart = nil,
		FireEmitter = nil,
		FireAccumulator = 0,
		FoamAccumulator = 0,
	}
	tracked[instance] = state
end

local function showFinished(instance: Instance, state: Tracked, elapsed: number): ()
	if elapsed >= 0 and elapsed < 3.2 then
		if state.CookingFinished == nil then
			local clone = finishedTemplate:Clone()
			clone.Parent = instance
			state.CookingFinished = clone
		end
		local image = (state.CookingFinished :: BillboardGui):FindFirstChild("Image")
		if image ~= nil and image:IsA("TextLabel") then
			image.TextTransparency = if elapsed < 0.1 then 1
				else if elapsed < 0.4 then 1 - (elapsed - 0.1) / 0.3
				else if elapsed < 2.9 then 0
				else (elapsed - 2.9) / 0.3
		end
	elseif state.CookingFinished ~= nil then
		state.CookingFinished:Destroy()
		state.CookingFinished = nil
	end
end

local function warningVisible(elapsed: number): boolean
	local toggleSpeed = 0.5
	local nextToggle = 0
	local visible = true
	while nextToggle <= elapsed do
		visible = not visible
		nextToggle += toggleSpeed
		toggleSpeed = math.max(0.05, toggleSpeed * 0.8)
	end
	return visible
end

local function showWarning(instance: Instance, state: Tracked, elapsed: number): ()
	local startAt = 0.1 + 2.5 + Config.CookSafeTime - 2.9
	local warningElapsed = elapsed - startAt
	if warningElapsed >= 0 and warningElapsed < Config.CookAlertDuration then
		if state.BurningWarning == nil then
			local clone = warningTemplate:Clone()
			clone.Parent = instance
			state.BurningWarning = clone
		end
		local image = (state.BurningWarning :: BillboardGui):FindFirstChild("Image")
		if image ~= nil and image:IsA("GuiObject") then
			image.Visible = warningVisible(warningElapsed)
		end
	elseif state.BurningWarning ~= nil then
		state.BurningWarning:Destroy()
		state.BurningWarning = nil
	end
end

local function updateCooking(instance: Instance, state: Tracked): ()
	local cookedAt = instance:GetAttribute(Config.CookedAtAttribute)
	if typeof(cookedAt) == "number" then
		local elapsed = workspace:GetServerTimeNow() - cookedAt
		showFinished(instance, state, elapsed)
		showWarning(instance, state, elapsed)
	else
		showFinished(instance, state, math.huge)
		showWarning(instance, state, math.huge)
	end
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
	local fire = instance:GetAttribute(Config.FireAttribute)
	if typeof(fire) == "number" and fire > 0 and instance:IsA("BasePart") then
		if state.FirePart == nil then
			local clone = fireTemplate:Clone()
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

local function updateFoam(instance: Instance, state: Tracked, dt: number): ()
	local part = instance:FindFirstChild("Emitter")
	local emitter = if part ~= nil then part:FindFirstChildOfClass("ParticleEmitter") else nil
	if emitter ~= nil then
		emitter.Enabled = false
	end
	if instance:GetAttribute(Config.SprayingAttribute) ~= true then
		state.FoamAccumulator = 0
		return
	end
	if emitter ~= nil then
		state.FoamAccumulator = emit(emitter, state.FoamAccumulator, dt, emitter.Rate)
	end
end

function EffectsController.Start(_self: typeof(EffectsController)): ()
	local assets = ReplicatedStorage:WaitForChild("Assets")
	local finished = assets:WaitForChild("CookingFinished")
	local warning = assets:WaitForChild("BurningWarning")
	local fire = assets:WaitForChild("FireEmitter")
	assert(finished:IsA("BillboardGui"), "CookingFinished must be a BillboardGui")
	assert(warning:IsA("BillboardGui"), "BurningWarning must be a BillboardGui")
	assert(fire:IsA("BasePart"), "FireEmitter must be a BasePart")
	finishedTemplate = finished
	warningTemplate = warning
	fireTemplate = fire
	for _, tag in { Tags.CookingTool, Tags.Countertop, Tags.ChoppingBoard, Tags.Stove, Tags.FireExtinguisher } do
		CollectionService:GetInstanceAddedSignal(tag):Connect(track)
		CollectionService:GetInstanceRemovedSignal(tag):Connect(untrack)
		for _, instance in CollectionService:GetTagged(tag) do
			track(instance)
		end
	end
	workspace.DescendantAdded:Connect(function(instance: Instance): ()
		for _, tag in { Tags.CookingTool, Tags.Countertop, Tags.ChoppingBoard, Tags.Stove, Tags.FireExtinguisher } do
			if CollectionService:HasTag(instance, tag) then
				track(instance)
				return
			end
		end
	end)
	RunService.Heartbeat:Connect(function(dt: number): ()
		for instance, state in tracked do
			if not instance:IsDescendantOf(workspace) then
				continue
			end
			if CollectionService:HasTag(instance, Tags.CookingTool) then
				updateCooking(instance, state)
			end
			updateFire(instance, state, dt)
			if CollectionService:HasTag(instance, Tags.FireExtinguisher) then
				updateFoam(instance, state, dt)
			end
		end
	end)
end

return EffectsController
