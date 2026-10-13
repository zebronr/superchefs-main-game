--!strict

-- Whether a character fits standing somewhere, with floor under it. The Ghost uses it to pop out of what it ended
-- Phase inside, the Bear to check where it throws a teammate.
local OpenFloor = {}

-- The box a character needs to stand somewhere: as wide as the root, from just above the feet (so the floor doesn't
-- count) to the top of the head. Lift is the box centre's height above the root; FeetDrop is the root's height above
-- the floor.
export type Body = { Size: Vector3, Lift: number, FeetDrop: number }

function OpenFloor.BodyOf(character: Model, root: BasePart): Body?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		return nil
	end
	-- R6 rigs report HipHeight 0: their legs (2 studs) hang below the torso instead.
	local legs = if humanoid.RigType == Enum.HumanoidRigType.R6 then 2 else humanoid.HipHeight
	local feet = root.Size.Y / 2 + legs
	local clearance = 0.4
	local top = root.Size.Y / 2 + 1.5
	local width = math.max(root.Size.X, root.Size.Z, 2)
	local height = top + feet - clearance
	return {
		Size = Vector3.new(width, height, width),
		Lift = (top - (feet - clearance)) / 2,
		FeetDrop = feet,
	}
end

-- Queries that see only what a part in `group` collides with, skipping `exclude`.
function OpenFloor.Params(group: string, exclude: { Instance }): (OverlapParams, RaycastParams)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	params.CollisionGroup = group
	params.RespectCanCollide = true
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = exclude
	rayParams.CollisionGroup = group
	rayParams.RespectCanCollide = true
	return params, rayParams
end

-- Whether the body fits with its root at `position` and has floor within `floorDrop` studs below its feet. With
-- `floorGroup`, that floor must be in this collision group (a counter top doesn't count).
function OpenFloor.Fits(
	position: Vector3,
	body: Body,
	params: OverlapParams,
	rayParams: RaycastParams,
	floorDrop: number,
	floorGroup: string?
): boolean
	local center = position + Vector3.new(0, body.Lift, 0)
	if #workspace:GetPartBoundsInBox(CFrame.new(center), body.Size, params) > 0 then
		return false
	end
	local hit = workspace:Raycast(position, Vector3.new(0, -(body.FeetDrop + floorDrop), 0), rayParams)
	return hit ~= nil and (floorGroup == nil or hit.Instance.CollisionGroup == floorGroup)
end

return OpenFloor
