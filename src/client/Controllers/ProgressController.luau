--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Interaction"))
local Tags = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Tags"))

local ProgressController = {}

type Tracked = {
	Kind: "Food" | "CookingTool" | "Sink",
	Ancestry: RBXScriptConnection,
	Destroying: RBXScriptConnection,
	Attributes: { RBXScriptConnection },
	Bar: BillboardGui?,
	LastProgress: number?,
}

local tracked: { [Instance]: Tracked } = {}
local template: BillboardGui
local chopSound: Sound

local function updateProgressBar(progressBar: BillboardGui, progress: number): ()
	local background = progressBar:FindFirstChild("BG")
	local clip = if background then background:FindFirstChild("Clip") else nil
	local bar = if clip then clip:FindFirstChild("Bar") else nil
	assert(bar ~= nil and bar:IsA("Frame"), "ProgressBar.BG.Clip.Bar must be a Frame")
	bar.Size = UDim2.new((math.clamp(progress, 0, 100) / 100) * 2, bar.Size.X.Offset, bar.Size.Y.Scale, bar.Size.Y.Offset)
end

local function showProgress(instance: Instance, state: Tracked, progress: number?): ()
	if progress == nil or (state.Kind == "CookingTool" and progress >= 100) then
		if state.Bar ~= nil then
			state.Bar:Destroy()
			state.Bar = nil
		end
		return
	end
	if state.Bar == nil then
		local bar = template:Clone()
		local parent = if state.Kind == "Sink" then instance:FindFirstChild("WashPartMarker") else instance
		if parent == nil then
			bar:Destroy()
			return
		end
		bar.Parent = parent
		state.Bar = bar
	end
	updateProgressBar(state.Bar :: BillboardGui, progress)
end

local function refreshSink(instance: Instance, state: Tracked): ()
	local progress = instance:GetAttribute(Config.WashProgressAttribute)
	showProgress(instance, state, if typeof(progress) == "number" then progress else nil)
end

local function refreshProgress(instance: Instance, state: Tracked, playSound: boolean): ()
	local value = instance:GetAttribute(Config.ChopProgressAttribute)
	if typeof(value) ~= "number" then
		showProgress(instance, state, nil)
		state.LastProgress = nil
		return
	end
	showProgress(instance, state, value)
	if playSound and value > (state.LastProgress or 0) then
		chopSound:Play()
	end
	state.LastProgress = value
end

local function refreshCooking(instance: Instance, state: Tracked): ()
	if typeof(instance:GetAttribute(Config.Cooking.CookContentAttribute)) ~= "string" then
		showProgress(instance, state, nil)
		return
	end
	local base = instance:GetAttribute(Config.Cooking.CookProgressAttribute)
	if typeof(base) ~= "number" then
		showProgress(instance, state, nil)
		return
	end
	local startedAt = instance:GetAttribute(Config.Cooking.CookStartedAtAttribute)
	local progress = if typeof(startedAt) == "number"
		then math.min(base + (workspace:GetServerTimeNow() - startedAt) * Config.Cooking.CookRate, 100)
		else base
	showProgress(instance, state, progress)
end

local function untrack(instance: Instance): ()
	local state = tracked[instance]
	if state == nil then
		return
	end
	tracked[instance] = nil
	state.Ancestry:Disconnect()
	state.Destroying:Disconnect()
	for _, connection in state.Attributes do
		connection:Disconnect()
	end
	if state.Bar then
		state.Bar:Destroy()
	end
end

local function refresh(instance: Instance): ()
	local state = tracked[instance]
	if state == nil then
		return
	end
	if instance:IsDescendantOf(workspace) then
		if #state.Attributes == 0 then
			if state.Kind == "Food" then
				table.insert(state.Attributes, instance:GetAttributeChangedSignal(Config.ChopProgressAttribute):Connect(function(): ()
					refreshProgress(instance, state, true)
				end))
				refreshProgress(instance, state, false)
			elseif state.Kind == "CookingTool" then
				for _, name in { Config.Cooking.CookContentAttribute, Config.Cooking.CookProgressAttribute, Config.Cooking.CookStartedAtAttribute } do
					table.insert(state.Attributes, instance:GetAttributeChangedSignal(name):Connect(function(): ()
						refreshCooking(instance, state)
					end))
				end
				refreshCooking(instance, state)
			else
				table.insert(state.Attributes, instance:GetAttributeChangedSignal(Config.WashProgressAttribute):Connect(function(): ()
					refreshSink(instance, state)
				end))
				refreshSink(instance, state)
			end
		end
	else
		for _, connection in state.Attributes do
			connection:Disconnect()
		end
		table.clear(state.Attributes)
		if state.Bar then
			state.Bar:Destroy()
			state.Bar = nil
		end
		state.LastProgress = nil
	end
end

local function track(instance: Instance, kind: "Food" | "CookingTool" | "Sink"): ()
	if tracked[instance] then
		return
	end
	local state: Tracked = {
		Kind = kind,
		Ancestry = instance.AncestryChanged:Connect(function(): ()
			refresh(instance)
		end),
		Destroying = instance.Destroying:Connect(function(): ()
			untrack(instance)
		end),
		Attributes = {},
		Bar = nil,
		LastProgress = nil,
	}
	tracked[instance] = state
	refresh(instance)
end

function ProgressController.Start(_self: typeof(ProgressController)): ()
	local progressBar = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("ProgressBar")
	assert(progressBar:IsA("BillboardGui"), "ReplicatedStorage.Assets.ProgressBar must be a BillboardGui")
	template = progressBar
	local sound = SoundService:WaitForChild("SoundEffects"):WaitForChild("Chop")
	assert(sound:IsA("Sound"), "SoundService.SoundEffects.Chop must be a Sound")
	chopSound = sound

	CollectionService:GetInstanceAddedSignal(Tags.Food):Connect(function(instance: Instance): ()
		track(instance, "Food")
	end)
	CollectionService:GetInstanceRemovedSignal(Tags.Food):Connect(untrack)
	for _, instance in CollectionService:GetTagged(Tags.Food) do
		track(instance, "Food")
	end
	CollectionService:GetInstanceAddedSignal(Tags.CookingTool):Connect(function(instance: Instance): ()
		track(instance, "CookingTool")
	end)
	CollectionService:GetInstanceRemovedSignal(Tags.CookingTool):Connect(untrack)
	for _, instance in CollectionService:GetTagged(Tags.CookingTool) do
		track(instance, "CookingTool")
	end
	CollectionService:GetInstanceAddedSignal(Tags.Sink):Connect(function(instance: Instance): ()
		track(instance, "Sink")
	end)
	CollectionService:GetInstanceRemovedSignal(Tags.Sink):Connect(untrack)
	for _, instance in CollectionService:GetTagged(Tags.Sink) do
		track(instance, "Sink")
	end
	RunService.Heartbeat:Connect(function(): ()
		for instance, state in tracked do
			if state.Kind == "CookingTool" and #state.Attributes > 0 then
				local startedAt = instance:GetAttribute(Config.Cooking.CookStartedAtAttribute)
				if typeof(startedAt) == "number" then
					refreshCooking(instance, state)
				end
			end
		end
	end)
end

return ProgressController
