--!strict

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local Interactable = require(script.Parent.Parent.Classes.Interactable)
local Item = require(script.Parent.Parent.Classes.Item)
local Station = require(script.Parent.Parent.Classes.Station)
local BinderService = require(script.Parent.BinderService)

-- Temporary test bootstrap: loads Level1 immediately. Layer 4 replaces it with the real start flow.
local LevelService = {}

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

local function placeDefaultObject(station: Instance, defaultObject: ObjectValue): ()
	local target = defaultObject.Value
	defaultObject:Destroy()
	if target == nil then
		return
	end

	local stationObject = Station.Cast(awaitObject(station))
	local item = Item.Cast(awaitObject(target))
	if stationObject == nil or item == nil then
		warn(`Could not place default object on {station:GetFullName()}`)
		return
	end
	if not stationObject.Slot:Place(item) then
		warn(`Default object {target:GetFullName()} does not fit on {station:GetFullName()}`)
	end
end

-- Legacy teleportPlayers: team 1, player i -> SpawnPoints["1_spawn{i}"].
local function moveToSpawn(map: Instance, player: Player, character: Model): ()
	local spawnPoints = map:WaitForChild("SpawnPoints")
	local index = table.find(Players:GetPlayers(), player) or 1
	local spawnPoint = spawnPoints:FindFirstChild(`1_spawn{index}`) or spawnPoints:FindFirstChild("1_spawn1")
	if spawnPoint == nil or not spawnPoint:IsA("BasePart") then
		warn(`No spawn point for {player.Name}`)
		return
	end
	character:WaitForChild("HumanoidRootPart")
	character:MoveTo(spawnPoint.Position)
end

local function trackPlayer(map: Instance, player: Player): ()
	player.CharacterAdded:Connect(function(character: Model)
		moveToSpawn(map, player, character)
	end)
	if player.Character then
		task.spawn(moveToSpawn, map, player, player.Character)
	end
end

function LevelService.Start(_self: typeof(LevelService)): ()
	local level = ServerStorage:WaitForChild("Maps"):WaitForChild("CoOp"):WaitForChild("Chapter1"):WaitForChild("Level1")
	local container = workspace:WaitForChild("$GAME")

	local map = level:Clone()
	map.Parent = container

	Players.PlayerAdded:Connect(function(player: Player)
		trackPlayer(map, player)
	end)
	for _, player in Players:GetPlayers() do
		trackPlayer(map, player)
	end

	local objects = map:WaitForChild("Objects")
	for _, station in objects:GetChildren() do
		local defaultObject = station:FindFirstChild("DefObjectOnTop")
		if defaultObject and defaultObject:IsA("ObjectValue") then
			task.spawn(placeDefaultObject, station, defaultObject)
		end
	end
end

return LevelService
