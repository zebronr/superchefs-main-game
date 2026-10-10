--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Gif = require(script.Parent.Parent.Util.Gif)
local Shared = ReplicatedStorage:WaitForChild("Shared")
local BitmapFont = require(Shared:WaitForChild("Util"):WaitForChild("BitmapFont"))
local Jersey15 = require(Shared:WaitForChild("Fonts"):WaitForChild("Jersey15"))
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))

local GameUIController = {}
local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui")
local gameInfo = gui:WaitForChild("GameInfo") :: ScreenGui
local orderList = gui:WaitForChild("OrderList") :: ScreenGui
local instructions = gui:WaitForChild("Instructions") :: ScreenGui
local readyGui = gui:WaitForChild("ReadySetGo") :: ScreenGui
local roundEnd = gui:WaitForChild("RoundEnd") :: ScreenGui
local startGui = gui:WaitForChild("StartRound") :: ScreenGui
local startButton = startGui:WaitForChild("Button") :: GuiButton
local infoFrame = gameInfo:WaitForChild("InfoFrame")
local coinsFrame = infoFrame:WaitForChild("CoinsFrame")
local coinsLabel = coinsFrame:WaitForChild("TextLabel") :: TextLabel
local coinSprite = coinsFrame:WaitForChild("CoinSprite") :: ImageLabel
local timerLabel = infoFrame:WaitForChild("TimerFrame"):WaitForChild("TextLabel") :: TextLabel
local coinTemplate = gameInfo:WaitForChild("CoinNotification") :: TextLabel
local endCoins = roundEnd:WaitForChild("Frame"):WaitForChild("Coins") :: TextLabel
local ready = readyGui:WaitForChild("Ready") :: GuiObject
local set = readyGui:WaitForChild("Set") :: GuiObject
local go = readyGui:WaitForChild("Go") :: GuiObject
local readyFrames = { ready, set, go }
local readySizes = { ready.Size, set.Size, go.Size }
local lastCoins: number? = nil
local coinConnection: RBXScriptConnection? = nil
local readyGeneration = 0
local popping = false

local function formatTime(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", math.floor(whole / 60), whole % 60)
end

local function refreshTimer(): ()
	local duration = ReplicatedStorage:GetAttribute("RoundDuration")
	local endsAt = ReplicatedStorage:GetAttribute("RoundEndsAt")
	local state = ReplicatedStorage:GetAttribute("RoundState")
	local seconds = if state == "Playing" and typeof(endsAt) == "number"
		then endsAt - workspace:GetServerTimeNow()
		else if typeof(duration) == "number" then duration else 180
	timerLabel.Text = formatTime(seconds)
end

local function popCoins(): ()
	if popping then
		return
	end
	popping = true
	local size = coinsLabel.Size
	local color = coinsLabel.TextColor3
	local enlarge = TweenService:Create(coinsLabel, TweenInfo.new(0.5), {
		Size = UDim2.new(size.X.Scale * 1.3, 0, size.Y.Scale * 1.3, 0),
		TextColor3 = Config.UI.Coins.Pop,
	})
	local shrink = TweenService:Create(coinsLabel, TweenInfo.new(0.5), { Size = size, TextColor3 = color })
	enlarge.Completed:Once(function(): ()
		shrink:Play()
	end)
	shrink.Completed:Once(function(): ()
		popping = false
	end)
	enlarge:Play()
end

local function refreshCoins(): ()
	local team = player:GetAttribute("Team")
	local value = if typeof(team) == "number" then ReplicatedStorage:GetAttribute(`Coins_{team}`) else nil
	local coins = if typeof(value) == "number" then value else 0
	coinsLabel.Text = tostring(coins)
	if lastCoins ~= nil and coins > lastCoins then
		Gif.Play(coinSprite)
		popCoins()
	end
	lastCoins = coins
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

local function showCoinNotif(amount: number): ()
	local label = coinTemplate:Clone()
	label.Text = `+{amount}`
	label.TextColor3 = Config.UI.Coins.Notification
	label.Visible = true
	label.Parent = coinTemplate.Parent
	TweenService:Create(label, TweenInfo.new(1.5, Enum.EasingStyle.Linear), {
		Position = UDim2.new(0.5, 0, 0.624, 0),
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

local function refreshStart(): ()
	startGui.Enabled = Config.Round.StartButton and ReplicatedStorage:GetAttribute("RoundState") == "Waiting"
end

local function refreshVisibility(): ()
	local state = ReplicatedStorage:GetAttribute("RoundState")
	gameInfo.Enabled = state == "Intro" or state == "Playing"
	orderList.Enabled = gameInfo.Enabled
	-- Instructions was never shown by the legacy start flow.
	instructions.Enabled = false
	refreshStart()
	refreshTimer()
end

function GameUIController.Start(_self: typeof(GameUIController)): ()
	gameInfo.Enabled = false
	orderList.Enabled = false
	instructions.Enabled = false
	hideReady()
	buildWords()
	startGui.Enabled = false
	startButton.Activated:Connect(function(): ()
		-- Hide at once; the button comes back if the server returns to Waiting.
		startGui.Enabled = false
		Net.Event("Round"):FireServer("Start")
	end)
	Gif.Reset(coinSprite)
	player:GetAttributeChangedSignal("Team"):Connect(watchTeam)
	watchTeam()
	ReplicatedStorage:GetAttributeChangedSignal("RoundState"):Connect(refreshVisibility)
	ReplicatedStorage:GetAttributeChangedSignal("RoundEndsAt"):Connect(refreshTimer)
	ReplicatedStorage:GetAttributeChangedSignal("RoundDuration"):Connect(refreshTimer)
	refreshVisibility()
	RunService.Heartbeat:Connect(refreshTimer)
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
