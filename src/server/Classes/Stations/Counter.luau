--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Item = require(script.Parent.Parent.Item)
local Station = require(script.Parent.Parent.Station)
local CarryService = require(script.Parent.Parent.Parent.Services.CarryService)
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Interaction"))
local Tags = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Tags"))

-- Ported from legacy Countertop.
local Counter = setmetatable({}, { __index = Station })
Counter.__index = Counter

export type Counter = Station.Station

function Counter.new(instance: Instance): Counter
	local self = Station.new(instance)
	setmetatable(self :: any, Counter)
	return self
end

-- The player takes the item on the counter and the held item goes on the counter.
local function swap(self: Counter, player: Player): boolean
	local top = self.Slot:Take()
	if top == nil then
		return false
	end
	local dropped = CarryService.Drop(player, true)
	if dropped == nil then
		self.Slot:Place(top)
		return false
	end
	if not CarryService.Pickup(player, top) then
		self.Slot:Place(top)
		CarryService.Pickup(player, dropped)
		return false
	end
	self.Slot:Place(dropped)
	return true
end

function Counter.Handle(self: Counter, player: Player, held: Item.Item?): boolean
	local onTop = self.Slot:Get()

	if held == nil then
		if onTop == nil then
			return false
		end
		local taken = self.Slot:Take()
		if taken == nil then
			return false
		end
		if not CarryService.Pickup(player, taken) then
			self.Slot:Place(taken)
			return false
		end
		return true
	end

	if onTop == nil then
		local dropped = CarryService.Drop(player, true)
		if dropped == nil then
			return false
		end
		if not self.Slot:Place(dropped) then
			CarryService.Pickup(player, dropped)
			return false
		end
		return true
	end

	if onTop:Accept(held, player) or held:Accept(onTop, player) then
		return true
	end

	local class = Tags.ClassOf(held.Instance)
	if class ~= nil and class == Tags.ClassOf(onTop.Instance) and not Config.AllowInteractionWithSelf[class] then
		return swap(self, player)
	end
	return false
end

return Counter
