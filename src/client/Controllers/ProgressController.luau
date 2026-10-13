--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local InteractionConfig = Config.Interaction
local Tags = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Tags"))

local ProgressController = {}

-- The template's parts code drives (see docs/UI-GUIDE.md, Assets.UI.ProgressBar).
type Parts = {
	Gui: BillboardGui,
	Root: GuiObject,
	Scale: UIScale,
	Glow: ImageLabel,
	Fill: GuiObject,
	Badge: GuiObject,
	BadgeFace: GuiObject,
	Check: GuiObject,
	Bang: GuiObject,
}

-- What the bar shows this frame. Fill is 0-1, Glow is the glow's transparency (1 = hidden).
type View = {
	Fill: number,
	Color: Color3,
	Badge: ("Check" | "Bang")?,
	Scale: number,
	Rotation: number,
	Glow: number,
}

type Tracked = {
	Kind: "Food" | "CookingTool" | "Sink",
	Ancestry: RBXScriptConnection,
	Destroying: RBXScriptConnection,
	Attributes: { RBXScriptConnection },
	Bar: Parts?,
	LastProgress: number?,
}

local tracked: { [Instance]: Tracked } = {}
local template: BillboardGui
local chopSound: Sound
local tuning = Config.UI.Progress
local cooking = InteractionConfig.Cooking

local function child(parent: Instance, name: string, className: string): any
	local found = parent:FindFirstChild(name)
	assert(found ~= nil and found:IsA(className), `ProgressBar: {parent.Name}.{name} must be a {className}`)
	return found
end

local function makeBar(parent: Instance): Parts
	local gui = template:Clone()
	local root: GuiObject = child(gui, "Root", "GuiObject")
	local face: GuiObject = child(root, "Face", "GuiObject")
	local track: GuiObject = child(face, "Track", "GuiObject")
	local badge: GuiObject = child(root, "Badge", "GuiObject")
	local parts: Parts = {
		Gui = gui,
		Root = root,
		Scale = child(root, "Scale", "UIScale"),
		Glow = child(root, "Glow", "ImageLabel"),
		Fill = child(track, "Fill", "GuiObject"),
		Badge = badge,
		BadgeFace = child(badge, "Face", "GuiObject"),
		Check = child(badge, "Check", "GuiObject"),
		Bang = child(badge, "Bang", "GuiObject"),
	}
	gui.Parent = parent
	return parts
end

local function fillView(progress: number): View
	return { Fill = progress / 100, Color = tuning.Fill, Badge = nil, Scale = 1, Rotation = 0, Glow = 1 }
end

local function render(parts: Parts, view: View): ()
	local fill = math.clamp(view.Fill, 0, 1)
	parts.Fill.Visible = fill > 0
	parts.Fill.Size = UDim2.fromScale(fill, 1)
	parts.Fill.BackgroundColor3 = view.Color
	parts.Badge.Visible = view.Badge ~= nil
	parts.BadgeFace.BackgroundColor3 = view.Color
	parts.Check.Visible = view.Badge == "Check"
	parts.Bang.Visible = view.Badge == "Bang"
	parts.Scale.Scale = view.Scale
	parts.Root.Rotation = view.Rotation
	parts.Glow.ImageTransparency = view.Glow
end

local function showProgress(instance: Instance, state: Tracked, view: View?): ()
	if view == nil then
		if state.Bar ~= nil then
			state.Bar.Gui:Destroy()
			state.Bar = nil
		end
		return
	end
	if state.Bar == nil then
		local parent = if state.Kind == "Sink" then instance:FindFirstChild("WashPartMarker") else instance
		if parent == nil then
			return
		end
		state.Bar = makeBar(parent)
	end
	render(state.Bar :: Parts, view)
end

local function refreshSink(instance: Instance, state: Tracked): ()
	local progress = instance:GetAttribute(InteractionConfig.WashProgressAttribute)
	showProgress(instance, state, if typeof(progress) == "number" then fillView(progress) else nil)
end

local function refreshProgress(instance: Instance, state: Tracked, playSound: boolean): ()
	local value = instance:GetAttribute(InteractionConfig.ChopProgressAttribute)
	if typeof(value) ~= "number" then
		showProgress(instance, state, nil)
		state.LastProgress = nil
		return
	end
	showProgress(instance, state, fillView(value))
	if playSound and value > (state.LastProgress or 0) then
		chopSound:Play()
	end
	state.LastProgress = value
end

-- Cooked: a full bar with a check that pops in, then the burn warning drains it down to the burn.
local function cookedView(elapsed: number, now: number): View?
	if elapsed < cooking.CookSafeTime then
		local pop = math.clamp(elapsed / tuning.DonePopTime, 0, 1)
		return { Fill = 1, Color = tuning.Fill, Badge = "Check", Scale = 1 + math.sin(pop * math.pi) * tuning.DonePop, Rotation = 0, Glow = 1 }
	end
	local warned = elapsed - cooking.CookSafeTime
	local t = warned / cooking.CookAlertDuration
	if t >= 1 then
		return nil
	end
	-- The pulse speeds up from WarnPulse[1] to [2] per second; the phase is its integral so the speed-up stays smooth.
	local slow, fast = tuning.WarnPulse[1], tuning.WarnPulse[2]
	local phase = slow * warned + (fast - slow) * warned * warned / (2 * cooking.CookAlertDuration)
	local wave = (1 - math.cos(phase * 2 * math.pi)) / 2
	local shake = tuning.WarnShake[1] + (tuning.WarnShake[2] - tuning.WarnShake[1]) * t
	return {
		Fill = 1 - t,
		Color = tuning.Warn,
		Badge = "Bang",
		Scale = 1,
		Rotation = shake * math.sin(now * tuning.WarnShakeSpeed * 2 * math.pi),
		Glow = tuning.WarnGlow[1] + (tuning.WarnGlow[2] - tuning.WarnGlow[1]) * wave,
	}
end

local function refreshCooking(instance: Instance, state: Tracked): ()
	local fire = instance:GetAttribute(cooking.FireAttribute)
	if typeof(instance:GetAttribute(cooking.CookContentAttribute)) ~= "string" or (typeof(fire) == "number" and fire > 0) then
		showProgress(instance, state, nil)
		return
	end
	local cookedAt = instance:GetAttribute(cooking.CookedAtAttribute)
	if typeof(cookedAt) == "number" then
		-- Deep Freeze holds the warning where it was when the tool froze.
		local frozenAt = instance:GetAttribute(Config.Skills.Attribute.FrozenAt)
		local now = if typeof(frozenAt) == "number" then frozenAt else workspace:GetServerTimeNow()
		showProgress(instance, state, cookedView(now - cookedAt, now))
		return
	end
	local base = instance:GetAttribute(cooking.CookProgressAttribute)
	if typeof(base) ~= "number" then
		showProgress(instance, state, nil)
		return
	end
	local startedAt = instance:GetAttribute(cooking.CookStartedAtAttribute)
	local progress = if typeof(startedAt) == "number"
		then math.min(base + (workspace:GetServerTimeNow() - startedAt) * cooking.CookRate, 100)
		else base
	showProgress(instance, state, fillView(progress))
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
		state.Bar.Gui:Destroy()
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
				table.insert(state.Attributes, instance:GetAttributeChangedSignal(InteractionConfig.ChopProgressAttribute):Connect(function(): ()
					refreshProgress(instance, state, true)
				end))
				refreshProgress(instance, state, false)
			elseif state.Kind == "CookingTool" then
				-- Heartbeat redraws cooking bars every frame; this just marks the tool as live.
				table.insert(state.Attributes, instance:GetAttributeChangedSignal(cooking.CookContentAttribute):Connect(function(): ()
					refreshCooking(instance, state)
				end))
				refreshCooking(instance, state)
			else
				table.insert(state.Attributes, instance:GetAttributeChangedSignal(InteractionConfig.WashProgressAttribute):Connect(function(): ()
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
			state.Bar.Gui:Destroy()
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
	local progressBar = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("UI"):WaitForChild("ProgressBar")
	assert(progressBar:IsA("BillboardGui"), "ReplicatedStorage.Assets.UI.ProgressBar must be a BillboardGui")
	template = progressBar
	local sound = SoundService:WaitForChild("SoundEffects"):WaitForChild("Chop")
	assert(sound:IsA("Sound"), "SoundService.SoundEffects.Chop must be a Sound")
	chopSound = sound

	CollectionService:GetInstanceAddedSignal(Tags.ClassTag(Tags.Food)):Connect(function(instance: Instance): ()
		track(instance, "Food")
	end)
	CollectionService:GetInstanceRemovedSignal(Tags.ClassTag(Tags.Food)):Connect(untrack)
	for _, instance in CollectionService:GetTagged(Tags.ClassTag(Tags.Food)) do
		track(instance, "Food")
	end
	CollectionService:GetInstanceAddedSignal(Tags.ClassTag(Tags.CookingTool)):Connect(function(instance: Instance): ()
		track(instance, "CookingTool")
	end)
	CollectionService:GetInstanceRemovedSignal(Tags.ClassTag(Tags.CookingTool)):Connect(untrack)
	for _, instance in CollectionService:GetTagged(Tags.ClassTag(Tags.CookingTool)) do
		track(instance, "CookingTool")
	end
	CollectionService:GetInstanceAddedSignal(Tags.ClassTag(Tags.Sink)):Connect(function(instance: Instance): ()
		track(instance, "Sink")
	end)
	CollectionService:GetInstanceRemovedSignal(Tags.ClassTag(Tags.Sink)):Connect(untrack)
	for _, instance in CollectionService:GetTagged(Tags.ClassTag(Tags.Sink)) do
		track(instance, "Sink")
	end
	-- Cooking bars move every frame: the fill, the done pop, the warning's pulse and shake.
	RunService.Heartbeat:Connect(function(): ()
		for instance, state in tracked do
			if state.Kind == "CookingTool" and #state.Attributes > 0 then
				refreshCooking(instance, state)
			end
		end
	end)
end

return ProgressController
