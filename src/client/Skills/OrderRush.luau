--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CameraController = require(script.Parent.Parent.Controllers.CameraController)
local SpeedController = require(script.Parent.Parent.Controllers.SpeedController)
local InstantSkill = require(script.Parent.InstantSkill)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local RushConfig = Config.Skills.OrderRush
local visuals = RushConfig.Visuals
local Attribute = Config.Skills.Attribute
local SkillEffects = require(Shared:WaitForChild("Util"):WaitForChild("SkillEffects"))

-- Alien (working name): Order Rush, client side. A UFO drops in over the Alien and beams it up, flies
-- from customer to customer beaming a copy of the Alien down beside each one, then beams it back down
-- where it started and leaves. Every client draws every chain from the Alien's attributes; the local
-- player predicts its own chain on press, is rooted until it ends, and its camera follows the UFO.
local localPlayer = Players.LocalPlayer
local ufoTemplate: PVInstance? = nil
local beamTemplate: BasePart? = nil
local afterimageHighlight: Highlight? = nil
local sparkleTemplate: ParticleEmitter? = nil

type Chain = {
	Character: Model,
	StartedAt: number,
	Origin: Vector3,
	Stops: { SkillEffects.RushStop },
}

type ImagePart = {
	Part: BasePart,
	Size: Vector3,
	Offset: CFrame,
}

type ImageData = {
	Model: Model,
	Root: BasePart,
	Parts: { ImagePart },
	FootHeight: number,
	Indicator: BasePart?,
	Highlight: Highlight?,
}

type Visual = {
	Chain: Chain,
	Ufo: PVInstance?,
	UfoSize: Vector3?,
	-- Where the UFO is, flat at the Alien's height (the local player's camera follows it).
	Focus: Vector3?,
	Beam: BasePart?,
	BeamTransparency: number,
	-- The copy of the Alien that rides the beam.
	Image: Model?,
	ImageRoot: BasePart?,
	ImageParts: { ImagePart },
	ImageFootHeight: number,
	ImageIndicator: BasePart?,
	ImageIndicatorRotation: CFrame?,
	ImageHighlight: Highlight?,
	ImageFillTransparency: number,
	ImageOutlineTransparency: number,
	ImageAtRest: boolean,
	ImageRestIndex: number?,
	ImageRestFrame: CFrame?,
	ImageFade: number,
	ImageGlow: number,
	-- Ground height under each anchor (0 = the origin), found once.
	Grounds: { [number]: number },
	-- Beam landings already sparkled (0 = origin at the start, n + 1 = origin at the return).
	Landed: { [number]: boolean },
	-- Server time the chain ended; the UFO leaves after it.
	ExitStartedAt: number?,
}

local predicted: Chain? = nil
local predictedExpiresAt = 0
local visualsByCharacter: { [Model]: Visual } = {}

local function expoOut(t: number): number
	return if t >= 1 then 1 else 1 - 2 ^ (-10 * t)
end

-- Smoothstep position for the straight vertical entrance.
local function flightEase(t: number): number
	local clamped = math.clamp(t, 0, 1)
	return clamped * clamped * (3 - 2 * clamped)
end

local function beamShoot(elapsed: number): number
	return expoOut(math.clamp(elapsed / visuals.BeamTime, 0, 1))
end

local function beamRetract(elapsed: number): number
	return 1 - expoOut(math.clamp(elapsed / visuals.BeamTime, 0, 1))
end

local function chainFromAttributes(character: Model): Chain?
	local startedAt = character:GetAttribute(Attribute.RushStartedAt)
	local origin = character:GetAttribute(Attribute.RushOrigin)
	local stops = SkillEffects.DecodeStops(character:GetAttribute(Attribute.RushStops))
	if typeof(startedAt) ~= "number" or typeof(origin) ~= "Vector3" or #stops == 0 then
		return nil
	end
	return { Character = character, StartedAt = startedAt, Origin = origin, Stops = stops }
end

-- The same stops the server will pick: least patient first, each beside its customer.
local function planChain(character: Model): Chain?
	local root = InstantSkill.Root(character)
	if root == nil then
		return nil
	end
	local stops: { SkillEffects.RushStop } = {}
	local previous = root.Position
	for _, customer in SkillEffects.RushTargets() do
		local stop = SkillEffects.StopPosition(customer, previous)
		if stop ~= nil then
			table.insert(stops, stop)
			previous = stop.Position
		end
	end
	if #stops == 0 then
		return nil
	end
	return { Character = character, StartedAt = workspace:GetServerTimeNow(), Origin = root.Position, Stops = stops }
end

-- Anchor 0 is the origin, 1..n the stops. The origin is where the hidden, rooted Alien actually is, not
-- the saved RushOrigin: pressed while moving, the server's copy lags behind and the Alien would pop forward.
local function anchor(chain: Chain, index: number): Vector3
	if index == 0 or index > #chain.Stops then
		local root = InstantSkill.Root(chain.Character)
		return if root ~= nil then root.Position else chain.Origin
	end
	return chain.Stops[index].Position
end

-- Where the Alien copy stands at an anchor: at the Alien's own height (customers' roots sit lower).
local function standAt(chain: Chain, index: number): CFrame
	local point = anchor(chain, index)
	if index == 0 or index > #chain.Stops then
		local root = InstantSkill.Root(chain.Character)
		return if root ~= nil then root.CFrame else CFrame.new(point)
	end
	local position = Vector3.new(point.X, chain.Origin.Y, point.Z)
	return CFrame.new(position) * CFrame.Angles(0, chain.Stops[index].Yaw, 0)
end

local function above(chain: Chain, index: number): Vector3
	local point = anchor(chain, index)
	return Vector3.new(point.X, chain.Origin.Y + visuals.UfoHeight, point.Z)
end

local function swoopAt(from: Vector3, to: Vector3, index: number, within: number, fly: number, settle: number): Vector3
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local side = if index % 2 == 1 then 1 else -1
	local perpendicular = if flat.Magnitude > 0 then Vector3.yAxis:Cross(flat.Unit) else Vector3.zero
	local control = (from + to) / 2 + perpendicular * (flat.Magnitude * visuals.UfoCurve * side)
	local arrival = (to - control) * 2
	local distance = arrival.Magnitude
	local active = visuals.UfoOvershoot > 0 and visuals.UfoSettleWobbles > 0 and settle > 0 and distance > 0
	local frequency = if active then math.pi * visuals.UfoSettleWobbles / settle else 0
	local speed = if active then math.min(visuals.UfoOvershoot * frequency, distance * 2 / fly) else 0
	if within < fly then
		local t = math.clamp(within / fly, 0, 1)
		-- Cubic progress ends with the same velocity that starts the settle sine.
		local slope = if distance > 0 then speed * fly / distance else 0
		local progress = t * t * (3 - 2 * t) + slope * t * t * (t - 1)
		local inverse = 1 - progress
		return from * (inverse * inverse) + control * (2 * inverse * progress) + to * (progress * progress)
	end
	if active and within < fly + settle then
		local x = within - fly
		local envelope = (1 - x / settle) ^ 2
		return to + arrival.Unit * (speed / frequency * envelope * math.sin(frequency * x))
	end
	return to
end

-- One timeline for prediction, server attributes, camera focus and finite-difference velocity.
local function ufoPathAt(chain: Chain, elapsed: number): Vector3
	local count = #chain.Stops
	local step = RushConfig.StepTime
	local fly = step * visuals.UfoFlyShare
	local returnAt = SkillEffects.RushStopTime(count) + step
	if elapsed < RushConfig.VanishTime then
		local dropTime = RushConfig.VanishTime * visuals.VanishDropShare
		local drop = flightEase(elapsed / dropTime)
		return above(chain, 0) + Vector3.new(0, visuals.UfoEnterHeight * (1 - drop), 0)
	elseif elapsed < returnAt then
		local index = math.clamp(math.floor((elapsed - RushConfig.VanishTime) / step) + 1, 1, count)
		local within = elapsed - SkillEffects.RushStopTime(index)
		return swoopAt(above(chain, index - 1), above(chain, index), index, within, fly, math.min(visuals.UfoSettleTime, step - fly))
	end
	local within = elapsed - returnAt
	local flyBack = RushConfig.ReturnTime * visuals.ReturnFlyShare
	return swoopAt(above(chain, count), above(chain, 0), count + 1, within, flyBack, math.min(visuals.UfoSettleTime, RushConfig.ReturnTime - flyBack))
end

local function groundAt(visual: Visual, index: number): number
	local key = if index > #visual.Chain.Stops then 0 else index
	local cached = visual.Grounds[key]
	if cached ~= nil then
		return cached
	end
	local chain = visual.Chain
	local point = anchor(chain, key)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = { workspace.CurrentCamera :: Instance }
	for _, player in Players:GetPlayers() do
		if player.Character ~= nil then
			table.insert(exclude, player.Character)
		end
	end
	params.FilterDescendantsInstances = exclude
	local from = Vector3.new(point.X, chain.Origin.Y, point.Z)
	local hit = workspace:Raycast(from, Vector3.new(0, -20, 0), params)
	local ground = if hit ~= nil then hit.Position.Y else chain.Origin.Y - 3
	visual.Grounds[key] = ground
	return ground
end

-- A see-through, anchored copy of the character for this client only. Capture its part layout once.
local function makeImage(character: Model): ImageData?
	local archivable = character.Archivable
	character.Archivable = true
	local clone = character:Clone()
	character.Archivable = archivable
	local root = clone:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		clone:Destroy()
		return nil
	end
	local parts: { ImagePart } = {}
	local indicator: BasePart? = nil
	local lowest = math.huge
	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("Script") or descendant:IsA("LocalScript") or descendant:IsA("ModuleScript") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CollisionGroup = visuals.CollisionGroup
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.LocalTransparencyModifier = 0
			if descendant.Name == "PlayerIndicator" then
				indicator = descendant
			elseif descendant ~= root then
				descendant.Transparency = math.max(descendant.Transparency, visuals.AfterimageTransparency)
				local offset = root.CFrame:ToObjectSpace(descendant.CFrame)
				local size = descendant.Size
				-- The rotated box's lowest Y gives the root's height above the copy's feet.
				local halfHeight = (math.abs(offset.XVector.Y) * size.X + math.abs(offset.YVector.Y) * size.Y + math.abs(offset.ZVector.Y) * size.Z) / 2
				lowest = math.min(lowest, offset.Position.Y - halfHeight)
				table.insert(parts, { Part = descendant, Size = size, Offset = offset })
			end
		elseif descendant:IsA("Decal") then
			descendant.LocalTransparencyModifier = 0
		elseif descendant:IsA("Highlight") then
			-- The afterimage highlight below replaces the player's outline.
			descendant:Destroy()
		elseif descendant:IsA("SurfaceGui") then
			-- The real character's "you" ring is off while hidden; the copy carries it instead.
			descendant.Enabled = true
		end
	end
	local humanoid = clone:FindFirstChildOfClass("Humanoid")
	if humanoid ~= nil then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	end
	local imageHighlight: Highlight? = nil
	if afterimageHighlight ~= nil then
		local highlight = afterimageHighlight:Clone()
		highlight.Adornee = clone
		highlight.Parent = clone
		imageHighlight = highlight
	end
	clone.Name = `{character.Name}Afterimage`
	clone.Parent = workspace.CurrentCamera
	return { Model = clone, Root = root, Parts = parts, FootHeight = if lowest < math.huge then math.max(-lowest, 0) else 0, Indicator = indicator, Highlight = imageHighlight }
end

local function setImageFade(visual: Visual, fade: number, glow: number): ()
	local image = visual.Image
	if image == nil then
		return
	end
	local fadeChanged = math.abs(visual.ImageFade - fade) >= 0.01
	local glowChanged = math.abs(visual.ImageGlow - glow) >= 0.01
	if not fadeChanged and not glowChanged then
		return
	end
	if fadeChanged then
		visual.ImageFade = fade
		for _, descendant in image:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.LocalTransparencyModifier = fade
			elseif descendant:IsA("Decal") then
				descendant.LocalTransparencyModifier = fade
			elseif descendant:IsA("SurfaceGui") then
				-- The "you" ring ignores LocalTransparencyModifier, so it goes with the copy.
				descendant.Enabled = fade < 0.5
			end
		end
	end
	if glowChanged then
		visual.ImageGlow = glow
	end
	local highlight = visual.ImageHighlight
	if highlight ~= nil then
		highlight.FillTransparency = 1 - (1 - visual.ImageFillTransparency) * glow * (1 - fade)
		highlight.OutlineTransparency = 1 - (1 - visual.ImageOutlineTransparency) * glow * (1 - fade)
	end
end

-- Stable stepped noise: server time, part index and chain start completely determine each glitch.
local function glitchHash(tick: number, index: number, startedAt: number, channel: number): number
	local start = math.floor(startedAt * 1000) % 65521
	local seed = tick % 104729 * 12.9898 + index * 78.233 + start * 37.719 + channel * 19.19
	local value = math.sin(seed) * 43758.5453
	return (value - math.floor(value)) * 2 - 1
end

local function axisScale(axis: Vector3, width: number, height: number): number
	local flat = math.abs(axis.X) + math.abs(axis.Z)
	local upright = math.abs(axis.Y)
	return (flat * width + upright * height) / (flat + upright)
end

local function partScale(rotation: CFrame, width: number, height: number): Vector3
	local x, y, z = rotation.XVector, rotation.YVector, rotation.ZVector
	return Vector3.new(
		axisScale(x, width, height),
		axisScale(y, width, height),
		axisScale(z, width, height)
	)
end

-- Places the Alien copy `rise` of the way from its spot at an anchor up into the UFO (0 = standing,
-- 1 = inside). Parts stretch and glitch independently; nil hides the copy.
local function drawImage(visual: Visual, index: number, rise: number?, glow: number, ufoPosition: Vector3, now: number, landElapsed: number?): ()
	local image = visual.Image
	local root = visual.ImageRoot
	if image == nil or root == nil then
		return
	end
	if rise == nil then
		setImageFade(visual, 1, glow)
		return
	end
	local landing = landElapsed ~= nil and visuals.ImageLandTime > 0 and landElapsed >= 0 and landElapsed < visuals.ImageLandTime
	local atRest = rise == 0 and not landing
	local stand = standAt(visual.Chain, index)
	local indicator = visual.ImageIndicator
	if indicator ~= nil then
		indicator.CFrame = CFrame.new(stand.Position.X, groundAt(visual, index) + indicator.Size.Y / 2 + Config.UI.IndicatorFloorLift, stand.Position.Z) * (visual.ImageIndicatorRotation :: CFrame)
	end
	if atRest and visual.ImageAtRest and visual.ImageRestIndex == index and visual.ImageRestFrame == stand then
		setImageFade(visual, 0, glow)
		return
	end
	local top = ufoPosition - Vector3.new(0, visuals.BeamTopOffset, 0)
	local shrink = 1 + (visuals.ImageShrink - 1) * rise
	local stretch = visuals.ImageStretch * math.sin(math.pi * rise)
	local height = shrink * (1 + stretch)
	local width = shrink / math.sqrt(1 + stretch)
	local glitch = if rise > 0 and rise < 1 then math.sin(math.pi * rise) else 0
	if landing then
		local t = (landElapsed :: number) / visuals.ImageLandTime
		local squash = math.max(1 - visuals.ImageLandSquash * (1 - t) ^ 2 * math.cos(2 * math.pi * t), 0.05)
		height *= squash
		width /= math.sqrt(squash)
		glitch += (1 - t) ^ 2
	end
	-- Move the root with the squash so the lowest part stays on the ground when standing.
	local target = (stand.Rotation + stand.Position:Lerp(top, rise)) * CFrame.new(0, -visual.ImageFootHeight * (1 - height), 0)
	root.CFrame = target
	local bodyScale = Vector3.new(width, height, width)
	local tick = if visuals.ImageGlitchRate > 0 then math.floor(now * visuals.ImageGlitchRate) else 0
	for partIndex, entry in visual.ImageParts do
		local offset = entry.Offset
		if atRest then
			-- Restore the captured values exactly once after the landing or beam motion.
			entry.Part.CFrame = target * offset
			entry.Part.Size = entry.Size
			continue
		end
		local jitter = CFrame.identity
		if glitch > 0 and visuals.ImageGlitchRate > 0 and (visuals.ImageGlitch > 0 or visuals.ImageGlitchTilt > 0) then
			local move = visuals.ImageGlitch * glitch
			local tilt = math.rad(visuals.ImageGlitchTilt) * glitch
			jitter = CFrame.new(
				move * glitchHash(tick, partIndex, visual.Chain.StartedAt, 1),
				move * glitchHash(tick, partIndex, visual.Chain.StartedAt, 2),
				move * glitchHash(tick, partIndex, visual.Chain.StartedAt, 3)
			) * CFrame.Angles(
				tilt * glitchHash(tick, partIndex, visual.Chain.StartedAt, 4),
				tilt * glitchHash(tick, partIndex, visual.Chain.StartedAt, 5),
				tilt * glitchHash(tick, partIndex, visual.Chain.StartedAt, 6)
			)
		end
		entry.Part.CFrame = target * CFrame.new(offset.Position * bodyScale) * offset.Rotation * jitter
		entry.Part.Size = entry.Size * partScale(offset.Rotation, width, height)
	end
	visual.ImageAtRest = atRest
	visual.ImageRestIndex = if visual.ImageAtRest then index else nil
	visual.ImageRestFrame = if visual.ImageAtRest then stand else nil
	setImageFade(visual, math.clamp((rise - 0.8) / 0.2, 0, 1), glow)
end

-- Stretches the beam `reach` of the way from under the UFO down to the ground (0 hides it).
local function drawBeam(visual: Visual, ufoPosition: Vector3, ground: number, reach: number, now: number, landElapsed: number?): ()
	local beam = visual.Beam
	if beam == nil then
		return
	end
	local pulse = visuals.BeamPulse * math.sin(now * visuals.BeamPulseSpeed)
	local targetTransparency = math.clamp(visual.BeamTransparency + pulse, 0, 1)
	beam.Transparency = 1 + (targetTransparency - 1) * reach
	local top = ufoPosition - Vector3.new(0, visuals.BeamTopOffset, 0)
	local length = math.max(top.Y - ground, 0) * math.clamp(reach, 0, 1)
	if length < 0.05 then
		return
	end
	local width = visuals.BeamWidth * (1 + visuals.BeamBreathe * math.sin(now * visuals.BeamBreatheSpeed))
	if landElapsed ~= nil and landElapsed >= 0 and landElapsed < visuals.BeamLandTime then
		local t = landElapsed / visuals.BeamLandTime
		width *= 1 + visuals.BeamLandSquash * (1 - t) ^ 2 * math.cos(t * math.pi * 3)
	end
	beam.Size = Vector3.new(width, length, width)
	beam.CFrame = CFrame.new(top - Vector3.new(0, length / 2, 0)) * CFrame.Angles(0, -now * visuals.BeamSpinSpeed, 0)
end

-- The UFO's own parts (the template is a Model or a single part).
local function ufoParts(ufo: Instance): { BasePart }
	local parts: { BasePart } = {}
	if ufo:IsA("BasePart") then
		table.insert(parts, ufo)
	end
	for _, descendant in ufo:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end
	return parts
end

local function drawUfo(visual: Visual, position: Vector3, velocity: Vector3, now: number, landElapsed: number?): Vector3
	visual.Focus = Vector3.new(position.X, visual.Chain.Origin.Y, position.Z)
	local drift = Vector3.new(
		visuals.UfoDrift * math.sin(now * visuals.UfoDriftSpeed),
		0,
		visuals.UfoDrift * math.sin(2 * now * visuals.UfoDriftSpeed) / 2
	)
	local drawn = position + Vector3.new(0, visuals.UfoBob * math.sin(now * visuals.UfoBobSpeed), 0) + drift
	local ufo = visual.Ufo
	if ufo == nil then
		return drawn
	end
	local flat = Vector3.new(velocity.X, 0, velocity.Z)
	local speedFraction = if visuals.UfoLeanSpeed > 0 then math.clamp(velocity.Magnitude / visuals.UfoLeanSpeed, 0, 1) else 0
	local lean = if visuals.UfoLeanSpeed > 0 then flat / visuals.UfoLeanSpeed else Vector3.zero
	local tilt = CFrame.identity
	if lean.Magnitude > 0.001 then
		local axis = Vector3.yAxis:Cross(lean.Unit)
		if axis.Magnitude > 0.001 then
			tilt = CFrame.fromAxisAngle(axis.Unit, math.rad(visuals.UfoTilt) * math.min(lean.Magnitude, 1))
		end
	end
	local size = visual.UfoSize
	if size ~= nil and ufo:IsA("BasePart") then
		local speedY = math.max(1 - visuals.UfoSpeedSquash * speedFraction, 0.05)
		local landY = 1
		if landElapsed ~= nil and visuals.UfoSettleTime > 0 and landElapsed >= 0 and landElapsed < visuals.UfoSettleTime then
			local t = landElapsed / visuals.UfoSettleTime
			landY = 1 - visuals.UfoLandSquash * (1 - t) ^ 2 * math.cos(2 * math.pi * t)
		end
		landY = math.max(landY, 0.05)
		local width = (1 + visuals.UfoSpeedSquash * speedFraction / 2) / math.sqrt(landY)
		ufo.Size = Vector3.new(size.X * width, size.Y * speedY * landY, size.Z * width)
	end
	ufo:PivotTo(CFrame.new(drawn) * tilt * CFrame.Angles(0, now * visuals.UfoSpinSpeed, 0))
	return drawn
end

local function land(visual: Visual, key: number, index: number): ()
	if visual.Landed[key] then
		return
	end
	visual.Landed[key] = true
	InstantSkill.Burst(sparkleTemplate, standAt(visual.Chain, index), visuals.SparkleCount)
end

-- Draws a running chain at `now` (server time). Pure in the chain's data, so the prediction and the
-- server's version draw the same thing and the handoff is seamless.
local function drawChain(visual: Visual, now: number): ()
	local chain = visual.Chain
	local elapsed = now - chain.StartedAt
	local count = #chain.Stops
	local step = RushConfig.StepTime
	local fly = step * visuals.UfoFlyShare
	local downTime = step * visuals.BeamDownShare
	local up = step * visuals.BeamUpShare
	local returnAt = SkillEffects.RushStopTime(count) + step
	local position = ufoPathAt(chain, elapsed)
	local velocity = (position - ufoPathAt(chain, elapsed - 1 / 60)) * 60

	if elapsed < RushConfig.VanishTime then
		-- Drop in over the Alien, beam on, the Alien rises into the UFO.
		local dropTime = RushConfig.VanishTime * visuals.VanishDropShare
		local riseTime = RushConfig.VanishTime * visuals.VanishRiseShare
		local drawn = drawUfo(visual, position, velocity, now, if elapsed >= dropTime then elapsed - dropTime else nil)
		local reach = beamShoot(elapsed - dropTime)
		drawBeam(visual, drawn, groundAt(visual, 0), reach, now, elapsed - dropTime - visuals.BeamTime)
		if elapsed >= dropTime then
			land(visual, 0, 0)
		end
		-- The real Alien stays until the beam reaches the ground (or the rise starts), then the copy takes its place.
		local beamed = elapsed >= math.min(dropTime + visuals.BeamTime, RushConfig.VanishTime - riseTime)
		InstantSkill.SetHidden(chain.Character, beamed)
		local rise = if beamed then math.clamp((elapsed - (RushConfig.VanishTime - riseTime)) / riseTime, 0, 1) else nil
		drawImage(visual, 0, rise, reach, drawn, now, nil)
		return
	end
	InstantSkill.SetHidden(chain.Character, true)
	if elapsed < returnAt then
		-- Customer `index`: fly over, beam the copy down beside them, let it stand, beam it back up.
		local index = math.clamp(math.floor((elapsed - RushConfig.VanishTime) / step) + 1, 1, count)
		local within = elapsed - SkillEffects.RushStopTime(index)
		if within < fly then
			local drawn = drawUfo(visual, position, velocity, now, nil)
			drawBeam(visual, drawn, groundAt(visual, index - 1), beamRetract(within), now)
			drawImage(visual, index, nil, 0, drawn, now, nil)
		else
			local drawn = drawUfo(visual, position, velocity, now, within - fly)
			local beamElapsed = within - fly
			local reach = beamShoot(beamElapsed)
			drawBeam(visual, drawn, groundAt(visual, index), reach, now, beamElapsed - visuals.BeamTime)
			if beamElapsed >= downTime then
				land(visual, index, index)
			end
			local down = 1 - expoOut(beamElapsed / downTime)
			local rise = math.clamp((within - (step - up)) / up, 0, 1)
			drawImage(visual, index, math.max(down, rise), reach, drawn, now, beamElapsed - downTime)
		end
	else
		-- Back over the start and beam the Alien down; the copy stands there until the real Alien returns.
		local within = elapsed - returnAt
		local flyBack = RushConfig.ReturnTime * visuals.ReturnFlyShare
		local downBack = RushConfig.ReturnTime * visuals.ReturnDownShare
		if within < flyBack then
			local drawn = drawUfo(visual, position, velocity, now, nil)
			drawBeam(visual, drawn, groundAt(visual, count), beamRetract(within), now)
			drawImage(visual, 0, nil, 0, drawn, now, nil)
		else
			local drawn = drawUfo(visual, position, velocity, now, within - flyBack)
			local beamElapsed = within - flyBack
			local reach = beamShoot(beamElapsed)
			drawBeam(visual, drawn, groundAt(visual, 0), reach, now, beamElapsed - visuals.BeamTime)
			if beamElapsed >= downBack then
				land(visual, count + 1, 0)
			end
			drawImage(visual, 0, 1 - expoOut(beamElapsed / downBack), reach, drawn, now, beamElapsed - downBack)
		end
	end
end

local function destroyVisual(character: Model): ()
	local visual = visualsByCharacter[character]
	if visual == nil then
		return
	end
	visualsByCharacter[character] = nil
	for _, instance in { visual.Ufo :: Instance?, visual.Beam :: Instance?, visual.Image :: Instance? } do
		if instance ~= nil then
			instance:Destroy()
		end
	end
	if character.Parent ~= nil then
		InstantSkill.SetHidden(character, false)
	end
end

-- After the chain: the Alien is back, the beam pulls up and the UFO zips away.
local function drawExit(visual: Visual, now: number): ()
	local startedAt = visual.ExitStartedAt :: number
	local character = visual.Chain.Character
	local x = now - startedAt
	if x >= visuals.UfoExitTime or character.Parent == nil then
		destroyVisual(character)
		return
	end
	local t = x / visuals.UfoExitTime
	local chain = visual.Chain
	local position = ufoPathAt(chain, SkillEffects.RushDuration(#chain.Stops)) + Vector3.new(0, visuals.UfoEnterHeight * t ^ 4, 0)
	local drawn = drawUfo(visual, position, Vector3.zero, now, nil)
	local reach = beamRetract(x)
	drawBeam(visual, drawn, groundAt(visual, 0), reach, now)
	drawImage(visual, 0, nil, reach, drawn, now, nil)
	local ufo = visual.Ufo
	if ufo ~= nil and t > 0.5 then
		for _, part in ufoParts(ufo) do
			part.LocalTransparencyModifier = (t - 0.5) / 0.5
		end
	end
end

local function newVisual(chain: Chain): Visual
	local image = makeImage(chain.Character)
	local ufo: PVInstance? = nil
	if ufoTemplate ~= nil then
		local created = ufoTemplate:Clone()
		for _, part in ufoParts(created) do
			part.Anchored = true
			part.CollisionGroup = visuals.CollisionGroup
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
		end
		created.Parent = workspace.CurrentCamera
		ufo = created
	end
	local visual: Visual = {
		Chain = chain,
		Ufo = ufo,
		UfoSize = if ufo ~= nil and ufo:IsA("BasePart") then ufo.Size else nil,
		Focus = nil,
		Beam = nil,
		BeamTransparency = 0,
		Image = if image ~= nil then image.Model else nil,
		ImageRoot = if image ~= nil then image.Root else nil,
		ImageParts = if image ~= nil then image.Parts else {},
		ImageFootHeight = if image ~= nil then image.FootHeight else 0,
		ImageIndicator = if image ~= nil then image.Indicator else nil,
		ImageIndicatorRotation = if image ~= nil and image.Indicator ~= nil then image.Indicator.CFrame.Rotation else nil,
		ImageHighlight = if image ~= nil then image.Highlight else nil,
		ImageFillTransparency = if image ~= nil and image.Highlight ~= nil then image.Highlight.FillTransparency else 1,
		ImageOutlineTransparency = if image ~= nil and image.Highlight ~= nil then image.Highlight.OutlineTransparency else 1,
		ImageAtRest = false,
		ImageRestIndex = nil,
		ImageRestFrame = nil,
		ImageFade = -1,
		ImageGlow = -1,
		Grounds = {},
		Landed = {},
		ExitStartedAt = nil,
	}
	if beamTemplate ~= nil then
		local beam = beamTemplate:Clone()
		beam.Anchored = true
		beam.CollisionGroup = visuals.CollisionGroup
		beam.CanCollide = false
		beam.CanQuery = false
		beam.CanTouch = false
		beam.CastShadow = false
		visual.BeamTransparency = beamTemplate.Transparency
		beam.Transparency = 1
		beam.Parent = workspace.CurrentCamera
		visual.Beam = beam
	end
	visualsByCharacter[chain.Character] = visual
	return visual
end

local function step(): ()
	local now = workspace:GetServerTimeNow()
	local chains: { [Model]: Chain } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local chain = if character ~= nil then chainFromAttributes(character) else nil
		if character ~= nil and chain ~= nil then
			chains[character] = chain
		end
	end

	local guess = predicted
	if guess ~= nil then
		local server = chains[guess.Character]
		local ended = now - guess.StartedAt >= SkillEffects.RushDuration(#guess.Stops)
		if server ~= nil then
			-- The server's chain replaces the guess (its stops win if they differ).
			predicted = nil
		elseif ended and os.clock() >= predictedExpiresAt or guess.Character.Parent == nil then
			predicted = nil
		elseif not ended then
			chains[guess.Character] = guess
		end
	end

	-- The local player is rooted for its own chain, on local time.
	local own = localPlayer.Character
	local ownChain = if own ~= nil then chains[own] else nil
	SpeedController.SetRooted(
		"OrderRush",
		ownChain ~= nil and now - ownChain.StartedAt < SkillEffects.RushDuration(#ownChain.Stops)
	)

	for character, chain in chains do
		if now - chain.StartedAt < SkillEffects.RushDuration(#chain.Stops) and character.Parent ~= nil then
			local visual = visualsByCharacter[character]
			if visual == nil or visual.ExitStartedAt ~= nil then
				-- A new chain (or one starting while the last UFO is still leaving).
				destroyVisual(character)
				visual = newVisual(chain)
			end
			local current = visual :: Visual
			current.Chain = chain
			drawChain(current, now)
		else
			chains[character] = nil
		end
	end
	-- The camera follows the local player's own UFO while its chain runs.
	local ownVisual = if own ~= nil then visualsByCharacter[own] else nil
	CameraController.SetFocus(
		if ownVisual ~= nil and ownVisual.ExitStartedAt == nil and chains[own :: Model] ~= nil then ownVisual.Focus else nil
	)

	for character, visual in table.clone(visualsByCharacter) do
		if chains[character] == nil then
			if visual.ExitStartedAt == nil then
				visual.ExitStartedAt = now
				if character.Parent ~= nil then
					InstantSkill.SetHidden(character, false)
				end
			end
			drawExit(visual, now)
		end
	end
end

local OrderRush: InstantSkill.InstantSkill = {
	RequiresEmptyHands = true,
	Setup = function(): ()
		local folder = InstantSkill.Folder("OrderRush")
		ufoTemplate = InstantSkill.Template(folder, "Ufo", "PVInstance") :: PVInstance?
		beamTemplate = InstantSkill.Template(folder, "TractorBeam", "BasePart") :: BasePart?
		afterimageHighlight = InstantSkill.Template(folder, "AfterimageHighlight", "Highlight") :: Highlight?
		sparkleTemplate = InstantSkill.Template(folder, "Sparkle", "ParticleEmitter") :: ParticleEmitter?
		RunService.Heartbeat:Connect(step)
	end,
	CanUse = function(_character: Model): boolean
		return #SkillEffects.RushTargets() > 0
	end,
	Predict = function(character: Model): ()
		local chain = planChain(character)
		if chain == nil then
			return
		end
		predicted = chain
		predictedExpiresAt = os.clock() + SkillEffects.RushDuration(#chain.Stops) + RushConfig.PredictionTimeout
		SpeedController.SetRooted("OrderRush", true)
	end,
	Rollback = function(): ()
		local guess = predicted
		predicted = nil
		SpeedController.SetRooted("OrderRush", false)
		if guess ~= nil then
			destroyVisual(guess.Character)
		end
	end,
	IsBusy = function(): boolean
		local character = localPlayer.Character
		return predicted ~= nil or (character ~= nil and character:GetAttribute(Attribute.RushStartedAt) ~= nil)
	end,
}

return OrderRush
