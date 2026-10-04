--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Trove = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Trove"))

export type Destroyable = { Destroy: (self: any) -> () }

export type Binder<T> = {
	Start: (self: Binder<T>) -> (),
	Get: (self: Binder<T>, instance: Instance) -> T?,
	GetAll: (self: Binder<T>) -> { T },
	Destroy: (self: Binder<T>) -> (),
}

local Binder = {}

function Binder.new<T>(tag: string, constructor: (Instance) -> T & Destroyable): Binder<T & Destroyable>
	type Bound = T & Destroyable
	local objects: { [Instance]: Bound } = {}
	local binding: { [Instance]: boolean } = {}
	local destroyingConnections: { [Instance]: RBXScriptConnection } = {}
	local ancestryConnections: { [Instance]: RBXScriptConnection } = {}
	local trove = Trove.new()
	local started = false
	local destroyed = false

	local function unbind(instance: Instance): ()
		local object = objects[instance]
		if object == nil then
			return
		end
		objects[instance] = nil

		local connection = destroyingConnections[instance]
		if connection then
			destroyingConnections[instance] = nil
			connection:Disconnect()
		end
		local success, message = pcall(function()
			object:Destroy()
		end)
		if not success then
			warn(`Binder {tag} failed to destroy {instance:GetFullName()}: {message}`)
		end
	end

	local function bind(instance: Instance): ()
		if
			destroyed
			or objects[instance] ~= nil
			or binding[instance]
			or not CollectionService:HasTag(instance, tag)
			or not instance:IsDescendantOf(workspace)
		then
			return
		end

		binding[instance] = true
		local success, result = pcall(constructor, instance)
		binding[instance] = nil
		if not success then
			warn(`Binder {tag} failed to construct {instance:GetFullName()}: {result}`)
			return
		end

		local object: Bound = result
		if destroyed or not CollectionService:HasTag(instance, tag) or not instance:IsDescendantOf(workspace) then
			object:Destroy()
			return
		end
		objects[instance] = object
		local connection = instance.Destroying:Connect(function(): ()
			unbind(instance)
		end)
		destroyingConnections[instance] = connection
	end

	-- Only instances inside workspace get objects; tagged templates elsewhere stay unbound.
	local function track(instance: Instance): ()
		if destroyed or ancestryConnections[instance] then
			return
		end
		ancestryConnections[instance] = instance.AncestryChanged:Connect(function(): ()
			if instance:IsDescendantOf(workspace) then
				bind(instance)
			else
				unbind(instance)
			end
		end)
		bind(instance)
	end

	local function untrack(instance: Instance): ()
		local connection = ancestryConnections[instance]
		if connection then
			ancestryConnections[instance] = nil
			connection:Disconnect()
		end
		unbind(instance)
	end

	local binder: Binder<Bound> = {
		Start = function(_self: Binder<Bound>): ()
			if started or destroyed then
				return
			end
			started = true
			trove:Connect(CollectionService:GetInstanceAddedSignal(tag), track)
			trove:Connect(CollectionService:GetInstanceRemovedSignal(tag), untrack)
			for _, instance in CollectionService:GetTagged(tag) do
				track(instance)
			end
		end,
		Get = function(_self: Binder<Bound>, instance: Instance): Bound?
			return objects[instance]
		end,
		GetAll = function(_self: Binder<Bound>): { Bound }
			local all: { Bound } = {}
			for _, object in objects do
				table.insert(all, object)
			end
			return all
		end,
		Destroy = function(_self: Binder<Bound>): ()
			if destroyed then
				return
			end
			destroyed = true
			trove:Destroy()
			for instance, connection in ancestryConnections do
				ancestryConnections[instance] = nil
				connection:Disconnect()
			end
			local instances: { Instance } = {}
			for instance in objects do
				table.insert(instances, instance)
			end
			for _, instance in instances do
				unbind(instance)
			end
		end,
	}

	return binder
end

return Binder
