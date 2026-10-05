--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Trove = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Trove"))

-- Inheritance stays one level deep: Station and Item extend Interactable, and
-- shared behavior lives in components (see Components/Slot).
local Interactable = {}
Interactable.__index = Interactable

export type Kind = "Station" | "Item"

export type Interactable = {
	Instance: Instance,
	Kind: Kind,
	AutoUse: boolean,
	Trove: typeof(Trove.new()),
	Interact: (self: Interactable, player: Player, held: Interactable?) -> boolean,
	StartUse: (self: Interactable, player: Player, onEnded: () -> ()) -> boolean,
	StopUse: (self: Interactable, player: Player) -> (),
	Accept: (self: Interactable, other: Interactable, player: Player?) -> boolean,
	Destroy: (self: Interactable) -> (),
}

function Interactable.new(instance: Instance, kind: Kind): Interactable
	local self: Interactable = setmetatable({
		Instance = instance,
		Kind = kind,
		AutoUse = false,
		Trove = Trove.new(),
	}, Interactable) :: any
	return self
end

function Interactable.Interact(_self: Interactable, _player: Player, _held: Interactable?): boolean
	return false
end

function Interactable.StartUse(_self: Interactable, _player: Player, _onEnded: () -> ()): boolean
	return false
end

function Interactable.StopUse(_self: Interactable, _player: Player): ()
end

-- Whether this object takes `other` into itself (a plate taking food, later). Base accepts nothing.
function Interactable.Accept(_self: Interactable, _other: Interactable, _player: Player?): boolean
	return false
end

function Interactable.Destroy(self: Interactable): ()
	self.Trove:Destroy()
end

return Interactable
