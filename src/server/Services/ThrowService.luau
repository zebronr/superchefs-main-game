--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Item = require(script.Parent.Parent.Classes.Item)
local Station = require(script.Parent.Parent.Classes.Station)
local BinderService = require(script.Parent.BinderService)
local CarryService = require(script.Parent.CarryService)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"):WaitForChild("Interaction")).Throw
local Projectile = require(Shared:WaitForChild("Util"):WaitForChild("Projectile"))
local Tags = require(Shared:WaitForChild("Tags"))

local ThrowService = {}

local function collisionAt(part: BasePart, position: Vector3, start: CFrame, character: Model?): boolean
	local excluded: { Instance } = { part }
	if character ~= nil then
		table.insert(excluded, character)
	end
	for _, tag in { Tags.Ignore, Tags.ProjectileIgnore } do
		for _, instance in CollectionService:GetTagged(tag) do
			table.insert(excluded, instance)
		end
	end
	-- Surface is set by every Slot.Place path, including chopping and stove placement.
	for _, instance in Item.GetRestingInstances() do
		table.insert(excluded, instance)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = excluded
	local cframe = Projectile.UnheldCFrame(part, Projectile.At(start, position))
	local origin = position + Vector3.new(0, 0.25, 0)
	for _, y in Config.CollisionAngles do
		local destination = (cframe * CFrame.new(0, y, -Config.CollisionRayLength)).Position
		local hit = workspace:Raycast(origin, destination - origin, params)
		if hit ~= nil and (hit.Position - position).Magnitude <= Config.CollisionRadius then
			return true
		end
	end
	return false
end

local function catchingStation(part: BasePart, position: Vector3): Station.Station?
	local candidates = CollectionService:GetTagged(Tags.ThrowInteractable)
	if #candidates == 0 then
		return nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = candidates
	local hit = workspace:Raycast(position, Vector3.new(0, -Config.FloorRayLength, 0), params)
	if hit == nil or hit.Instance == part then
		return nil
	end
	return Station.Cast(BinderService.GetObject(hit.Instance))
end

local function fallEndpoint(part: BasePart, position: Vector3): Vector3?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	-- Exclude the projectile so the downward ray cannot land on its own collider.
	params.FilterDescendantsInstances = { part }
	local hit = workspace:Raycast(position, Vector3.new(0, -Config.FloorRayLength, 0), params)
	return if hit then hit.Position + Vector3.yAxis * Projectile.VerticalExtent(part) / 2 else nil
end

function ThrowService.Throw(player: Player, clientCFrame: CFrame): ()
	local item = CarryService.GetHeld(player)
	if item == nil or not CollectionService:HasTag(item.Instance, Tags.Food) then
		return
	end
	local part = item.Part
	if not ((clientCFrame.Position - part.Position).Magnitude <= Config.MarginOfError) then
		return
	end
	if CarryService.Drop(player, true) ~= item then
		return
	end
	local endpoint = Projectile.Endpoint(part, clientCFrame)
	local duration = Projectile.Duration(clientCFrame.Position, endpoint)
	local startedAt = workspace:GetServerTimeNow()
	local character = player.Character
	local heartbeat: RBXScriptConnection? = nil
	local destroying: RBXScriptConnection? = nil
	local finished = false

	local function disconnect(): ()
		if heartbeat ~= nil then
			heartbeat:Disconnect()
			heartbeat = nil
		end
		if destroying ~= nil then
			destroying:Disconnect()
			destroying = nil
		end
	end

	local function stop(position: Vector3, station: Station.Station?): ()
		if finished then
			return
		end
		finished = true
		disconnect()
		part.CFrame = Projectile.At(clientCFrame, position)
		part.AssemblyLinearVelocity = Vector3.zero
		part.AssemblyAngularVelocity = Vector3.zero
		part.Anchored = false
		part:SetAttribute(Config.ThrowStartAttribute, nil)
		part:SetAttribute(Config.ThrowEndAttribute, nil)
		part:SetAttribute(Config.ThrowStartedAtAttribute, nil)
		part:SetAttribute(Config.FallFromAttribute, nil)
		part:SetAttribute(Config.FallToAttribute, nil)
		part:SetAttribute(Config.FallStartedAtAttribute, nil)
		CollectionService:RemoveTag(part, Tags.Projectile)
		Tags.SetInteractionDisabled(item.Instance, false)
		if station ~= nil and station.Instance:IsDescendantOf(workspace) then
			station:Receive(item)
		end
	end

	part.Anchored = true
	part:SetAttribute(Config.ThrowStartAttribute, clientCFrame)
	part:SetAttribute(Config.ThrowEndAttribute, endpoint)
	part:SetAttribute(Config.ThrowStartedAtAttribute, startedAt)
	CollectionService:AddTag(part, Tags.Projectile)
	destroying = part.Destroying:Connect(function(): ()
		finished = true
		disconnect()
	end)

	local falling = false
	local fallFrom = Vector3.zero
	local fallTo = Vector3.zero
	local fallStartedAt = 0
	local fallDuration = 0
	local landingStation: Station.Station? = nil
	heartbeat = RunService.Heartbeat:Connect(function(): ()
		local now = workspace:GetServerTimeNow()
		if falling then
			local t = if fallDuration > 0 then math.clamp((now - fallStartedAt) / fallDuration, 0, 1) else 1
			if t >= 1 then
				stop(fallTo, landingStation)
			end
			return
		end
		local t = if duration > 0 then math.clamp((now - startedAt) / duration, 0, 1) else 1
		local position = Projectile.Bezier(clientCFrame.Position, endpoint, t)
		-- As in legacy, the server computes a path for collision but only clients move the anchored part in flight.
		if collisionAt(part, position, clientCFrame, character) then
			landingStation = catchingStation(part, position)
			local surface = fallEndpoint(part, position)
			if surface == nil then
				stop(position, nil)
				return
			end
			falling = true
			fallFrom = position
			fallTo = surface
			fallDuration = Projectile.FallDuration(fallFrom, fallTo)
			fallStartedAt = now
			part:SetAttribute(Config.FallFromAttribute, fallFrom)
			part:SetAttribute(Config.FallToAttribute, fallTo)
			part:SetAttribute(Config.FallStartedAtAttribute, fallStartedAt)
		elseif t >= 1 then
			stop(endpoint, nil)
		end
	end)
end

return ThrowService
