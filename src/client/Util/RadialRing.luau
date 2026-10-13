--!strict

-- A ring drawn as two clipped halves. In Studio: frames RingLeft and RingRight, each holding a Ring image
-- (twice the frame's width) with a UIGradient that hides one half of it. Fills clockwise from 12 o'clock.
export type Ring = { Left: ImageLabel, Right: ImageLabel, LeftGradient: UIGradient, RightGradient: UIGradient }

local RadialRing = {}

local function half(parent: Instance, name: string): (ImageLabel?, UIGradient?)
	local frame = parent:FindFirstChild(name)
	local image = if frame ~= nil then frame:FindFirstChild("Ring") else nil
	if image == nil or not image:IsA("ImageLabel") then
		return nil, nil
	end
	return image, image:FindFirstChildWhichIsA("UIGradient")
end

function RadialRing.Find(parent: Instance): Ring?
	local left, leftGradient = half(parent, "RingLeft")
	local right, rightGradient = half(parent, "RingRight")
	if left == nil or right == nil or leftGradient == nil or rightGradient == nil then
		return nil
	end
	return { Left = left, Right = right, LeftGradient = leftGradient, RightGradient = rightGradient }
end

-- Shows `fraction` (0 to 1) of the ring, optionally recoloring it.
function RadialRing.Set(ring: Ring, fraction: number, color: Color3?): ()
	local angle = math.clamp(fraction, 0, 1) * 360
	ring.RightGradient.Rotation = math.clamp(angle, 0, 180)
	ring.LeftGradient.Rotation = math.clamp(angle, 180, 360)
	if color ~= nil then
		ring.Left.ImageColor3 = color
		ring.Right.ImageColor3 = color
	end
end

return RadialRing
