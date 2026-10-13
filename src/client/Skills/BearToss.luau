--!strict

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local CameraController = require(script.Parent.Parent.Controllers.CameraController)
local SpeedController = require(script.Parent.Parent.Controllers.SpeedController)
local InstantSkill = require(script.Parent.InstantSkill)
local RagdollCopy = require(script.Parent.Parent.Util.RagdollCopy)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Tuning = Config.Skills.BearToss
local Attribute = Config.Skills.Attribute
local Tags = require(Shared:WaitForChild("Tags"))
local TossPath = require(Shared:WaitForChild("Util"):WaitForChild("TossPath"))

-- Bear: Bear Toss, the client side. See docs/design/characters/bear-toss.md.
-- The Bear aims a landing ring with the movement keys or stick while it holds a teammate overhead; a dashed guide
-- (the Gecko guide's look) bends along the arc. The held or thrown player's own client carries its hidden character
-- (it owns the physics) from the data on it: overhead while TossHeldBy is set, along the arc during the flight
-- (TossStartedAt, TossFrom, TossTo), then standing at the landing until the get-up. Every client draws a floppy
-- ragdoll copy in its place from the same data, plus the Bear's dips and the landing dust.
local BearToss = {}

BearToss.HoldLimit = Tuning.HoldLimit
BearToss.ActiveTime = Tuning.ThrowTime

local localPlayer = Players.LocalPlayer
local visuals = Tuning.Visuals
-- Seconds between landing searches while aiming, and between refreshing the thrown player's queries.
local FIND_INTERVAL = 0.08
local QUERY_INTERVAL = 0.25
-- The client throws on its own this long before the hold limit, so the server never sees a timeout.
local AUTO_THROW_EARLY = 0.1
-- Straight pieces the aim arc is measured in, to lay the guide's dashes along it.
local GUIDE_SAMPLES = 32

local ringTemplate: BasePart? = nil
local beamTemplate: Beam? = nil
local dustTemplate: ParticleEmitter? = nil

local function playSound(name: string): ()
	local folder = SoundService:FindFirstChild("SoundEffects")
	local sound = if folder then folder:FindFirstChild(name) else nil
	if sound ~= nil and sound:IsA("Sound") then
		sound:Play()
	end
end

local function flat(vector: Vector3): Vector3
	local result = Vector3.new(vector.X, 0, vector.Z)
	return if result.Magnitude > 1e-3 then result.Unit else Vector3.zero
end

local function yawOf(direction: Vector3): number
	return math.atan2(-direction.X, -direction.Z)
end

local function rootOf(character: Model?): BasePart?
	return if character ~= nil then InstantSkill.Root(character) else nil
end

local function alive(character: Model?): boolean
	local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	return humanoid ~= nil and humanoid.Health > 0
end

local function newVisual(template: BasePart?): BasePart?
	if template == nil then
		return nil
	end
	local part = template:Clone()
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Parent = workspace
	return part
end

-- Dips ---------------------------------------------------------------------------------------------------------

-- A squat on a character's root joint that wobbles back (the Bear lifting or throwing).
type Dip = { Joint: Motor6D, Original: CFrame, Depth: number, StartedAt: number }

local dips: { [Model]: Dip } = {}

local function dip(character: Model, depth: number): ()
	local joint = InstantSkill.RootJoint(character)
	if joint == nil then
		return
	end
	local previous = dips[character]
	dips[character] = {
		Joint = joint,
		Original = if previous ~= nil and previous.Joint == joint then previous.Original else joint.C0,
		Depth = depth,
		StartedAt = os.clock(),
	}
end

local function stepDips(): ()
	local now = os.clock()
	for character, current in dips do
		local t = (now - current.StartedAt) / visuals.DipTime
		if t >= 1 or character.Parent == nil or current.Joint.Parent == nil then
			current.Joint.C0 = current.Original
			dips[character] = nil
			continue
		end
		local amount = 1 - InstantSkill.Elastic(t, visuals.DipWobble)
		current.Joint.C0 = CFrame.new(0, -current.Depth * amount, 0) * current.Original
	end
end

-- Grab targets -----------------------------------------------------------------------------------------------------

local function inGrab(root: BasePart, point: Vector3): number?
	local offset = Vector3.new(point.X - root.Position.X, 0, point.Z - root.Position.Z)
	local distance = offset.Magnitude
	if distance > Tuning.GrabReach then
		return nil
	end
	local look = flat(root.CFrame.LookVector)
	if distance > 1 and look ~= Vector3.zero then
		local angle = math.deg(math.acos(math.clamp(look:Dot(offset.Unit), -1, 1)))
		if angle > Tuning.GrabAngle then
			return nil
		end
	end
	return distance
end

local function teamOf(player: Player): number
	local team = player:GetAttribute("Team")
	return if typeof(team) == "number" then team else 1
end

-- The teammate the server would most likely grab (it decides; chopping and washing are only known there).
local function findTeammate(root: BasePart): Model?
	local team = teamOf(localPlayer)
	local best: Model? = nil
	local bestDistance = math.huge
	for _, other in Players:GetPlayers() do
		local character = other.Character
		local otherRoot = rootOf(character)
		if
			other == localPlayer
			or character == nil
			or otherRoot == nil
			or teamOf(other) ~= team
			or not alive(character)
			or character:GetAttribute(Attribute.State) ~= nil
			or TossPath.Busy(character)
		then
			continue
		end
		local distance = inGrab(root, otherRoot.Position)
		if distance ~= nil and distance < bestDistance then
			best = character
			bestDistance = distance
		end
	end
	return best
end

local function runnerInReach(root: BasePart): boolean
	for _, runnerRoot in CollectionService:GetTagged(Tags.ClassTag(Tags.Runner)) do
		if runnerRoot:IsA("BasePart") and inGrab(root, runnerRoot.Position) ~= nil then
			return true
		end
	end
	return false
end

-- Aiming -------------------------------------------------------------------------------------------------------

-- The aim guide: the Gecko guide's white dashes laid along the flight arc. Each dash is its own short straight Beam,
-- which faces the camera from any side (one long curved Beam turns edge-on and thins out).
type Dash = { Start: Attachment, Finish: Attachment, Beam: Beam }
type Guide = { Dashes: { Dash } }

type Aim = {
	Character: Model,
	Root: BasePart,
	Humanoid: Humanoid,
	-- The teammate overhead, or nil for a dasher catch (released at once, no ring).
	Target: Model?,
	StartedAt: number,
	-- The flat point the keys move; the landing is the nearest valid spot to it.
	Cursor: Vector3,
	Landing: Vector3?,
	-- Where the ring and the arc's end are drawn: glides toward the landing (or the cursor) instead of jumping.
	Shown: Vector3?,
	FoundAt: number,
	Queries: TossPath.Queries?,
	QueriesAt: number,
	PressMoveDirection: Vector3?,
	Ring: BasePart?,
	Guide: Guide?,
	Released: boolean,
}

local aim: Aim? = nil

-- Whether pressing does anything: a teammate or a dasher in reach. Nothing in reach costs nothing.
function BearToss.CanAim(character: Model): boolean
	local root = rootOf(character)
	return root ~= nil and (findTeammate(root) ~= nil or runnerInReach(root))
end

local function heldFrom(root: BasePart): Vector3
	return root.Position + Vector3.yAxis * Tuning.LiftHeight
end

local function clampCursor(root: BasePart, cursor: Vector3): Vector3
	local offset = Vector3.new(cursor.X - root.Position.X, 0, cursor.Z - root.Position.Z)
	local distance = offset.Magnitude
	if distance < 1e-3 then
		offset = flat(root.CFrame.LookVector)
		distance = 1
	end
	local clamped = math.clamp(distance, Tuning.MinRange, Tuning.MaxRange)
	return Vector3.new(root.Position.X, 0, root.Position.Z) + offset / distance * clamped
end

local function newGuide(): Guide?
	return if beamTemplate ~= nil then { Dashes = {} } else nil
end

local function newDash(template: Beam): Dash
	local start = Instance.new("Attachment")
	start.Name = "BearTossDash"
	start.Parent = workspace.Terrain
	local finish = Instance.new("Attachment")
	finish.Name = "BearTossDashEnd"
	finish.Parent = workspace.Terrain
	local beam = template:Clone()
	beam.Attachment0 = start
	beam.Attachment1 = finish
	beam.Parent = start
	return { Start = start, Finish = finish, Beam = beam }
end

-- Lays the dashes along TossPath's arc from `from` to `to`, marching toward the landing.
local function drawGuide(guide: Guide, from: Vector3, to: Vector3, color: Color3, now: number): ()
	local template = beamTemplate
	if template == nil then
		return
	end
	-- The arc sampled into short straight pieces, with the distance along it at each point.
	local points: { Vector3 } = {}
	local lengths: { number } = {}
	local total = 0
	for index = 0, GUIDE_SAMPLES do
		local point = TossPath.Position(from, to, index / GUIDE_SAMPLES)
		if index > 0 then
			total += (point - points[index]).Magnitude
		end
		table.insert(points, point)
		table.insert(lengths, total)
	end
	local function pointAt(distance: number): Vector3
		for index = 2, #points do
			if lengths[index] >= distance then
				local span = lengths[index] - lengths[index - 1]
				local t = if span > 1e-6 then (distance - lengths[index - 1]) / span else 0
				return points[index - 1]:Lerp(points[index], t)
			end
		end
		return points[#points]
	end
	local period = visuals.GuideDash + visuals.GuideGap
	local shift = (now * visuals.GuideSpeed) % period
	local sequence = ColorSequence.new(color)
	local used = 0
	local distance = shift - period
	while distance < total do
		local first = math.max(distance, 0)
		local last = math.min(distance + visuals.GuideDash, total)
		if last - first > 0.05 then
			used += 1
			local dash = guide.Dashes[used]
			if dash == nil then
				dash = newDash(template)
				guide.Dashes[used] = dash
			end
			dash.Start.WorldPosition = pointAt(first)
			dash.Finish.WorldPosition = pointAt(last)
			dash.Beam.Color = sequence
			dash.Beam.Enabled = true
		end
		distance += period
	end
	for index = used + 1, #guide.Dashes do
		guide.Dashes[index].Beam.Enabled = false
	end
end

local function clearVisuals(current: Aim): ()
	if current.Ring ~= nil then
		current.Ring:Destroy()
		current.Ring = nil
	end
	if current.Guide ~= nil then
		for _, dash in current.Guide.Dashes do
			dash.Start:Destroy()
			dash.Finish:Destroy()
		end
		current.Guide = nil
	end
end

function BearToss.BeginAim(character: Model): ()
	local root = rootOf(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if root == nil or humanoid == nil then
		return
	end
	local target = findTeammate(root)
	local look = flat(root.CFrame.LookVector)
	aim = {
		Character = character,
		Root = root,
		Humanoid = humanoid,
		Target = target,
		StartedAt = os.clock(),
		Cursor = clampCursor(root, root.Position + look * Tuning.StartDistance),
		Landing = nil,
		Shown = nil,
		FoundAt = -math.huge,
		Queries = nil,
		QueriesAt = -math.huge,
		PressMoveDirection = flat(humanoid.MoveDirection),
		Ring = if target ~= nil then newVisual(ringTemplate) else nil,
		Guide = if target ~= nil then newGuide() else nil,
		Released = false,
	}
	dip(character, visuals.LiftDip)
	playSound("BearLift")
end

-- True when the client should release on its own: right away for a dasher, or just before the hold limit.
function BearToss.AutoRelease(): boolean
	local current = aim
	if current == nil or current.Released then
		return false
	end
	return current.Target == nil or os.clock() - current.StartedAt >= Tuning.HoldLimit - AUTO_THROW_EARLY
end

local function drawAim(current: Aim, dt: number, now: number): ()
	local feetDrop = if current.Queries ~= nil then current.Queries.Body.FeetDrop else 3
	local landing = current.Landing
	-- A blocked ring sits on the floor under the cursor, at the Bear's floor height.
	local wanted = landing or Vector3.new(current.Cursor.X, current.Root.Position.Y, current.Cursor.Z)
	local previous = current.Shown
	local shown: Vector3 = if previous == nil
		then wanted
		else previous:Lerp(wanted, 1 - math.exp(-visuals.AimSmoothing * dt))
	current.Shown = shown
	local floor = shown - Vector3.yAxis * feetDrop
	local valid = landing ~= nil
	local ring = current.Ring
	local template = ringTemplate
	if ring ~= nil and template ~= nil then
		local size = template.Size
		local pulse = 1 + visuals.RingPulse * math.sin(now * visuals.RingPulseSpeed)
		-- A flat invisible plate (Y is its thickness) showing the ring Decal on top.
		ring.Size = Vector3.new(size.X * pulse, size.Y, size.Z * pulse)
		ring.CFrame = CFrame.new(floor + Vector3.yAxis * (size.Y / 2 + 0.02))
		local decal = ring:FindFirstChildOfClass("Decal")
		if decal ~= nil then
			decal.Color3 = if valid then visuals.RingColor else visuals.BlockedColor
		end
	end
	local guide = current.Guide
	if guide ~= nil then
		drawGuide(
			guide,
			heldFrom(current.Root),
			floor + Vector3.yAxis * 0.1,
			if valid then visuals.GuideColor else visuals.BlockedColor,
			now
		)
	end
end

function BearToss.StepAim(dt: number): boolean
	local current = aim
	if current == nil or current.Released or current.Target == nil then
		return false
	end
	local target = current.Target :: Model
	local root = current.Root
	-- The keys held at the press don't move the ring until they change.
	local input = flat(current.Humanoid.MoveDirection)
	local pressDirection = current.PressMoveDirection
	if pressDirection ~= nil then
		if pressDirection:Dot(input) > 0.99 then
			input = Vector3.zero
		else
			current.PressMoveDirection = nil
		end
	end
	current.Cursor = clampCursor(root, current.Cursor + input * Tuning.RingSpeed * dt)
	local facing = flat(current.Cursor - root.Position)
	if facing ~= Vector3.zero then
		root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, yawOf(facing), 0)
	end

	local now = os.clock()
	if now - current.QueriesAt >= QUERY_INTERVAL then
		current.Queries = TossPath.Queries(target)
		current.QueriesAt = now
	end
	local queries = current.Queries
	if queries ~= nil and now - current.FoundAt >= FIND_INTERVAL then
		current.FoundAt = now
		current.Landing = TossPath.Find(root.Position, heldFrom(root), current.Cursor, queries)
	end
	drawAim(current, dt, now)
	local center = current.Shown or current.Cursor
	CameraController.SetAimOffset(
		Vector3.new(center.X - root.Position.X, 0, center.Z - root.Position.Z) * Tuning.CameraAimShare,
		Tuning.CameraEaseSpeed
	)
	return false
end

function BearToss.ReleaseAim(predict: boolean): ()
	local current = aim
	if current == nil then
		return
	end
	current.Released = true
	clearVisuals(current)
	CameraController.SetAimOffset(Vector3.zero, Tuning.CameraEaseSpeed)
	if predict then
		dip(current.Character, visuals.ThrowDip)
		playSound("BearThrow")
	end
end

function BearToss.EndAim(): ()
	local current = aim
	if current == nil then
		return
	end
	aim = nil
	clearVisuals(current)
	CameraController.SetAimOffset(Vector3.zero, Tuning.CameraEaseSpeed)
end

-- The landing root position (zero when there is none, which the server treats as a put-down).
function BearToss.GetDirection(): Vector3
	local current = aim
	return if current ~= nil and current.Landing ~= nil then current.Landing else Vector3.zero
end

function BearToss.GetTarget(): Instance?
	local current = aim
	return if current ~= nil then current.Target else nil
end

-- The tossed local character --------------------------------------------------------------------------------

-- The local character's real body while it is tossed. It is hidden (everyone sees the ragdoll copy instead) and
-- only carries the player's position: overhead while held, along the arc in flight, standing at the landing while
-- the ragdoll gets up.
type Pin = { Mode: "Held" | "Flying", HeldBy: number?, StartedAt: number? }

local pin: Pin? = nil

local function setPinned(character: Model, pinned: boolean): ()
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid ~= nil then
		humanoid.PlatformStand = pinned
	end
	SpeedController.SetRooted("Toss", pinned)
end

local function bearRoot(userId: number?): BasePart?
	local bear = if userId ~= nil then Players:GetPlayerByUserId(userId) else nil
	return if bear ~= nil then rootOf(bear.Character) else nil
end

-- Put down in front of the Bear (the toss was cancelled), or left where it is when that spot is blocked.
local function putDown(character: Model, root: BasePart, heldBy: number?): ()
	local bear = bearRoot(heldBy)
	if bear == nil then
		return
	end
	local look = flat(bear.CFrame.LookVector)
	local spot = bear.Position + look * Tuning.DropDistance
	local queries = TossPath.Queries(character)
	if queries ~= nil and TossPath.Fits(spot, queries) then
		root.CFrame = CFrame.new(spot) * CFrame.Angles(0, yawOf(look), 0)
	end
end

local function headingYaw(flight: TossPath.Flight, fallback: number): number
	local heading = flat(flight.To - flight.From)
	return if heading ~= Vector3.zero then yawOf(heading) else fallback
end

local function stepLocal(): ()
	local character = localPlayer.Character
	local root = rootOf(character)
	if character == nil or root == nil then
		pin = nil
		return
	end
	local now = workspace:GetServerTimeNow()
	local heldBy = TossPath.HeldBy(character)
	local flight = TossPath.Flight(character)
	local current = pin
	local yaw = yawOf(flat(root.CFrame.LookVector))

	if flight ~= nil and now < TossPath.EndsAt(flight) then
		if current == nil or current.Mode ~= "Flying" or current.StartedAt ~= flight.StartedAt then
			pin = { Mode = "Flying", HeldBy = nil, StartedAt = flight.StartedAt }
			setPinned(character, true)
			playSound("BearYelp")
		end
		local alpha = math.clamp((now - flight.StartedAt) / Tuning.FlightTime, 0, 1)
		root.CFrame = CFrame.new(TossPath.Position(flight.From, flight.To, alpha))
			* CFrame.Angles(0, headingYaw(flight, yaw), 0)
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		return
	end

	if heldBy ~= nil then
		if current == nil or current.Mode ~= "Held" then
			pin = { Mode = "Held", HeldBy = heldBy, StartedAt = nil }
			setPinned(character, true)
		end
		local bear = bearRoot(heldBy)
		if bear ~= nil then
			root.CFrame = CFrame.new(heldFrom(bear)) * bear.CFrame.Rotation
		end
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		return
	end

	if current ~= nil then
		pin = nil
		if current.Mode == "Flying" and flight ~= nil and flight.StartedAt == current.StartedAt then
			root.CFrame = CFrame.new(flight.To) * CFrame.Angles(0, headingYaw(flight, yaw), 0)
		elseif current.Mode == "Held" then
			putDown(character, root, current.HeldBy)
		else
			root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, yaw, 0)
		end
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		setPinned(character, false)
	end
end

-- Every tossed character's ragdoll, the dips and the landing ----------------------------------------------------

-- What this client draws for one player in a toss. The real character is hidden while `Copy` stands in for it.
type View = {
	Copy: RagdollCopy.Copy?,
	-- The held item, hidden with the character.
	Item: BasePart?,
	-- Where the lift started (the body's CFrame) and when (os.clock).
	LiftFrom: CFrame?,
	LiftAt: number,
	-- The flight being drawn, and whether the ragdoll was let go at the landing.
	StartedAt: number?,
	Dropped: boolean,
}

type Watch = { HeldBy: number?, StartedAt: number?, Landed: boolean, View: View? }

local watches: { [Model]: Watch } = {}

local function landingDust(position: Vector3, feetDrop: number): ()
	local floor = position - Vector3.yAxis * feetDrop
	InstantSkill.Burst(dustTemplate, CFrame.new(floor) * CFrame.Angles(math.pi / 2, 0, 0), visuals.DustCount)
	for index = 1, visuals.DustRingCount do
		local angle = index / visuals.DustRingCount * 2 * math.pi
		local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * visuals.DustRingRadius
		InstantSkill.Burst(dustTemplate, CFrame.lookAt(floor + offset, floor + offset * 2), 1)
	end
end

local function dipBear(userId: number?, depth: number): ()
	local bear = if userId ~= nil then Players:GetPlayerByUserId(userId) else nil
	-- The local Bear already dipped when it pressed or released.
	if bear ~= nil and bear ~= localPlayer and bear.Character ~= nil then
		dip(bear.Character, depth)
	end
end

local function heldItem(character: Model): BasePart?
	local root = rootOf(character)
	local holder = if root ~= nil then root:FindFirstChild("ObjectHolder") else nil
	return if holder ~= nil and holder:IsA("WeldConstraint") then holder.Part1 else nil
end

local function setItemHidden(item: BasePart?, hidden: boolean): ()
	if item == nil then
		return
	end
	local value = if hidden then 1 else 0
	item.LocalTransparencyModifier = value
	for _, descendant in item:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.LocalTransparencyModifier = value
		elseif descendant:IsA("Decal") then
			descendant.LocalTransparencyModifier = value
		end
	end
end

local function openView(character: Model): View
	local root = rootOf(character)
	local copy = RagdollCopy.Make(character, Config.Character.RagdollCollisionGroup)
	local item = heldItem(character)
	InstantSkill.SetHidden(character, true)
	setItemHidden(item, true)
	if copy ~= nil and copy.Body ~= nil then
		copy.Body.Anchored = true
	end
	return {
		Copy = copy,
		Item = item,
		LiftFrom = if copy ~= nil and copy.Body ~= nil then copy.Body.CFrame elseif root ~= nil then root.CFrame else nil,
		LiftAt = os.clock(),
		StartedAt = nil,
		Dropped = false,
	}
end

local function closeView(character: Model, view: View): ()
	if view.Copy ~= nil then
		view.Copy.Model:Destroy()
	end
	if character.Parent ~= nil then
		InstantSkill.SetHidden(character, false)
	end
	setItemHidden(view.Item, false)
end

-- The body lying back across the Bear's raised arms, squirming.
local function heldPose(view: View, bear: BasePart): CFrame
	local wiggle = math.rad(visuals.HeldWiggle) * math.sin(os.clock() * visuals.HeldWiggleSpeed)
	local target = CFrame.new(heldFrom(bear)) * bear.CFrame.Rotation * CFrame.Angles(math.rad(visuals.HeldTilt), 0, wiggle)
	local from = view.LiftFrom
	if from == nil then
		return target
	end
	local t = math.clamp((os.clock() - view.LiftAt) / Tuning.LiftTime, 0, 1)
	return from:Lerp(target, InstantSkill.ExpoOut(t))
end

-- Lets the ragdoll go at the landing with the arc's speed, so it slams down and rolls.
local function drop(view: View, flight: TossPath.Flight): ()
	view.Dropped = true
	local copy = view.Copy
	local body = if copy ~= nil then copy.Body else nil
	if copy == nil or body == nil then
		return
	end
	body.Anchored = false
	local heading = flat(flight.To - flight.From)
	local velocity = heading / Tuning.FlightTime * visuals.LandCarry
		- Vector3.yAxis * (4 * Tuning.ArcHeight / Tuning.FlightTime)
	local roll = heading:Cross(Vector3.yAxis) * -visuals.LandSpin
	for _, part in copy.Parts do
		part.AssemblyLinearVelocity = velocity
		part.AssemblyAngularVelocity = roll
	end
end

local function stepView(character: Model, view: View, heldBy: number?, flight: TossPath.Flight?, now: number): ()
	local copy = view.Copy
	local body = if copy ~= nil then copy.Body else nil
	if flight ~= nil and now < TossPath.EndsAt(flight) then
		if view.StartedAt ~= flight.StartedAt then
			view.StartedAt = flight.StartedAt
			view.Dropped = false
			if body ~= nil then
				body.Anchored = true
			end
		end
		-- Clamped: a client whose clock runs a little behind holds the start pose instead of extrapolating.
		local elapsed = math.max(now - flight.StartedAt, 0)
		if elapsed < Tuning.FlightTime then
			if body ~= nil then
				local spin = elapsed * visuals.TumbleSpeed
				body.CFrame = CFrame.new(TossPath.Position(flight.From, flight.To, elapsed / Tuning.FlightTime))
					* CFrame.Angles(0, headingYaw(flight, 0), 0)
					* CFrame.Angles(math.rad(visuals.HeldTilt) - spin, 0, 0)
			end
		elseif not view.Dropped then
			drop(view, flight)
		end
		if copy ~= nil then
			local left = TossPath.EndsAt(flight) - now
			RagdollCopy.Fade(copy, math.clamp(1 - left / visuals.GetUpFade, 0, 1))
		end
		return
	end
	if heldBy ~= nil and body ~= nil then
		local bear = bearRoot(heldBy)
		if bear ~= nil then
			body.CFrame = heldPose(view, bear)
		end
	end
end

local function stepWatches(): ()
	local now = workspace:GetServerTimeNow()
	local seen: { [Model]: boolean } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character == nil then
			continue
		end
		seen[character] = true
		local watch = watches[character]
		if watch == nil then
			watch = { HeldBy = nil, StartedAt = nil, Landed = true, View = nil }
			watches[character] = watch
		end
		local heldBy = TossPath.HeldBy(character)
		if heldBy ~= nil and heldBy ~= watch.HeldBy then
			dipBear(heldBy, visuals.LiftDip)
		end
		local flight = TossPath.Flight(character)
		if flight ~= nil and flight.StartedAt ~= watch.StartedAt then
			watch.StartedAt = flight.StartedAt
			watch.Landed = false
			dipBear(watch.HeldBy, visuals.ThrowDip)
		end
		if flight ~= nil and not watch.Landed and now >= flight.StartedAt + Tuning.FlightTime then
			watch.Landed = true
			local queries = TossPath.Queries(character)
			landingDust(flight.To, if queries ~= nil then queries.Body.FeetDrop else 3)
			playSound("BearLand")
		end
		watch.HeldBy = heldBy or (if flight ~= nil then watch.HeldBy else nil)

		local tossed = heldBy ~= nil or (flight ~= nil and now < TossPath.EndsAt(flight))
		local view = watch.View
		if tossed and alive(character) then
			if view == nil then
				view = openView(character)
				watch.View = view
			end
			stepView(character, view :: View, heldBy, flight, now)
		elseif view ~= nil then
			watch.View = nil
			closeView(character, view)
			-- Back on its feet: a puff where it stands up.
			local root = rootOf(character)
			local queries = if root ~= nil then TossPath.Queries(character) else nil
			if root ~= nil and flight ~= nil then
				landingDust(root.Position, if queries ~= nil then queries.Body.FeetDrop else 3)
			end
		end
	end
	for character, watch in watches do
		if not seen[character] then
			if watch.View ~= nil then
				closeView(character, watch.View)
			end
			watches[character] = nil
		end
	end
end

function BearToss.Setup(): ()
	task.spawn(function(): ()
		local folder = InstantSkill.Folder("BearToss")
		ringTemplate = InstantSkill.Template(folder, "Ring", "BasePart") :: BasePart?
		beamTemplate = InstantSkill.Template(folder, "ArcBeam", "Beam") :: Beam?
		dustTemplate = InstantSkill.Template(folder, "Dust", "ParticleEmitter") :: ParticleEmitter?
	end)
	RunService.RenderStepped:Connect(function(): ()
		stepLocal()
		stepWatches()
		stepDips()
	end)
	localPlayer.CharacterAdded:Connect(function(): ()
		pin = nil
		SpeedController.SetRooted("Toss", false)
	end)
end

return BearToss
