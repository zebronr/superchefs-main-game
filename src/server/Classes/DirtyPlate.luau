--!strict

local Interactable = require(script.Parent.Interactable)
local Item = require(script.Parent.Item)
local PlateStack = require(script.Parent.Components.PlateStack)

local DirtyPlate = setmetatable({}, { __index = Item })
DirtyPlate.__index = DirtyPlate

export type DirtyPlate = Item.Item & {
	IsDirtyPlate: boolean,
	Stack: PlateStack.PlateStack,
	Count: (self: DirtyPlate) -> number,
	TakeAll: (self: DirtyPlate) -> { DirtyPlate },
}

function DirtyPlate.new(instance: Instance): DirtyPlate
	local self = Item.new(instance) :: DirtyPlate
	self.IsDirtyPlate = true
	self.Stack = PlateStack.new(self.Part)
	setmetatable(self :: any, DirtyPlate)
	return self
end

function DirtyPlate.Cast(object: Interactable.Interactable?): DirtyPlate?
	local item = Item.Cast(object)
	if item ~= nil and (item :: any).IsDirtyPlate == true then
		return item :: any
	end
	return nil
end

function DirtyPlate.Count(self: DirtyPlate): number
	return 1 + self.Stack:Count()
end

function DirtyPlate.TakeAll(self: DirtyPlate): { DirtyPlate }
	local plates: { DirtyPlate } = {}
	while self.Stack:Count() > 0 do
		local item = self.Stack:PopTop()
		if item ~= nil then
			table.insert(plates, 1, item :: DirtyPlate)
		end
	end
	return plates
end

function DirtyPlate.Accept(self: DirtyPlate, other: Interactable.Interactable, _player: Player?): boolean
	local plate = DirtyPlate.Cast(other)
	if plate == nil or plate == self or self.Holder == nil or plate.Holder ~= nil then
		return false
	end
	local detach = plate.Detach
	if detach ~= nil and not detach() then
		return false
	end
	if plate.Surface ~= nil then
		return false
	end
	local rest = plate:TakeAll()
	if not self.Stack:Push(plate) then
		for _, stacked in rest do
			plate.Stack:Push(stacked :: any)
		end
		return false
	end
	for _, stacked in rest do
		assert(self.Stack:Push(stacked :: any), "Dirty plate stack transfer failed")
	end
	return true
end

function DirtyPlate.Destroy(self: DirtyPlate): ()
	self.Stack:Destroy()
	Item.Destroy(self)
end

return DirtyPlate
