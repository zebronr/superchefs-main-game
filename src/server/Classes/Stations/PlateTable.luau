--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Item = require(script.Parent.Parent.Item)
local DirtyPlate = require(script.Parent.Parent.DirtyPlate)
local Plate = require(script.Parent.Parent.Plate)
local PlateStack = require(script.Parent.Parent.Components.PlateStack)
local Station = require(script.Parent.Parent.Station)
local CarryService = require(script.Parent.Parent.Parent.Services.CarryService)
local Tags = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Tags"))

local plateTemplate = ServerStorage:WaitForChild("Assets"):WaitForChild("Plates"):WaitForChild("Plate")
local dirtyPlateTemplate = ServerStorage:WaitForChild("Assets"):WaitForChild("Plates"):WaitForChild("DirtyPlate")
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

function PlateTable.AddPlate(self: PlateTable, dirty: boolean?): ()
	if not self.Alive or not self.Instance:IsDescendantOf(workspace) then
		return
	end

	local plate = (if dirty then dirtyPlateTemplate else plateTemplate):Clone()
	Tags.SetInteractionDisabled(plate, true)
	plate.Parent = workspace:FindFirstChild("$GAME") or workspace

	local item = Item.Await(plate, BIND_TIMEOUT)
	if item == nil or not self.Alive or not self.Instance:IsDescendantOf(workspace) or not self.Stack:InsertBelowTop(item) then
		warn(`Could not add returned plate to {self.Instance:GetFullName()}`)
		plate:Destroy()
	end
end

local function takeStack(self: PlateTable): { Item.Item }
	local plates: { Item.Item } = {}
	while self.Stack:Count() > 0 do
		local plate = self.Stack:PopTop()
		if plate ~= nil then
			table.insert(plates, 1, plate)
		end
	end
	return plates
end

local function restoreStack(self: PlateTable, plates: { Item.Item }): ()
	for _, plate in plates do
		assert(self.Stack:Push(plate :: any), "Could not restore PlateTable stack")
	end
end

local function handleDirty(self: PlateTable, player: Player, held: Item.Item?): boolean
	local carried = DirtyPlate.Cast(held)
	if held ~= nil and carried == nil then
		return false
	end
	local plates = takeStack(self)
	if #plates == 0 then
		return false
	end
	if carried ~= nil then
		for _, plate in plates do
			assert(carried.Stack:Push(plate :: any), "Could not transfer dirty PlateTable stack")
		end
		return true
	end
	local bottom = DirtyPlate.Cast(plates[1])
	if bottom == nil then
		restoreStack(self, plates)
		return false
	end
	for index = 2, #plates do
		assert(bottom.Stack:Push(plates[index] :: any), "Could not assemble carried dirty stack")
	end
	if not CarryService.Pickup(player, bottom) then
		bottom:TakeAll()
		restoreStack(self, plates)
		return false
	end
	return true
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
	if DirtyPlate.Cast(top) ~= nil then
		return handleDirty(self, player, held)
	end
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
