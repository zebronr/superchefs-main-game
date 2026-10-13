--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Interactable = require(script.Parent.Interactable)
local Item = require(script.Parent.Item)
local Slot = require(script.Parent.Components.Slot)
local Tags = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Tags"))
local Trove = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Trove"))

-- A fixed object with a surface. Subclasses implement Handle; Interact applies the locks first.
local Station = setmetatable({}, { __index = Interactable })
Station.__index = Station

export type Station = Interactable.Interactable & {
	Part: BasePart,
	Slot: Slot.Slot,
	Handle: (self: Station, player: Player, held: Item.Item?) -> boolean,
	Receive: (self: Station, item: Item.Item) -> boolean,
	PlaceDefault: (self: Station, item: Item.Item) -> boolean,
	Preloaded: (self: Station, item: Item.Item) -> (),
	IsLocked: (self: Station) -> boolean,
}

function Station.new(instance: Instance): Station
	assert(instance:IsA("BasePart"), `Station {instance:GetFullName()} must be a BasePart`)
	local trove = Trove.new()
	local slot = trove:Add(Slot.new(instance))
	local self: Station = setmetatable({
		Instance = instance,
		Kind = "Station",
		Trove = trove,
		Part = instance,
		Slot = slot,
	}, Station) :: any
	return self
end

-- Narrows an Interactable to a Station.
function Station.Cast(object: Interactable.Interactable?): Station?
	if object ~= nil and object.Kind == "Station" then
		return object :: any
	end
	return nil
end

function Station.IsLocked(self: Station): boolean
	if
		CollectionService:HasTag(self.Instance, Tags.Locked)
		or CollectionService:HasTag(self.Instance, Tags.FireLocked)
	then
		return true
	end
	local onTop = self.Slot:Get()
	-- Whatever sits on top is locked too while it's on fire (a burning pot can't be taken off the stove).
	return onTop ~= nil
		and (
			CollectionService:HasTag(onTop.Instance, Tags.Locked)
			or CollectionService:HasTag(onTop.Instance, Tags.FireLocked)
		)
end

function Station.Handle(_self: Station, _player: Player, _held: Item.Item?): boolean
	return false
end

function Station.Receive(_self: Station, _item: Item.Item): boolean
	return false
end

-- Where the map's default items (DefObjectOnTop) go; a station with its own storage overrides it.
function Station.PlaceDefault(self: Station, item: Item.Item): boolean
	return self.Slot:Place(item)
end

-- The map placed a default item straight into the slot (no Handle or Receive ran).
function Station.Preloaded(_self: Station, _item: Item.Item): () end

function Station.Interact(self: Station, player: Player, held: Interactable.Interactable?): boolean
	if self:IsLocked() then
		return false
	end
	return self:Handle(player, Item.Cast(held))
end

return Station
