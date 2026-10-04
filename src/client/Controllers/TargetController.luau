--!strict

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"):WaitForChild("Interaction"))
local Tags = require(Shared:WaitForChild("Tags"))

-- Ported from legacy HighlightHandler: picks the best interactable near the character and highlights it.
local TargetController = {}

local localPlayer = Players.LocalPlayer

local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Include

local candidates: { [Instance]: boolean } = {}
local ancestryConnections: { [Instance]: RBXScriptConnection } = {}
local candidatesDirty = false

local target: Instance? = nil
local targetNode: BasePart? = nil
local highlights: { Instance } = {}

local highlightTemplate: Highlight? = nil

local function isRelevant(instance: Instance): boolean
	return instance:IsDescendantOf(workspace)
		and (CollectionService:HasTag(instance, Tags.ProximityNode) or Tags.ClassOf(instance) ~= nil)
end

local function refresh(instance: Instance): ()
	local relevant = isRelevant(instance)
	if relevant then
		if not candidates[instance] then
			candidates[instance] = true
			candidatesDirty = true
		end
	elseif candidates[instance] then
		candidates[instance] = nil
		candidatesDirty = true
	end
end

local function track(instance: Instance): ()
	if not ancestryConnections[instance] then
		ancestryConnections[instance] = instance.AncestryChanged:Connect(function(): ()
			refresh(instance)
		end)
	end
	refresh(instance)
end

local function untrack(instance: Instance): ()
	refresh(instance)
	if not CollectionService:HasTag(instance, Tags.ProximityNode) and Tags.ClassOf(instance) == nil then
		local connection = ancestryConnections[instance]
		if connection then
			ancestryConnections[instance] = nil
			connection:Disconnect()
		end
	end
end

local function clearHighlights(): ()
	for _, highlight in highlights do
		highlight:Destroy()
	end
	table.clear(highlights)
end

local function highlight(newTarget: Instance): ()
	local template = highlightTemplate
	if template == nil then
		return
	end
	local function attach(parent: Instance): ()
		local clone = template:Clone()
		clone.Parent = parent
		table.insert(highlights, clone)
	end
	attach(newTarget)
	for _, descendant in newTarget:GetDescendants() do
		if descendant:IsA("BasePart") then
			attach(descendant)
		end
	end
end

local function setTarget(newTarget: Instance?, node: BasePart?): ()
	targetNode = node
	if newTarget == target then
		return
	end
	clearHighlights()
	target = newTarget
	if newTarget ~= nil then
		highlight(newTarget)
	end
end

local function findBest(rootPart: BasePart): (Instance?, BasePart?)
	local position = rootPart.Position
	local nearby = workspace:GetPartBoundsInRadius(position, Config.TargetRadius, overlapParams)

	local bestTarget: Instance? = nil
	local bestNode: BasePart? = nil
	local bestScore = -math.huge

	for _, part in nearby do
		local candidate: Instance? = part
		local node: BasePart? = nil
		if CollectionService:HasTag(part, Tags.ProximityNode) then
			candidate = if part.Parent then part.Parent.Parent else nil
			node = part
		end
		if candidate == nil then
			continue
		end

		local class = Tags.ClassOf(candidate)
		if class == nil or Tags.IsInteractionDisabled(candidate) then
			continue
		end

		local distance = (part.Position - position).Magnitude
		if distance >= (Config.MinDistance[class] or Config.DefaultMinDistance) then
			continue
		end

		local priority = Config.TargetPriority[class] or Config.DefaultPriority
		local score = priority * Config.PriorityWeight - distance
		if score > bestScore then
			bestScore = score
			bestTarget = candidate
			bestNode = node
		end
	end
	return bestTarget, bestNode
end

local function update(): ()
	if candidatesDirty then
		candidatesDirty = false
		local list: { Instance } = {}
		for instance in candidates do
			table.insert(list, instance)
		end
		overlapParams.FilterDescendantsInstances = list
	end

	local character = localPlayer.Character
	local rootPart = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if rootPart == nil or not rootPart:IsA("BasePart") then
		setTarget(nil, nil)
		return
	end

	local bestTarget, bestNode = findBest(rootPart)
	setTarget(bestTarget, bestNode)
end

function TargetController.GetTarget(): (Instance?, BasePart?)
	return target, targetNode
end

function TargetController.Start(_self: typeof(TargetController)): ()
	local template = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("VisibilityHighlight")
	assert(template:IsA("Highlight"), "ReplicatedStorage.Assets.VisibilityHighlight must be a Highlight")
	highlightTemplate = template

	local tracked: { string } = { Tags.ProximityNode }
	for _, tag in Tags.Classes do
		table.insert(tracked, tag)
	end
	for _, tag in tracked do
		CollectionService:GetInstanceAddedSignal(tag):Connect(track)
		CollectionService:GetInstanceRemovedSignal(tag):Connect(untrack)
		for _, instance in CollectionService:GetTagged(tag) do
			track(instance)
		end
	end

	-- A new character invalidates the current target immediately.
	localPlayer.CharacterRemoving:Connect(function(): ()
		setTarget(nil, nil)
	end)
	RunService.Heartbeat:Connect(update)
end

return TargetController
