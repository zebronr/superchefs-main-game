--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SpeedController = require(script.Parent.Parent.Controllers.SpeedController)
local InstantSkill = require(script.Parent.InstantSkill)
local Particles = require(script.Parent.Parent.Util.Particles)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local HustleConfig = Config.Skills.Hustle
local visuals = HustleConfig.Visuals
local SkillEffects = require(Shared:WaitForChild("Util"):WaitForChild("SkillEffects"))

-- Bill: Hustle, client side. The local player speeds up on press; every client draws Hustle for every hustling Bill
-- from HustleUntil: a squash-and-spring with a steam puff at the start, speed lines (while moving), the trail and
-- sweat flicks during, and an exhale puff at the end. Time left shows on Bill himself: the lines and trail thin out
-- like fuel running low, sputter near the end, and he blinks white a few times just before it's over. Templates live in Assets.Skills.Hustle.

type Spring = { Joint: Motor6D, Original: CFrame }

-- A blink borrows the character's own player-color Highlight (Roblox draws only one Highlight per character, so a
-- second one would hide it) and puts its fill back afterwards.
type Blink = { Highlight: Highlight, FillColor: Color3, FillTransparency: number }

type Visual = {
	Trail: Trail?,
	-- The trail template's WidthScale, shrunk as the fuel runs out.
	TrailWidth: NumberSequence?,
	Blink: Blink?,
	Attachments: { Attachment },
	Lines: ParticleEmitter?,
	Spring: Spring?,
	-- Server time Hustle started (the spring's timeline).
	StartedAt: number,
	NextSweat: number,
}

local localPlayer = Players.LocalPlayer
local trailTemplate: Trail? = nil
local linesTemplate: ParticleEmitter? = nil
local sweatTemplate: ParticleEmitter? = nil
local steamTemplate: ParticleEmitter? = nil
local exhaleTemplate: ParticleEmitter? = nil
local random = Random.new()

-- Local prediction: os.clock() when the local Hustle ends.
local predictedUntil: number? = nil
local active: { [Model]: Visual } = {}

local function head(character: Model): BasePart?
	local part = character:FindFirstChild("Head")
	return if part ~= nil and part:IsA("BasePart") then part else nil
end

-- Upright, on top of the head.
local function headTop(part: BasePart): CFrame
	return CFrame.new(part.Position + Vector3.new(0, part.Size.Y / 2, 0))
end

-- Fires a puff that rides along with `part` (LockedToPart), at `offset` in the part's space. A world-space burst gets
-- left behind: a running Bill overtakes it within a frame or two and it shows up inside his head.
local function puff(template: ParticleEmitter?, part: BasePart, offset: CFrame, count: number): ()
	if template == nil or count <= 0 then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "HustlePuff"
	attachment.CFrame = offset
	local emitter = template:Clone()
	emitter.Enabled = false
	emitter.LockedToPart = true
	emitter.Parent = attachment
	attachment.Parent = part
	emitter:Emit(count)
	task.delay(emitter.Lifetime.Max + 0.1, attachment.Destroy, attachment)
end

-- In front of the face along the direction Bill faces (the root's, so head bobs don't aim it), facing forward.
local function inFront(face: BasePart, root: BasePart, distance: number): CFrame
	local forward = face.CFrame:VectorToObjectSpace(root.CFrame.LookVector)
	local position = forward * distance
	return CFrame.lookAt(position, position + forward)
end

local function endBlink(visual: Visual): ()
	local blink = visual.Blink
	visual.Blink = nil
	if blink ~= nil and blink.Highlight.Parent ~= nil then
		blink.Highlight.FillColor = blink.FillColor
		blink.Highlight.FillTransparency = blink.FillTransparency
	end
end

local function stopSpring(visual: Visual): ()
	local spring = visual.Spring
	visual.Spring = nil
	if spring ~= nil and spring.Joint.Parent ~= nil then
		spring.Joint.C0 = spring.Original
	end
end

local function removeVisual(character: Model, exhale: boolean): ()
	local visual = active[character]
	if visual == nil then
		return
	end
	active[character] = nil
	stopSpring(visual)
	if visual.Trail ~= nil then
		visual.Trail:Destroy()
	end
	for _, attachment in visual.Attachments do
		attachment:Destroy()
	end
	if visual.Lines ~= nil then
		visual.Lines:Destroy()
	end
	endBlink(visual)
	local face = head(character)
	local root = InstantSkill.Root(character)
	if exhale and face ~= nil and root ~= nil then
		puff(exhaleTemplate, face, inFront(face, root, visuals.ExhaleForward), visuals.EndCount)
	end
end

local function addVisual(character: Model, startedAt: number): ()
	local root = InstantSkill.Root(character)
	if root == nil or active[character] ~= nil then
		return
	end
	local visual: Visual = {
		Trail = nil,
		TrailWidth = nil,
		Blink = nil,
		Attachments = {},
		Lines = nil,
		Spring = nil,
		StartedAt = startedAt,
		NextSweat = os.clock() + random:NextNumber(visuals.SweatInterval[1], visuals.SweatInterval[2]),
	}
	if trailTemplate ~= nil then
		local top = Instance.new("Attachment")
		top.Name = "HustleTrailTop"
		top.Position = Vector3.new(0, visuals.TrailWidth / 2, 0)
		top.Parent = root
		local bottom = Instance.new("Attachment")
		bottom.Name = "HustleTrailBottom"
		bottom.Position = Vector3.new(0, -visuals.TrailWidth / 2, 0)
		bottom.Parent = root
		local trail = trailTemplate:Clone()
		trail.Attachment0 = top
		trail.Attachment1 = bottom
		trail.Enabled = true
		trail.Parent = root
		visual.Trail = trail
		visual.TrailWidth = trail.WidthScale
		visual.Attachments = { top, bottom }
	end
	if linesTemplate ~= nil then
		-- On the root part, so the lines start all over the body's box and fly out behind it.
		local lines = linesTemplate:Clone()
		lines.Enabled = false
		lines.Parent = root
		visual.Lines = lines
	end
	-- A late joiner (or a Bill streaming in mid-Hustle) skips the start: no spring, no steam.
	if workspace:GetServerTimeNow() - startedAt < visuals.SpringTime then
		local joint = InstantSkill.RootJoint(character)
		if joint ~= nil and visuals.SpringDip > 0 then
			visual.Spring = { Joint = joint, Original = joint.C0 }
		end
		local face = head(character)
		if face ~= nil then
			-- In front of the face, puffing up (the template emits Top), so it never draws inside the head.
			puff(steamTemplate, face, inFront(face, root, visuals.SteamForward), visuals.StartCount)
		end
	end
	active[character] = visual
end

local function scaled(sequence: NumberSequence, scale: number): NumberSequence
	local keypoints = {}
	for _, keypoint in sequence.Keypoints do
		table.insert(keypoints, NumberSequenceKeypoint.new(keypoint.Time, keypoint.Value * scale, keypoint.Envelope * scale))
	end
	return NumberSequence.new(keypoints)
end

-- Seconds of Hustle left: the local prediction's own clock for the local player, otherwise HustleUntil.
local function remainingOf(character: Model, now: number): number
	if character == localPlayer.Character and predictedUntil ~= nil then
		return predictedUntil - os.clock()
	end
	local hustleUntil = character:GetAttribute(Config.Skills.Attribute.HustleUntil)
	return if typeof(hustleUntil) == "number" then hustleUntil - now else 0
end

local function stepVisual(character: Model, visual: Visual, now: number): ()
	local remaining = math.max(remainingOf(character, now), 0)
	-- Fuel: full at the start, FuelMin at the end. Sputtering cuts the trail and lines on and off near the end,
	-- timed from the time left so every client cuts in step.
	local fuel = visuals.FuelMin + (1 - visuals.FuelMin) * math.clamp(remaining / HustleConfig.Duration, 0, 1)
	local on = remaining > visuals.SputterTime or (remaining * visuals.SputterRate) % 1 < visuals.SputterOn
	if visual.Trail ~= nil and visual.TrailWidth ~= nil then
		visual.Trail.Enabled = on
		visual.Trail.WidthScale = scaled(visual.TrailWidth, fuel)
	end
	local white = false
	for _, at in visuals.BlinkAt do
		if remaining <= at and remaining > at - visuals.BlinkLength then
			white = true
		end
	end
	if white and visual.Blink == nil then
		local highlight = InstantSkill.CharacterHighlight(character)
		if highlight ~= nil then
			visual.Blink = {
				Highlight = highlight,
				FillColor = highlight.FillColor,
				FillTransparency = highlight.FillTransparency,
			}
			highlight.FillColor = visuals.BlinkColor
			highlight.FillTransparency = visuals.BlinkTransparency
		end
	elseif not white then
		endBlink(visual)
	end
	local spring = visual.Spring
	if spring ~= nil then
		local t = math.clamp((now - visual.StartedAt) / visuals.SpringTime, 0, 1)
		if t >= 1 or spring.Joint.Parent == nil then
			stopSpring(visual)
		else
			-- Quick squash down, then spring back up past rest with a wobble.
			local dip = if t < 0.25
				then InstantSkill.ExpoOut(t / 0.25)
				else 1 - InstantSkill.Elastic((t - 0.25) / 0.75, visuals.SpringWobble)
			spring.Joint.C0 = CFrame.new(0, -visuals.SpringDip * dip, 0) * spring.Original
		end
	end
	local lines = visual.Lines
	local root = InstantSkill.Root(character)
	if lines ~= nil and root ~= nil then
		local velocity = root.AssemblyLinearVelocity
		if on and Vector3.new(velocity.X, 0, velocity.Z).Magnitude > visuals.LineMinSpeed then
			Particles.Stream(lines, (linesTemplate :: ParticleEmitter).Rate * fuel)
		else
			Particles.Stop(lines)
		end
	end
	if os.clock() >= visual.NextSweat then
		visual.NextSweat = os.clock() + random:NextNumber(visuals.SweatInterval[1], visuals.SweatInterval[2])
		local face = head(character)
		if face ~= nil then
			InstantSkill.Burst(sweatTemplate, headTop(face), visuals.SweatCount)
		end
	end
end

-- Server time the character's Hustle started, from HustleUntil (nil when the server hasn't said).
local function startedAtOf(character: Model): number?
	local hustleUntil = character:GetAttribute(Config.Skills.Attribute.HustleUntil)
	return if typeof(hustleUntil) == "number" then hustleUntil - HustleConfig.Duration else nil
end

local function isHustling(character: Model, now: number): boolean
	if character == localPlayer.Character and predictedUntil ~= nil then
		return true
	end
	return SkillEffects.HustleActive(character, now)
end

local function step(): ()
	local now = workspace:GetServerTimeNow()
	local character = localPlayer.Character
	local endsAt = predictedUntil
	if endsAt ~= nil and os.clock() >= endsAt then
		predictedUntil = nil
	end
	-- Speed follows the prediction on local time, then whatever the server says.
	SpeedController.SetMultiplier(
		"Hustle",
		if character ~= nil and isHustling(character, now) then HustleConfig.MoveMultiplier else nil
	)

	local seen: { [Model]: boolean } = {}
	for _, player in Players:GetPlayers() do
		local other = player.Character
		if other ~= nil and isHustling(other, now) then
			seen[other] = true
			addVisual(other, startedAtOf(other) or now)
		end
	end
	for model, visual in table.clone(active) do
		if not seen[model] then
			removeVisual(model, model.Parent ~= nil)
		else
			stepVisual(model, visual, now)
		end
	end
end

local Hustle: InstantSkill.InstantSkill = {
	RequiresEmptyHands = false,
	Setup = function(): ()
		local folder = InstantSkill.Folder("Hustle")
		trailTemplate = InstantSkill.Template(folder, "SpeedTrail", "Trail") :: Trail?
		linesTemplate = InstantSkill.Template(folder, "SpeedLines", "ParticleEmitter") :: ParticleEmitter?
		sweatTemplate = InstantSkill.Template(folder, "Sweat", "ParticleEmitter") :: ParticleEmitter?
		steamTemplate = InstantSkill.Template(folder, "Steam", "ParticleEmitter") :: ParticleEmitter?
		exhaleTemplate = InstantSkill.Template(folder, "Exhale", "ParticleEmitter") :: ParticleEmitter?
		RunService.Heartbeat:Connect(step)
	end,
	CanUse = function(_character: Model): boolean
		return true
	end,
	Predict = function(character: Model): ()
		predictedUntil = os.clock() + HustleConfig.Duration
		SpeedController.SetMultiplier("Hustle", HustleConfig.MoveMultiplier)
		addVisual(character, workspace:GetServerTimeNow())
	end,
	Rollback = function(): ()
		predictedUntil = nil
		SpeedController.SetMultiplier("Hustle", nil)
		local character = localPlayer.Character
		if character ~= nil and not SkillEffects.HustleActive(character) then
			removeVisual(character, false)
		end
	end,
	IsBusy = function(): boolean
		return false
	end,
}

return Hustle
