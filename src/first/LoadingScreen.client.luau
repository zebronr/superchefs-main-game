--!strict

-- The loading screen (Figma "Loading screen", blue version). In the empty place before START a gray Roblox-style
-- boot screen (`Boot`) shows the logo and START (hosts only, Config.Round.StartHosts). START spins the logo for
-- Config.Loading.BootTime (a head start for recording), then the loading screen slides in, the server loads the map, and the screen
-- follows the real loading (1 map streamed, 2 assets preloaded, 3 every chef loaded, 4 round starting). Once the
-- server starts the intro the bar runs up to 100% and the screen slides away.
-- Layout: ReplicatedFirst.LoadingGui (see docs/UI-GUIDE.md). Tuning: Config.Loading. All motion is cosmetic.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local template = script.Parent:WaitForChild("LoadingGui") :: ScreenGui
local gui = template:Clone()
gui.Name = "LoadingScreen"
gui.Enabled = true
gui.Parent = player:WaitForChild("PlayerGui")
ReplicatedFirst:RemoveDefaultLoadingScreen()
-- When the screen last slid in (the ticket swings in from there).
local shownAt = os.clock()

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Util = Shared:WaitForChild("Util")
local BitmapLabels = require(Util:WaitForChild("BitmapLabels"))
local Config = require(Shared:WaitForChild("Config"))
local LoadingState = require(Util:WaitForChild("LoadingState"))
local Net = require(Shared:WaitForChild("Net"))
local Tags = require(Shared:WaitForChild("Tags"))
local tuning = Config.Loading

local background = gui:WaitForChild("Background") :: Frame
local pattern = background:WaitForChild("Pattern") :: Frame
local canvas = gui:WaitForChild("Canvas") :: Frame
local canvasScale = canvas:WaitForChild("Scale") :: UIScale
local swing = canvas:WaitForChild("Swing") :: Frame
local swingRest = swing.Position
local ticket = swing:WaitForChild("Ticket") :: Frame
local levelLabel = ticket:WaitForChild("Level") :: TextLabel
local kickerLabel = ticket:WaitForChild("Kicker") :: TextLabel
local menu = ticket:WaitForChild("Menu") :: Frame
local dishTemplate = menu:WaitForChild("Dish") :: Frame
local sticker = canvas:WaitForChild("NewMechanic") :: Frame
local stickerPop = sticker:WaitForChild("Pop") :: UIScale
local stickerName = sticker:WaitForChild("Name") :: TextLabel
local stickerHint = sticker:WaitForChild("Hint") :: TextLabel
local progress = canvas:WaitForChild("Progress") :: Frame
local fill = progress:WaitForChild("Fill") :: Frame
local status = canvas:WaitForChild("Status") :: TextLabel
local party = canvas:WaitForChild("Party") :: Frame
local rows = party:WaitForChild("Rows") :: Frame
local rowTemplate = rows:WaitForChild("Row") :: Frame
local tipText = canvas:WaitForChild("Tip"):WaitForChild("Text") :: TextLabel
local boot = gui:WaitForChild("Boot") :: Frame
local bootStage = boot:WaitForChild("Stage") :: Frame
local bootScale = bootStage:WaitForChild("Scale") :: UIScale
local bootLogo = bootStage:WaitForChild("Logo") :: GuiObject
local bootLogoRest = bootLogo.Rotation
local startButton = bootStage:WaitForChild("Start") :: GuiButton

type Step = { Frame: Frame, Pop: UIScale, Ring: GuiObject, Inner: GuiObject, Icon: ImageLabel, Check: GuiObject, CheckPop: UIScale }
local steps: { Step } = {}
for index = 1, 4 do
	local frame = progress:WaitForChild(`Step{index}`) :: Frame
	local check = frame:WaitForChild("Check") :: GuiObject
	local icon = frame:WaitForChild("Icon") :: ImageLabel
	icon.Image = tuning.StepIcons[index]
	table.insert(steps, {
		Frame = frame,
		Pop = frame:WaitForChild("Pop") :: UIScale,
		Ring = frame:WaitForChild("Ring") :: GuiObject,
		Inner = frame:WaitForChild("Inner") :: GuiObject,
		Icon = icon,
		Check = check,
		CheckPop = check:WaitForChild("Pop") :: UIScale,
	})
end

dishTemplate.Visible = false
rowTemplate.Visible = false
sticker.Visible = false
startButton.Visible = false

-- Draws the Jersey 15 labels now; BitmapTextController would only reach them once the client controllers run.
local function bindLabels(root: Instance): ()
	if not BitmapLabels.IsReady() then
		return
	end
	for _, descendant in root:GetDescendants() do
		if CollectionService:HasTag(descendant, Tags.BitmapText) then
			BitmapLabels.Bind(descendant)
		end
	end
end

local function setText(label: TextLabel, text: string): ()
	if label.Text ~= text then
		label.Text = text
	end
end

local function fit(): ()
	local size = gui.AbsoluteSize
	if size.X > 0 and size.Y > 0 then
		canvasScale.Scale = math.min(size.X / tuning.DesignSize.X, size.Y / tuning.DesignSize.Y)
		bootScale.Scale = canvasScale.Scale
	end
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
fit()

-- "salad(mango_cucumber)" -> "SALAD"
local function dishName(name: string): string
	local base = string.match(name, "^[^%(]+") or name
	return string.upper((string.gsub(base, "_", " ")))
end

local tips: { string } = {}
local tipIndex = 0
local tipAt = -math.huge
local filledPath: string? = nil

local function fillTicket(): ()
	local path = Config.Levels.GetCurrentPath()
	if path == nil or path == filledPath then
		return
	end
	filledPath = path
	local level = Config.Levels.GetCurrent()
	levelLabel.Text = level.Title or "SUPERCHEFS"
	kickerLabel.Text = if level.Number ~= nil then `ORDER UP!   TABLE {level.Number}` else "ORDER UP!"
	for _, child in menu:GetChildren() do
		if child:IsA("GuiObject") and child ~= dishTemplate then
			child:Destroy()
		end
	end
	local seen: { [string]: boolean } = {}
	local count = 0
	for _, recipe in level.Recipes do
		if count >= tuning.MaxMenu then
			break
		end
		if not seen[recipe.FoodImage] then
			seen[recipe.FoodImage] = true
			count += 1
			local dish = dishTemplate:Clone()
			dish.Name = `Dish{count}`
			dish.LayoutOrder = count
			dish.Visible = true
			local icon = dish:FindFirstChild("Icon", true)
			if icon ~= nil and icon:IsA("ImageLabel") then
				icon.Image = recipe.FoodImage
			end
			local nameLabel = dish:FindFirstChild("Name", true)
			if nameLabel ~= nil and nameLabel:IsA("TextLabel") then
				nameLabel.Text = dishName(recipe.Name)
			end
			dish.Parent = menu
		end
	end
	local mechanic = level.NewMechanic
	if mechanic ~= nil then
		stickerName.Text = mechanic.Name
		stickerHint.Text = mechanic.Hint
	end
	-- Tips for the base game plus every mechanic the level turns on.
	tips = table.clone(tuning.Tips.Base or {})
	local switches = level :: any
	for key, entries in tuning.Tips do
		if key ~= "Base" and switches[key] == true then
			for _, entry in entries do
				table.insert(tips, entry)
			end
		end
	end
	tipIndex = if #tips > 0 then math.random(#tips) - 1 else 0
	tipAt = -math.huge
	bindLabels(gui)
end

-- Step 1 (after START): the server clones the map in and moves the character to its spawn; done once the area
-- around it has streamed in. Back to Waiting (the server emptied out) starts over.
local mapDone = false
local mapStreaming = false
local loadingSince: number? = nil
local loadGeneration = 0

local function mapPresent(): boolean
	local container = workspace:FindFirstChild("$GAME")
	if container == nil then
		return false
	end
	for _, child in container:GetChildren() do
		if child:FindFirstChild("Objects") ~= nil or child:FindFirstChild("MapBarrier") ~= nil then
			return true
		end
	end
	return false
end

local function updateMap(now: number, loading: boolean): ()
	if not loading then
		if loadingSince ~= nil then
			loadGeneration += 1
		end
		mapDone, mapStreaming, loadingSince = false, false, nil
		return
	end
	local since = loadingSince or now
	loadingSince = since
	if mapDone or mapStreaming then
		return
	end
	local character = player.Character
	if character ~= nil and character:GetAttribute("HeldForMap") ~= true and game:IsLoaded() and mapPresent() then
		mapStreaming = true
		local generation = loadGeneration
		task.spawn(function(): ()
			if workspace.StreamingEnabled then
				pcall(function(): ()
					player:RequestStreamAroundAsync(character:GetPivot().Position)
				end)
			end
			if generation == loadGeneration then
				mapStreaming = false
				mapDone = true
			end
		end)
	elseif now - since > tuning.MapTimeout then
		mapDone = true
	end
end

local function canStart(): boolean
	if Config.Round.StudioAnyoneStarts and RunService:IsStudio() then
		return true
	end
	return table.find(Config.Round.StartHosts, player.UserId) ~= nil
end

local function isFilming(target: Player): boolean
	return target:GetAttribute(Config.CinematicCamera.Attribute) == true
end

local function startPending(): boolean
	local pressed = LoadingState.StartPressedAt
	return pressed ~= nil and os.clock() - pressed < tuning.StartConfirmTimeout
end

-- os.clock() of the START press while the boot logo spins; the server hears it BootTime later.
local bootPressedAt: number? = nil

startButton.Activated:Connect(function(): ()
	if bootPressedAt ~= nil then
		return
	end
	-- Hide at once (prediction); it comes back if the server never leaves Waiting.
	startButton.Visible = false
	local pressedAt = os.clock()
	bootPressedAt = pressedAt
	task.delay(tuning.BootTime, function(): ()
		if bootPressedAt == pressedAt then
			bootPressedAt = nil
			LoadingState.PressStart()
			Net.Event("Round"):FireServer("Start")
		end
	end)
end)

-- Party card: one row per player in the server (filmers left out), READY once their client has loaded.
local rowByPlayer: { [Player]: Frame } = {}

local function modelColor(model: unknown): Color3
	local skill = if typeof(model) == "string" then Config.Skills.ByCharacter[model] else nil
	local look = if skill ~= nil then Config.UI.Superskill.Looks[skill] else nil
	return if look ~= nil then look.Color else tuning.UnknownChef
end

local function chefColor(target: Player): Color3
	local character = target.Character
	return modelColor(if character ~= nil then character:GetAttribute(Config.Skills.Attribute.CharacterModel) else nil)
end

-- Boot screen character picker (demo): one button per Config.Character.Selectable chef, and the server respawns the
-- player as the pick. The pick is outlined at once and gives way to the real character after PickTimeout.
local chefRow = bootStage:WaitForChild("Chefs") :: Frame
local chefTemplate = chefRow:WaitForChild("Chef") :: GuiButton
chefTemplate.Visible = false
local chefStrokes: { [string]: UIStroke } = {}
local pickedName: string? = nil
local pickedAt = -math.huge

for index, modelName in Config.Character.Selectable do
	local button = chefTemplate:Clone()
	button.Name = modelName
	button.LayoutOrder = index
	button.Visible = true
	local color = modelColor(modelName)
	local face = button:FindFirstChild("Face") :: GuiObject?
	local shadow = button:FindFirstChild("Shadow") :: GuiObject?
	local label = button:FindFirstChild("Label") :: TextLabel?
	if face ~= nil then
		face.BackgroundColor3 = color
		local stroke = face:FindFirstChild("Selected") :: UIStroke?
		if stroke ~= nil then
			chefStrokes[modelName] = stroke
		end
	end
	if shadow ~= nil then
		shadow.BackgroundColor3 = color:Lerp(Color3.new(0, 0, 0), tuning.PickShadowDarken)
	end
	if label ~= nil then
		label.Text = string.upper(modelName)
	end
	button.Activated:Connect(function(): ()
		pickedName = modelName
		pickedAt = os.clock()
		Net.Event("Round"):FireServer("PickCharacter", modelName)
	end)
	button.Parent = chefRow
end
bindLabels(chefRow)

local function updatePicker(shown: boolean): ()
	chefRow.Visible = shown
	local character = player.Character
	local current = if character ~= nil then character:GetAttribute(Config.Skills.Attribute.CharacterModel) else nil
	local picked = pickedName
	if picked ~= nil and (current == picked or os.clock() - pickedAt > tuning.PickTimeout) then
		pickedName = nil
		picked = nil
	end
	local selected = picked or current
	for modelName, stroke in chefStrokes do
		stroke.Enabled = modelName == selected
	end
end

local function refreshParty(loading: boolean): (number, number)
	local active: { Player } = {}
	for _, target in Players:GetPlayers() do
		if not isFilming(target) then
			table.insert(active, target)
		end
	end
	local loaded = 0
	local keep: { [Player]: boolean } = {}
	for index, target in active do
		local isLoaded = target:GetAttribute("Loaded") == true
		if isLoaded then
			loaded += 1
		end
		if index <= tuning.MaxPartyRows then
			keep[target] = true
			local row: Frame? = rowByPlayer[target]
			if not row then
				local newRow = rowTemplate:Clone()
				newRow.Name = `Row{target.UserId}`
				newRow.Visible = true
				newRow.Parent = rows
				local nameLabel = newRow:FindFirstChild("Name") :: TextLabel?
				if nameLabel ~= nil then
					nameLabel.Text = string.upper(target.DisplayName)
				end
				bindLabels(newRow)
				rowByPlayer[target] = newRow
				row = newRow
			end
			assert(row)
			row.LayoutOrder = index
			local chef = row:FindFirstChild("Chef") :: GuiObject?
			if chef ~= nil then
				chef.BackgroundColor3 = chefColor(target)
			end
			local state = row:FindFirstChild("State") :: GuiObject?
			if state ~= nil then
				-- READY means the map has loaded, so the badge shows only once loading has begun.
				state.Visible = loading
				local face = state:FindFirstChild("Face") :: GuiObject?
				local shadow = state:FindFirstChild("Shadow") :: GuiObject?
				local label = state:FindFirstChild("Label") :: TextLabel?
				if face ~= nil then
					face.BackgroundColor3 = if isLoaded then tuning.ReadyFace else tuning.LoadingFace
				end
				if shadow ~= nil then
					shadow.BackgroundColor3 = if isLoaded then tuning.ReadyShadow else tuning.LoadingShadow
				end
				if label ~= nil then
					setText(label, if isLoaded then tuning.ReadyText else tuning.LoadingText)
					label.TextColor3 = if isLoaded then tuning.ReadyLabel else tuning.LoadingLabel
				end
			end
		end
	end
	for target, row in rowByPlayer do
		if not keep[target] then
			row:Destroy()
			rowByPlayer[target] = nil
		end
	end
	local shown = math.min(#active, tuning.MaxPartyRows)
	party.Size = UDim2.new(party.Size.X.Scale, party.Size.X.Offset, 0, tuning.PartyHeader + shown * tuning.PartyRow + tuning.PartyFooter)
	return loaded, #active
end

local function easeOutBack(p: number): number
	local c = 1.7
	local q = p - 1
	return 1 + (c + 1) * q ^ 3 + c * q ^ 2
end

local sentLoaded = false
local shownProgress = 0
local fullAt: number? = nil
-- 0 = slid away above the screen, 1 = on screen. A player joining mid-load sees it at once (set on the first frame).
local openness = 0
local firstFrame = true
-- The boot screen goes once the loading screen has fully covered it, until the server is back to Waiting.
local bootDone = false
local partyAt = -math.huge
local partyLoaded, partyTotal = 0, 1

-- Bar position of each step icon's centre. Step k runs the bar up to the next icon (the last one up to the end), so
-- the bar heads for the icon of the step in progress and lights each icon as it reaches it.
local function iconAt(index: number): number
	local frame = steps[index].Frame
	return (frame.Position.X.Offset + frame.Size.X.Offset / 2) / progress.Size.X.Offset
end
local iconStops: { number } = {}
local stepEnds: { number } = {}
for index = 1, 4 do
	iconStops[index] = iconAt(index)
	stepEnds[index] = if index < 4 then iconAt(index + 1) else 1
end
local litAt: { number? } = {}

RunService.RenderStepped:Connect(function(dt: number): ()
	local now = os.clock()
	fillTicket()
	local roundState = ReplicatedStorage:GetAttribute("RoundState")
	-- Waiting = the empty place before START; everything after it loads the map.
	local loading = roundState ~= nil and roundState ~= "Waiting"

	-- Real loading.
	updateMap(now, loading)
	local assetsFraction = math.clamp(LoadingState.PreloadTier / math.max(tuning.AssetsTier, 1), 0, 1)
	local assetsDone = assetsFraction >= 1 and LoadingState.ClientReady
	-- Loaded counts only once the bar has shown the map and asset steps, so a fast load still plays out on screen
	-- (the server starts the round when every chef has sent Loaded).
	local loaded = loading and mapDone and assetsDone and shownProgress >= stepEnds[2] - tuning.FillStepMargin - 0.001
	if loaded and not sentLoaded then
		sentLoaded = true
		Net.Event("Round"):FireServer("Loaded")
	elseif not loading then
		sentLoaded = false
	end
	if now - partyAt > 0.25 then
		partyAt = now
		partyLoaded, partyTotal = refreshParty(loading)
	end
	-- The server starts without stragglers after its timeout, so a started round finishes every step.
	local started = loading and roundState ~= "Loading"
	local done = {
		mapDone or started,
		(mapDone and assetsDone) or started,
		(mapDone and assetsDone and partyLoaded >= partyTotal) or started,
		started,
	}
	local fractions = {
		0, -- no real measure: the creep below carries it
		assetsFraction,
		partyLoaded / math.max(partyTotal, 1),
		0,
	}
	local current = 5
	for index = 1, 4 do
		if not done[index] then
			current = index
			break
		end
	end

	-- Faked smoothness: the bar never jumps or goes back. It creeps on by itself toward the end of the step in
	-- progress (never past it), catches up to real progress at a capped speed, and a frame hitch only counts as a
	-- short frame.
	local step = math.min(dt, tuning.FillMaxFrame)
	if not loading then
		shownProgress = 0
		fullAt = nil
		table.clear(litAt)
	else
		local goal = 1
		if current <= 4 then
			local from = if current > 1 then stepEnds[current - 1] else 0
			local cap = stepEnds[current] - tuning.FillStepMargin
			local real = from + (stepEnds[current] - from) * fractions[current]
			local creep = shownProgress + (cap - shownProgress) * (1 - math.exp(-tuning.FillCreepRate * step))
			goal = math.min(math.max(real, creep), cap)
		end
		-- Once the round has started the rest of the bar runs up quickly instead of waiting at its last stop.
		local speed = if current > 4 then tuning.FillFinishSpeed else tuning.FillSpeed
		if goal > shownProgress then
			shownProgress = math.min(goal, shownProgress + speed * step)
		end
		if shownProgress >= 1 and fullAt == nil then
			fullAt = now
		end
	end
	fill.Size = UDim2.new(shownProgress, 0, fill.Size.Y.Scale, fill.Size.Y.Offset)

	-- An icon lights up (with its check) as the bar reaches it; the next one is the step in progress.
	local heading = 0
	for index, stepFrame in steps do
		local lit = loading and shownProgress >= iconStops[index] - 0.002
		if lit and litAt[index] == nil then
			litAt[index] = now
		end
		if loading and not lit and heading == 0 then
			heading = index
		end
		local isCurrent = index == heading
		stepFrame.Ring.BackgroundColor3 = if lit then tuning.DoneRing elseif isCurrent then tuning.CurrentRing else tuning.TodoRing
		stepFrame.Inner.BackgroundColor3 = if lit then tuning.DoneInner else tuning.TodoInner
		local bright = lit or isCurrent
		stepFrame.Icon.ImageColor3 = if bright then Color3.new(1, 1, 1) else tuning.TodoIconColor
		stepFrame.Icon.ImageTransparency = if bright then 0 else tuning.TodoIconTransparency
		local reachedAt = litAt[index]
		local age = if lit and reachedAt ~= nil then now - reachedAt else -1
		stepFrame.Pop.Scale = if age >= 0 and age < tuning.StepPopTime
			then 1 + (tuning.StepPopScale - 1) * math.sin(math.pi * age / tuning.StepPopTime)
			else 1
		local checkAge = age - tuning.CheckDelay
		stepFrame.Check.Visible = lit and checkAge >= 0
		stepFrame.CheckPop.Scale = if checkAge >= 0 then easeOutBack(math.clamp(checkAge / 0.25, 0, 1)) else 0
	end

	-- The text names the step the bar is in, which can trail the real loading.
	local shownStep = current
	for index = 1, math.min(current, 4) - 1 do
		if shownProgress < stepEnds[index] - tuning.FillStepMargin - 0.001 then
			shownStep = index
			break
		end
	end
	local host = canStart() and Config.Round.StartButton
	-- A START press shows the loading screen at once (prediction) until the server leaves Waiting.
	local pending = not loading and startPending()
	local text = if not loading then `{tuning.StepStatus[1]}  0%`
		elseif shownStep <= 3 then `{tuning.StepStatus[shownStep]}  {math.floor(shownProgress * 100 + 0.5)}%`
		else tuning.StepStatus[4]
	setText(status, text)
	local booting = bootPressedAt ~= nil
	startButton.Visible = host and roundState == "Waiting" and not pending and not booting
	updatePicker(roundState == "Waiting" and not pending and not booting)

	-- The ticket drops in on its clip and swings to rest; the NEW TODAY sticker slaps on last.
	local t = now - shownAt
	local drop = math.clamp(t / tuning.SwingDropTime, 0, 1)
	local fall = (1 - (1 - drop) ^ 3)
	swing.Position = swingRest + UDim2.fromOffset(0, -(1 - fall) * tuning.DesignSize.Y)
	swing.Rotation = tuning.TicketTilt + tuning.SwingAngle * math.exp(-tuning.SwingDamping * t) * math.cos(tuning.SwingFrequency * t)
	local level = Config.Levels.GetCurrentPath() ~= nil and Config.Levels.GetCurrent() or nil
	local stickerAge = t - tuning.StickerDelay
	sticker.Visible = level ~= nil and level.NewMechanic ~= nil and stickerAge >= 0
	if sticker.Visible then
		local p = math.clamp(stickerAge / tuning.StickerTime, 0, 1)
		stickerPop.Scale = tuning.StickerScale + (1 - tuning.StickerScale) * (1 - (1 - p) ^ 3)
	end

	-- Tips rotate.
	if #tips > 0 and now - tipAt >= tuning.TipInterval then
		tipAt = now
		tipIndex = tipIndex % #tips + 1
		tipText.Text = tips[tipIndex]
	end

	-- Background food scrolls up-left along its own repeat, so it loops without a seam.
	local height = background.AbsoluteSize.Y
	local period = Vector2.new(260, 240)
	local along = (t * tuning.PatternSpeed / period.Magnitude) % 1
	local offset = -period * along * height / tuning.DesignSize.Y
	pattern.Position = UDim2.fromOffset(offset.X, offset.Y)

	-- Slides in on START (or a load already under way) and stays until this client has loaded, the round has
	-- started (the intro) and the full bar has shown for FinishHold; then it slides away.
	local finished = loaded and started and fullAt ~= nil and now - fullAt >= tuning.FinishHold
	local wanted = not isFilming(player) and (pending or (loading and not finished))
	if firstFrame then
		firstFrame = false
		openness = if wanted then 1 else 0
	elseif wanted and openness == 0 then
		shownAt = now
	end
	openness = math.clamp(openness + (if wanted then dt / tuning.OpenTime else -dt / tuning.CloseTime), 0, 1)
	local slide = -(1 - openness) ^ 2 * gui.AbsoluteSize.Y
	background.Position = UDim2.fromOffset(0, slide)
	canvas.Position = UDim2.new(0.5, 0, 0.5, slide)
	-- Rotated pattern tiles escape the clip, so a closed screen hides outright.
	background.Visible = openness > 0
	canvas.Visible = openness > 0
	-- The boot screen sits under the loading screen until it has slid all the way in; the logo spins after START.
	if not loading then
		bootDone = false
	elseif openness >= 1 then
		bootDone = true
	end
	boot.Visible = not isFilming(player) and not bootDone
	bootLogo.Rotation = if booting or pending or loading
		then bootLogo.Rotation + tuning.BootSpinSpeed * dt
		else bootLogoRest
	gui.Enabled = openness > 0 or boot.Visible
end)
