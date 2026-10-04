--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Interactable = require(script.Parent.Interactable)
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Interaction"))
local Tags = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Tags"))
local Trove = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Trove"))

-- A carryable BasePart. Floor interaction is handled by InteractionService.
local Item = setmetatable({}, { __index = Interactable })
Item.__index = Item

export type Item = Interactable.Interactable & {
	Part: BasePart,
	Holder: Player?,
	-- The surface part this item rests on, if any (managed by Slot).
	Surface: BasePart?,
	Detach: (() -> boolean)?,
	CanSwapWith: (self: Item, other: Item) -> boolean,
}

local items: { [Instance]: Item } = {}
local waiting: { [Instance]: { thread } } = {}

function Item.new(instance: Instance): Item
	assert(instance:IsA("BasePart"), `Item {instance:GetFullName()} must be a BasePart`)
	local self: Item = setmetatable({
		Instance = instance,
		Kind = "Item",
		Trove = Trove.new(),
		Part = instance,
		Holder = nil,
		Surface = nil,
		Detach = nil,
	}, Item) :: any

	items[instance] = self
	local threads = waiting[instance]
	if threads then
		waiting[instance] = nil
		for _, thread in threads do
			task.spawn(thread, self)
		end
	end
	return self
end

function Item.Get(instance: Instance): Item?
	return items[instance]
end

-- Yields until the binder has created the Item for `instance`; nil on timeout.
function Item.Await(instance: Instance, timeout: number): Item?
	local existing = items[instance]
	if existing then
		return existing
	end

	local thread = coroutine.running()
	local threads = waiting[instance]
	if threads == nil then
		threads = {}
		waiting[instance] = threads
	end
	table.insert(threads, thread)

	local timer = task.delay(timeout, function(): ()
		local pending = waiting[instance]
		if pending then
			local index = table.find(pending, thread)
			if index then
				table.remove(pending, index)
				if #pending == 0 then
					waiting[instance] = nil
				end
				task.spawn(thread, nil)
			end
		end
	end)
	local result = coroutine.yield() :: Item?
	if result ~= nil then
		task.cancel(timer)
	end
	return result
end

-- Narrows an Interactable to an Item.
function Item.Cast(object: Interactable.Interactable?): Item?
	if object ~= nil and object.Kind == "Item" then
		return object :: any
	end
	return nil
end

function Item.CanSwapWith(self: Item, other: Item): boolean
	local class = Tags.ClassOf(self.Instance)
	return class ~= nil and class == Tags.ClassOf(other.Instance) and not Config.AllowInteractionWithSelf[class]
end

function Item.Destroy(self: Item): ()
	if items[self.Instance] == self then
		items[self.Instance] = nil
	end
	self.Trove:Destroy()
end

return Item
