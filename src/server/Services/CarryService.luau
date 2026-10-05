--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Item = require(script.Parent.Parent.Classes.Item)
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Interaction"))
local Tags = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Tags"))

-- Replaces legacy PlayerValues.ObjectCarried and ObjectAction.
local CarryService = {}

type Hold = {
	Item: Item.Item,
	Weld: WeldConstraint,
	Destroyed: RBXScriptConnection,
}

local holds: { [Player]: Hold } = {}
local resetThreads: { [BasePart]: thread } = {}

function CarryService.GetHeld(player: Player): Item.Item?
	local hold = holds[player]
	if hold then
		return hold.Item
	end
	return nil
end

-- Clears the hold state without any physics side effects.
function CarryService.Release(player: Player): Item.Item?
	local hold = holds[player]
	if hold == nil then
		return nil
	end
	holds[player] = nil
	hold.Destroyed:Disconnect()
	hold.Weld:Destroy()
	hold.Item.Holder = nil
	return hold.Item
end

function CarryService.Pickup(player: Player, item: Item.Item): boolean
	if holds[player] ~= nil or item.Holder ~= nil or item.Surface ~= nil then
		return false
	end

	local character = player.Character
	local rootPart = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if rootPart == nil or not rootPart:IsA("BasePart") then
		return false
	end

	local part = item.Part
	local pendingReset = resetThreads[part]
	if pendingReset then
		resetThreads[part] = nil
		task.cancel(pendingReset)
	end

	part.Massless = true
	part.Anchored = false
	local ownerSuccess, ownerError = pcall(function()
		part:SetNetworkOwner(player)
	end)
	if not ownerSuccess then
		warn(`Failed to set network owner of {part:GetFullName()}: {ownerError}`)
	end

	local offset = Tags.GetVector3(part, "holdingOffset")
	Tags.SetInteractionDisabled(item.Instance, true)

	local weld = Instance.new("WeldConstraint")
	weld.Name = "ObjectHolder"
	weld.Parent = rootPart
	weld.Part0 = rootPart

	part.CanCollide = false
	part.CFrame = rootPart.CFrame
		* CFrame.new(0, 0, -Config.CarryDistance)
		* CFrame.Angles(math.rad(offset.X), math.rad(offset.Y), math.rad(offset.Z))

	weld.Part1 = part

	item.Holder = player
	local destroyed = item.Instance.Destroying:Connect(function(): ()
		local hold = holds[player]
		if hold and hold.Item == item then
			CarryService.Release(player)
		end
	end)
	holds[player] = {
		Item = item,
		Weld = weld,
		Destroyed = destroyed,
	}
	return true
end

function CarryService.Drop(player: Player, keepDisabled: boolean?): Item.Item?
	local item = CarryService.Release(player)
	if item == nil then
		return nil
	end

	local part = item.Part
	part.Massless = false
	part.Anchored = false
	pcall(function()
		part:SetNetworkOwner(player)
	end)
	part.CanCollide = true

	if not keepDisabled then
		task.delay(Config.DropReenableDelay, function(): ()
			-- Skip if it was picked up or placed again in the meantime.
			if item.Holder == nil and item.Surface == nil and item.Instance.Parent ~= nil then
				Tags.SetInteractionDisabled(item.Instance, false)
			end
		end)
	end

	resetThreads[part] = task.delay(Config.NetworkOwnerResetDelay, function(): ()
		resetThreads[part] = nil
		pcall(function()
			if part:GetNetworkOwner() == player then
				part:SetNetworkOwner(nil)
			end
			part.AssemblyLinearVelocity = Vector3.zero
		end)
	end)
	return item
end

local function watchCharacter(player: Player, character: Model): ()
	-- A new character means the old hold is stale.
	CarryService.Drop(player)
	task.spawn(function(): ()
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid and humanoid:IsA("Humanoid") then
			humanoid.Died:Connect(function(): ()
				CarryService.Drop(player)
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
			CarryService.Drop(player)
		end
	end)
	local character = player.Character
	if character then
		watchCharacter(player, character)
	end
end

function CarryService.Start(_self: typeof(CarryService)): ()
	Players.PlayerAdded:Connect(watchPlayer)
	Players.PlayerRemoving:Connect(function(player: Player): ()
		CarryService.Drop(player)
	end)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
end

return CarryService
