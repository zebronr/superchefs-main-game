--!strict

local Players = game:GetService("Players")

local Config = require(script.Parent.Parent:WaitForChild("Config"))
local OpenFloor = require(script.Parent:WaitForChild("OpenFloor"))
local SkillEffects = require(script.Parent:WaitForChild("SkillEffects"))
local Attribute = Config.Skills.Attribute
local Tuning = Config.Skills.BearToss

-- The Bear's toss, shared by the server (which checks it) and every client (which draws it): the flight arc, where a
-- thrown player can land, and the toss state read from the thrown player's attributes.
local TossPath = {}

export type Flight = { StartedAt: number, From: Vector3, To: Vector3 }

-- Root position `alpha` (0 .. 1) of the way through a flight: a straight line lifted into an arc.
function TossPath.Position(from: Vector3, to: Vector3, alpha: number): Vector3
	return from:Lerp(to, alpha) + Vector3.yAxis * (4 * Tuning.ArcHeight * alpha * (1 - alpha))
end

-- The Bear's UserId while it holds `character` overhead.
function TossPath.HeldBy(character: Instance): number?
	local value = character:GetAttribute(Attribute.TossHeldBy)
	return if typeof(value) == "number" then value else nil
end

function TossPath.Flight(character: Instance): Flight?
	local startedAt = character:GetAttribute(Attribute.TossStartedAt)
	local from = character:GetAttribute(Attribute.TossFrom)
	local to = character:GetAttribute(Attribute.TossTo)
	if typeof(startedAt) ~= "number" or typeof(from) ~= "Vector3" or typeof(to) ~= "Vector3" then
		return nil
	end
	return { StartedAt = startedAt, From = from, To = to }
end

-- True while `character` is held overhead, flying or getting up: it can't move, interact, throw, dash or use its
-- superskill.
function TossPath.Busy(character: Instance?, now: number?): boolean
	if character == nil then
		return false
	end
	if TossPath.HeldBy(character) ~= nil then
		return true
	end
	local flight = TossPath.Flight(character)
	return flight ~= nil and (now or workspace:GetServerTimeNow()) < TossPath.EndsAt(flight)
end

-- When a flight is over: the landing, then the get-up.
function TossPath.EndsAt(flight: Flight): number
	return flight.StartedAt + Tuning.FlightTime + Tuning.GetUpTime
end

-- Whether the flat distance from the Bear's root to a landing is inside the throw range (plus `margin`).
function TossPath.InRange(origin: Vector3, to: Vector3, margin: number): boolean
	local distance = Vector3.new(to.X - origin.X, 0, to.Z - origin.Z).Magnitude
	return distance >= Tuning.MinRange - margin and distance <= Tuning.MaxRange + margin
end

-- Queries for one toss: `landing` sees what the thrown player collides with when solid (where it must fit), `arc`
-- what it collides with now (a phasing Ghost's flight ignores walls). Players and what the thrown player holds are
-- skipped.
export type Queries = {
	Body: OpenFloor.Body,
	Landing: OverlapParams,
	LandingRay: RaycastParams,
	ArcRay: RaycastParams,
}

function TossPath.Queries(thrown: Model): Queries?
	local root = thrown:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return nil
	end
	local body = OpenFloor.BodyOf(thrown, root)
	if body == nil then
		return nil
	end
	local exclude: { Instance } = {}
	for _, player in Players:GetPlayers() do
		if player.Character ~= nil then
			table.insert(exclude, player.Character)
		end
	end
	local holder = root:FindFirstChild("ObjectHolder")
	local held = if holder ~= nil and holder:IsA("WeldConstraint") then holder.Part1 else nil
	if held ~= nil then
		table.insert(exclude, held)
	end
	local landing, landingRay = OpenFloor.Params(SkillEffects.CollisionGroup(thrown, false), exclude)
	local _, arcRay = OpenFloor.Params(SkillEffects.CollisionGroup(thrown), exclude)
	return { Body = body, Landing = landing, LandingRay = landingRay, ArcRay = arcRay }
end

-- Whether nothing the thrown player collides with is in the way of the arc.
function TossPath.Clear(from: Vector3, to: Vector3, queries: Queries): boolean
	local previous = from
	for index = 1, Tuning.ArcSamples do
		local point = TossPath.Position(from, to, index / Tuning.ArcSamples)
		if workspace:Raycast(previous, point - previous, queries.ArcRay) ~= nil then
			return false
		end
		previous = point
	end
	return true
end

-- Whether the thrown player can stand with its root at `to`: it fits, on a floor (Bounds), not a counter top.
function TossPath.Fits(to: Vector3, queries: Queries): boolean
	return OpenFloor.Fits(
		to,
		queries.Body,
		queries.Landing,
		queries.LandingRay,
		Tuning.LandingFloorDrop,
		Config.Character.BoundsCollisionGroup
	)
end

-- The landing root position for the flat spot under `point`, looking down from `from` (the thrown player overhead),
-- or nil when that spot is a counter, a wall or no floor.
function TossPath.LandingAt(point: Vector3, from: Vector3, queries: Queries): Vector3?
	local top = Vector3.new(point.X, from.Y, point.Z)
	local hit = workspace:Raycast(top, Vector3.new(0, -(Tuning.ArcHeight + 20), 0), queries.LandingRay)
	if hit == nil or hit.Instance.CollisionGroup ~= Config.Character.BoundsCollisionGroup then
		return nil
	end
	local root = hit.Position + Vector3.yAxis * queries.Body.FeetDrop
	return if TossPath.Fits(root, queries) then root else nil
end

-- Whether a landing is valid for a throw from the Bear at `origin`, with the thrown player starting at `from`.
function TossPath.Valid(origin: Vector3, from: Vector3, to: Vector3, queries: Queries, margin: number): boolean
	return TossPath.InRange(origin, to, margin) and TossPath.Fits(to, queries) and TossPath.Clear(from, to, queries)
end

-- The nearest valid landing to the flat spot `point` (within LandingSearchRadius), or nil.
function TossPath.Find(origin: Vector3, from: Vector3, point: Vector3, queries: Queries): Vector3?
	local function try(spot: Vector3): Vector3?
		if not TossPath.InRange(origin, spot, 0) then
			return nil
		end
		local root = TossPath.LandingAt(spot, from, queries)
		return if root ~= nil and TossPath.Clear(from, root, queries) then root else nil
	end
	local found = try(point)
	if found ~= nil then
		return found
	end
	local radius = Tuning.LandingSearchStep
	while radius <= Tuning.LandingSearchRadius do
		local count = math.max(math.floor(2 * math.pi * radius / Tuning.LandingSearchStep), 6)
		for index = 0, count - 1 do
			local angle = index / count * 2 * math.pi
			found = try(point + Vector3.new(math.cos(angle), 0, math.sin(angle)) * radius)
			if found ~= nil then
				return found
			end
		end
		radius += Tuning.LandingSearchStep
	end
	return nil
end

return TossPath
