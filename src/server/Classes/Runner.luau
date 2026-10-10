--!strict

local Interactable = require(script.Parent.Interactable)

local Runner = setmetatable({}, { __index = Interactable })
Runner.__index = Runner

local onCatch: ((Model, Player) -> boolean)? = nil

function Runner.SetCatchHandler(handler: (Model, Player) -> boolean): ()
	onCatch = handler
end

function Runner.new(instance: Instance): Interactable.Interactable
	local self = Interactable.new(instance, "Runner")
	setmetatable(self :: any, Runner)
	return self
end

function Runner.Interact(self: Interactable.Interactable, player: Player, _held: Interactable.Interactable?): boolean
	local model = self.Instance.Parent
	return model ~= nil and model:IsA("Model") and onCatch ~= nil and onCatch(model, player)
end

return Runner
