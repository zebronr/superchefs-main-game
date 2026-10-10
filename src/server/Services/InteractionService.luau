--!strict

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Interactable = require(script.Parent.Parent.Classes.Interactable)
local Item = require(script.Parent.Parent.Classes.Item)
local Station = require(script.Parent.Parent.Classes.Station)
local BinderService = require(script.Parent.BinderService)
local CarryService = require(script.Parent.CarryService)
local CharacterService = require(script.Parent.CharacterService)
local EffectService = require(script.Parent.EffectService)
local ThrowService = require(script.Parent.ThrowService)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local InteractionConfig = Config.Interaction
local Net = require(Shared:WaitForChild("Net"))
local Tags = require(Shared:WaitForChild("Tags"))

-- Replaces the legacy InteractionHandler: validates requests, then routes them to objects.
local InteractionService = {}

local requestCounts: { [Player]: number } = {}
local locks: { [Interactable.Interactable]: boolean } = {}
type ActiveUse = {
	Object: Interactable.Interactable,
	StartPosition: Vector3,
	Node: Instance?,
}
local activeUse: { [Player]: ActiveUse } = {}

-- Ported from legacy verifyRequest's rate limit: at most MaxRequests per player per RequestWindow.
local function consumeRequest(player: Player): boolean
	local count = requestCounts[player] or 0
	if count >= InteractionConfig.MaxRequests then
		warn(`{player.Name} sent too many interaction requests`)
		return false
	end
	requestCounts[player] = count + 1
	task.delay(InteractionConfig.RequestWindow, function(): ()
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
	local minDistance = (if class then InteractionConfig.MinDistance[class] else nil) or InteractionConfig.DefaultMinDistance
	local maxDistance = minDistance + InteractionConfig.ServerDistanceMargin
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
	local class = Tags.ClassOf(target.Instance)
	local heldClass = if held then Tags.ClassOf(held.Instance) else nil
	-- Legacy routes a held Plate or CookingTool ahead of visible Food.
	if (class == Tags.Food and heldClass ~= Tags.Plate and heldClass ~= Tags.CookingTool)
		or (class == Tags.Plate and held == nil) then
		EffectService.PlaySound("Interact")
	end

	if held == nil then
		CarryService.Pickup(player, target)
		return
	end

	if target:Accept(held, player) or held:Accept(target, player) then
		return
	end

	if held:CanSwapWith(target) then
		if class == Tags.Plate then
			EffectService.PlaySound("Interact")
		end
		CarryService.Drop(player)
		CarryService.Pickup(player, target)
	end
end

local function interact(player: Player, target: Instance?): ()
	local held = CarryService.GetHeld(player)

	if target == nil then
		if held ~= nil then
			local class = Tags.ClassOf(held.Instance)
			if class == Tags.Food or class == Tags.Plate then
				EffectService.PlaySound("Interact")
			end
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
		elseif object.Kind == "Runner" then
			object:Interact(player, held)
		end
		return true
	end)
	locks[object] = nil
	if not success then
		warn(`Interaction by {player.Name} on {target:GetFullName()} failed: {message}`)
	end
end

-- The station an item rests on, following plate stacks down to the station's own part.
local function stationOf(item: Item.Item): Station.Station?
	local surface = item.Surface
	for _ = 1, 32 do
		if surface == nil then
			return nil
		end
		local object = BinderService.GetObject(surface)
		local station = Station.Cast(object)
		if station ~= nil then
			return station
		end
		local below = Item.Cast(object)
		if below == nil then
			return nil
		end
		surface = below.Surface
	end
	return nil
end

function InteractionService.StationOf(item: Item.Item): Station.Station?
	return stationOf(item)
end

function InteractionService.IsUsing(player: Player): boolean
	return activeUse[player] ~= nil
end

-- Takes `item` into the player's empty hands the way an empty-handed Interact would: an item on a
-- station goes through that station's Interact, a loose item through CarryService. Returns what
-- ended up in the hands (a PlateTable hands out its top plate), or nil.
function InteractionService.TakeFor(player: Player, item: Item.Item): Item.Item?
	if CarryService.GetHeld(player) ~= nil then
		return nil
	end
	local station = if item.Surface ~= nil then stationOf(item) else nil
	local object: Interactable.Interactable? = if item.Surface ~= nil then station :: any else item :: any
	if object == nil or locks[object] then
		return nil
	end
	locks[object] = true
	local success, message = pcall(function(): boolean
		if station ~= nil then
			station:Interact(player, nil)
		else
			interactWithItem(player, item, nil)
		end
		return true
	end)
	locks[object] = nil
	if not success then
		warn(`Taking {item.Instance:GetFullName()} for {player.Name} failed: {message}`)
	end
	return CarryService.GetHeld(player)
end

local function stopUse(player: Player): ()
	local use = activeUse[player]
	if use == nil then
		return
	end
	local success, message = pcall(function(): boolean
		use.Object:StopUse(player)
		return true
	end)
	activeUse[player] = nil
	if not success then
		warn(`Use release by {player.Name} failed: {message}`)
	end
end

function InteractionService.StopAllUse(): ()
	for player in activeUse do
		stopUse(player)
	end
end

local function startUse(player: Player, target: Instance?, node: Instance?, rootPart: BasePart): ()
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
			local current = activeUse[player]
			if current ~= nil and current.Object == object then
				activeUse[player] = nil
			end
		end)
	end)
	if not success then
		warn(`Use by {player.Name} on {object.Instance:GetFullName()} failed: {started}`)
	elseif started then
		activeUse[player] = {
			Object = object,
			StartPosition = rootPart.Position,
			Node = node,
		}
	end
end

local function onRequest(player: Player, action: unknown, target: unknown, node: unknown, heldState: unknown): ()
	if action == "StopUse" then
		if consumeRequest(player) then
			stopUse(player)
		end
		return
	end
	-- Aiming or using a super skill blocks every other action.
	local skillCharacter = player.Character
	if skillCharacter ~= nil and skillCharacter:GetAttribute(Config.Skills.Attribute.State) ~= nil then
		return
	end
	if action == "Dash" then
		CharacterService.Dash(player)
		return
	end
	if action == "Throw" then
		if typeof(target) ~= "CFrame" or not consumeRequest(player) or activeUse[player] ~= nil then
			return
		end
		ThrowService.Throw(player, target, function(candidate: Player): boolean
			-- A Gecko with its tongue out has empty hands but is busy; aiming is interrupted by the catch instead.
			local candidateCharacter = candidate.Character
			local busy = candidateCharacter ~= nil
				and candidateCharacter:GetAttribute(Config.Skills.Attribute.State) == "Active"
			return activeUse[candidate] == nil and not busy
		end)
		return
	end
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
		local current = activeUse[player]
		if current ~= nil and not current.Object.AutoUse then
			stopUse(player)
		end
		return
	end
	if action == "Interact" then
		stopUse(player)
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
		startUse(player, targetInstance, nodeInstance, rootPart)
	end
end

local function checkAutoUse(): ()
	for player, use in activeUse do
		if not use.Object.AutoUse then
			continue
		end
		local character = player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if root == nil or not root:IsA("BasePart") then
			stopUse(player)
			continue
		end
		local delta = root.Position - use.StartPosition
		if Vector3.new(delta.X, 0, delta.Z).Magnitude > InteractionConfig.AutoUse.MoveTolerance
			or not isInRange(root, use.Object.Instance, use.Node) then
			stopUse(player)
		end
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
	player.CharacterRemoving:Connect(function(removing: Model): ()
		if player.Character == removing then
			stopUse(player)
		end
	end)
	local character = player.Character
	if character then
		watchCharacter(player, character)
	end
end

function InteractionService.Start(_self: typeof(InteractionService)): ()
	Net.Event("Interact").OnServerEvent:Connect(onRequest)
	RunService.Heartbeat:Connect(checkAutoUse)
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
