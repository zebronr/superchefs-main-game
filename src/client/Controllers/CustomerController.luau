--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Levels = Config.Levels

type Bubble = {
	Gui: BillboardGui,
	BaseSize: UDim2,
	BaseOffset: Vector3,
	Phase: number,
	Shown: boolean,
	ShownAt: number?,
	HideAt: number?,
	LastState: string?,
	StateAt: number?,
	Icon: ImageLabel?,
	Alert: GuiObject?,
	Dash: GuiObject?,
	Bar: GuiObject?,
	RunnerHighlight: Highlight?,
	Fill: Frame?,
	Frost: GuiObject?,
	Snowflake: GuiObject?,
	FrostTexture: ImageLabel?,
	FrostScale: UIScale?,
	SnowflakeScale: UIScale?,
	FrostBaseScale: number,
	SnowflakeBaseScale: number,
	FrostPosition: UDim2?,
	SnowflakeRotation: number,
	FrostParts: { { Object: GuiObject, Background: number, Image: number? } },
	FrozenAt: number?,
	ThawAt: number?,
}

local CustomerController = {}
local bubbles: { [Model]: Bubble } = {}
local walkTracks: { [Model]: AnimationTrack? } = {}
local warnedAnimator = false

local GREEN = Config.UI.Patience.Green
local YELLOW = Config.UI.Patience.Yellow
local RED = Config.UI.Patience.Red
local FROZEN = Config.UI.Patience.Frozen
local FrozenAttribute = Config.Skills.Attribute.FrozenAt
local frostTuning = Config.UI.Patience
local bubbleTuning = Config.UI.Bubble

local function scaleFor(object: GuiObject?): UIScale?
	if object == nil then
		return nil
	end
	local scale = object:FindFirstChildOfClass("UIScale")
	if scale == nil then
		local created = Instance.new("UIScale")
		created.Parent = object
		return created
	end
	return scale
end

local function frostParts(frost: GuiObject?): { { Object: GuiObject, Background: number, Image: number? } }
	local parts: { { Object: GuiObject, Background: number, Image: number? } } = {}
	if frost == nil then
		return parts
	end
	local function addPart(object: GuiObject): ()
		local image = if object:IsA("ImageLabel") or object:IsA("ImageButton") then object.ImageTransparency else nil
		table.insert(parts, { Object = object, Background = object.BackgroundTransparency, Image = image })
	end
	addPart(frost)
	for _, descendant in frost:GetDescendants() do
		if descendant:IsA("GuiObject") then
			addPart(descendant)
		end
	end
	return parts
end

local function frostOpacity(bubble: Bubble, fade: number): ()
	for _, part in bubble.FrostParts do
		part.Object.BackgroundTransparency = part.Background + (1 - part.Background) * fade
		local image = part.Image
		local object = part.Object
		if image ~= nil then
			if object:IsA("ImageLabel") then
				object.ImageTransparency = image + (1 - image) * fade
			elseif object:IsA("ImageButton") then
				object.ImageTransparency = image + (1 - image) * fade
			end
		end
	end
end

local function pop(t: number): number
	if t >= 1 then
		return 1
	end
	return 1 - 2 ^ (-10 * t) + frostTuning.FrostPopOvershoot * math.sin(t * math.pi * 5) * (1 - t) ^ 2
end

local function updateFrost(model: Model, bubble: Bubble, now: number): boolean
	local attribute = model:GetAttribute(FrozenAttribute)
	local frozenAt = if typeof(attribute) == "number" then attribute else nil
	if frozenAt ~= bubble.FrozenAt then
		if frozenAt ~= nil then
			bubble.ThawAt = nil
			frostOpacity(bubble, 0)
		elseif bubble.FrozenAt ~= nil then
			bubble.ThawAt = now
		end
		bubble.FrozenAt = frozenAt
	end
	local frost = bubble.Frost
	local snowflake = bubble.Snowflake
	local texture = bubble.FrostTexture
	if texture ~= nil then
		texture.Visible = frozenAt ~= nil
	end
	if snowflake ~= nil then
		snowflake.Visible = frozenAt ~= nil
		if frozenAt ~= nil then
			local t = if frostTuning.FrostPopTime > 0 then math.clamp((now - frozenAt) / frostTuning.FrostPopTime, 0, 1) else 1
			local scale = bubble.SnowflakeScale
			if scale ~= nil then scale.Scale = bubble.SnowflakeBaseScale * math.max(pop(t), 0.001) end
			snowflake.Rotation = bubble.SnowflakeRotation + (now - frozenAt) * frostTuning.SnowflakeSpin
		end
	end
	if frost ~= nil then
		local position = bubble.FrostPosition
		local scale = bubble.FrostScale
		if frozenAt ~= nil then
			frost.Visible = true
			local t = if frostTuning.FrostPopTime > 0 then math.clamp((now - frozenAt) / frostTuning.FrostPopTime, 0, 1) else 1
			if scale ~= nil then scale.Scale = bubble.FrostBaseScale * math.max(pop(t), 0.001) end
			if position ~= nil then frost.Position = position end
			frostOpacity(bubble, 0)
		elseif bubble.ThawAt ~= nil then
			local t = if frostTuning.FrostCrackTime > 0 then math.clamp((now - bubble.ThawAt) / frostTuning.FrostCrackTime, 0, 1) else 1
			frost.Visible = t < 1
			if scale ~= nil then scale.Scale = bubble.FrostBaseScale * (1 + frostTuning.FrostCrackScale * t) end
			if position ~= nil then
				frost.Position = position + UDim2.fromOffset(math.sin(t * math.pi * 8) * frostTuning.FrostCrackShake * (1 - t), 0)
			end
			frostOpacity(bubble, t)
		else
			frost.Visible = false
		end
	end
	return frozenAt ~= nil
end

local function remove(model: Model): ()
	local track = walkTracks[model]
	if track ~= nil then
		walkTracks[model] = nil
		track:Stop()
		track:Destroy()
	end
	local bubble = bubbles[model]
	if bubble ~= nil then
		bubbles[model] = nil
		bubble.Gui:Destroy()
		if bubble.RunnerHighlight ~= nil then
			bubble.RunnerHighlight:Destroy()
		end
	end
end

local function updateWalk(model: Model): ()
	if typeof(model:GetAttribute(FrozenAttribute)) == "number" then
		return
	end
	local state = model:GetAttribute("CustomerState")
	local walking = state == "Walking" or state == "Leaving" or state == "Dashing"
	local track = walkTracks[model]
	if walking and track == nil then
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local animator = if humanoid then humanoid:FindFirstChildOfClass("Animator") else nil
		if animator == nil then
			if not warnedAnimator then
				warn("Customer Humanoid.Animator is missing; walk animation skipped")
				warnedAnimator = true
			end
			return
		end
		local animation = Instance.new("Animation")
		animation.AnimationId = Config.Customers.WalkAnimation
		local loaded = animator:LoadAnimation(animation)
		animation:Destroy()
		loaded.Looped = true
		walkTracks[model] = loaded
		loaded:Play()
	end
	local current = walkTracks[model]
	if walking then
		if current ~= nil then
			current:AdjustSpeed(if state == "Dashing" then Config.Customers.DashAnimSpeed else 1)
		end
	elseif current ~= nil then
		walkTracks[model] = nil
		current:Stop()
		current:Destroy()
	end
end

local function add(model: Model, template: BillboardGui): ()
	if bubbles[model] ~= nil or model:GetAttribute("CustomerState") == nil then
		return
	end
	local head = model:FindFirstChild("Head")
	if head == nil or not head:IsA("BasePart") then
		return
	end
	local gui = template:Clone()
	local icon = gui:FindFirstChild("Icon", true)
	local alert = gui:FindFirstChild("Alert", true)
	local dash = gui:FindFirstChild("Dash", true)
	local bar = gui:FindFirstChild("Bar", true)
	local fill = if bar then bar:FindFirstChild("Fill") else nil
	local frost = gui:FindFirstChild("Frost", true)
	local snowflake = gui:FindFirstChild("Snowflake", true)
	local frostTexture = if fill then fill:FindFirstChild("FrostTexture") else nil
	local frostObject = if frost and frost:IsA("GuiObject") then frost else nil
	local snowflakeObject = if snowflake and snowflake:IsA("GuiObject") then snowflake else nil
	local frostScale = scaleFor(frostObject)
	local snowflakeScale = scaleFor(snowflakeObject)
	bubbles[model] = {
		Gui = gui,
		BaseSize = gui.Size,
		BaseOffset = gui.StudsOffset,
		Phase = math.random() * bubbleTuning.BobPeriod,
		Shown = false,
		ShownAt = nil,
		HideAt = nil,
		LastState = nil,
		StateAt = nil,
		Icon = if icon and icon:IsA("ImageLabel") then icon else nil,
		Alert = if alert and alert:IsA("GuiObject") then alert else nil,
		Dash = if dash and dash:IsA("GuiObject") then dash else nil,
		Bar = if bar and bar:IsA("GuiObject") then bar else nil,
		Fill = if fill and fill:IsA("Frame") then fill else nil,
		Frost = frostObject,
		Snowflake = snowflakeObject,
		FrostTexture = if frostTexture and frostTexture:IsA("ImageLabel") then frostTexture else nil,
		FrostScale = frostScale,
		SnowflakeScale = snowflakeScale,
		FrostBaseScale = if frostScale then frostScale.Scale else 1,
		SnowflakeBaseScale = if snowflakeScale then snowflakeScale.Scale else 1,
		FrostPosition = if frostObject then frostObject.Position else nil,
		SnowflakeRotation = if snowflakeObject then snowflakeObject.Rotation else 0,
		FrostParts = frostParts(frostObject),
		FrozenAt = nil,
		ThawAt = nil,
	}
	if frostObject ~= nil then frostObject.Visible = false end
	if snowflakeObject ~= nil then snowflakeObject.Visible = false end
	if frostTexture ~= nil and frostTexture:IsA("ImageLabel") then frostTexture.Visible = false end
	gui.Enabled = false
	gui.Adornee = head
	gui.Parent = head
	model.Destroying:Once(function(): ()
		remove(model)
	end)
end

local function animate(bubble: Bubble, frozen: boolean, fraction: number?, clock: number, waiting: boolean, dashing: boolean): ()
	local sx, sy = 1, 1
	local bob, shake = 0, 0
	local shownAt = bubble.ShownAt
	local hideAt = bubble.HideAt
	if bubble.Shown then
		if shownAt ~= nil and clock - shownAt < bubbleTuning.PopTime then
			local t = math.clamp((clock - shownAt) / bubbleTuning.PopTime, 0, 1)
			local e = 1 - 2 ^ (-10 * t) + bubbleTuning.PopOvershoot * math.sin(t * math.pi * 5) * (1 - t) ^ 2
			local w = bubbleTuning.PopSquash * math.sin(t * math.pi * 4) * (1 - t) ^ 2
			sx *= e * (1 + w)
			sy *= e * (1 - w)
		end
		local stateAt = bubble.StateAt
		if stateAt ~= nil then
			if clock - stateAt < bubbleTuning.StateBounceTime then
				local t = math.clamp((clock - stateAt) / bubbleTuning.StateBounceTime, 0, 1)
				local w = bubbleTuning.StateBounce * math.sin(t * math.pi * 3) * (1 - t) ^ 2
				sx *= 1 + w
				sy *= 1 - w
			else
				bubble.StateAt = nil
			end
		end
		if not frozen then
			if waiting and fraction ~= nil and fraction < bubbleTuning.LowPatience then
				local p = bubbleTuning.UrgeScale * (0.5 + 0.5 * math.sin(clock * 2 * math.pi / bubbleTuning.UrgePeriod))
				sx *= 1 + p
				sy *= 1 + p
				shake = bubbleTuning.UrgeShake * math.sin(clock * 40)
			end
			local height = if dashing then bubbleTuning.DashBobHeight else bubbleTuning.BobHeight
			local period = if dashing then bubbleTuning.DashBobPeriod else bubbleTuning.BobPeriod
			bob = height * math.sin((clock + bubble.Phase) * 2 * math.pi / period)
		end
	elseif hideAt ~= nil then
		local t = math.clamp((clock - hideAt) / bubbleTuning.OutTime, 0, 1)
		local k = 1 - t ^ 4
		sx *= k
		sy *= k
	end
	sx = math.max(sx, 0.001)
	sy = math.max(sy, 0.001)
	local baseSize = bubble.BaseSize
	bubble.Gui.Size = UDim2.new(baseSize.X.Scale * sx, baseSize.X.Offset * sx, baseSize.Y.Scale * sy, baseSize.Y.Offset * sy)
	bubble.Gui.StudsOffset = bubble.BaseOffset + Vector3.new(shake, bob + (sy - 1) * baseSize.Y.Scale / 2, 0)
end

local function update(model: Model, bubble: Bubble): ()
	local now = workspace:GetServerTimeNow()
	local frozen = updateFrost(model, bubble, now)
	local clock = os.clock()
	local state = model:GetAttribute("CustomerState")
	local waitingToOrder = state == "WaitingToOrder"
	local waitingForFood = state == "WaitingForFood"
	local dashing = state == "Dashing"
	local want = waitingToOrder or waitingForFood or dashing
	if want then
		if not bubble.Shown then
			bubble.Shown = true
			bubble.ShownAt = clock
			bubble.HideAt = nil
			bubble.LastState = if typeof(state) == "string" then state else nil
			bubble.StateAt = nil
			bubble.Gui.Enabled = true
		elseif state ~= bubble.LastState then
			bubble.LastState = if typeof(state) == "string" then state else nil
			bubble.StateAt = clock
		end
	elseif bubble.Shown then
		bubble.Shown = false
		bubble.HideAt = clock
	end
	if bubble.RunnerHighlight ~= nil then
		bubble.RunnerHighlight.Enabled = dashing
	end
	if not want then
		local hideAt = bubble.HideAt
		if hideAt ~= nil and clock - hideAt < bubbleTuning.OutTime then
			animate(bubble, frozen, nil, clock, false, false)
			return
		end
		bubble.Gui.Enabled = false
		bubble.HideAt = nil
		bubble.Gui.Size = bubble.BaseSize
		bubble.Gui.StudsOffset = bubble.BaseOffset
		return
	end
	if bubble.Alert ~= nil then
		bubble.Alert.Visible = waitingToOrder
	end
	if bubble.Dash ~= nil then
		bubble.Dash.Visible = dashing
	end
	local icon = bubble.Icon
	if icon ~= nil then
		icon.Visible = waitingForFood
		if waitingForFood then
			local recipeId = model:GetAttribute("Recipe")
			local recipe = if typeof(recipeId) == "number" then Levels.GetCurrent().Recipes[recipeId] else nil
			if recipe ~= nil and icon.Image ~= recipe.FoodImage then
				icon.Image = recipe.FoodImage
			end
		end
	end
	if bubble.Bar ~= nil then
		bubble.Bar.Visible = not dashing
	end
	local fill = bubble.Fill
	local startedAt = model:GetAttribute("PatienceStartedAt")
	local duration = model:GetAttribute("PatienceDuration")
	local fraction: number? = nil
	if typeof(startedAt) == "number" and typeof(duration) == "number" then
		-- Deep Freeze holds the bar where it was when the customer froze.
		local timerNow = if frozen then bubble.FrozenAt :: number else now
		fraction = math.clamp((startedAt + duration - timerNow) / math.max(duration, 0.001), 0, 1)
	end
	if fill ~= nil and fraction ~= nil then
		local progress = 1 - fraction
		fill.Size = UDim2.new(fraction, 0, 1, 0)
		fill.BackgroundColor3 = if frozen
			then FROZEN
			elseif progress <= 0.5 then GREEN:Lerp(YELLOW, progress * 2)
			else YELLOW:Lerp(RED, (progress - 0.5) * 2)
	end
	animate(bubble, frozen, fraction, clock, waitingToOrder or waitingForFood, dashing)
end

function CustomerController.Start(_self: typeof(CustomerController)): ()
	local template = ReplicatedStorage:WaitForChild("UIs"):WaitForChild("CustomerBubble")
	if not template:IsA("BillboardGui") then
		warn("UIs.CustomerBubble must be a BillboardGui")
		return
	end
	for _, name in { "Frost", "Snowflake" } do
		local child = template:FindFirstChild(name, true)
		if child == nil or not child:IsA("GuiObject") then
			warn(`UIs.CustomerBubble.{name} (GuiObject) is missing; that frozen bubble effect is skipped`)
		end
	end
	local bar = template:FindFirstChild("Bar", true)
	local fill = if bar then bar:FindFirstChild("Fill") else nil
	local texture = if fill then fill:FindFirstChild("FrostTexture") else nil
	if texture == nil or not texture:IsA("ImageLabel") then
		warn("UIs.CustomerBubble.Bar.Fill.FrostTexture (ImageLabel) is missing; that frozen bar texture is skipped")
	end
	local temp = workspace:WaitForChild("$Temp")
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local highlights = if assets then assets:FindFirstChild("Highlights") else nil
	local runnerTemplate = if highlights then highlights:FindFirstChild("RunnerHighlight") else nil
	if runnerTemplate == nil or not runnerTemplate:IsA("Highlight") then
		warn("ReplicatedStorage.Assets.Highlights.RunnerHighlight is missing (Highlight)")
		runnerTemplate = nil
	end
	local function consider(child: Instance): ()
		if child:IsA("Model") then
			add(child, template)
			local bubble = bubbles[child]
			if bubble ~= nil and bubble.RunnerHighlight == nil and runnerTemplate ~= nil then
				local clone = runnerTemplate:Clone()
				clone.Adornee = child
				clone.Enabled = false
				clone.Parent = child
				bubble.RunnerHighlight = clone
			end
		end
	end
	temp.ChildAdded:Connect(consider)
	temp.ChildRemoved:Connect(function(child: Instance): ()
		if child:IsA("Model") then
			remove(child)
		end
	end)
	for _, child in temp:GetChildren() do
		consider(child)
	end
	RunService.Heartbeat:Connect(function(): ()
		-- With streaming, a customer can arrive before its Head, or its Head (and the bubble on it) can
		-- stream out and back in: rebuild any bubble that is missing or no longer on the model.
		for _, child in temp:GetChildren() do
			if child:IsA("Model") then
				updateWalk(child)
				local bubble = bubbles[child]
				if bubble ~= nil and not bubble.Gui:IsDescendantOf(child) then
					remove(child)
				end
				if bubbles[child] == nil then
					consider(child)
				end
			end
		end
		for model, bubble in bubbles do
			update(model, bubble)
		end
	end)
end

return CustomerController
