--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Binder = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("Binder"))

local BinderService = {}
local binders: { [string]: Binder.Binder<Binder.Destroyable> } = {}

local function _register(tag: string, constructor: (Instance) -> Binder.Destroyable): ()
	binders[tag] = Binder.new(tag, constructor)
end

function BinderService.Get(tag: string): Binder.Binder<Binder.Destroyable>?
	return binders[tag]
end

function BinderService.Init(_self: typeof(BinderService)): ()
	-- register("Counter", Counter.new)
end

function BinderService.Start(_self: typeof(BinderService)): ()
	for _, binder in binders do
		binder:Start()
	end
end

return BinderService
