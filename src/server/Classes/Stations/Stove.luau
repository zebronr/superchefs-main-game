--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Item = require(script.Parent.Parent.Item)
local CookingTool = require(script.Parent.Parent.CookingTool)
local Station = require(script.Parent.Parent.Station)
local Counter = require(script.Parent.Counter)
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Interaction")).Cooking

local Stove = setmetatable({}, { __index = Station })
Stove.__index = Stove

export type Stove = Station.Station

function Stove.new(instance: Instance): Stove
	local self = Station.new(instance)
	setmetatable(self :: any, Stove)
	return self
end

-- A pot leaving the stove stops cooking; a pot arriving starts.
local function syncTool(before: Item.Item?, after: Item.Item?): ()
	if before == after then
		return
	end
	local oldTool = CookingTool.Cast(before)
	if oldTool ~= nil then
		oldTool:SetEnabled(false)
	end
	local newTool = CookingTool.Cast(after)
	if newTool ~= nil then
		local class = newTool.Instance:GetAttribute("cookingToolClass")
		if typeof(class) == "string" and table.find(Config.StoveToolClasses, class) ~= nil then
			newTool:SetEnabled(true)
		end
	end
end

function Stove.Handle(self: Stove, player: Player, held: Item.Item?): boolean
	local before = self.Slot:Get()
	local result = Counter.Handle(self, player, held)
	syncTool(before, self.Slot:Get())
	return result
end

function Stove.Receive(self: Stove, item: Item.Item): boolean
	local before = self.Slot:Get()
	local result = Counter.Receive(self, item)
	syncTool(before, self.Slot:Get())
	return result
end

function Stove.Destroy(self: Stove): ()
	local tool = CookingTool.Cast(self.Slot:Get())
	if tool ~= nil then
		tool:SetEnabled(false)
	end
	Station.Destroy(self)
end

return Stove
