--!strict

local Players = game:GetService("Players")

local Config = require(script.Parent.Parent:WaitForChild("Config"))
local SkillsConfig = Config.Skills
local Attribute = SkillsConfig.Attribute
local HustleConfig = SkillsConfig.Hustle
local FreezeConfig = SkillsConfig.DeepFreeze
local RushConfig = SkillsConfig.OrderRush

-- Reads the instant skills' effects from replicated attributes, so the server and every client agree:
-- Bill's Hustle, the Penguin's frost circles and the Alien's Order Rush timeline.
local SkillEffects = {}

local function number(instance: Instance, name: string): number?
	local value = instance:GetAttribute(name)
	return if typeof(value) == "number" then value else nil
end

-- Hustle -----------------------------------------------------------------------------------------

function SkillEffects.HustleActive(character: Instance?, now: number?): boolean
	if character == nil then
		return false
	end
	local hustleUntil = number(character, Attribute.HustleUntil)
	return hustleUntil ~= nil and (now or workspace:GetServerTimeNow()) < hustleUntil
end

-- Chopping and washing speed for a character.
function SkillEffects.WorkMultiplier(character: Instance?): number
	return if SkillEffects.HustleActive(character) then HustleConfig.WorkMultiplier else 1
end

-- Walk speed multiplier from Hustle.
function SkillEffects.MoveMultiplier(character: Instance?): number
	return if SkillEffects.HustleActive(character) then HustleConfig.MoveMultiplier else 1
end

-- Deep Freeze ------------------------------------------------------------------------------------

export type Zone = {
	Owner: Model,
	Center: Vector3,
	StartedAt: number,
	Until: number,
}

-- The zone a character's attributes describe, if it is running at `now`.
function SkillEffects.ZoneOf(character: Model, now: number): Zone?
	local center = character:GetAttribute(Attribute.FreezeCenter)
	local startedAt = number(character, Attribute.FreezeStartedAt)
	local freezeUntil = number(character, Attribute.FreezeUntil)
	if typeof(center) ~= "Vector3" or startedAt == nil or freezeUntil == nil then
		return nil
	end
	if now < startedAt or now >= freezeUntil then
		return nil
	end
	return { Owner = character, Center = center, StartedAt = startedAt, Until = freezeUntil }
end

-- Every running frost circle (one per Penguin at most).
function SkillEffects.FreezeZones(now: number?): { Zone }
	local time = now or workspace:GetServerTimeNow()
	local zones: { Zone } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local zone = if character ~= nil then SkillEffects.ZoneOf(character, time) else nil
		if zone ~= nil then
			table.insert(zones, zone)
		end
	end
	return zones
end

function SkillEffects.InZone(zone: Zone, position: Vector3): boolean
	local offset = position - zone.Center
	return math.abs(offset.Y) <= FreezeConfig.Height
		and Vector3.new(offset.X, 0, offset.Z).Magnitude <= FreezeConfig.Radius
end

-- The zone covering `position`, if any.
function SkillEffects.ZoneAt(position: Vector3, zones: { Zone }): Zone?
	for _, zone in zones do
		if SkillEffects.InZone(zone, position) then
			return zone
		end
	end
	return nil
end

function SkillEffects.IsFrozen(position: Vector3, zones: { Zone }?): boolean
	return SkillEffects.ZoneAt(position, zones or SkillEffects.FreezeZones()) ~= nil
end

-- Order Rush -------------------------------------------------------------------------------------

export type RushStop = {
	Position: Vector3,
	Yaw: number,
}

local function rootOf(model: Model): BasePart?
	local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	return if root ~= nil and root:IsA("BasePart") then root else nil
end

-- Seconds of order patience a customer has left (a frozen customer's clock stopped at FrozenAt).
function SkillEffects.PatienceLeft(customer: Model, now: number): number
	local startedAt = number(customer, "PatienceStartedAt")
	local duration = number(customer, "PatienceDuration")
	if startedAt == nil or duration == nil then
		return math.huge
	end
	local frozenAt = number(customer, Attribute.FrozenAt)
	return startedAt + duration - (frozenAt or now)
end

-- Customers waiting to order, least patience first, at most MaxCustomers.
function SkillEffects.RushTargets(now: number?): { Model }
	local time = now or workspace:GetServerTimeNow()
	local temp = workspace:FindFirstChild("$Temp")
	local waiting: { { Model: Model, Left: number } } = {}
	if temp ~= nil then
		for _, child in temp:GetChildren() do
			if child:IsA("Model") and child:GetAttribute("CustomerState") == "WaitingToOrder" and rootOf(child) ~= nil then
				table.insert(waiting, { Model = child, Left = SkillEffects.PatienceLeft(child, time) })
			end
		end
	end
	table.sort(waiting, function(left, right): boolean
		return left.Left < right.Left
	end)
	local targets: { Model } = {}
	for index = 1, math.min(#waiting, RushConfig.MaxCustomers) do
		table.insert(targets, waiting[index].Model)
	end
	return targets
end

local function stopRayParams(): RaycastParams
	local exclude: { Instance } = {}
	local camera = workspace.CurrentCamera
	if camera ~= nil then
		table.insert(exclude, camera)
	end
	for _, player in Players:GetPlayers() do
		if player.Character ~= nil then
			table.insert(exclude, player.Character)
		end
	end
	local temp = workspace:FindFirstChild("$Temp")
	if temp ~= nil then
		for _, child in temp:GetChildren() do
			if child:IsA("Model") and child:GetAttribute("CustomerState") ~= nil then
				table.insert(exclude, child)
			end
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	return params
end

local function clearStop(rootPosition: Vector3, spot: Vector3, params: RaycastParams): boolean
	return workspace:Raycast(rootPosition, spot - rootPosition, params) == nil
		and workspace:Raycast(spot, Vector3.new(0, -RushConfig.StopOffset * 2, 0), params) ~= nil
end

-- The waiter stands beside the customer, slightly toward the table, and faces them.
function SkillEffects.StopPosition(customer: Model, from: Vector3): RushStop?
	local root = rootOf(customer)
	if root == nil then
		return nil
	end
	local toward = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
	local right = Vector3.new(root.CFrame.RightVector.X, 0, root.CFrame.RightVector.Z).Unit
	local forward = toward * RushConfig.StopForward
	local first = root.Position + right * RushConfig.StopOffset + forward
	local second = root.Position - right * RushConfig.StopOffset + forward
	local preferred = if (first - from).Magnitude <= (second - from).Magnitude then first else second
	local other = if preferred == first then second else first
	local params = stopRayParams()
	local spot: Vector3
	if clearStop(root.Position, preferred, params) then
		spot = preferred
	elseif clearStop(root.Position, other, params) then
		spot = other
	else
		local offset = Vector3.new(from.X - root.Position.X, 0, from.Z - root.Position.Z)
		local direction = if offset.Magnitude > 0.05 then offset.Unit else -toward
		spot = root.Position + direction * RushConfig.StopOffset
	end
	local facing = Vector3.new(root.Position.X - spot.X, 0, root.Position.Z - spot.Z).Unit
	return { Position = spot, Yaw = math.atan2(-facing.X, -facing.Z) }
end

-- Stops are replicated as one string attribute: "x,y,z,yaw;x,y,z,yaw".
function SkillEffects.EncodeStops(stops: { RushStop }): string
	local parts: { string } = {}
	for _, stop in stops do
		local position = stop.Position
		table.insert(parts, string.format("%.2f,%.2f,%.2f,%.3f", position.X, position.Y, position.Z, stop.Yaw))
	end
	return table.concat(parts, ";")
end

function SkillEffects.DecodeStops(value: unknown): { RushStop }
	local stops: { RushStop } = {}
	if typeof(value) ~= "string" then
		return stops
	end
	for _, part in string.split(value, ";") do
		local coords = string.split(part, ",")
		local x, y, z, yaw = tonumber(coords[1]), tonumber(coords[2]), tonumber(coords[3]), tonumber(coords[4])
		if x ~= nil and y ~= nil and z ~= nil and yaw ~= nil then
			table.insert(stops, { Position = Vector3.new(x, y, z), Yaw = yaw })
		end
	end
	return stops
end

-- Seconds after the start that the afterimage reaches stop `index` (1-based).
function SkillEffects.RushStopTime(index: number): number
	return RushConfig.VanishTime + (index - 1) * RushConfig.StepTime
end

-- Seconds after the start that stop `index`'s order is taken.
function SkillEffects.RushTakeTime(index: number): number
	return SkillEffects.RushStopTime(index) + RushConfig.StepTime / 2
end

-- Seconds the whole chain lasts for `count` stops.
function SkillEffects.RushDuration(count: number): number
	return RushConfig.VanishTime + count * RushConfig.StepTime + RushConfig.ReturnTime
end

return SkillEffects
