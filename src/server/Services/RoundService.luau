--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CarryService = require(script.Parent.CarryService)
local CharacterService = require(script.Parent.CharacterService)
local CustomerService = require(script.Parent.CustomerService)
local InteractionService = require(script.Parent.InteractionService)
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
local endThread: thread? = nil
local endToken: number? = nil
local startsAt = 0
-- When this intro's opening shot began, or nil when it has none.
local cinematicAt: number? = nil
local starting = false
-- Players whose client has connected its listeners; only they get round messages.
local readyPlayers: { [Player]: true } = {}

local function activeCount(): number
	return #TeamService.GetActivePlayers()
end

local function isCurrent(token: number): boolean
	return generation == token and activeCount() > 0
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

local beginIntro: (cinematic: boolean) -> ()

local function clearEndTimer(): ()
	if endThread ~= nil then
		task.cancel(endThread)
		endThread = nil
	end
	endToken = nil
	ReplicatedStorage:SetAttribute("RoundPausedLeft", nil)
end

local function endRound(token: number): ()
	if not isCurrent(token) then
		return
	end
	if typeof(ReplicatedStorage:GetAttribute("RoundPausedLeft")) == "number" then
		return
	end
	local endsAt = ReplicatedStorage:GetAttribute("RoundEndsAt")
	if typeof(endsAt) == "number" and workspace:GetServerTimeNow() < endsAt then
		return
	end
	endThread = nil
	endToken = nil
	generation += 1
	local endedToken = generation
	OrderService.Stop()
	CustomerService.Stop()
	ReplicatedStorage:SetAttribute("RoundEndsAt", nil)
	ReplicatedStorage:SetAttribute("RoundPausedLeft", nil)
	ReplicatedStorage:SetAttribute("RoundState", "Ended")
	Net.Event("Round"):FireAllClients("ClearNPCs")
	for player in readyPlayers do
		if TeamService.IsActive(player) then
			Net.Event("Round"):FireClient(player, "RoundEnd", coinsFor(TeamService.GetTeam(player)))
		end
	end
	task.delay(RoundConfig.RoundEndDuration, function(): ()
		if not isCurrent(endedToken) then
			return
		end
		LevelService.ResetMap()
		if isCurrent(endedToken) then
			beginIntro(false)
		end
	end)
end

local function scheduleEnd(token: number, seconds: number): ()
	endToken = token
	endThread = task.delay(seconds, function(): ()
		endRound(token)
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
	scheduleEnd(token, level.LevelDuration)
end

function RoundService.SetTimerPaused(paused: boolean): ()
	if ReplicatedStorage:GetAttribute("RoundState") ~= "Playing" then
		return
	end
	local left = ReplicatedStorage:GetAttribute("RoundPausedLeft")
	if (typeof(left) == "number") == paused then
		return
	end
	if paused then
		local endsAt = ReplicatedStorage:GetAttribute("RoundEndsAt")
		local scheduled = endThread
		if typeof(endsAt) ~= "number" or scheduled == nil or endToken ~= generation then
			return
		end
		task.cancel(scheduled)
		endThread = nil
		ReplicatedStorage:SetAttribute("RoundPausedLeft", math.max(0, endsAt - workspace:GetServerTimeNow()))
	else
		local token = endToken
		if typeof(left) ~= "number" or token == nil then
			return
		end
		ReplicatedStorage:SetAttribute("RoundEndsAt", workspace:GetServerTimeNow() + left)
		ReplicatedStorage:SetAttribute("RoundPausedLeft", nil)
		scheduleEnd(token, left)
	end
end

beginIntro = function(cinematic: boolean): ()
	if activeCount() == 0 then
		return
	end
	generation += 1
	local token = generation
	local level = Levels.GetCurrent()
	clearEndTimer()
	OrderService.Stop()
	CustomerService.Stop()
	TeamService.AssignAll(level.Teams)
	CharacterService.RefreshColors()
	for team = 1, level.Teams do
		ReplicatedStorage:SetAttribute(`Coins_{team}`, 0)
	end
	ReplicatedStorage:SetAttribute("RoundDuration", level.LevelDuration)
	ReplicatedStorage:SetAttribute("RoundEndsAt", nil)
	ReplicatedStorage:SetAttribute("RoundPausedLeft", nil)
	ReplicatedStorage:SetAttribute("RoundState", "Intro")
	for player in readyPlayers do
		if TeamService.IsActive(player) then
			OrderService.SendSnapshot(player)
		end
	end
	LevelService.MoveAllToSpawns()
	local lead = RoundConfig.IntroLead + (if cinematic then RoundConfig.CinematicLength else 0)
	cinematicAt = if cinematic then workspace:GetServerTimeNow() + RoundConfig.IntroLead else nil
	startsAt = workspace:GetServerTimeNow() + lead
	for player in readyPlayers do
		if TeamService.IsActive(player) then
			if cinematicAt ~= nil then
				Net.Event("Round"):FireClient(player, "Cinematic", cinematicAt)
			end
			Net.Event("Round"):FireClient(player, "ReadySetGo", startsAt)
		end
	end
	task.delay(lead + RoundConfig.ReadySetGoDuration, function(): ()
		beginPlaying(token)
	end)
end

local function stopForEmptyServer(): ()
	generation += 1
	clearEndTimer()
	OrderService.Stop()
	CustomerService.Stop()
	ReplicatedStorage:SetAttribute("RoundState", "Waiting")
	ReplicatedStorage:SetAttribute("RoundEndsAt", nil)
	ReplicatedStorage:SetAttribute("RoundPausedLeft", nil)
	Net.Event("Round"):FireAllClients("ClearNPCs")
	-- Back to the empty place; everyone loads the map again after the next START.
	LevelService.UnloadMap()
	for _, player in Players:GetPlayers() do
		player:SetAttribute("Loaded", nil)
	end
end

local function everyoneLoaded(): boolean
	for _, player in TeamService.GetActivePlayers() do
		if player:GetAttribute("Loaded") ~= true then
			return false
		end
	end
	return true
end

-- START: load the map, wait for every chef's client to report it loaded (or the timeout), then the intro.
local function startIfWaiting(): ()
	if starting or ReplicatedStorage:GetAttribute("RoundState") ~= "Waiting" then
		return
	end
	starting = true
	ReplicatedStorage:SetAttribute("RoundState", "Loading")
	LevelService.LoadMap()
	local deadline = os.clock() + RoundConfig.LoadTimeout
	task.spawn(function(): ()
		while activeCount() > 0
			and ReplicatedStorage:GetAttribute("RoundState") == "Loading"
			and os.clock() < deadline
			and not everyoneLoaded()
		do
			task.wait(0.1)
		end
		starting = false
		if activeCount() > 0 and ReplicatedStorage:GetAttribute("RoundState") == "Loading" then
			beginIntro(RoundConfig.Cinematic.Enabled)
		end
	end)
end

local function onPlayerAdded(player: Player): ()
	TeamService.AssignJoin(player, Levels.GetCurrent().Teams)
	CharacterService.RefreshColors()
end

-- The join-time messages wait for the client's listeners, or they arrive too late to show.
local function markReady(player: Player): ()
	if readyPlayers[player] ~= nil or player.Parent ~= Players or not TeamService.IsActive(player) then
		return
	end
	readyPlayers[player] = true
	local state = ReplicatedStorage:GetAttribute("RoundState")
	OrderService.SendSnapshot(player)
	if state == "Ended" then
		Net.Event("Round"):FireClient(player, "RoundEnd", coinsFor(TeamService.GetTeam(player)))
	elseif state == "Intro" then
		if cinematicAt ~= nil then
			Net.Event("Round"):FireClient(player, "Cinematic", cinematicAt)
		end
		Net.Event("Round"):FireClient(player, "ReadySetGo", startsAt)
	elseif state == "Waiting" and not RoundConfig.StartButton then
		startIfWaiting()
	end
end

-- Demo: only the hosts in Config.Round.StartHosts may start the round (anyone in Studio).
local function canStart(player: Player): boolean
	if RoundConfig.StudioAnyoneStarts and RunService:IsStudio() then
		return true
	end
	return table.find(RoundConfig.StartHosts, player.UserId) ~= nil
end

-- Admin reset (/resetgame): back to the boot screen before START with the coins cleared and every chef respawned
-- (held items and superskills go with the old character). Character picks are kept.
local function resetGame(): ()
	stopForEmptyServer()
	for team = 1, Levels.GetCurrent().Teams do
		ReplicatedStorage:SetAttribute(`Coins_{team}`, 0)
	end
	for _, player in TeamService.GetActivePlayers() do
		InteractionService.StopUse(player)
		local held = CarryService.Release(player)
		if held ~= nil then
			held.Instance:Destroy()
		end
		task.spawn(function(): ()
			player:LoadCharacterAsync()
		end)
	end
end

local function onRequest(player: Player, message: unknown, value: unknown): ()
	if message == "Loaded" then
		-- The map has streamed in for this client; the round starts once every chef has it.
		if LevelService.GetMap() ~= nil then
			player:SetAttribute("Loaded", true)
		end
		return
	elseif message == "Reset" then
		if canStart(player) then
			resetGame()
		end
		return
	end
	if not TeamService.IsActive(player) then
		return
	end
	if message == "Ready" then
		markReady(player)
	elseif message == "Start" and RoundConfig.StartButton and canStart(player) then
		markReady(player)
		startIfWaiting()
	elseif message == "PickCharacter" and ReplicatedStorage:GetAttribute("RoundState") == "Waiting" then
		CharacterService.Pick(player, value)
	end
end

function RoundService.PlayerActivityChanged(player: Player): ()
	if TeamService.IsActive(player) then
		markReady(player)
	else
		readyPlayers[player] = nil
	end
	-- A chef turning filmer (/cinecam) never resets the round, even as the last chef: the kitchen keeps running for
	-- the camera. Only an empty server goes back to Waiting (PlayerRemoving).
	if activeCount() > 0 and not RoundConfig.StartButton then
		startIfWaiting()
	end
end

function RoundService.Start(_self: typeof(RoundService)): ()
	local level = Levels.GetCurrent()
	clearEndTimer()
	ReplicatedStorage:SetAttribute("RoundState", "Waiting")
	ReplicatedStorage:SetAttribute("RoundEndsAt", nil)
	ReplicatedStorage:SetAttribute("RoundPausedLeft", nil)
	ReplicatedStorage:SetAttribute("RoundDuration", level.LevelDuration)
	for team = 1, level.Teams do
		ReplicatedStorage:SetAttribute(`Coins_{team}`, 0)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	Net.Event("Round").OnServerEvent:Connect(onRequest)
	Players.PlayerRemoving:Connect(function(player: Player): ()
		readyPlayers[player] = nil
		if #Players:GetPlayers() - 1 == 0 then
			stopForEmptyServer()
		end
	end)
	for _, player in TeamService.GetActivePlayers() do
		onPlayerAdded(player)
	end
end

return RoundService
