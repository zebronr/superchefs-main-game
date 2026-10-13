--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Interactable = require(script.Parent.Parent.Classes.Interactable)
local Item = require(script.Parent.Parent.Classes.Item)
local Station = require(script.Parent.Parent.Classes.Station)
local BinderService = require(script.Parent.BinderService)
local CarryService = require(script.Parent.CarryService)
local InteractionService = require(script.Parent.InteractionService)
local TeamService = require(script.Parent.TeamService)
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Levels = Config.Levels
local RoundConfig = Config.Round

local LevelService = {}
local mapTemplate: Instance? = nil
local map: Instance? = nil
local container: Instance? = nil
local initialChildren: { Instance } = {}
local mapGeneration = 0
local started = false

function LevelService.GetLevelData(): Config.LevelData
	return Levels.GetCurrent()
end

local BIND_ATTEMPTS = 120

local function awaitObject(instance: Instance): Interactable.Interactable?
	for _ = 1, BIND_ATTEMPTS do
		local object = BinderService.GetObject(instance)
		if object ~= nil then
			return object
		end
		task.wait()
	end
	return nil
end

local function placeDefaultObject(station: Instance, defaultObject: ObjectValue, generation: number): ()
	local target = defaultObject.Value
	defaultObject:Destroy()
	if target == nil then
		return
	end

	local stationObject = Station.Cast(awaitObject(station))
	local item = Item.Cast(awaitObject(target))
	if generation ~= mapGeneration then
		return
	end
	if stationObject == nil or item == nil then
		warn(`Could not place default object on {station:GetFullName()}`)
		return
	end
	if not stationObject:PlaceDefault(item) then
		warn(`Default object {target:GetFullName()} does not fit on {station:GetFullName()}`)
		return
	end
	stationObject:Preloaded(item)
end

-- Before START there is no map: characters are held in place (anchored) so they don't fall out of the world.
local function setHeld(character: Model, held: boolean): ()
	local root = character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return
	end
	if held then
		root.Anchored = true
		character:SetAttribute("HeldForMap", true)
	elseif character:GetAttribute("HeldForMap") == true then
		root.Anchored = false
		character:SetAttribute("HeldForMap", nil)
	end
end

local function moveToSpawn(player: Player, character: Model): ()
	if not TeamService.IsActive(player) then
		return
	end
	local currentMap = map
	if currentMap == nil then
		if character:WaitForChild("HumanoidRootPart", 5) ~= nil and map == nil and player.Character == character then
			setHeld(character, true)
		end
		return
	end
	local spawnPoints = currentMap:WaitForChild("SpawnPoints")
	local team = TeamService.GetTeam(player)
	local slot = TeamService.GetSlot(player)
	local spawnPoint = spawnPoints:FindFirstChild(`{team}_spawn{slot}`) or spawnPoints:FindFirstChild("1_spawn1")
	if spawnPoint == nil or not spawnPoint:IsA("BasePart") then
		warn(`No spawn point for {player.Name}`)
		return
	end
	-- CharacterService swaps the default avatar for a custom model; skip the one it replaced.
	local root = character:WaitForChild("HumanoidRootPart", 5)
	if root == nil or player.Character ~= character or map ~= currentMap or not TeamService.IsActive(player) then
		return
	end
	setHeld(character, false)
	character:MoveTo(spawnPoint.Position)
end

local function trackPlayer(player: Player): ()
	player.CharacterAdded:Connect(function(character: Model)
		moveToSpawn(player, character)
	end)
	player:GetAttributeChangedSignal("Team"):Connect(function(): ()
		local character = player.Character
		if TeamService.IsActive(player) and character ~= nil then
			task.spawn(moveToSpawn, player, character)
		end
	end)
	if player.Character then
		task.spawn(moveToSpawn, player, player.Character)
	end
end

local function cloneMap(): ()
	local target = container
	local template = mapTemplate
	if target == nil or template == nil then
		return
	end
	mapGeneration += 1
	local newMap = template:Clone()
	newMap.Parent = target
	map = newMap
	local objects = newMap:WaitForChild("Objects")
	for _, station in objects:GetChildren() do
		-- A plate table can hold several (one ObjectValue per plate in the stack).
		for _, defaultObject in station:GetChildren() do
			if defaultObject.Name == "DefObjectOnTop" and defaultObject:IsA("ObjectValue") then
				task.spawn(placeDefaultObject, station, defaultObject, mapGeneration)
			end
		end
	end
end

function LevelService.GetServeMode(): Config.ServeMode
	return RoundConfig.ServeMode
end

function LevelService.GetMap(): Instance?
	return map
end

function LevelService.GetMapGeneration(): number
	return mapGeneration
end

function LevelService.MoveAllToSpawns(): ()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character ~= nil then
			task.spawn(moveToSpawn, player, character)
		end
	end
end

local function clearMap(): boolean
	local target = container
	if target == nil then
		return false
	end
	mapGeneration += 1
	InteractionService.StopAllUse()
	for _, player in Players:GetPlayers() do
		local held = CarryService.Release(player)
		if held ~= nil then
			held.Instance:Destroy()
		end
	end
	-- The snapshots were taken before the first map clone; every later child is round-owned.
	for _, child in target:GetChildren() do
		child:Destroy()
	end
	map = nil
	for _, snapshot in initialChildren do
		snapshot:Clone().Parent = target
	end
	return true
end

-- Swaps the round's map for a fresh copy.
function LevelService.ResetMap(): ()
	if clearMap() then
		cloneMap()
	end
end

-- Loads the map if there is none yet (START) and sends everyone to their spawns.
function LevelService.LoadMap(): ()
	if map == nil then
		cloneMap()
	end
	LevelService.MoveAllToSpawns()
end

-- Back to the empty place (the server emptied out): the next START loads the map again.
function LevelService.UnloadMap(): ()
	clearMap()
end

function LevelService.Start(_self: typeof(LevelService)): ()
	if started then
		return
	end
	started = true
	-- The mode is read once at server start; there is no runtime switching.
	local path = Levels.DefaultFor[RoundConfig.ServeMode]
	Levels.SetCurrent(path)
	ReplicatedStorage:SetAttribute("ServeMode", RoundConfig.ServeMode)
	ReplicatedStorage:SetAttribute("LevelPath", path)
	local template: Instance = ServerStorage:WaitForChild("Maps")
	for _, segment in string.split(path, "/") do
		template = template:WaitForChild(segment)
	end
	mapTemplate = template
	container = workspace:WaitForChild("$GAME")
	for _, child in (container :: Instance):GetChildren() do
		table.insert(initialChildren, child:Clone())
	end
	-- No map until START (RoundService): players wait in an empty place behind the loading screen.
	Players.PlayerAdded:Connect(trackPlayer)
	for _, player in Players:GetPlayers() do
		trackPlayer(player)
	end
end

return LevelService
