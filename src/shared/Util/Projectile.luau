--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local ThrowConfig = Config.Interaction.Throw
local Tags = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Tags"))

local Projectile = {}

function Projectile.UnheldCFrame(part: BasePart, cframe: CFrame): CFrame
	local offset = Tags.GetVector3(part, "holdingOffset")
	return cframe * CFrame.Angles(-math.rad(offset.X), -math.rad(offset.Y), -math.rad(offset.Z))
end

function Projectile.VerticalExtent(part: BasePart): number
	local up = part.CFrame.UpVector
	local size = part.Size
	return math.abs(up.X * size.X) + math.abs(up.Y * size.Y) + math.abs(up.Z * size.Z)
end

function Projectile.Endpoint(part: BasePart, start: CFrame): Vector3
	local forward = Projectile.UnheldCFrame(part, start) * CFrame.new(0, 0, -ThrowConfig.Distance)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	-- The legacy unfiltered ray can hit the projectile itself at the throw's endpoint.
	params.FilterDescendantsInstances = { part }
	local floor = workspace:Raycast(forward.Position, Vector3.new(0, -ThrowConfig.FloorRayLength, 0), params)
	return if floor then floor.Position + Vector3.yAxis * Projectile.VerticalExtent(part) / 2 else forward.Position
end

function Projectile.Midpoint(start: Vector3, finish: Vector3): Vector3
	return start:Lerp(finish, 0.5) + Vector3.yAxis * ThrowConfig.Height
end

function Projectile.Duration(start: Vector3, finish: Vector3): number
	local mid = Projectile.Midpoint(start, finish)
	return ((mid - start).Magnitude + (finish - mid).Magnitude) / ThrowConfig.Speed
end

function Projectile.Bezier(start: Vector3, finish: Vector3, t: number): Vector3
	local mid = Projectile.Midpoint(start, finish)
	return start:Lerp(mid, t):Lerp(mid:Lerp(finish, t), t)
end

-- The Bezier point after `elapsed` seconds, and whether the arc is done.
function Projectile.FlightPosition(start: Vector3, finish: Vector3, elapsed: number): (Vector3, boolean)
	local duration = Projectile.Duration(start, finish)
	local t = if duration > 0 then math.clamp(elapsed / duration, 0, 1) else 1
	return Projectile.Bezier(start, finish, t), t >= 1
end

-- Sphere sweep shared by the server and the thrower's prediction, so both collide by the same rule.
function Projectile.Sweep(from: Vector3, to: Vector3, params: RaycastParams): RaycastResult?
	if from == to then
		return nil
	end
	return workspace:Spherecast(from, ThrowConfig.CastRadius, to - from, params)
end

-- The resting position of the part on whatever lies below `position`, or nil over the void.
function Projectile.SurfaceBelow(part: BasePart, position: Vector3, params: RaycastParams): Vector3?
	local hit = workspace:Raycast(position, Vector3.new(0, -ThrowConfig.FloorRayLength, 0), params)
	return if hit then hit.Position + Vector3.yAxis * Projectile.VerticalExtent(part) / 2 else nil
end

function Projectile.FallDuration(from: Vector3, to: Vector3): number
	return math.sqrt(2 * math.max(from.Y - to.Y, 0) / ThrowConfig.FallGravity)
end

-- Straight down under constant gravity, never below the landing point.
function Projectile.FallPosition(from: Vector3, to: Vector3, elapsed: number): Vector3
	local y = math.max(from.Y - 0.5 * ThrowConfig.FallGravity * elapsed * elapsed, to.Y)
	return Vector3.new(from.X, y, from.Z)
end

function Projectile.At(start: CFrame, position: Vector3): CFrame
	return CFrame.new(position) * start.Rotation
end

return Projectile
