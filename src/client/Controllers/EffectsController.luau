--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local CookingConfig = Config.Interaction.Cooking
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
local effectClasses = { Tags.CookingTool, Tags.Countertop, Tags.ChoppingBoard, Tags.Stove, Tags.FireExtinguisher }
local finishedTemplate: BillboardGui
local warningTemplate: BillboardGui
local fireTemplate: BasePart
local smokeTemplate: BasePart
local errorTemplate: Highlight
local random = Random.new()
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
	local startAt = 0.1 + 2.5 + CookingConfig.CookSafeTime - 2.9
	local warningElapsed = elapsed - startAt
	if warningElapsed >= 0 and warningElapsed < CookingConfig.CookAlertDuration then
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
	local cookedAt = instance:GetAttribute(CookingConfig.CookedAtAttribute)
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
	local fire = instance:GetAttribute(CookingConfig.FireAttribute)
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
	local uiAssets = assets:WaitForChild("UI")
	local effectAssets = assets:WaitForChild("Effects")
	local finished = uiAssets:WaitForChild("CookingFinished")
	local warning = uiAssets:WaitForChild("BurningWarning")
	local fire = effectAssets:WaitForChild("FireEmitter")
	local smoke = effectAssets:WaitForChild("DashTrail")
	local errorHighlight = assets:WaitForChild("Highlights"):WaitForChild("ErrorHighlight")
	assert(finished:IsA("BillboardGui"), "CookingFinished must be a BillboardGui")
	assert(warning:IsA("BillboardGui"), "BurningWarning must be a BillboardGui")
	assert(fire:IsA("BasePart"), "FireEmitter must be a BasePart")
	assert(smoke:IsA("BasePart"), "DashTrail must be a BasePart")
	assert(errorHighlight:IsA("Highlight"), "ErrorHighlight must be a Highlight")
	finishedTemplate = finished
	warningTemplate = warning
	fireTemplate = fire
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
	workspace.DescendantAdded:Connect(function(instance: Instance): ()
		local class = Tags.ClassOf(instance)
		if class ~= nil and table.find(effectClasses, class) ~= nil then
			track(instance)
		end
	end)
	RunService.Heartbeat:Connect(function(dt: number): ()
		for instance, state in tracked do
			if not instance:IsDescendantOf(workspace) then
				continue
			end
			local class = Tags.ClassOf(instance)
			if class == Tags.CookingTool then
				updateCooking(instance, state)
			end
			updateFire(instance, state, dt)
			if class == Tags.FireExtinguisher then
				updateFoam(instance, state, dt)
			end
		end
	end)
end

return EffectsController
