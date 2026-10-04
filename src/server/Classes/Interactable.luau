--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Trove = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Trove"))

local Interactable = {}
Interactable.__index = Interactable

type self = {
	Instance: Instance,
	Trove: typeof(Trove.new()),
}

export type Interactable = typeof(setmetatable({} :: self, Interactable))

function Interactable.new(instance: Instance): Interactable
	local self = setmetatable({} :: self, Interactable)
	self.Instance = instance
	self.Trove = Trove.new()
	return self
end

function Interactable.Interact(_self: Interactable, _player: Player, _heldItem: Instance?): boolean
	return false
end

function Interactable.Destroy(self: Interactable): ()
	self.Trove:Destroy()
end

-- local Counter = setmetatable({}, { __index = Interactable }); Counter.__index = Counter
return Interactable
