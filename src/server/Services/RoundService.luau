--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharacterService = require(script.Parent.CharacterService)
local CustomerService = require(script.Parent.CustomerService)
local LevelService = require(script.Parent.LevelService)
local OrderService = require(script.Parent.OrderService)
local TeamService = require(script.Parent.TeamService)
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Levels = Config.Levels
local RoundConfig = Config.Round
local Net = require(Shared:WaitForChild("Net"))

local RoundService = {}
local generation = 0
local startsAt = 0
local starting = false
-- Players whose client has connected its listeners; only they get round messages.
local readyPlayers: { [Player]: true } = {}

local function isCurrent(token: number): boolean
	return generation == token and #Players:GetPlayers() > 0
end

local function coinsFor(team: number): number
	local value = ReplicatedStorage:GetAttribute(`Coins_{team}`)
	return if typeof(value) == "number" then value else 0
end

local function broadcastNPCs(token: number): ()
	task.spawn(function(): ()
		while isCurrent(token) and ReplicatedStorage:GetAttribute("RoundState") == "Playing" do
			task.wait(RoundConfig.NPCSpawnInterval)
			if not isCurrent(token) or ReplicatedStorage:GetAttribute("RoundState") ~= "Playing" then
				return
			end
			local map = LevelService.GetMap()
			local waypoints = if map then map:FindFirstChild("NPCWaypoints") else nil
			local starters = if waypoints then waypoints:FindFirstChild("Starters") else nil
			if starters ~= nil then
				local children = starters:GetChildren()
				if #children > 0 then
					-- The seed picks the NPC model and route, so every client shows the same one.
					Net.Event("Round"):FireAllClients("SpawnNPC", children[math.random(#children)].Name, math.random(1, 2 ^ 30))
				end
			end
		end
	end)
end

local beginIntro: () -> ()

local function endRound(token: number): ()
	if not isCurrent(token) then
		return
	end
	generation += 1
	local endedToken = generation
	OrderService.Stop()
	CustomerService.Stop()
	ReplicatedStorage:SetAttribute("RoundEndsAt", nil)
	ReplicatedStorage:SetAttribute("RoundState", "Ended")
	Net.Event("Round"):FireAllClients("ClearNPCs")
	for player in readyPlayers do
		Net.Event("Round"):FireClient(player, "RoundEnd", coinsFor(TeamService.GetTeam(player)))
	end
	task.delay(RoundConfig.RoundEndDuration, function(): ()
		if not isCurrent(endedToken) then
			return
		end
		LevelService.ResetMap()
		if isCurrent(endedToken) then
			beginIntro()
		end
	end)
end

local function beginPlaying(token: number): ()
	if not isCurrent(token) then
		return
	end
	local level = Levels.GetCurrent()
	local endsAt = workspace:GetServerTimeNow() + level.LevelDuration
	ReplicatedStorage:SetAttribute("RoundState", "Playing")
	ReplicatedStorage:SetAttribute("RoundEndsAt", endsAt)
	OrderService.StartRound(level.Teams, token)
	if RoundConfig.ServeMode == "Manual" then
		CustomerService.StartRound(token)
	else
		broadcastNPCs(token)
	end
	task.delay(level.LevelDuration, function(): ()
		endRound(token)
	end)
end

beginIntro = function(): ()
	if #Players:GetPlayers() == 0 then
		return
	end
	generation += 1
	local token = generation
	local level = Levels.GetCurrent()
	OrderService.Stop()
	CustomerService.Stop()
	TeamService.AssignAll(level.Teams)
	CharacterService.RefreshColors()
	for team = 1, level.Teams do
		ReplicatedStorage:SetAttribute(`Coins_{team}`, 0)
	end
	ReplicatedStorage:SetAttribute("RoundDuration", level.LevelDuration)
	ReplicatedStorage:SetAttribute("RoundEndsAt", nil)
	ReplicatedStorage:SetAttribute("RoundState", "Intro")
	for player in readyPlayers do
		OrderService.SendSnapshot(player)
	end
	LevelService.MoveAllToSpawns()
	startsAt = workspace:GetServerTimeNow() + RoundConfig.IntroLead
	for player in readyPlayers do
		Net.Event("Round"):FireClient(player, "ReadySetGo", startsAt)
	end
	task.delay(RoundConfig.IntroLead + RoundConfig.ReadySetGoDuration, function(): ()
		beginPlaying(token)
	end)
end

local function stopForEmptyServer(): ()
	generation += 1
	OrderService.Stop()
	CustomerService.Stop()
	ReplicatedStorage:SetAttribute("RoundState", "Waiting")
	ReplicatedStorage:SetAttribute("RoundEndsAt", nil)
	Net.Event("Round"):FireAllClients("ClearNPCs")
	LevelService.ResetMap()
end

local function startIfWaiting(): ()
	if starting or ReplicatedStorage:GetAttribute("RoundState") ~= "Waiting" then
		return
	end
	starting = true
	task.spawn(function(): ()
		while #Players:GetPlayers() > 0 and LevelService.GetMap() == nil do
			task.wait()
		end
		starting = false
		if #Players:GetPlayers() > 0 and ReplicatedStorage:GetAttribute("RoundState") == "Waiting" then
			beginIntro()
		end
	end)
end

local function onPlayerAdded(player: Player): ()
	TeamService.AssignJoin(player, Levels.GetCurrent().Teams)
	CharacterService.RefreshColors()
end

-- The join-time messages wait for the client's listeners, or they arrive too late to show.
local function markReady(player: Player): ()
	if readyPlayers[player] ~= nil or player.Parent ~= Players then
		return
	end
	readyPlayers[player] = true
	local state = ReplicatedStorage:GetAttribute("RoundState")
	OrderService.SendSnapshot(player)
	if state == "Ended" then
		Net.Event("Round"):FireClient(player, "RoundEnd", coinsFor(TeamService.GetTeam(player)))
	elseif state == "Intro" then
		Net.Event("Round"):FireClient(player, "ReadySetGo", startsAt)
	elseif state == "Waiting" and not RoundConfig.StartButton then
		startIfWaiting()
	end
end

local function onRequest(player: Player, message: unknown): ()
	if message == "Ready" then
		markReady(player)
	elseif message == "Start" and RoundConfig.StartButton then
		markReady(player)
		startIfWaiting()
	end
end

function RoundService.Start(_self: typeof(RoundService)): ()
	local level = Levels.GetCurrent()
	ReplicatedStorage:SetAttribute("RoundState", "Waiting")
	ReplicatedStorage:SetAttribute("RoundEndsAt", nil)
	ReplicatedStorage:SetAttribute("RoundDuration", level.LevelDuration)
	for team = 1, level.Teams do
		ReplicatedStorage:SetAttribute(`Coins_{team}`, 0)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	Net.Event("Round").OnServerEvent:Connect(onRequest)
	Players.PlayerRemoving:Connect(function(player: Player): ()
		readyPlayers[player] = nil
		if #Players:GetPlayers() <= 1 then
			stopForEmptyServer()
		end
	end)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return RoundService
