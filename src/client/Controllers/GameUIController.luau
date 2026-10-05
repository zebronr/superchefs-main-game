--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Gif = require(script.Parent.Parent.Util.Gif)
local Shared = ReplicatedStorage:WaitForChild("Shared")
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

local function startReady(startsAt: number): ()
	readyGeneration += 1
	local generation = readyGeneration
	roundEnd.Enabled = false
	task.spawn(function(): ()
		local frames = { ready, set, go }
		while generation == readyGeneration do
			local elapsed = workspace:GetServerTimeNow() - startsAt
			local index = math.floor(elapsed) + 1
			if index > 3 then
				break
			end
			readyGui.Enabled = index >= 1
			for frameIndex, frame in frames do
				frame.Visible = frameIndex == index
			end
			task.wait(math.clamp(startsAt + math.max(index, 1) - workspace:GetServerTimeNow(), 0.01, 0.1))
		end
		if generation == readyGeneration then
			hideReady()
		end
	end)
end

local function refreshVisibility(): ()
	local state = ReplicatedStorage:GetAttribute("RoundState")
	gameInfo.Enabled = state == "Intro" or state == "Playing"
	orderList.Enabled = gameInfo.Enabled
	-- Instructions was never shown by the legacy start flow.
	instructions.Enabled = false
	refreshTimer()
end

function GameUIController.Start(_self: typeof(GameUIController)): ()
	gameInfo.Enabled = false
	orderList.Enabled = false
	instructions.Enabled = false
	hideReady()
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
