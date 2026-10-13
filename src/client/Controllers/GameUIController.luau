--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local CoinFly = require(script.Parent.Parent.Util.CoinFly)
local Gif = require(script.Parent.Parent.Util.Gif)
local Shared = ReplicatedStorage:WaitForChild("Shared")
local BitmapFont = require(Shared:WaitForChild("Util"):WaitForChild("BitmapFont"))
local Jersey15 = require(Shared:WaitForChild("Fonts"):WaitForChild("Jersey15"))
local Config = require(Shared:WaitForChild("Config"))
local Levels = Config.Levels
local Net = require(Shared:WaitForChild("Net"))

local GameUIController = {}
local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui")
local gameInfo = gui:WaitForChild("GameInfo") :: ScreenGui
local orderList = gui:WaitForChild("OrderList") :: ScreenGui
local instructions = gui:WaitForChild("Instructions") :: ScreenGui
local readyGui = gui:WaitForChild("ReadySetGo") :: ScreenGui
local roundEnd = gui:WaitForChild("RoundEnd") :: ScreenGui
local infoFrame = gameInfo:WaitForChild("InfoFrame") :: GuiObject
local coinsFrame = infoFrame:WaitForChild("CoinsFrame")
-- The coin card and its shadow squash about their centres when coins land.
local coinsPops = {
	coinsFrame:WaitForChild("Pop") :: UIScale,
	infoFrame:WaitForChild("CoinsShadow"):WaitForChild("Pop") :: UIScale,
}
local hudScale = infoFrame:WaitForChild("Scale") :: UIScale
local coinsLabel = coinsFrame:WaitForChild("TextLabel") :: TextLabel
-- Optional drop-shadow copies of the coin and timer text, kept in sync with them.
local coinsShadow = coinsFrame:FindFirstChild("TextShadow") :: TextLabel?
local coinSprite = coinsFrame:WaitForChild("CoinSprite") :: ImageLabel
local timerFrame = infoFrame:WaitForChild("TimerFrame")
local timerLabel = timerFrame:WaitForChild("TextLabel") :: TextLabel
local timerShadow = timerFrame:FindFirstChild("TextShadow") :: TextLabel?
local coinTemplate = gameInfo:WaitForChild("CoinNotification") :: TextLabel
local notifRandom = Random.new()
local endCoins = roundEnd:WaitForChild("Frame"):WaitForChild("Coins") :: TextLabel
local ready = readyGui:WaitForChild("Ready") :: GuiObject
local set = readyGui:WaitForChild("Set") :: GuiObject
local go = readyGui:WaitForChild("Go") :: GuiObject
local readyFrames = { ready, set, go }
local readySizes = { ready.Size, set.Size, go.Size }
local lastCoins: number? = nil
local coinConnection: RBXScriptConnection? = nil
local readyGeneration = 0
-- The number on the coin card rolls from rollFrom to rollTo starting at rollAt (local clock).
local rollFrom = 0
local rollTo = 0
local rollAt = -math.huge
local squashAt = -math.huge
-- The total the card is heading to, gains still in flight included.
local targetCoins = 0

local function formatTime(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", math.floor(whole / 60), whole % 60)
end

local function refreshTimer(): ()
	local duration = ReplicatedStorage:GetAttribute("RoundDuration")
	local endsAt = ReplicatedStorage:GetAttribute("RoundEndsAt")
	local pausedLeft = ReplicatedStorage:GetAttribute("RoundPausedLeft")
	local state = ReplicatedStorage:GetAttribute("RoundState")
	local seconds = if state == "Playing" and typeof(pausedLeft) == "number" then pausedLeft
		elseif state == "Playing" and typeof(endsAt) == "number" then endsAt - workspace:GetServerTimeNow()
		else if typeof(duration) == "number" then duration else 180
	local text = formatTime(seconds)
	timerLabel.Text = text
	if timerShadow ~= nil then
		timerShadow.Text = text
	end
end

local function setCoinsText(coins: number): ()
	coinsLabel.Text = tostring(coins)
	if coinsShadow ~= nil then
		coinsShadow.Text = coinsLabel.Text
	end
end

local function shownCoins(): number
	local p = math.clamp((os.clock() - rollAt) / Config.UI.Coins.RollTime, 0, 1)
	return math.round(rollFrom + (rollTo - rollFrom) * (1 - (1 - p) ^ 2))
end

-- Coins landing on the card: the coin spins, the card squashes and the number rolls up to `coins`.
local function landCoins(coins: number): ()
	rollFrom = shownCoins()
	rollTo = coins
	rollAt = os.clock()
	squashAt = rollAt
	Gif.Play(coinSprite)
end

-- A gain lands when its coin reaches the card: a served plate's coin when orders pay on serve (OrdersController),
-- or, with table cash, the coin of cash this player collected (CashController; others' gains land at once).
local function landDelay(): number
	return if Levels.GetCurrent().EnableTableCash then CoinFly.Remaining() else Config.UI.Coins.LandDelay
end

local function drawCoins(): ()
	local tuning = Config.UI.Coins
	setCoinsText(shownCoins())
	local p = math.clamp((os.clock() - squashAt) / tuning.SquashTime, 0, 1)
	local scale = 1 + tuning.Squash * math.sin(p * math.pi * 2) * (1 - p)
	for _, pop in coinsPops do
		pop.Scale = scale
	end
end

local function refreshCoins(): ()
	local team = player:GetAttribute("Team")
	local value = if typeof(team) == "number" then ReplicatedStorage:GetAttribute(`Coins_{team}`) else nil
	local coins = if typeof(value) == "number" then value else 0
	if lastCoins ~= nil and coins > lastCoins then
		task.delay(landDelay(), landCoins, coins)
	else
		rollFrom = coins
		rollTo = coins
	end
	lastCoins = coins
	targetCoins = coins
end

local function watchTeam(): ()
	if coinConnection ~= nil then
		coinConnection:Disconnect()
		coinConnection = nil
	end
	local team = player:GetAttribute("Team")
	lastCoins = nil
	if typeof(team) == "number" then
		coinConnection = ReplicatedStorage:GetAttributeChangedSignal(`Coins_{team}`):Connect(refreshCoins)
	end
	refreshCoins()
end

local function floatCoinNotif(amount: number): ()
	local tuning = Config.UI.Coins
	local label = coinTemplate:Clone()
	label.Text = `+{amount}`
	label.TextColor3 = tuning.Notification
	-- Flies off the top of the coin card (it scales with the HUD) at a random angle, so gains don't all stack in a
	-- column. Cosmetic, so each client picks its own.
	local angle = math.rad(notifRandom:NextNumber(tuning.NotificationAngle[1], tuning.NotificationAngle[2]))
	local start = notifRandom:NextNumber(-1, 1) * tuning.NotificationJitter
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Size = tuning.NotificationSize
	label.Position = UDim2.new(0.5, start, 0, 0)
	label.Rotation = 0
	label.ZIndex = 10
	label.Visible = true
	label.Parent = coinsFrame
	TweenService:Create(label, TweenInfo.new(1.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Position = UDim2.new(
			0.5,
			start + math.sin(angle) * tuning.NotificationRise,
			0,
			-math.cos(angle) * tuning.NotificationRise
		),
		Rotation = math.deg(angle) * tuning.NotificationLean,
	}):Play()
	task.delay(0.8, function(): ()
		if label.Parent == nil then
			return
		end
		local fade = TweenService:Create(label, TweenInfo.new(0.7, Enum.EasingStyle.Linear), { TextTransparency = 1 })
		fade.Completed:Once(function(): ()
			label:Destroy()
		end)
		fade:Play()
	end)
end

local function showCoinNotif(amount: number): ()
	task.delay(landDelay(), floatCoinNotif, amount)
end

-- Coins and timer: bottom-right on PC, bottom-centre on touch screens, scaled with the screen height.
local function placeHud(): ()
	local tuning = Config.UI.Hud
	-- Same rule as MobileControls (InputController): a touch screen gets the touch layout, keyboard or not.
	local touch = UserInputService.TouchEnabled
	infoFrame.Position = if touch then tuning.TouchPosition else tuning.DesktopPosition
	infoFrame.AnchorPoint = if touch then tuning.TouchAnchor else tuning.DesktopAnchor
	local camera = workspace.CurrentCamera
	if camera ~= nil then
		hudScale.Scale = camera.ViewportSize.Y / tuning.DesignHeight * (if touch then tuning.TouchScale else tuning.DesktopScale)
	end
end

local function hideReady(): ()
	ready.Visible = false
	set.Visible = false
	go.Visible = false
	readyGui.Enabled = false
end

-- Size of a word at `t` seconds into its one-second slot: back-eased pop in, then a quick shrink out.
local function wordScale(t: number): number
	local tuning = Config.UI.ReadySetGo
	local scale = 1
	if t < tuning.PopTime then
		local p = t / tuning.PopTime - 1
		local c = tuning.PopOvershoot
		scale = 1 + (c + 1) * p ^ 3 + c * p ^ 2
	end
	local left = 1 - t
	if left < tuning.OutTime then
		scale *= (left / tuning.OutTime) ^ 4
	end
	return math.max(scale, 0)
end

local function startReady(startsAt: number): ()
	readyGeneration += 1
	local generation = readyGeneration
	local tuning = Config.UI.ReadySetGo
	local tilts = { -tuning.Tilt, tuning.Tilt, 0 }
	roundEnd.Enabled = false
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function(): ()
		local elapsed = workspace:GetServerTimeNow() - startsAt
		local index = math.floor(elapsed) + 1
		if generation ~= readyGeneration or index > #readyFrames then
			connection:Disconnect()
			if generation == readyGeneration then
				hideReady()
			end
			return
		end
		readyGui.Enabled = index >= 1
		for frameIndex, frame in readyFrames do
			frame.Visible = frameIndex == index
		end
		if index >= 1 then
			local frame = readyFrames[index]
			local base = readySizes[index]
			local scale = wordScale(elapsed - (index - 1)) * (if index == #readyFrames then tuning.GoScale else 1)
			frame.Size = UDim2.new(base.X.Scale * scale, base.X.Offset * scale, base.Y.Scale * scale, base.Y.Offset * scale)
			frame.Rotation = tilts[index]
		end
	end)
end

-- Draws each banner's word in Jersey 15 from the bitmap font, inside its TextLabel and in its
-- text color; the label's own text is hidden. Banner colors and layout live in Studio.
local function buildWords(): ()
	if not BitmapFont.IsReady(Jersey15) then
		return
	end
	for _, frame in readyFrames do
		local label = frame:FindFirstChildWhichIsA("TextLabel")
		if label ~= nil then
			label.TextTransparency = 1
			BitmapFont.Render(Jersey15, label.Text, label, { Name = "Word", Color = label.TextColor3 })
		end
	end
end

local function refreshVisibility(): ()
	local state = ReplicatedStorage:GetAttribute("RoundState")
	gameInfo.Enabled = state == "Intro" or state == "Playing"
	-- An admin reset goes back to Waiting from any state, the round end screen included.
	if state == "Waiting" then
		readyGeneration += 1
		hideReady()
		roundEnd.Enabled = false
	end
	orderList.Enabled = gameInfo.Enabled
	-- Instructions was never shown by the legacy start flow.
	instructions.Enabled = false
	refreshTimer()
end

-- Effect tester: shows the coins and order HUD outside a round.
function GameUIController.Preview(): ()
	gameInfo.Enabled = true
	orderList.Enabled = true
end

-- Effect tester: plays a coin gain of `amount` on the card (local only; the next real change resets it).
function GameUIController.PreviewGain(amount: number): ()
	targetCoins += amount
	task.delay(landDelay(), landCoins, targetCoins)
	showCoinNotif(amount)
end

function GameUIController.Start(_self: typeof(GameUIController)): ()
	gameInfo.Enabled = false
	orderList.Enabled = false
	instructions.Enabled = false
	hideReady()
	buildWords()
	placeHud()
	local camera = workspace.CurrentCamera
	if camera ~= nil then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(placeHud)
	end
	Gif.Reset(coinSprite)
	player:GetAttributeChangedSignal("Team"):Connect(watchTeam)
	watchTeam()
	ReplicatedStorage:GetAttributeChangedSignal("RoundState"):Connect(refreshVisibility)
	ReplicatedStorage:GetAttributeChangedSignal("RoundEndsAt"):Connect(refreshTimer)
	ReplicatedStorage:GetAttributeChangedSignal("RoundPausedLeft"):Connect(refreshTimer)
	ReplicatedStorage:GetAttributeChangedSignal("RoundDuration"):Connect(refreshTimer)
	refreshVisibility()
	RunService.Heartbeat:Connect(refreshTimer)
	RunService.RenderStepped:Connect(drawCoins)
	Net.Event("Round").OnClientEvent:Connect(function(message: unknown, value: unknown): ()
		if message == "ReadySetGo" and typeof(value) == "number" then
			startReady(value)
		elseif message == "RoundEnd" and typeof(value) == "number" then
			readyGeneration += 1
			hideReady()
			endCoins.Text = `{value} coins`
			roundEnd.Enabled = true
		elseif message == "Orders" then
			roundEnd.Enabled = false
		end
	end)
	Net.Event("Effect").OnClientEvent:Connect(function(message: unknown, value: unknown): ()
		if message == "CoinNotif" and typeof(value) == "number" then
			showCoinNotif(value)
		end
	end)
end

return GameUIController
