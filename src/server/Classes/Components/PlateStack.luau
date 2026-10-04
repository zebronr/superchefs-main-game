--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Item = require(script.Parent.Parent.Item)
local Slot = require(script.Parent.Slot)
local Tags = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Tags"))

local PlateStack = {}
PlateStack.__index = PlateStack

type Entry = {
	Item: Item.Item,
	Weld: WeldConstraint,
	Destroying: RBXScriptConnection,
}

type self = {
	Base: BasePart,
	Entries: { Entry },
	Destroyed: boolean,
}

export type PlateStack = typeof(setmetatable({} :: self, PlateStack))

function PlateStack.new(base: BasePart): PlateStack
	local self = setmetatable({} :: self, PlateStack)
	self.Base = base
	self.Entries = {}
	self.Destroyed = false
	return self
end

function PlateStack.Count(self: PlateStack): number
	return #self.Entries
end

function PlateStack.Top(self: PlateStack): Item.Item?
	local entry = self.Entries[#self.Entries]
	return if entry ~= nil then entry.Item else nil
end

local function surfaceBelow(self: PlateStack, index: number): BasePart
	local below = self.Entries[index - 1]
	return if below ~= nil then below.Item.Part else self.Base
end

local function unweld(entry: Entry): ()
	entry.Weld:Destroy()
end

local function removeAt(self: PlateStack, index: number, clearInteraction: boolean): Item.Item
	local entry = table.remove(self.Entries, index) :: Entry
	entry.Destroying:Disconnect()
	unweld(entry)
	entry.Item.Surface = nil
	if clearInteraction then
		Tags.SetInteractionDisabled(entry.Item.Instance, false)
	end

	local above = self.Entries[index]
	if above ~= nil then
		unweld(above)
		local surface = surfaceBelow(self, index)
		above.Weld = Slot.WeldOnTop(above.Item.Part, surface)
		above.Item.Surface = surface
	end
	return entry.Item
end

local function addAt(self: PlateStack, item: Item.Item, index: number): boolean
	if self.Destroyed or item.Holder ~= nil or item.Surface ~= nil or item.Instance.Parent == nil then
		return false
	end
	for _, entry in self.Entries do
		if entry.Item == item then
			return false
		end
	end

	local above = self.Entries[index]
	if above ~= nil then
		unweld(above)
	end
	local surface = surfaceBelow(self, index)
	local weld = Slot.WeldOnTop(item.Part, surface)
	item.Surface = surface
	Tags.SetInteractionDisabled(item.Instance, true)
	local entry: Entry
	entry = {
		Item = item,
		Weld = weld,
		Destroying = item.Instance.Destroying:Connect(function(): ()
			local currentIndex = table.find(self.Entries, entry)
			if currentIndex ~= nil then
				removeAt(self, currentIndex, false)
			end
		end),
	}
	table.insert(self.Entries, index, entry)

	if above ~= nil then
		above.Weld = Slot.WeldOnTop(above.Item.Part, item.Part)
		above.Item.Surface = item.Part
	end
	return true
end

function PlateStack.Push(self: PlateStack, item: Item.Item): boolean
	return addAt(self, item, #self.Entries + 1)
end

function PlateStack.InsertBelowTop(self: PlateStack, item: Item.Item): boolean
	return addAt(self, item, math.max(1, #self.Entries))
end

function PlateStack.PopTop(self: PlateStack): Item.Item?
	local count = #self.Entries
	if count == 0 then
		return nil
	end
	return removeAt(self, count, true)
end

function PlateStack.Destroy(self: PlateStack): ()
	if self.Destroyed then
		return
	end
	self.Destroyed = true
	while #self.Entries > 0 do
		removeAt(self, #self.Entries, true)
	end
end

return PlateStack
