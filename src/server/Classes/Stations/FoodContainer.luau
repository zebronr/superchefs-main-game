--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Item = require(script.Parent.Parent.Item)
local Station = require(script.Parent.Parent.Station)
local CarryService = require(script.Parent.Parent.Parent.Services.CarryService)
local Tags = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Tags"))

-- Ported from legacy FoodContainer.
local FoodContainer = setmetatable({}, { __index = Station })
FoodContainer.__index = FoodContainer

export type FoodContainer = Station.Station

local BIND_TIMEOUT = 5

function FoodContainer.new(instance: Instance): FoodContainer
	local self = Station.new(instance)
	setmetatable(self :: any, FoodContainer)
	return self
end

function FoodContainer.Handle(self: FoodContainer, player: Player, held: Item.Item?): boolean
	if held ~= nil then
		return false
	end

	local foodValue = self.Instance:FindFirstChild("Food")
	if foodValue == nil or not foodValue:IsA("ObjectValue") then
		warn(`FoodContainer {self.Instance:GetFullName()} has no Food ObjectValue`)
		return false
	end
	local template = foodValue.Value
	if template == nil then
		warn(`FoodContainer {self.Instance:GetFullName()} has an empty Food value`)
		return false
	end

	local food = template:Clone()
	Tags.SetInteractionDisabled(food, true)
	food.Parent = workspace:FindFirstChild("$GAME") or workspace

	local item = Item.Await(food, BIND_TIMEOUT)
	if item == nil or not CarryService.Pickup(player, item) then
		food:Destroy()
		return false
	end
	return true
end

return FoodContainer
