--!strict

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Interactable = require(script.Parent.Parent.Classes.Interactable)
local Item = require(script.Parent.Parent.Classes.Item)
local Station = require(script.Parent.Parent.Classes.Station)
local BinderService = require(script.Parent.BinderService)
local CarryService = require(script.Parent.CarryService)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"):WaitForChild("Interaction"))
local Net = require(Shared:WaitForChild("Net"))
local Tags = require(Shared:WaitForChild("Tags"))

-- Replaces the legacy InteractionHandler: validates requests, then routes them to objects.
local InteractionService = {}

local requestCounts: { [Player]: number } = {}
local locks: { [Interactable.Interactable]: boolean } = {}
local activeUse: { [Player]: Interactable.Interactable } = {}

-- Ported from legacy verifyRequest's rate limit: at most MaxRequests per player per RequestWindow.
local function consumeRequest(player: Player): boolean
	local count = requestCounts[player] or 0
	if count >= Config.MaxRequests then
		warn(`{player.Name} sent too many interaction requests`)
		return false
	end
	requestCounts[player] = count + 1
	task.delay(Config.RequestWindow, function(): ()
		local remaining = (requestCounts[player] or 1) - 1
		if remaining > 0 then
			requestCounts[player] = remaining
		else
			requestCounts[player] = nil
		end
	end)
	return true
end

local function isInRange(rootPart: BasePart, target: Instance, node: Instance?): boolean
	local class = Tags.ClassOf(target)
	local minDistance = (if class then Config.MinDistance[class] else nil) or Config.DefaultMinDistance
	local maxDistance = minDistance + Config.ServerDistanceMargin
	local position = rootPart.Position

	if
		node ~= nil
		and node:IsA("BasePart")
		and node.Parent ~= nil
		and node.Parent.Parent == target
		and CollectionService:HasTag(node, Tags.ProximityNode)
		and (position - node.Position).Magnitude <= maxDistance
	then
		return true
	end
	return target:IsA("BasePart") and (position - target.Position).Magnitude <= maxDistance
end

local function interactWithItem(player: Player, target: Item.Item, held: Item.Item?): ()
	if target.Holder ~= nil or target.Surface ~= nil then
		return
	end
	-- TODO(layer 9): Interact sound

	if held == nil then
		CarryService.Pickup(player, target)
		return
	end

	if target:Accept(held, player) or held:Accept(target, player) then
		return
	end

	if held:CanSwapWith(target) then
		CarryService.Drop(player)
		CarryService.Pickup(player, target)
	end
end

local function interact(player: Player, target: Instance?): ()
	local held = CarryService.GetHeld(player)

	if target == nil then
		if held ~= nil then
			-- TODO(layer 9): Interact sound
			CarryService.Drop(player)
		end
		return
	end

	local object = BinderService.GetObject(target)
	if object == nil or locks[object] then
		return
	end

	-- The lock is always released, even if the interaction errors.
	locks[object] = true
	local success, message = pcall(function(): boolean
		local station = Station.Cast(object)
		if station ~= nil then
			station:Interact(player, held)
			return true
		end
		local item = Item.Cast(object)
		if item ~= nil then
			interactWithItem(player, item, held)
		end
		return true
	end)
	locks[object] = nil
	if not success then
		warn(`Interaction by {player.Name} on {target:GetFullName()} failed: {message}`)
	end
end

local function stopUse(player: Player): ()
	local object = activeUse[player]
	if object == nil then
		return
	end
	local success, message = pcall(function(): boolean
		object:StopUse(player)
		return true
	end)
	if not success then
		activeUse[player] = nil
		warn(`Use release by {player.Name} failed: {message}`)
	end
end

local function startUse(player: Player, target: Instance?): ()
	if activeUse[player] ~= nil then
		return
	end
	local held = CarryService.GetHeld(player)
	local object = if held ~= nil then held else if target ~= nil then BinderService.GetObject(target) else nil
	if object == nil then
		return
	end
	local success, started = pcall(function(): boolean
		return object:StartUse(player, function(): ()
			if activeUse[player] == object then
				activeUse[player] = nil
			end
		end)
	end)
	if not success then
		warn(`Use by {player.Name} on {object.Instance:GetFullName()} failed: {started}`)
	elseif started then
		activeUse[player] = object
	end
end

local function onRequest(player: Player, action: unknown, target: unknown, node: unknown, heldState: unknown): ()
	if action ~= "Interact" and action ~= "Use" then
		return
	end
	if target ~= nil and typeof(target) ~= "Instance" then
		return
	end
	if node ~= nil and typeof(node) ~= "Instance" then
		return
	end
	if action == "Use" and typeof(heldState) ~= "boolean" then
		return
	end
	if not consumeRequest(player) then
		return
	end
	if action == "Use" and heldState == false then
		stopUse(player)
		return
	end
	if activeUse[player] ~= nil then
		return
	end

	local targetInstance = target :: Instance?
	local nodeInstance = node :: Instance?

	local character = player.Character
	local rootPart = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if rootPart == nil or not rootPart:IsA("BasePart") then
		return
	end

	if targetInstance ~= nil then
		if not targetInstance:IsDescendantOf(workspace) or Tags.IsInteractionDisabled(targetInstance) then
			return
		end
		if not isInRange(rootPart, targetInstance, nodeInstance) then
			return
		end
	elseif CarryService.GetHeld(player) == nil then
		return
	end

	if action == "Interact" then
		interact(player, targetInstance)
	else
		startUse(player, targetInstance)
	end
end

local function watchCharacter(player: Player, character: Model): ()
	stopUse(player)
	task.spawn(function(): ()
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid and humanoid:IsA("Humanoid") then
			humanoid.Died:Connect(function(): ()
				if player.Character == character then
					stopUse(player)
				end
			end)
		end
	end)
end

local function watchPlayer(player: Player): ()
	player.CharacterAdded:Connect(function(character: Model): ()
		watchCharacter(player, character)
	end)
	player.CharacterRemoving:Connect(function(): ()
		stopUse(player)
	end)
	local character = player.Character
	if character then
		watchCharacter(player, character)
	end
end

function InteractionService.Start(_self: typeof(InteractionService)): ()
	Net.Event("Interact").OnServerEvent:Connect(onRequest)
	Players.PlayerAdded:Connect(watchPlayer)
	Players.PlayerRemoving:Connect(function(player: Player): ()
		stopUse(player)
		requestCounts[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
end

return InteractionService
