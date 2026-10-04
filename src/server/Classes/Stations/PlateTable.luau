--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Item = require(script.Parent.Parent.Item)
local Plate = require(script.Parent.Parent.Plate)
local PlateStack = require(script.Parent.Parent.Components.PlateStack)
local Station = require(script.Parent.Parent.Station)
local CarryService = require(script.Parent.Parent.Parent.Services.CarryService)
local Tags = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Tags"))

local plateTemplate = ServerStorage:WaitForChild("Assets"):WaitForChild("Plates"):WaitForChild("Plate")
local BIND_TIMEOUT = 5

local PlateTable = setmetatable({}, { __index = Station })
PlateTable.__index = PlateTable

export type PlateTable = Station.Station & {
	Stack: PlateStack.PlateStack,
	Alive: boolean,
}

local tables: { [Instance]: PlateTable } = {}

function PlateTable.new(instance: Instance): PlateTable
	local self = Station.new(instance) :: PlateTable
	self.Stack = self.Trove:Add(PlateStack.new(self.Part))
	self.Alive = true
	setmetatable(self :: any, PlateTable)
	tables[instance] = self
	return self
end

function PlateTable.ForTeam(team: number): PlateTable?
	local name = `PlateTable_{team}`
	for instance, plateTable in tables do
		if instance.Name == name and plateTable.Alive and instance:IsDescendantOf(workspace) then
			return plateTable :: any
		end
	end
	return nil
end

function PlateTable.AddPlate(self: PlateTable): ()
	if not self.Alive or not self.Instance:IsDescendantOf(workspace) then
		return
	end

	local plate = plateTemplate:Clone()
	Tags.SetInteractionDisabled(plate, true)
	plate.Parent = workspace:FindFirstChild("$GAME") or workspace

	local item = Item.Await(plate, BIND_TIMEOUT)
	if item == nil or not self.Alive or not self.Instance:IsDescendantOf(workspace) or not self.Stack:InsertBelowTop(item) then
		warn(`Could not add returned plate to {self.Instance:GetFullName()}`)
		plate:Destroy()
	end
end

local function swap(self: PlateTable, player: Player): boolean
	local top = self.Stack:PopTop()
	if top == nil then
		return false
	end
	local dropped = CarryService.Drop(player, true)
	if dropped == nil then
		self.Stack:Push(top)
		return false
	end
	if not self.Stack:Push(dropped) then
		self.Stack:Push(top)
		CarryService.Pickup(player, dropped)
		return false
	end
	if not CarryService.Pickup(player, top) then
		self.Stack:PopTop()
		self.Stack:Push(top)
		CarryService.Pickup(player, dropped)
		return false
	end
	return true
end

function PlateTable.Handle(self: PlateTable, player: Player, held: Item.Item?): boolean
	local top = self.Stack:Top()
	if top == nil then
		return false
	end
	-- TODO(layer 6): DirtyPlate stacks and carried DirtyPlates.
	if Plate.Cast(top) == nil or (held ~= nil and Tags.ClassOf(held.Instance) == Tags.DirtyPlate) then
		return false
	end

	if held == nil then
		local taken = self.Stack:PopTop()
		if taken == nil then
			return false
		end
		if not CarryService.Pickup(player, taken) then
			self.Stack:Push(taken)
			return false
		end
		return true
	end

	if top:Accept(held, player) or held:Accept(top, player) then
		return true
	end
	if held:CanSwapWith(top) then
		return swap(self, player)
	end
	return false
end

function PlateTable.Destroy(self: PlateTable): ()
	self.Alive = false
	if tables[self.Instance] == self then
		tables[self.Instance] = nil
	end
	Station.Destroy(self)
end

return PlateTable
