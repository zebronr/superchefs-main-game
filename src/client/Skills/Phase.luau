--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local InstantSkill = require(script.Parent.InstantSkill)
local Particles = require(script.Parent.Parent.Util.Particles)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local PhaseConfig = Config.Skills.Phase
local visuals = PhaseConfig.Visuals
local SkillEffects = require(Shared:WaitForChild("Util"):WaitForChild("SkillEffects"))
local OpenFloor = require(Shared:WaitForChild("Util"):WaitForChild("OpenFloor"))
local CharacterConfig = Config.Character

-- Ghost: Phase, client side. The local player phases on press: its parts go in the GhostPhase group on this client
-- at once (it simulates its own character), and when Phase ends it pops out of whatever it's inside before its
-- parts become solid again. Every client draws Phase for every phasing character from PhaseUntil:
--   start: the body shrinks in and bursts out with a puff and a ring of puffs on the floor;
--   during: see-through with a ghostly glow (a faint fill, a haze and a pale light; the fill draws through walls
--   while inside one), floating with a bob and a lean into its movement, trailing wisps and, when fast, echoes of
--   its body; the body squashes going into a wall and
--   stretches coming out, with a ring of puffs on the wall face;
--   ending: it flickers toward solid, faster and faster;
--   end: a lift and a pop, and a stretch with a puff when it's spat out of a wall.
-- Templates live in Assets.Skills.Phase.

type Joint = { Joint: Motor6D, Original: CFrame }

-- The character's player-color Highlight while Phase borrows it, with what to put back.
type Tint = { Highlight: Highlight, FillColor: Color3, FillTransparency: number, DepthMode: Enum.HighlightDepthMode }

-- What the body is doing: shrinking in and bursting out at the start (the same on every axis), squashing into a
-- wall, or stretching out of one.
type WarpKind = "Start" | "In" | "Out"

-- The body warping. It scales every body part (and the joint offsets between them, so the limbs stay attached) on
-- this client only, and puts them back when it settles.
type Warp = {
	Kind: WarpKind,
	-- os.clock() the warp (re)started.
	StartedAt: number,
	-- Flat world direction it squashes or stretches along (unused for Start).
	Heading: Vector3,
	Sizes: { [BasePart]: Vector3 },
	Meshes: { [SpecialMesh]: Vector3 },
	Joints: { [JointInstance]: { C0: CFrame, C1: CFrame } },
}

type Visual = {
	-- Server time Phase started (the bob's timeline).
	StartedAt: number,
	-- 0 solid .. 1 fully phased: the see-through, glow, float and lean all blend with it.
	Fade: number,
	Phasing: boolean,
	-- os.clock() the end pop started.
	PoppedAt: number?,
	-- Whether a jump out of a wall was already drawn for this end.
	Spat: boolean,
	-- The root joint, which the float, lean and pop move.
	Root: Joint?,
	-- The lean (radians about the root's X and Z) and how fast it's changing, a spring toward the movement.
	Lean: Vector2,
	LeanSpeed: Vector2,
	-- os.clock() the start burst goes off (nil once it has, or for a late joiner).
	BurstAt: number?,
	-- os.clock() the next echo may peel off.
	NextEchoAt: number,
	-- Root position last frame (to spot being spat out of a wall).
	LastPosition: Vector3?,
	Wisps: ParticleEmitter?,
	-- The haze around the body and the light it casts.
	Aura: ParticleEmitter?,
	Glow: PointLight?,
	Tint: Tint?,
	-- Parts given a LocalTransparencyModifier (the character's and a carried item's), to clear at the end.
	Faded: { [Instance]: boolean },
	-- Walls (world parts) the Ghost is inside right now: overlapping any after none warps it going in, overlapping
	-- none after some warps it coming out.
	Inside: { [BasePart]: boolean },
	Warp: Warp?,
}

-- A tinted copy of one body part, left behind where it was.
type EchoPart = { Part: BasePart, Size: Vector3, CFrame: CFrame, Decals: { Decal } }

type Echo = { Parts: { EchoPart }, StartedAt: number }

local localPlayer = Players.LocalPlayer
local wispsTemplate: ParticleEmitter? = nil
local auraTemplate: ParticleEmitter? = nil
local glowTemplate: PointLight? = nil
local puffTemplate: ParticleEmitter? = nil
local popTemplate: ParticleEmitter? = nil

-- Local prediction: os.clock() when the local Phase ends.
local predictedUntil: number? = nil
-- Where the local Phase started: the fallback spot when no open floor is near the end.
local startPivot: CFrame? = nil
-- Whether the local character's parts are in the GhostPhase group on this client.
local localPhasing = false
local active: { [Model]: Visual } = {}
local echoes: { Echo } = {}

local function isPhasing(character: Model, now: number): boolean
	if character == localPlayer.Character and predictedUntil ~= nil then
		return true
	end
	return SkillEffects.PhaseActive(character, now)
end

-- Server time the character's Phase started, from PhaseUntil (nil when the server hasn't said).
local function startedAtOf(character: Model): number?
	local phaseUntil = character:GetAttribute(Config.Skills.Attribute.PhaseUntil)
	return if typeof(phaseUntil) == "number" then phaseUntil - PhaseConfig.Duration else nil
end

-- Seconds of Phase left: the local prediction's own clock for the local player, otherwise PhaseUntil.
local function remainingOf(character: Model, now: number): number
	if character == localPlayer.Character and predictedUntil ~= nil then
		return predictedUntil - os.clock()
	end
	local phaseUntil = character:GetAttribute(Config.Skills.Attribute.PhaseUntil)
	return if typeof(phaseUntil) == "number" then phaseUntil - now else 0
end

local function setGroup(character: Model, phasing: boolean): ()
	local group = SkillEffects.CollisionGroup(character, phasing)
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.CollisionGroup ~= group then
			descendant.CollisionGroup = group
		end
	end
end

-- Pop-out ------------------------------------------------------------------------------------------

-- Moves the local character out of anything solid it ended Phase inside: to the nearest open floor (preferring the
-- way it was heading), or back where Phase started. Returns true when it moved.
local function popOut(character: Model): boolean
	local root = InstantSkill.Root(character)
	local body = if root then OpenFloor.BodyOf(character, root) else nil
	if root == nil or body == nil then
		return false
	end
	-- Only what the solid character collides with counts (not items, decor without collision, or other players
	-- when it's incorporeal).
	local params, rayParams = OpenFloor.Params(SkillEffects.CollisionGroup(character, false), { character })
	local floorDrop = PhaseConfig.PushOutFloorDrop

	local origin = root.Position
	if OpenFloor.Fits(origin, body, params, rayParams, floorDrop) then
		return false
	end
	local velocity = root.AssemblyLinearVelocity
	local heading = Vector3.new(velocity.X, 0, velocity.Z)
	heading = if heading.Magnitude > 0.1 then heading.Unit else Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
	local target: Vector3? = nil
	local radius = PhaseConfig.PushOutStep
	while target == nil and radius <= PhaseConfig.PushOutRadius do
		local best = -math.huge
		for index = 0, PhaseConfig.PushOutAngles - 1 do
			local angle = index / PhaseConfig.PushOutAngles * math.pi * 2
			local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
			local spot = origin + direction * radius
			local score = direction:Dot(heading)
			if score > best and OpenFloor.Fits(spot, body, params, rayParams, floorDrop) then
				best = score
				target = spot
			end
		end
		radius += PhaseConfig.PushOutStep
	end
	if target ~= nil then
		character:PivotTo(character:GetPivot() + (target - origin))
	elseif startPivot ~= nil then
		character:PivotTo(startPivot)
	else
		return false
	end
	root.AssemblyLinearVelocity = Vector3.zero
	return true
end


-- Visuals --------------------------------------------------------------------------------------------

local function heldPart(character: Model): BasePart?
	local root = InstantSkill.Root(character)
	local weld = if root then root:FindFirstChild("ObjectHolder") else nil
	return if weld ~= nil and weld:IsA("WeldConstraint") then weld.Part1 else nil
end

local function fadeInstance(visual: Visual, instance: Instance, value: number): ()
	if instance:IsA("BasePart") or instance:IsA("Decal") then
		(instance :: any).LocalTransparencyModifier = value
		visual.Faded[instance] = true
	end
end

-- `strength` is 0 solid .. 1 fully see-through.
local function applyFade(character: Model, visual: Visual, strength: number): ()
	local value = strength * visuals.Transparency
	local current: { [Instance]: boolean } = {}
	local function fade(root: Instance): ()
		current[root] = true
		fadeInstance(visual, root, value)
		for _, descendant in root:GetDescendants() do
			current[descendant] = true
			fadeInstance(visual, descendant, value)
		end
	end
	for _, child in character:GetChildren() do
		fade(child)
	end
	local held = heldPart(character)
	if held ~= nil then
		fade(held)
	end
	-- Something no longer carried (or removed) goes back to solid.
	for instance in visual.Faded do
		if not current[instance] then
			if instance.Parent ~= nil then
				(instance :: any).LocalTransparencyModifier = 0
			end
			visual.Faded[instance] = nil
		end
	end
end

local function clearFade(visual: Visual): ()
	for instance in visual.Faded do
		if instance.Parent ~= nil then
			(instance :: any).LocalTransparencyModifier = 0
		end
	end
	table.clear(visual.Faded)
end

local function restoreTint(visual: Visual): ()
	local tint = visual.Tint
	visual.Tint = nil
	if tint ~= nil and tint.Highlight.Parent ~= nil then
		tint.Highlight.FillColor = tint.FillColor
		tint.Highlight.FillTransparency = tint.FillTransparency
		tint.Highlight.DepthMode = tint.DepthMode
	end
end

-- The glow on the character's player-color Highlight (`strength` 0 none .. 1 full), drawn through walls while
-- `inside` one.
local function applyTint(character: Model, visual: Visual, strength: number, inside: boolean): ()
	local highlight = InstantSkill.CharacterHighlight(character)
	if visual.Tint ~= nil and (visual.Tint :: Tint).Highlight ~= highlight then
		restoreTint(visual)
	end
	if highlight == nil then
		return
	end
	local tint = visual.Tint
	if tint == nil then
		tint = {
			Highlight = highlight,
			FillColor = highlight.FillColor,
			FillTransparency = highlight.FillTransparency,
			DepthMode = highlight.DepthMode,
		}
		visual.Tint = tint
	end
	highlight.FillColor = visuals.TintColor
	local fill = if inside then visuals.InsideTintTransparency else visuals.TintTransparency
	highlight.FillTransparency = 1 - (1 - fill) * strength
	highlight.DepthMode = if inside then Enum.HighlightDepthMode.AlwaysOnTop else (tint :: Tint).DepthMode
end

-- 1 normally; in the last FlickerTime seconds, alternates with FlickerSolid, faster and faster.
local function flickerOf(character: Model, visual: Visual, now: number): number
	if not visual.Phasing then
		return 1
	end
	local remaining = remainingOf(character, now)
	if remaining > visuals.FlickerTime or remaining <= 0 then
		return 1
	end
	-- The flicker count so far, with the rate rising linearly from FlickerRateStart to FlickerRateEnd.
	local elapsed = visuals.FlickerTime - remaining
	local rise = visuals.FlickerRateEnd - visuals.FlickerRateStart
	local count = visuals.FlickerRateStart * elapsed + rise * elapsed * elapsed / (2 * visuals.FlickerTime)
	return if count % 1 < 0.5 then 1 else visuals.FlickerSolid
end

local function resetRoot(visual: Visual): ()
	local joint = visual.Root
	visual.Root = nil
	if joint ~= nil and joint.Joint.Parent ~= nil then
		joint.Joint.C0 = joint.Original
	end
end

-- Puffs in a ring around `axis` through `center`.
local function ring(center: Vector3, axis: Vector3, radius: number, count: number): ()
	local side = axis:Cross(Vector3.yAxis)
	if side.Magnitude < 0.1 then
		side = axis:Cross(Vector3.xAxis)
	end
	side = side.Unit
	local other = axis:Cross(side).Unit
	for index = 0, count - 1 do
		local angle = index / count * math.pi * 2
		local offset = (side * math.cos(angle) + other * math.sin(angle)) * radius
		InstantSkill.Burst(puffTemplate, CFrame.new(center + offset), 1)
	end
end

-- Warp -----------------------------------------------------------------------------------------------

-- A joint the warp scales: the body's Motor6Ds (not the root joint, which the float, lean and pop move) and the
-- welds holding accessories on.
local function warpsJoint(character: Model, joint: JointInstance, rootJoint: Motor6D?): boolean
	local part0 = joint.Part0
	local part1 = joint.Part1
	if joint == rootJoint or part0 == nil or part1 == nil then
		return false
	end
	if not part0:IsDescendantOf(character) or not part1:IsDescendantOf(character) then
		return false
	end
	local holder = part1.Parent
	return joint:IsA("Motor6D") or (joint:IsA("Weld") and holder ~= nil and holder:IsA("Accessory"))
end

local function restoreWarp(visual: Visual): ()
	local warp = visual.Warp
	visual.Warp = nil
	if warp == nil then
		return
	end
	for part, size in warp.Sizes do
		if part.Parent ~= nil then
			part.Size = size
		end
	end
	for mesh, scale in warp.Meshes do
		if mesh.Parent ~= nil then
			mesh.Scale = scale
		end
	end
	for joint, original in warp.Joints do
		if joint.Parent ~= nil then
			joint.C0 = original.C0
			joint.C1 = original.C1
		end
	end
end

-- Starts a warp. One already running restarts as the new kind but keeps the originals it saved; a wall crossing
-- within WarpGap of the last restart is skipped unless `force`d (a wall made of several parts).
local function startWarp(character: Model, visual: Visual, kind: WarpKind, heading: Vector3, force: boolean): ()
	local clock = os.clock()
	local warp = visual.Warp
	if warp ~= nil then
		if not force and clock - warp.StartedAt < visuals.WarpGap then
			return
		end
		warp.Kind = kind
		warp.StartedAt = clock
		warp.Heading = heading
		return
	end
	local root = InstantSkill.Root(character)
	local rootJoint = InstantSkill.RootJoint(character)
	local fresh: Warp = {
		Kind = kind,
		StartedAt = clock,
		Heading = heading,
		Sizes = {},
		Meshes = {},
		Joints = {},
	}
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") then
			if descendant ~= root and not descendant.Anchored then
				fresh.Sizes[descendant] = descendant.Size
			end
		elseif descendant:IsA("SpecialMesh") then
			fresh.Meshes[descendant] = descendant.Scale
		elseif descendant:IsA("JointInstance") and warpsJoint(character, descendant, rootJoint) then
			fresh.Joints[descendant] = { C0 = descendant.C0, C1 = descendant.C1 }
		end
	end
	visual.Warp = fresh
end

-- How much a part grows along each of its own axes when the body scales by `along` on `heading` and `across` on
-- the other two directions.
local function axisScale(frame: CFrame, heading: Vector3, along: number, across: number): Vector3
	local x = frame.RightVector:Dot(heading)
	local y = frame.UpVector:Dot(heading)
	local z = frame.LookVector:Dot(heading)
	local spread = along - across
	return Vector3.new(across + spread * x * x, across + spread * y * y, across + spread * z * z)
end

local function stepWarp(visual: Visual): ()
	local warp = visual.Warp
	if warp == nil then
		return
	end
	local start = warp.Kind == "Start"
	local duration = if start then visuals.StartTime else visuals.WarpTime
	local t = (os.clock() - warp.StartedAt) / math.max(duration, 0.01)
	if t >= 1 then
		restoreWarp(visual)
		return
	end
	-- Snap into shape, then spring back past it (negative) and wobble out like jelly.
	local snap = if start then visuals.StartSnap else 0.15
	local decay = if start then visuals.StartWobble else visuals.WarpWobble
	local amount
	if t < snap then
		amount = InstantSkill.ExpoOut(t / snap)
	else
		local settle = (t - snap) / (1 - snap)
		amount = math.cos(settle * math.pi * 3) * (1 - settle) ^ decay
	end
	local along, across
	if start then
		along = math.max(1 - visuals.StartShrink * amount, 0.2)
		across = along
	else
		along = if warp.Kind == "In" then 1 - visuals.WarpSquash * amount else 1 + visuals.WarpStretch * amount
		along = math.max(along, 0.2)
		-- Roughly keeps the volume: shorter is wider, longer is thinner.
		across = 1 / math.sqrt(along)
	end
	local scales: { [BasePart]: Vector3 } = {}
	local function scaleOf(part: BasePart): Vector3
		local cached: Vector3? = scales[part]
		if cached ~= nil then
			return cached
		end
		local scale = axisScale(part.CFrame, warp.Heading, along, across)
		scales[part] = scale
		return scale
	end
	for part, size in warp.Sizes do
		if part.Parent ~= nil then
			part.Size = size * scaleOf(part)
		end
	end
	for mesh, scale in warp.Meshes do
		local part = mesh.Parent
		if part ~= nil and part:IsA("BasePart") then
			mesh.Scale = scale * scaleOf(part)
		end
	end
	for joint, original in warp.Joints do
		local part0 = joint.Part0
		local part1 = joint.Part1
		if joint.Parent ~= nil and part0 ~= nil and part1 ~= nil then
			joint.C0 = CFrame.new(original.C0.Position * scaleOf(part0)) * original.C0.Rotation
			joint.C1 = CFrame.new(original.C1.Position * scaleOf(part1)) * original.C1.Rotation
		end
	end
end

-- Echoes ---------------------------------------------------------------------------------------------

-- A tinted copy of the body left where it is, made of plain copies of its parts (no joints, scripts or effects).
local function spawnEcho(character: Model): ()
	local root = InstantSkill.Root(character)
	local echo: Echo = { Parts = {}, StartedAt = os.clock() }
	for _, descendant in character:GetDescendants() do
		if not descendant:IsA("BasePart") or descendant == root or descendant.Anchored or descendant.Transparency >= 1 then
			continue
		end
		-- Clone returns nil for a part that isn't Archivable.
		local copy: BasePart? = descendant:Clone()
		if copy == nil then
			continue
		end
		local decals: { Decal } = {}
		for _, inside in copy:GetDescendants() do
			if inside:IsA("ParticleEmitter") then
				inside.Enabled = false
			end
			if inside:IsA("Decal") then
				inside.Transparency = visuals.EchoTransparency
				table.insert(decals, inside)
			elseif not inside:IsA("SpecialMesh") then
				inside:Destroy()
			end
		end
		copy.Anchored = true
		copy.CanCollide = false
		copy.CanQuery = false
		copy.CanTouch = false
		copy.CastShadow = false
		copy.CollisionGroup = visuals.EchoCollisionGroup
		copy.Material = Enum.Material.SmoothPlastic
		copy.Color = visuals.TintColor
		copy.Transparency = visuals.EchoTransparency
		copy.CFrame = descendant.CFrame
		copy.Parent = workspace.Terrain
		table.insert(echo.Parts, { Part = copy, Size = copy.Size, CFrame = copy.CFrame, Decals = decals })
	end
	table.insert(echoes, echo)
end

local function stepEchoes(): ()
	local clock = os.clock()
	for index = #echoes, 1, -1 do
		local echo = echoes[index]
		local t = (clock - echo.StartedAt) / math.max(visuals.EchoTime, 0.01)
		if t >= 1 then
			for _, piece in echo.Parts do
				piece.Part:Destroy()
			end
			table.remove(echoes, index)
			continue
		end
		local transparency = visuals.EchoTransparency + (1 - visuals.EchoTransparency) * t
		local scale = 1 - visuals.EchoShrink * t
		local rise = Vector3.new(0, visuals.EchoRise * t, 0)
		for _, piece in echo.Parts do
			piece.Part.Size = piece.Size * scale
			piece.Part.CFrame = piece.CFrame + rise
			piece.Part.Transparency = transparency
			for _, decal in piece.Decals do
				decal.Transparency = transparency
			end
		end
	end
end

-- Lifecycle ------------------------------------------------------------------------------------------

local function removeVisual(character: Model): ()
	local visual = active[character]
	if visual == nil then
		return
	end
	active[character] = nil
	resetRoot(visual)
	restoreWarp(visual)
	restoreTint(visual)
	clearFade(visual)
	if visual.Wisps ~= nil then
		visual.Wisps:Destroy()
	end
	if visual.Aura ~= nil then
		visual.Aura:Destroy()
	end
	if visual.Glow ~= nil then
		visual.Glow:Destroy()
	end
end

local function addVisual(character: Model, startedAt: number): ()
	local root = InstantSkill.Root(character)
	if root == nil or active[character] ~= nil then
		return
	end
	local joint = InstantSkill.RootJoint(character)
	local visual: Visual = {
		StartedAt = startedAt,
		Fade = 0,
		Phasing = true,
		PoppedAt = nil,
		Spat = false,
		Root = if joint ~= nil then { Joint = joint, Original = joint.C0 } else nil,
		Lean = Vector2.zero,
		LeanSpeed = Vector2.zero,
		BurstAt = nil,
		NextEchoAt = 0,
		LastPosition = nil,
		Wisps = nil,
		Aura = nil,
		Glow = nil,
		Tint = nil,
		Faded = {},
		Inside = {},
		Warp = nil,
	}
	if wispsTemplate ~= nil then
		local wisps = wispsTemplate:Clone()
		wisps.Enabled = false
		wisps.Parent = root
		visual.Wisps = wisps
	end
	if auraTemplate ~= nil then
		local aura = auraTemplate:Clone()
		aura.Enabled = false
		aura.Parent = root
		visual.Aura = aura
	end
	if glowTemplate ~= nil then
		local glow = glowTemplate:Clone()
		glow.Brightness = 0
		glow.Range = visuals.GlowRange
		glow.Parent = root
		visual.Glow = glow
	end
	active[character] = visual
	-- A late joiner (or a Ghost streaming in mid-Phase) skips the start: no shrink and burst.
	if workspace:GetServerTimeNow() - startedAt < visuals.StartTime then
		startWarp(character, visual, "Start", Vector3.zero, true)
		visual.BurstAt = os.clock() + visuals.StartTime * visuals.StartSnap
	else
		visual.Fade = 1
	end
end

-- The end: the Ghost turns solid with a lift and a pop.
local function pop(character: Model, visual: Visual): ()
	visual.Phasing = false
	visual.PoppedAt = os.clock()
	visual.Inside = {}
	if visual.Wisps ~= nil then
		Particles.Stop(visual.Wisps)
	end
	if visual.Aura ~= nil then
		Particles.Stop(visual.Aura)
	end
	local root = InstantSkill.Root(character)
	if root ~= nil then
		InstantSkill.Burst(popTemplate, root.CFrame, visuals.PopCount)
	end
end

-- The start burst: a puff on the body and a ring of puffs on the floor.
local function burst(character: Model, root: BasePart): ()
	InstantSkill.Burst(puffTemplate, root.CFrame, visuals.StartCount)
	local body = OpenFloor.BodyOf(character, root)
	if body ~= nil then
		local feet = root.Position - Vector3.new(0, body.FeetDrop - 0.3, 0)
		ring(feet, Vector3.yAxis, visuals.RingRadius, visuals.RingCount)
	end
end

-- Walls ----------------------------------------------------------------------------------------------

-- A ring of puffs on `wall`'s face where the Ghost crossed it: looking along its heading from outside the wall,
-- toward the root (going in: from behind; coming out: from ahead).
local function splash(wall: BasePart, root: BasePart, heading: Vector3, entering: boolean): ()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { wall }
	local probe = visuals.WarpProbe
	local direction = if entering then heading else -heading
	local hit = workspace:Raycast(root.Position - direction * probe, direction * probe * 2, params)
	if hit ~= nil then
		ring(hit.Position + hit.Normal * 0.3, hit.Normal, visuals.SplashRadius, visuals.SplashCount)
	end
end

-- Walls the character's body overlaps now; warps it going into or out of them since last frame.
local function stepWalls(character: Model, visual: Visual): ()
	local root = InstantSkill.Root(character)
	local body = if root then OpenFloor.BodyOf(character, root) else nil
	if root == nil or body == nil then
		return
	end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local characters: { Instance } = {}
	for _, player in Players:GetPlayers() do
		if player.Character ~= nil then
			table.insert(characters, player.Character)
		end
	end
	params.FilterDescendantsInstances = characters
	params.RespectCanCollide = true
	local now: { [BasePart]: boolean } = {}
	local center = root.Position + Vector3.new(0, body.Lift, 0)
	for _, part in workspace:GetPartBoundsInBox(CFrame.new(center), body.Size, params) do
		if part.CollisionGroup == CharacterConfig.WorldCollisionGroup then
			now[part] = true
		end
	end
	local velocity = root.AssemblyLinearVelocity
	local flat = Vector3.new(velocity.X, 0, velocity.Z)
	-- Standing still in a wall doesn't warp (there's no face it crossed).
	local heading = if flat.Magnitude > 1 then flat.Unit else nil
	-- Only going from open air into something, or all the way out, counts: a stove made of several parts or a row
	-- of counters is one wall.
	local wasInside = next(visual.Inside) ~= nil
	local isInside = next(now) ~= nil
	if heading ~= nil and wasInside ~= isInside then
		local crossed = if isInside then next(now) else next(visual.Inside)
		startWarp(character, visual, if isInside then "In" else "Out", heading, false)
		if crossed ~= nil and crossed.Parent ~= nil then
			splash(crossed, root, heading, isInside)
		end
	end
	visual.Inside = now
end

-- Body -----------------------------------------------------------------------------------------------

-- The root joint: floating with a bob, leaning into the movement, and the end pop's lift.
local function stepRoot(visual: Visual, root: BasePart, now: number, dt: number): ()
	local joint = visual.Root
	if joint == nil then
		return
	end
	if joint.Joint.Parent == nil then
		visual.Root = nil
		return
	end
	local blend = visual.Fade
	local bob = math.sin((now - visual.StartedAt) / visuals.FloatPeriod * math.pi * 2) * visuals.FloatBob
	local lift = (visuals.FloatHeight + bob) * blend
	if visual.PoppedAt ~= nil then
		local t = (os.clock() - visual.PoppedAt) / math.max(visuals.PopTime, 0.01)
		if t < 1 then
			lift += visuals.PopStretch * math.sin(t * math.pi) * (1 - t) * 2
		end
	end
	-- Lean: top toward the movement (the root's -Z is forward), on a spring so it lags and sways back.
	local target = Vector2.zero
	if visual.Phasing then
		local velocity = root.CFrame:VectorToObjectSpace(root.AssemblyLinearVelocity)
		target = Vector2.new(velocity.Z, -velocity.X) * visuals.LeanPerSpeed
		if target.Magnitude > visuals.LeanMax then
			target = target.Unit * visuals.LeanMax
		end
	end
	local step = math.min(dt, 1 / 30)
	local pull = (target - visual.Lean) * visuals.LeanStiffness - visual.LeanSpeed * visuals.LeanDamping
	visual.LeanSpeed += pull * step
	visual.Lean += visual.LeanSpeed * step
	local lean = visual.Lean * blend
	joint.Joint.C0 = CFrame.new(0, lift, 0) * CFrame.Angles(lean.X, 0, lean.Y) * joint.Original
end

local function stepVisual(character: Model, visual: Visual, now: number, dt: number): ()
	local clock = os.clock()
	local target = if visual.Phasing then 1 else 0
	local speed = dt / math.max(visuals.FadeTime, 0.01)
	visual.Fade = if visual.Fade < target then math.min(visual.Fade + speed, target) else math.max(visual.Fade - speed, target)
	local strength = visual.Fade * flickerOf(character, visual, now)
	applyFade(character, visual, strength)

	if visual.Phasing then
		stepWalls(character, visual)
	end
	applyTint(character, visual, strength, visual.Phasing and next(visual.Inside) ~= nil)
	if visual.Glow ~= nil then
		visual.Glow.Brightness = visuals.GlowBrightness * strength
	end
	-- The haze thins out with the flicker at the end.
	if visual.Aura ~= nil and visual.Phasing then
		Particles.Stream(visual.Aura, visuals.AuraRate * strength)
	end

	local root = InstantSkill.Root(character)
	if root == nil then
		return
	end
	if visual.BurstAt ~= nil and clock >= visual.BurstAt then
		visual.BurstAt = nil
		burst(character, root)
	end
	stepRoot(visual, root, now, dt)

	-- Spat out of a wall at the end: the character jumped this frame.
	local position = root.Position
	local last = visual.LastPosition
	if visual.PoppedAt ~= nil and not visual.Spat and last ~= nil and clock - visual.PoppedAt <= visuals.SpitWindow then
		local jump = Vector3.new(position.X - last.X, 0, position.Z - last.Z)
		if jump.Magnitude > visuals.SpitJump then
			visual.Spat = true
			InstantSkill.Burst(puffTemplate, CFrame.new(last), visuals.SpitCount)
			startWarp(character, visual, "Out", jump.Unit, true)
		end
	end
	visual.LastPosition = position
	stepWarp(visual)

	local velocity = root.AssemblyLinearVelocity
	local flatSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local wisps = visual.Wisps
	if wisps ~= nil and visual.Phasing then
		if flatSpeed > visuals.WispMinSpeed then
			Particles.Stream(wisps)
		else
			Particles.Stop(wisps)
		end
	end
	if visual.Phasing and flatSpeed > visuals.EchoMinSpeed and clock >= visual.NextEchoAt then
		visual.NextEchoAt = clock + visuals.EchoInterval
		spawnEcho(character)
	end
end

local function finished(visual: Visual): boolean
	if visual.Phasing or visual.Fade > 0 or visual.Warp ~= nil then
		return false
	end
	return visual.PoppedAt == nil or os.clock() - visual.PoppedAt >= visuals.PopTime
end

-- Local collision ------------------------------------------------------------------------------------

-- Keeps the local character's group on what this client believes, so a replicated group from the server (a little
-- early or late) never makes it solid inside a wall. Turning solid pops it out first.
local function stepLocal(now: number): ()
	local character = localPlayer.Character
	if character == nil then
		localPhasing = false
		return
	end
	local phasing = isPhasing(character, now)
	if phasing ~= localPhasing then
		localPhasing = phasing
		if not phasing then
			popOut(character)
			startPivot = nil
		end
	end
	setGroup(character, phasing)
end

local function step(dt: number): ()
	local now = workspace:GetServerTimeNow()
	local endsAt = predictedUntil
	if endsAt ~= nil and os.clock() >= endsAt then
		predictedUntil = nil
	end
	stepLocal(now)
	stepEchoes()

	local seen: { [Model]: boolean } = {}
	for _, player in Players:GetPlayers() do
		local other = player.Character
		if other ~= nil and isPhasing(other, now) then
			seen[other] = true
			local visual = active[other]
			if visual == nil then
				addVisual(other, startedAtOf(other) or now)
			elseif not visual.Phasing then
				-- Phased again before the last one finished fading.
				removeVisual(other)
				addVisual(other, startedAtOf(other) or now)
			end
		end
	end
	for model, visual in table.clone(active) do
		if model.Parent == nil then
			removeVisual(model)
			continue
		end
		if visual.Phasing and not seen[model] then
			pop(model, visual)
		end
		stepVisual(model, visual, now, dt)
		if finished(visual) then
			removeVisual(model)
		end
	end
end

local Phase: InstantSkill.InstantSkill = {
	RequiresEmptyHands = false,
	Setup = function(): ()
		local folder = InstantSkill.Folder("Phase")
		wispsTemplate = InstantSkill.Template(folder, "Wisps", "ParticleEmitter") :: ParticleEmitter?
		auraTemplate = InstantSkill.Template(folder, "Aura", "ParticleEmitter") :: ParticleEmitter?
		glowTemplate = InstantSkill.Template(folder, "Glow", "PointLight") :: PointLight?
		puffTemplate = InstantSkill.Template(folder, "Puff", "ParticleEmitter") :: ParticleEmitter?
		popTemplate = InstantSkill.Template(folder, "Pop", "ParticleEmitter") :: ParticleEmitter?
		RunService.Heartbeat:Connect(step)
	end,
	CanUse = function(_character: Model): boolean
		return true
	end,
	Predict = function(character: Model): ()
		predictedUntil = os.clock() + PhaseConfig.Duration
		startPivot = character:GetPivot()
		localPhasing = true
		setGroup(character, true)
		addVisual(character, workspace:GetServerTimeNow())
	end,
	Rollback = function(): ()
		predictedUntil = nil
		-- stepLocal pops the character out and turns it solid on the next frame.
	end,
	IsBusy = function(): boolean
		return false
	end,
	BlocksInteract = function(): boolean
		local character = localPlayer.Character
		return not PhaseConfig.CanInteract and character ~= nil and isPhasing(character, workspace:GetServerTimeNow())
	end,
	BlocksThrow = function(): boolean
		local character = localPlayer.Character
		return character ~= nil and isPhasing(character, workspace:GetServerTimeNow())
	end,
	-- It floats instead of walking.
	StopsRunAnimation = function(): boolean
		local character = localPlayer.Character
		return character ~= nil and isPhasing(character, workspace:GetServerTimeNow())
	end,
}

return Phase
