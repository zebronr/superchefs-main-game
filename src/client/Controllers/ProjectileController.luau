--!strict

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local ThrowConfig = Config.Interaction.Throw
local Projectile = require(Shared:WaitForChild("Util"):WaitForChild("Projectile"))
local Tags = require(Shared:WaitForChild("Tags"))

local ProjectileController = {}

type Tracked = {
	Part: BasePart,
	Trail: Trail,
	First: Attachment,
	Second: Attachment,
	Destroying: RBXScriptConnection,
}

local tracked: { [Instance]: Tracked } = {}
local trailTemplate: Trail

local function destroyTrail(state: Tracked): ()
	state.Trail:Destroy()
	state.First:Destroy()
	state.Second:Destroy()
end

local function untrack(instance: Instance, destroyed: boolean): ()
	local state = tracked[instance]
	if state == nil then
		return
	end
	tracked[instance] = nil
	state.Destroying:Disconnect()
	if destroyed then
		destroyTrail(state)
	else
		task.delay(ThrowConfig.TrailLinger, function(): ()
			destroyTrail(state)
		end)
	end
end

local function track(instance: Instance): ()
	if tracked[instance] ~= nil or not instance:IsA("BasePart") then
		return
	end
	local trail = trailTemplate:Clone()
	local first = Instance.new("Attachment")
	local second = Instance.new("Attachment")
	first.Position = Vector3.new(-1, 0, 0)
	second.Position = Vector3.new(1, 0, 0)
	first.Parent = instance
	second.Parent = instance
	trail.Attachment0 = first
	trail.Attachment1 = second
	trail.Parent = instance
	tracked[instance] = {
		Part = instance,
		Trail = trail,
		First = first,
		Second = second,
		Destroying = instance.Destroying:Connect(function(): ()
			untrack(instance, true)
		end),
	}
end

-- The thrower's local flight, run until the server's replicated timeline takes over.
type Prediction = {
	Part: BasePart,
	Holder: WeldConstraint,
	-- The part's offset from the weld's Part0, restored before re-welding on rollback.
	HoldOffset: CFrame?,
	Start: CFrame,
	Endpoint: Vector3,
	StartedAt: number,
	Params: RaycastParams,
	Previous: Vector3,
	Last: Vector3,
	Frozen: boolean,
	-- Set once the server confirms: the gap to blend away, and when the blend began.
	Offset: Vector3?,
	ReconcileAt: number,
}

local predictions: { [BasePart]: Prediction } = {}

-- Where the replicated attributes say the part is now, with the throw's start CFrame.
local function sample(part: BasePart): (Vector3?, CFrame?)
	local start = part:GetAttribute(ThrowConfig.ThrowStartAttribute)
	if typeof(start) ~= "CFrame" then
		return nil, nil
	end
	local now = workspace:GetServerTimeNow()
	local fallStartedAt = part:GetAttribute(ThrowConfig.FallStartedAtAttribute)
	if typeof(fallStartedAt) == "number" then
		local from = part:GetAttribute(ThrowConfig.FallFromAttribute)
		local to = part:GetAttribute(ThrowConfig.FallToAttribute)
		if typeof(from) == "Vector3" and typeof(to) == "Vector3" then
			return Projectile.FallPosition(from, to, now - fallStartedAt), start
		end
		return nil, nil
	end
	local finish = part:GetAttribute(ThrowConfig.ThrowEndAttribute)
	local startedAt = part:GetAttribute(ThrowConfig.ThrowStartedAtAttribute)
	if typeof(finish) ~= "Vector3" or typeof(startedAt) ~= "number" then
		return nil, nil
	end
	local position = Projectile.FlightPosition(start.Position, finish, now - startedAt)
	return position, start
end

local function render(state: Tracked): ()
	local part = state.Part
	local position, start = sample(part)
	if position == nil or start == nil then
		return
	end
	local prediction = predictions[part]
	if prediction ~= nil and prediction.Offset ~= nil then
		local alpha = math.clamp((workspace:GetServerTimeNow() - prediction.ReconcileAt) / ThrowConfig.ReconcileTime, 0, 1)
		position += prediction.Offset * (1 - alpha)
		if alpha >= 1 then
			predictions[part] = nil
		end
	end
	part.CFrame = Projectile.At(start, position)
end

local function rollback(prediction: Prediction): ()
	predictions[prediction.Part] = nil
	local holder = prediction.Holder
	if holder.Parent ~= nil then
		-- A WeldConstraint welds at the current offset, so put the part back in the hand first.
		local root: BasePart? = holder.Part0
		if root ~= nil and prediction.HoldOffset ~= nil then
			prediction.Part.CFrame = root.CFrame * prediction.HoldOffset
		end
		holder.Enabled = true
		prediction.Part.Anchored = false
	end
	untrack(prediction.Part, true)
end

local function stepPrediction(prediction: Prediction): ()
	local part = prediction.Part
	if part.Parent == nil then
		predictions[part] = nil
		return
	end
	local now = workspace:GetServerTimeNow()
	if prediction.Offset ~= nil then
		-- Confirmed: render() blends and ends the prediction; the server stopping the flight ends it too.
		if tracked[part] == nil then
			predictions[part] = nil
		end
		return
	end
	if CollectionService:HasTag(part, Tags.Projectile) and typeof(part:GetAttribute(ThrowConfig.ThrowStartedAtAttribute)) == "number" then
		local serverPosition = sample(part)
		if serverPosition ~= nil then
			prediction.Offset = prediction.Last - serverPosition
			prediction.ReconcileAt = now
			return
		end
	end
	if prediction.Holder.Parent == nil and not CollectionService:HasTag(part, Tags.Projectile) then
		-- The server dropped the hold and already ended the flight (a catch or an instant hit) before this client saw it.
		predictions[part] = nil
		untrack(part, false)
		return
	end
	if now - prediction.StartedAt > ThrowConfig.PredictionTimeout then
		rollback(prediction)
		return
	end
	if prediction.Frozen then
		return
	end
	local position, done = Projectile.FlightPosition(prediction.Start.Position, prediction.Endpoint, now - prediction.StartedAt)
	local hit = Projectile.Sweep(prediction.Previous, position, prediction.Params)
	if hit ~= nil then
		position = hit.Position + hit.Normal * ThrowConfig.CastRadius
		prediction.Frozen = true
	elseif done then
		prediction.Frozen = true
	end
	prediction.Previous = position
	prediction.Last = position
	part.CFrame = Projectile.At(prediction.Start, position)
end

-- Starts the thrower's local flight right before the Throw request is fired.
function ProjectileController.Predict(part: BasePart, holder: WeldConstraint, start: CFrame): ()
	if predictions[part] ~= nil or CollectionService:HasTag(part, Tags.Projectile) then
		return
	end
	local excluded: { Instance } = { part }
	local character = Players.LocalPlayer.Character
	if character ~= nil then
		table.insert(excluded, character)
	end
	for _, tag in { Tags.Ignore, Tags.ProjectileIgnore, Tags.Projectile } do
		for _, instance in CollectionService:GetTagged(tag) do
			table.insert(excluded, instance)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = excluded
	-- Client-only changes: the server removes the weld and anchors the part when it processes the throw.
	local root: BasePart? = holder.Part0
	local holdOffset = if root ~= nil then root.CFrame:ToObjectSpace(part.CFrame) else nil
	holder.Enabled = false
	part.Anchored = true
	local now = workspace:GetServerTimeNow()
	predictions[part] = {
		Part = part,
		Holder = holder,
		HoldOffset = holdOffset,
		Start = start,
		Endpoint = Projectile.Endpoint(part, start),
		StartedAt = now,
		Params = params,
		Previous = start.Position,
		Last = start.Position,
		Frozen = false,
		Offset = nil,
		ReconcileAt = 0,
	}
	track(part)
end

function ProjectileController.Start(_self: typeof(ProjectileController)): ()
	local template = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Effects"):WaitForChild("ProjectileTrail")
	assert(template:IsA("Trail"), "ProjectileTrail must be a Trail")
	trailTemplate = template
	CollectionService:GetInstanceAddedSignal(Tags.Projectile):Connect(track)
	CollectionService:GetInstanceRemovedSignal(Tags.Projectile):Connect(function(instance: Instance): ()
		untrack(instance, false)
	end)
	for _, instance in CollectionService:GetTagged(Tags.Projectile) do
		track(instance)
	end
	RunService.RenderStepped:Connect(function(): ()
		for _, prediction in predictions do
			stepPrediction(prediction)
		end
		for _, state in tracked do
			render(state)
		end
	end)
end

return ProjectileController
