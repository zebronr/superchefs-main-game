--!strict

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Item = require(script.Parent.Parent.Classes.Item)
local Station = require(script.Parent.Parent.Classes.Station)
local BinderService = require(script.Parent.BinderService)
local CarryService = require(script.Parent.CarryService)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local ThrowConfig = Config.Interaction.Throw
local Projectile = require(Shared:WaitForChild("Util"):WaitForChild("Projectile"))
local Tags = require(Shared:WaitForChild("Tags"))

local ThrowService = {}

local interceptFind: ((from: Vector3, to: Vector3) -> Player?)? = nil
local interceptTake: ((player: Player, item: Item.Item, position: Vector3) -> ())? = nil
local characterHitHandler: ((player: Player) -> ())? = nil

-- Lets a skill grab a flying item. `find` is asked each flight step, before the catch check, for a
-- player whose skill reaches the step; `take` then receives the item, which stays anchored where it is.
function ThrowService.SetInterceptor(
	find: (from: Vector3, to: Vector3) -> Player?,
	take: (player: Player, item: Item.Item, position: Vector3) -> ()
): ()
	interceptFind = find
	interceptTake = take
end

-- Called with the player whose character a projectile hit, or who just caught one.
function ThrowService.SetCharacterHitHandler(handler: (player: Player) -> ()): ()
	characterHitHandler = handler
end

local function buildParams(part: BasePart, character: Model?): RaycastParams
	local excluded: { Instance } = { part }
	if character ~= nil then
		table.insert(excluded, character)
	end
	for _, tag in { Tags.Ignore, Tags.ProjectileIgnore, Tags.Projectile } do
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
	return params
end

local function distanceToSegment(point: Vector3, from: Vector3, to: Vector3): number
	local segment = to - from
	local lengthSquared = segment:Dot(segment)
	if lengthSquared == 0 then
		return (point - from).Magnitude
	end
	local t = math.clamp((point - from):Dot(segment) / lengthSquared, 0, 1)
	return (point - (from + segment * t)).Magnitude
end

local function flat(vector: Vector3): Vector3
	local result = Vector3.new(vector.X, 0, vector.Z)
	return if result.Magnitude > 1e-4 then result.Unit else Vector3.zero
end

local function catchingStation(part: BasePart, position: Vector3): Station.Station?
	local candidates = CollectionService:GetTagged(Tags.ThrowInteractable)
	if #candidates == 0 then
		return nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = candidates
	local hit = workspace:Raycast(position, Vector3.new(0, -ThrowConfig.FloorRayLength, 0), params)
	if hit == nil or hit.Instance == part then
		return nil
	end
	return Station.Cast(BinderService.GetObject(hit.Instance))
end

function ThrowService.Throw(player: Player, clientCFrame: CFrame, canCatch: (Player) -> boolean): ()
	local item = CarryService.GetHeld(player)
	if item == nil or not Tags.IsClass(item.Instance, Tags.Food) then
		return
	end
	local part = item.Part
	if not ((clientCFrame.Position - part.Position).Magnitude <= ThrowConfig.MarginOfError) then
		return
	end
	if CarryService.Drop(player, true) ~= item then
		return
	end
	local endpoint = Projectile.Endpoint(part, clientCFrame)
	-- Back-date the start by the one-way latency so the server timeline matches the thrower's prediction.
	local pingOk, ping = pcall(function(): number
		return player:GetNetworkPing()
	end)
	local lag = if pingOk then math.clamp(ping / 2, 0, ThrowConfig.MaxLagCompensation) else 0
	local startedAt = workspace:GetServerTimeNow() - lag
	local params = buildParams(part, player.Character)
	-- The flat direction the item travels, used for the catch facing test.
	local travel = flat(endpoint - clientCFrame.Position)
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

	-- Ends the flight bookkeeping without placing the part; shared by landing and catching.
	local function release(): boolean
		if finished then
			return false
		end
		finished = true
		disconnect()
		part:SetAttribute(ThrowConfig.ThrowStartAttribute, nil)
		part:SetAttribute(ThrowConfig.ThrowEndAttribute, nil)
		part:SetAttribute(ThrowConfig.ThrowStartedAtAttribute, nil)
		part:SetAttribute(ThrowConfig.FallFromAttribute, nil)
		part:SetAttribute(ThrowConfig.FallToAttribute, nil)
		part:SetAttribute(ThrowConfig.FallStartedAtAttribute, nil)
		CollectionService:RemoveTag(part, Tags.Projectile)
		return true
	end

	local function stop(position: Vector3, station: Station.Station?): ()
		if not release() then
			return
		end
		part.CFrame = Projectile.At(clientCFrame, position)
		part.AssemblyLinearVelocity = Vector3.zero
		part.AssemblyAngularVelocity = Vector3.zero
		part.Anchored = false
		Tags.SetInteractionDisabled(item.Instance, false)
		if station ~= nil and station.Instance:IsDescendantOf(workspace) then
			station:Receive(item)
		end
	end

	-- The closest eligible player whose root is near the path and who faces the incoming item.
	local function findCatcher(from: Vector3, to: Vector3): Player?
		local best: Player? = nil
		local bestDistance = ThrowConfig.CatchRadius
		for _, candidate in Players:GetPlayers() do
			if candidate == player or CarryService.GetHeld(candidate) ~= nil or not canCatch(candidate) then
				continue
			end
			local candidateCharacter = candidate.Character
			local humanoid = if candidateCharacter then candidateCharacter:FindFirstChildOfClass("Humanoid") else nil
			local root = if candidateCharacter then candidateCharacter:FindFirstChild("HumanoidRootPart") else nil
			if humanoid == nil or humanoid.Health <= 0 or root == nil or not root:IsA("BasePart") then
				continue
			end
			local distance = distanceToSegment(root.Position, from, to)
			if distance > bestDistance then
				continue
			end
			local facing = flat(root.CFrame.LookVector)
			if facing:Dot(-travel) < ThrowConfig.CatchFacingDot then
				continue
			end
			best = candidate
			bestDistance = distance
		end
		return best
	end

	part.Anchored = true
	part:SetAttribute(ThrowConfig.ThrowStartAttribute, clientCFrame)
	part:SetAttribute(ThrowConfig.ThrowEndAttribute, endpoint)
	part:SetAttribute(ThrowConfig.ThrowStartedAtAttribute, startedAt)
	CollectionService:AddTag(part, Tags.Projectile)
	destroying = part.Destroying:Connect(function(): ()
		finished = true
		disconnect()
	end)

	local falling = false
	local fallFrom = Vector3.zero
	local fallTo = Vector3.zero
	local fallStartedAt = 0
	local landingStation: Station.Station? = nil
	local previous = clientCFrame.Position

	local function startFall(from: Vector3, now: number): ()
		landingStation = catchingStation(part, from)
		local surface = Projectile.SurfaceBelow(part, from, params)
		if surface == nil then
			stop(from, nil)
			return
		end
		falling = true
		fallFrom = from
		fallTo = surface
		fallStartedAt = now
		part:SetAttribute(ThrowConfig.FallFromAttribute, fallFrom)
		part:SetAttribute(ThrowConfig.FallToAttribute, fallTo)
		part:SetAttribute(ThrowConfig.FallStartedAtAttribute, fallStartedAt)
	end

	heartbeat = RunService.Heartbeat:Connect(function(): ()
		local now = workspace:GetServerTimeNow()
		if falling then
			if now - fallStartedAt >= Projectile.FallDuration(fallFrom, fallTo) then
				stop(fallTo, landingStation)
			end
			return
		end
		-- As in legacy, the server computes the path but only clients move the anchored part in flight.
		local position, done = Projectile.FlightPosition(clientCFrame.Position, endpoint, now - startedAt)
		local find = interceptFind
		local take = interceptTake
		local interceptor = if find ~= nil and take ~= nil then find(previous, position) else nil
		if interceptor ~= nil and take ~= nil then
			if release() then
				take(interceptor, item, position)
			end
			return
		end
		local catcher = findCatcher(previous, position)
		if catcher ~= nil then
			local caught = CarryService.Pickup(catcher, item)
			if caught then
				release()
				local onHit = characterHitHandler
				if onHit ~= nil then
					onHit(catcher)
				end
				return
			end
			startFall(position, now)
			return
		end
		local hit = Projectile.Sweep(previous, position, params)
		if hit ~= nil then
			local onHit = characterHitHandler
			local model = hit.Instance:FindFirstAncestorWhichIsA("Model")
			local hitPlayer = if model ~= nil then Players:GetPlayerFromCharacter(model) else nil
			if hitPlayer ~= nil and onHit ~= nil then
				onHit(hitPlayer)
			end
			startFall(hit.Position + hit.Normal * ThrowConfig.CastRadius, now)
		elseif done then
			-- Landing at the end of the arc is an impact too: a station under the endpoint receives the item.
			stop(endpoint, catchingStation(part, endpoint))
		else
			previous = position
		end
	end)
end

return ThrowService
