--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Interaction"))
local Tags = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Tags"))

local ProgressController = {}

type Tracked = {
	Ancestry: RBXScriptConnection,
	Destroying: RBXScriptConnection,
	Attribute: RBXScriptConnection?,
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
	bar.Size = UDim2.new((progress / 100) * 2, bar.Size.X.Offset, bar.Size.Y.Scale, bar.Size.Y.Offset)
end

local function refreshProgress(instance: Instance, state: Tracked, playSound: boolean): ()
	local value = instance:GetAttribute(Config.ChopProgressAttribute)
	if typeof(value) ~= "number" then
		if state.Bar then
			state.Bar:Destroy()
			state.Bar = nil
		end
		state.LastProgress = nil
		return
	end
	if state.Bar == nil then
		local bar = template:Clone()
		bar.Parent = instance
		state.Bar = bar
	end
	local bar = state.Bar
	assert(bar ~= nil)
	updateProgressBar(bar, value)
	if playSound and value > (state.LastProgress or 0) then
		chopSound:Play()
	end
	state.LastProgress = value
end

local function untrack(instance: Instance): ()
	local state = tracked[instance]
	if state == nil then
		return
	end
	tracked[instance] = nil
	state.Ancestry:Disconnect()
	state.Destroying:Disconnect()
	if state.Attribute then
		state.Attribute:Disconnect()
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
		if state.Attribute == nil then
			state.Attribute = instance:GetAttributeChangedSignal(Config.ChopProgressAttribute):Connect(function(): ()
				refreshProgress(instance, state, true)
			end)
			refreshProgress(instance, state, false)
		end
	else
		if state.Attribute then
			state.Attribute:Disconnect()
			state.Attribute = nil
		end
		if state.Bar then
			state.Bar:Destroy()
			state.Bar = nil
		end
		state.LastProgress = nil
	end
end

local function track(instance: Instance): ()
	if tracked[instance] then
		return
	end
	local state: Tracked = {
		Ancestry = instance.AncestryChanged:Connect(function(): ()
			refresh(instance)
		end),
		Destroying = instance.Destroying:Connect(function(): ()
			untrack(instance)
		end),
		Attribute = nil,
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

	CollectionService:GetInstanceAddedSignal(Tags.Food):Connect(track)
	CollectionService:GetInstanceRemovedSignal(Tags.Food):Connect(untrack)
	for _, instance in CollectionService:GetTagged(Tags.Food) do
		track(instance)
	end
end

return ProgressController
