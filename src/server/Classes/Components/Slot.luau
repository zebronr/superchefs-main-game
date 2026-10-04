--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Item = require(script.Parent.Parent.Item)
local Tags = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Tags"))

local WELD_NAME = "objectTopWelder"

-- Holds at most one Item resting on top of a surface part.
local Slot = {}
Slot.__index = Slot

type self = {
	Surface: BasePart,
	Item: Item.Item?,
	Weld: WeldConstraint?,
	DestroyedConnection: RBXScriptConnection?,
}

export type Slot = typeof(setmetatable({} :: self, Slot))

function Slot.new(surface: BasePart): Slot
	local self = setmetatable({} :: self, Slot)
	self.Surface = surface
	self.Item = nil
	self.Weld = nil
	self.DestroyedConnection = nil
	return self
end

function Slot.Get(self: Slot): Item.Item?
	return self.Item
end

local function clear(self: Slot): ()
	local weld = self.Weld
	if weld then
		self.Weld = nil
		weld:Destroy()
	end
	local connection = self.DestroyedConnection
	if connection then
		self.DestroyedConnection = nil
		connection:Disconnect()
	end
	local item = self.Item
	if item then
		self.Item = nil
		if item.Surface == self.Surface then
			item.Surface = nil
		end
		item.Detach = nil
	end
end

-- Ported from legacy Welds.PlaceObjectOnTop; also used for plated models.
function Slot.WeldOnTop(part: BasePart, surface: BasePart, increment: number?): WeldConstraint
	local offset = -Tags.GetVector3(part, "weldingOffset") + Tags.GetVector3(surface, "directionOffset")
	local rotation = CFrame.Angles(math.rad(offset.X), math.rad(offset.Y), math.rad(offset.Z))

	local rotatedCFrame = surface.CFrame * rotation
	local size = part.Size
	local up = rotatedCFrame.UpVector
	local height = math.abs(up.X * size.X) + math.abs(up.Y * size.Y) + math.abs(up.Z * size.Z)

	local weld = Instance.new("WeldConstraint")
	weld.Name = WELD_NAME
	weld.Parent = surface

	part.CFrame = surface.CFrame * CFrame.new(0, surface.Size.Y / 2 + height / 2 + (increment or 0), 0) * rotation
	weld.Part0 = surface
	weld.Part1 = part
	return weld
end

function Slot.Place(self: Slot, item: Item.Item, increment: number?): boolean
	if self.Item ~= nil or item.Holder ~= nil or item.Surface ~= nil then
		return false
	end

	local surface = self.Surface
	local weld = Slot.WeldOnTop(item.Part, surface, increment)

	self.Item = item
	self.Weld = weld
	item.Surface = surface
	item.Detach = function(): boolean
		return self:Take() == item
	end
	-- You interact with the counter, not the item resting on it.
	Tags.SetInteractionDisabled(item.Instance, true)
	self.DestroyedConnection = item.Instance.Destroying:Connect(function(): ()
		clear(self)
	end)
	return true
end

function Slot.Take(self: Slot): Item.Item?
	local item = self.Item
	if item == nil then
		return nil
	end
	clear(self)
	Tags.SetInteractionDisabled(item.Instance, false)
	return item
end

function Slot.Destroy(self: Slot): ()
	clear(self)
end

return Slot
