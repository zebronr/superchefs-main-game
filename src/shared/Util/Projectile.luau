--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Interaction")).Throw
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
	local forward = Projectile.UnheldCFrame(part, start) * CFrame.new(0, 0, -Config.Distance)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	-- The legacy unfiltered ray can hit the projectile itself at the throw's endpoint.
	params.FilterDescendantsInstances = { part }
	local floor = workspace:Raycast(forward.Position, Vector3.new(0, -Config.FloorRayLength, 0), params)
	return if floor then floor.Position + Vector3.yAxis * Projectile.VerticalExtent(part) / 2 else forward.Position
end

function Projectile.Midpoint(start: Vector3, finish: Vector3): Vector3
	return start:Lerp(finish, 0.5) + Vector3.yAxis * Config.Height
end

function Projectile.Duration(start: Vector3, finish: Vector3): number
	local mid = Projectile.Midpoint(start, finish)
	return ((mid - start).Magnitude + (finish - mid).Magnitude) / Config.Speed
end

function Projectile.Bezier(start: Vector3, finish: Vector3, t: number): Vector3
	local mid = Projectile.Midpoint(start, finish)
	return start:Lerp(mid, t):Lerp(mid:Lerp(finish, t), t)
end

function Projectile.FallDuration(start: Vector3, finish: Vector3): number
	return (finish - start).Magnitude / Config.Gravity
end

function Projectile.At(start: CFrame, position: Vector3): CFrame
	return CFrame.new(position) * start.Rotation
end

return Projectile
