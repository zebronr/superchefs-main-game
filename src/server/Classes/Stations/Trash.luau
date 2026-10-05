--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Item = require(script.Parent.Parent.Item)
local Plate = require(script.Parent.Parent.Plate)
local Station = require(script.Parent.Parent.Station)
local CarryService = require(script.Parent.Parent.Parent.Services.CarryService)
local Tags = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Tags"))

-- Ported from legacy Trash: food is destroyed, a plate is emptied and stays in hand.
local Trash = setmetatable({}, { __index = Station })
Trash.__index = Trash

export type Trash = Station.Station

function Trash.new(instance: Instance): Trash
	local self = Station.new(instance)
	setmetatable(self :: any, Trash)
	return self
end

function Trash.Handle(_self: Trash, player: Player, held: Item.Item?): boolean
	if held == nil then
		return false
	end
	if Tags.IsClass(held.Instance, Tags.Food) then
		CarryService.Drop(player, true)
		held.Instance:Destroy()
		return true
	end
	local plate = Plate.Cast(held)
	if plate ~= nil and plate.Content ~= nil then
		plate:Clear()
		return true
	end
	-- Dirty plates, pots and extinguishers are ignored (legacy).
	return false
end

return Trash
