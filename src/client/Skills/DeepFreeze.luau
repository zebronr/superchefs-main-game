--!strict

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local SpeedController = require(script.Parent.Parent.Controllers.SpeedController)
local InstantSkill = require(script.Parent.InstantSkill)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local FreezeConfig = Config.Skills.DeepFreeze
local visuals = FreezeConfig.Visuals
local FrozenAttribute = Config.Skills.Attribute.FrozenAt
local SkillEffects = require(Shared:WaitForChild("Util"):WaitForChild("SkillEffects"))
local Tags = require(Shared:WaitForChild("Tags"))

-- Every client renders this superskill from zone times and FrozenAt; only the local cast is predicted.
local localPlayer = Players.LocalPlayer
local circleTemplate: BasePart? = nil
local shockwaveTemplate: BasePart? = nil
local capTemplate: MeshPart? = nil
local iceBlockTemplate: BasePart? = nil
local chunkTemplate: MeshPart? = nil
local spikeTemplate: MeshPart? = nil
local highlightTemplate: Highlight? = nil
local snowTemplate: ParticleEmitter? = nil
local shatterTemplate: ParticleEmitter? = nil
local breathTemplate: ParticleEmitter? = nil
local glintTemplate: ParticleEmitter? = nil
local mistTemplate: ParticleEmitter? = nil
local snowfallTemplate: ParticleEmitter? = nil
local glowTemplate: Highlight? = nil
local stationFrostTemplate: BasePart? = nil
local sounds: { [string]: Sound? } = {}
-- Per-client noise only (glint spots). Shard and spike paths use seeded generators instead.
local random = Random.new()

type Spike = {
	Part: MeshPart,
	Base: CFrame,
	Size: Vector3,
	Delay: number,
	Direction: Vector3,
	Transparency: number,
	BurstPlayed: boolean,
}
type StationFrost = {
	Part: BasePart,
	Top: CFrame,
	Size: Vector3,
	Delay: number,
	Transparency: number,
}
type Circle = {
	Part: BasePart?,
	Shockwave: BasePart?,
	Cracks: { Decal },
	Frost: { Decal },
	WaveDecals: { Decal },
	Spikes: { Spike },
	-- Atmosphere: mist over the ice, snow falling from Sky, and the Penguin's glow for the whole freeze.
	Emitters: { ParticleEmitter },
	Sky: BasePart?,
	Glow: Highlight?,
	-- White frost slabs on top of the stations inside the circle, so players see what got frozen.
	StationFrosts: { StationFrost },
	GlowFill: number,
	GlowOutline: number,
	Seed: number,
	Floor: Vector3,
	StartedAt: number,
	Until: number,
	EndAt: number?,
	CutShort: boolean,
	CrackPlayed: boolean,
	ShatterPlayed: boolean,
}
type FrozenVisual = {
	Highlight: Highlight?,
	Cap: MeshPart?,
	Block: BasePart?,
	BlockTransparency: number,
	Tracks: { [AnimationTrack]: number },
	NextShiver: number,
	ShiverAt: number?,
	IsTool: boolean,
	StartedAt: number,
	ThawAt: number?,
	Fill: Color3,
	FillTransparency: number,
	OutlineTransparency: number,
	NextBreath: number,
	NextGlint: number,
}
type Shard = {
	Part: MeshPart,
	Origin: Vector3,
	Velocity: Vector3,
	Spin: Vector3,
	StartedAt: number,
	Size: Vector3,
	Transparency: number,
}
type Stomp = { Joint: Motor6D, Original: CFrame, StartedAt: number }

local predicted: SkillEffects.Zone? = nil
local predictedExpiresAt = 0
local circles: { [Model]: Circle } = {}
local frozen: { [Instance]: FrozenVisual } = {}
local shards: { Shard } = {}
local stomps: { [Model]: Stomp } = {}
local highlightScanAt = 0
local controls: any = nil
local slide = Vector3.zero

local function expoOut(t: number): number
	return if t >= 1 then 1 else 1 - 2 ^ (-10 * t)
end

local function quartIn(t: number): number
	return t ^ 4
end

local function elastic(t: number, wobble: number): number
	if t <= 0 then
		return 0
	elseif t >= 1 then
		return 1
	end
	return expoOut(t) + wobble * math.sin(t * math.pi * 5) * (1 - t) ^ 2
end

local function soundAt(name: string, position: Vector3): ()
	local template = sounds[name]
	if template == nil then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = position
	attachment.Parent = workspace.Terrain
	local sound = template:Clone()
	sound.Parent = attachment
	sound.Ended:Connect(function(): ()
		attachment:Destroy()
	end)
	sound:Play()
	task.delay(math.max(sound.TimeLength, 1) + 2, function(): ()
		if attachment.Parent ~= nil then
			attachment:Destroy()
		end
	end)
end

local function floorBelow(center: Vector3, owner: Model): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = { owner }
	for _, player in Players:GetPlayers() do
		if player.Character ~= nil then
			table.insert(exclude, player.Character)
		end
	end
	params.FilterDescendantsInstances = exclude
	local hit = workspace:Raycast(center, Vector3.new(0, -FreezeConfig.Height, 0), params)
	return if hit ~= nil then hit.Position else center - Vector3.new(0, 3, 0)
end

local function jointOf(character: Model): Motor6D?
	local root = InstantSkill.Root(character)
	local r6 = if root then root:FindFirstChild("RootJoint") else nil
	if r6 ~= nil and r6:IsA("Motor6D") then
		return r6
	end
	local torso = character:FindFirstChild("LowerTorso")
	local r15 = if torso then torso:FindFirstChild("Root") else nil
	return if r15 ~= nil and r15:IsA("Motor6D") then r15 else nil
end

local function startStomp(character: Model, startedAt: number): ()
	if visuals.StompDip <= 0 or visuals.StompTime <= 0 then
		return
	end
	local previous = stomps[character]
	local joint = jointOf(character)
	if joint == nil then
		return
	end
	stomps[character] = {
		Joint = joint,
		Original = if previous ~= nil and previous.Joint == joint then previous.Original else joint.C0,
		StartedAt = startedAt,
	}
end

local function stepStomps(now: number): ()
	for character, stomp in stomps do
		local t = math.clamp((now - stomp.StartedAt) / visuals.StompTime, 0, 1)
		if t >= 1 or character.Parent == nil or stomp.Joint.Parent == nil then
			stomp.Joint.C0 = stomp.Original
			stomps[character] = nil
		else
			local dip = if t < 0.22 then expoOut(t / 0.22) else 1 - elastic((t - 0.22) / 0.78, 0.22)
			stomp.Joint.C0 = stomp.Original * CFrame.new(0, -visuals.StompDip * dip, 0)
		end
	end
end

local function collectDecals(part: BasePart, name: string): { Decal }
	local result: { Decal } = {}
	for _, descendant in part:GetDescendants() do
		if descendant:IsA("Decal") and descendant.Name == name then
			table.insert(result, descendant)
		end
	end
	return result
end

-- The superskill's spike layout comes only from replicated owner and start time.
local function spikeSeed(owner: Model, startedAt: number): number
	local player = Players:GetPlayerFromCharacter(owner)
	local ownerId = if player ~= nil then player.UserId else 0
	if player == nil then
		for index = 1, #owner.Name do
			ownerId = (ownerId * 31 + string.byte(owner.Name, index)) % 2147483647
		end
	end
	return (ownerId * 65599 + math.floor(startedAt * 2 + 0.5)) % 2147483647
end

local function addSpikes(circle: Circle, zone: SkillEffects.Zone): ()
	local template = spikeTemplate
	if template == nil or visuals.SpikeCount <= 0 then
		return
	end
	local rng = Random.new(spikeSeed(zone.Owner, zone.StartedAt))
	local count = math.floor(visuals.SpikeCount)
	local phase = rng:NextNumber(0, math.pi * 2)
	for index = 1, count do
		local edge = index % 3 ~= 0
		local fraction = if edge then rng:NextNumber(0.8, 1.05) else rng:NextNumber(0.35, 0.8)
		local radius = math.max(FreezeConfig.Radius * fraction, visuals.SpikeClearance)
		local angle = phase + (index - 1 + rng:NextNumber(-0.25, 0.25)) * math.pi * 2 / count
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local position = circle.Floor + direction * radius
		local yaw = rng:NextNumber(-math.pi, math.pi)
		local lean = math.rad(rng:NextNumber(0, visuals.SpikeLean))
		local base = CFrame.lookAt(position, position + direction) * CFrame.Angles(-lean, yaw, 0)
		local scale = rng:NextNumber(visuals.SpikeScaleMin, visuals.SpikeScaleMax)
		if edge then
			scale = math.max(scale, rng:NextNumber(visuals.SpikeScaleMin, visuals.SpikeScaleMax))
		end
		local spike = template:Clone()
		spike.Anchored = true
		spike.CanCollide = false
		spike.CanQuery = false
		spike.CanTouch = false
		spike.CastShadow = true
		spike.CFrame = base
		spike.Size = template.Size * 0.01
		spike.Transparency = 1
		spike.Parent = workspace
		table.insert(circle.Spikes, {
			Part = spike, Base = base, Size = template.Size * scale,
			Delay = visuals.SpikeSpreadTime * math.min(radius / FreezeConfig.Radius, 1) + rng:NextNumber(0, visuals.SpikeSpreadTime * 0.13),
			Direction = direction, Transparency = template.Transparency, BurstPlayed = false,
		})
	end
end

local STATION_CLASSES = {
	-- Flat-topped stations only: the sink tap and serving window awning are not worktops.
	Tags.Countertop, Tags.ChoppingBoard, Tags.FoodContainer, Tags.PlateTable,
	Tags.CustomerTable, Tags.Trash, Tags.Stove,
}

local function addStationFrosts(circle: Circle): ()
	local template = stationFrostTemplate
	if template == nil or visuals.StationFrostFit <= 0 then
		return
	end
	for _, className in STATION_CLASSES do
		for _, station in CollectionService:GetTagged(Tags.ClassTag(className)) do
			if not station:IsDescendantOf(workspace) then
				continue
			end
			local box: CFrame, size: Vector3
			if station:IsA("Model") then
				box, size = station:GetBoundingBox()
			elseif station:IsA("BasePart") then
				box, size = station.CFrame, station.Size
			else
				continue
			end
			local offset = box.Position - circle.Floor
			local distance = Vector3.new(offset.X, 0, offset.Z).Magnitude
			if distance > FreezeConfig.Radius then
				continue
			end
			local part = template:Clone()
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
			part.Size = template.Size * 0.01
			part.Transparency = 1
			part.Parent = workspace
			local flat = box.Rotation
			table.insert(circle.StationFrosts, {
				Part = part,
				Top = CFrame.new(box.Position + box.UpVector * (size.Y / 2)) * flat,
				Size = Vector3.new(size.X * visuals.StationFrostFit, template.Size.Y, size.Z * visuals.StationFrostFit),
				Delay = visuals.SpikeSpreadTime * math.min(distance / FreezeConfig.Radius, 1),
				Transparency = template.Transparency,
			})
		end
	end
end

local function drawStationFrosts(circle: Circle, now: number, fade: number): ()
	for _, frost in circle.StationFrosts do
		local t = if visuals.FrostCapTime > 0 then math.clamp((now - circle.StartedAt - frost.Delay) / visuals.FrostCapTime, 0, 1) else 1
		local grow = math.max(elastic(t, visuals.GrowWobble), 0.01)
		local size = Vector3.new(frost.Size.X * grow, frost.Size.Y, frost.Size.Z * grow)
		frost.Part.Size = size
		frost.Part.CFrame = frost.Top * CFrame.new(0, size.Y / 2, 0)
		frost.Part.Transparency = if t <= 0 then 1 else frost.Transparency + (1 - frost.Transparency) * fade
	end
end

local function addCircle(zone: SkillEffects.Zone, now: number): Circle
	local floor = floorBelow(zone.Center, zone.Owner)
	local circle: Circle = {
		Part = nil, Shockwave = nil, Cracks = {}, Frost = {}, WaveDecals = {}, Spikes = {},
		Emitters = {}, Sky = nil, Glow = nil, StationFrosts = {}, GlowFill = 1, GlowOutline = 1, Seed = spikeSeed(zone.Owner, zone.StartedAt),
		Floor = floor, StartedAt = zone.StartedAt, Until = zone.Until,
		EndAt = nil, CutShort = false, CrackPlayed = false, ShatterPlayed = false,
	}
	if circleTemplate ~= nil and visuals.FrostScale > 0 then
		local part = circleTemplate:Clone()
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		circle.Cracks = collectDecals(part, "Cracks")
		circle.Frost = collectDecals(part, "Frost")
		for _, decal in circle.Cracks do
			decal.Transparency = 1
		end
		part.Parent = workspace
		circle.Part = part
		if mistTemplate ~= nil then
			local mist = mistTemplate:Clone()
			mist.Enabled = true
			mist.Parent = part
			table.insert(circle.Emitters, mist)
		end
	end
	if snowfallTemplate ~= nil and visuals.SnowfallHeight > 0 then
		local sky = Instance.new("Part")
		sky.Name = "DeepFreezeSky"
		sky.Transparency = 1
		sky.Anchored = true
		sky.CanCollide = false
		sky.CanQuery = false
		sky.CanTouch = false
		sky.CastShadow = false
		local diameter = FreezeConfig.Radius * 2
		sky.Size = Vector3.new(diameter, 0.05, diameter)
		sky.CFrame = CFrame.new(floor + Vector3.new(0, visuals.SnowfallHeight, 0))
		local snowfall = snowfallTemplate:Clone()
		snowfall.Enabled = true
		snowfall.Parent = sky
		table.insert(circle.Emitters, snowfall)
		sky.Parent = workspace
		circle.Sky = sky
	end
	if glowTemplate ~= nil then
		local glow = glowTemplate:Clone()
		circle.GlowFill = glow.FillTransparency
		circle.GlowOutline = glow.OutlineTransparency
		glow.Adornee = zone.Owner
		glow.Parent = zone.Owner
		circle.Glow = glow
	end
	if shockwaveTemplate ~= nil and visuals.ShockwaveScale > 0 and visuals.ShockwaveTime > 0 then
		local wave = shockwaveTemplate:Clone()
		wave.Anchored = true
		wave.CanCollide = false
		wave.CanQuery = false
		wave.CanTouch = false
		wave.CastShadow = false
		for _, descendant in wave:GetDescendants() do
			if descendant:IsA("Decal") then
				table.insert(circle.WaveDecals, descendant)
			end
		end
		wave.Parent = workspace
		circle.Shockwave = wave
	end
	addSpikes(circle, zone)
	addStationFrosts(circle)
	circles[zone.Owner] = circle
	if now - zone.StartedAt < visuals.GrowTime then
		InstantSkill.Burst(snowTemplate, CFrame.lookAt(floor, floor + Vector3.yAxis), visuals.BurstCount)
		soundAt("FreezeStomp", floor)
		soundAt("FreezeWhoosh", floor)
	end
	startStomp(zone.Owner, zone.StartedAt)
	return circle
end

local function destroyCircle(owner: Model, circle: Circle): ()
	if circle.Part ~= nil then
		circle.Part:Destroy()
	end
	if circle.Shockwave ~= nil then
		circle.Shockwave:Destroy()
	end
	for _, spike in circle.Spikes do
		spike.Part:Destroy()
	end
	if circle.Sky ~= nil then
		circle.Sky:Destroy()
	end
	if circle.Glow ~= nil then
		circle.Glow:Destroy()
	end
	for _, frost in circle.StationFrosts do
		frost.Part:Destroy()
	end
	circles[owner] = nil
end

local function spawnShard(origin: Vector3, outward: Vector3, now: number, rng: Random): ()
	if chunkTemplate == nil or visuals.ShardTime <= 0 then
		return
	end
	local part = chunkTemplate:Clone()
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Size *= rng:NextNumber(visuals.ShardSizeMin, visuals.ShardSizeMax)
	part.CFrame = CFrame.new(origin)
	part.Parent = workspace
	table.insert(shards, {
		Part = part, Origin = origin,
		Velocity = outward * visuals.ShardSpeed + Vector3.yAxis * visuals.ShardUpSpeed,
		Spin = Vector3.new(rng:NextNumber(-12, 12), rng:NextNumber(-12, 12), rng:NextNumber(-12, 12)),
		StartedAt = now, Size = part.Size, Transparency = part.Transparency,
	})
end

local function shatterCircle(circle: Circle, now: number): ()
	if circle.ShatterPlayed then
		return
	end
	circle.ShatterPlayed = true
	InstantSkill.Burst(shatterTemplate, CFrame.lookAt(circle.Floor, circle.Floor + Vector3.yAxis), visuals.ShatterCount)
	soundAt("FreezeShatter", circle.Floor)
	local rng = Random.new(circle.Seed + 1)
	for _ = 1, visuals.ShardCount do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = FreezeConfig.Radius * math.sqrt(rng:NextNumber())
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		spawnShard(circle.Floor + direction * radius, direction, now, rng)
	end
	for _, spike in circle.Spikes do
		for _ = 1, visuals.SpikeShards do
			spawnShard(spike.Base.Position + spike.Base.UpVector * (spike.Size.Y * 0.5), spike.Direction, now, rng)
		end
	end
end

local function stepShards(now: number): ()
	for index = #shards, 1, -1 do
		local shard = shards[index]
		local age = now - shard.StartedAt
		if age >= visuals.ShardTime or shard.Part.Parent == nil then
			shard.Part:Destroy()
			table.remove(shards, index)
		else
			local t = math.clamp(age / visuals.ShardTime, 0, 1)
			local position = shard.Origin + shard.Velocity * age - Vector3.yAxis * (visuals.ShardGravity * age * age / 2)
			shard.Part.CFrame = CFrame.new(position) * CFrame.Angles(shard.Spin.X * age, shard.Spin.Y * age, shard.Spin.Z * age)
			shard.Part.Size = shard.Size * math.max(1 - quartIn(t), 0.01)
			shard.Part.Transparency = shard.Transparency + (1 - shard.Transparency) * quartIn(t)
		end
	end
end

local function drawSpikes(circle: Circle, now: number, shake: Vector3): ()
	local age = now - circle.StartedAt
	local endAt = circle.EndAt
	for _, spike in circle.Spikes do
		local riseAge = age - spike.Delay
		local height = if visuals.SpikeRiseTime > 0 then elastic(math.clamp(riseAge / visuals.SpikeRiseTime, 0, 1), visuals.GrowWobble) else 1
		height = math.max(height, 0.01)
		local width = if height < 1 then 0.7 + 0.3 * height else 1 + (height - 1) * 0.5
		local fade = 0
		if endAt ~= nil then
			local fadeTime = if circle.CutShort then visuals.CutFadeTime else visuals.ShatterTime
			local t = if fadeTime > 0 then math.clamp((now - endAt) / fadeTime, 0, 1) else 1
			if circle.CutShort then
				height *= 1 - quartIn(t)
				fade = quartIn(t)
			else
				local pop = math.min(t / 0.3, 1)
				local shrink = math.clamp((t - 0.3) / 0.7, 0, 1)
				height *= (1 + 0.1 * expoOut(pop)) * (1 - quartIn(shrink))
				width *= 1 + 0.1 * expoOut(pop)
				fade = shrink
			end
		end
		local part = spike.Part
		local size = Vector3.new(spike.Size.X * width, spike.Size.Y * math.max(height, 0.01), spike.Size.Z * width)
		part.Size = size
		-- A MeshPart's CFrame is its box centre: lift by half its height so it grows up from its base.
		part.CFrame = spike.Base * CFrame.new(0, size.Y / 2, 0) + shake
		part.Transparency = if riseAge < 0 then 1 else spike.Transparency + (1 - spike.Transparency) * fade
		if not spike.BurstPlayed and riseAge >= 0 then
			spike.BurstPlayed = true
			if riseAge < math.max(visuals.SpikeRiseTime, 0.001) and endAt == nil then
				InstantSkill.Burst(snowTemplate, CFrame.lookAt(spike.Base.Position, spike.Base.Position + Vector3.yAxis), visuals.SpikeBurstCount)
			end
		end
	end
end

local function drawCircle(circle: Circle, now: number): ()
	local age = now - circle.StartedAt
	local grow = if visuals.GrowTime > 0 then math.clamp(age / visuals.GrowTime, 0, 1) else 1
	local size = if age < visuals.GrowTime then elastic(grow, visuals.GrowWobble) else 1 + visuals.IdleBreathe * math.sin((age - visuals.GrowTime) * visuals.IdleBreatheSpeed)
	local endAge = if circle.EndAt ~= nil then math.max(now - circle.EndAt, 0) else 0
	local fadeTime = if circle.CutShort then visuals.CutFadeTime else visuals.ShatterTime
	if circle.EndAt ~= nil and not circle.CutShort then
		local t = if visuals.ShatterTime > 0 then math.clamp(endAge / visuals.ShatterTime, 0, 1) else 1
		size *= 1 + visuals.ShatterPop * (1 - quartIn(t))
	end
	-- Time left reads at a glance: the ice melts in from the rim and cracks spread over the whole freeze.
	local spread = math.clamp(age / math.max(circle.Until - circle.StartedAt, 0.001), 0, 1)
	size *= 1 - visuals.MeltShrink * spread
	local shake = Vector3.zero
	local crack = if visuals.CrackTime > 0 then math.clamp(1 - (circle.Until - now) / visuals.CrackTime, 0, 1) else 0
	if circle.EndAt == nil and visuals.CrackShake > 0 and visuals.CrackSteps > 0 and crack > 0 then
		local step = math.floor(now * visuals.CrackSteps)
		shake = Vector3.new(math.sin(step * 17.31), 0, math.sin(step * 29.17)) * visuals.CrackShake * quartIn(crack)
	end
	local part = circle.Part
	local template = circleTemplate
	if part ~= nil and template ~= nil then
		local diameter = FreezeConfig.Radius * 2 * visuals.FrostScale * math.max(size, 0.01)
		part.Size = Vector3.new(diameter, template.Size.Y, diameter)
		-- The ice's top face sits GroundOffset above the floor, under the player's indicator ring.
		part.CFrame = CFrame.new(circle.Floor + shake + Vector3.new(0, -template.Size.Y / 2 + visuals.GroundOffset, 0))
		local fade = if circle.EndAt ~= nil then (if fadeTime > 0 then quartIn(math.clamp(endAge / fadeTime, 0, 1)) else 1) else 0
		part.Transparency = template.Transparency + (1 - template.Transparency) * fade
		for _, decal in circle.Frost do
			decal.Transparency = fade
		end
		for _, decal in circle.Cracks do
			local shown = visuals.CrackSpread * spread + (1 - visuals.CrackSpread) * crack
			decal.Transparency = 1 - shown * (1 - fade)
		end
	end
	drawSpikes(circle, now, shake)
	local glow = circle.Glow
	if glow ~= nil then
		local glowFade = if circle.EndAt ~= nil then (if fadeTime > 0 then math.clamp(endAge / fadeTime, 0, 1) else 1) else 0
		glow.FillTransparency = circle.GlowFill + (1 - circle.GlowFill) * glowFade
		glow.OutlineTransparency = circle.GlowOutline + (1 - circle.GlowOutline) * glowFade
	end
	for _, emitter in circle.Emitters do
		emitter.Enabled = circle.EndAt == nil
	end
	drawStationFrosts(circle, now, if circle.EndAt ~= nil then (if fadeTime > 0 then quartIn(math.clamp(endAge / fadeTime, 0, 1)) else 1) else 0)
	local wave = circle.Shockwave
	local waveTemplate = shockwaveTemplate
	if wave ~= nil and waveTemplate ~= nil then
		local t = math.clamp(age / visuals.ShockwaveTime, 0, 1)
		local diameter = FreezeConfig.Radius * 2 * visuals.ShockwaveScale * math.max(expoOut(t), 0.01)
		wave.Size = Vector3.new(diameter, waveTemplate.Size.Y, diameter)
		local frostHeight = 0
		if template ~= nil then
			frostHeight = template.Size.Y
		end
		wave.CFrame = CFrame.new(circle.Floor + Vector3.new(0, waveTemplate.Size.Y / 2 - frostHeight + visuals.GroundOffset, 0))
		for _, decal in circle.WaveDecals do
			decal.Transparency = t
		end
		if t >= 1 then
			wave:Destroy()
			circle.Shockwave = nil
		end
	end
	if crack > 0 and not circle.CrackPlayed and circle.EndAt == nil then
		circle.CrackPlayed = true
		soundAt("FreezeCrack", circle.Floor)
	end
end

local function currentZones(now: number): { SkillEffects.Zone }
	local zones = SkillEffects.FreezeZones(now)
	local guess = predicted
	if guess ~= nil then
		local confirmed = false
		for _, zone in zones do
			if zone.Owner == guess.Owner and math.abs(zone.StartedAt - guess.StartedAt) <= Config.Skills.MaxLagCompensation + 0.1 then
				confirmed = true
			end
		end
		if confirmed or os.clock() >= predictedExpiresAt or guess.Owner.Parent == nil then
			predicted = nil
		else
			table.insert(zones, guess)
		end
	end
	return zones
end

local function updateCircles(zones: { SkillEffects.Zone }, now: number): ()
	local seen: { [Model]: boolean } = {}
	for _, zone in zones do
		seen[zone.Owner] = true
		local circle: Circle? = circles[zone.Owner]
		if circle ~= nil and math.abs(circle.StartedAt - zone.StartedAt) > Config.Skills.MaxLagCompensation + 0.1 then
			destroyCircle(zone.Owner, circle)
			circle = nil
		end
		local active = circle or addCircle(zone, now)
		active.StartedAt = zone.StartedAt
		active.Until = zone.Until
		active.EndAt = nil
		active.CutShort = false
		local stomp = stomps[zone.Owner]
		if stomp ~= nil then
			stomp.StartedAt = zone.StartedAt
		end
		drawCircle(active, now)
	end
	for owner, circle in circles do
		if not seen[owner] then
			if circle.EndAt == nil then
				circle.CutShort = now < circle.Until - 0.1 or owner.Parent == nil
				circle.EndAt = if circle.CutShort then now else circle.Until
				if not circle.CutShort then
					shatterCircle(circle, circle.Until)
				end
			end
			local fadeTime = if circle.CutShort then visuals.CutFadeTime else visuals.ShatterTime
			if fadeTime <= 0 or now - (circle.EndAt :: number) >= fadeTime then
				destroyCircle(owner, circle)
			else
				drawCircle(circle, now)
			end
		end
	end
end

local function bounds(instance: Instance): (CFrame?, Vector3?)
	if instance.Parent == nil then
		return nil, nil
	end
	if instance:IsA("Model") then
		return instance:GetBoundingBox()
	elseif instance:IsA("BasePart") then
		return instance.CFrame, instance.Size
	end
	return nil
end

local function emitAt(template: ParticleEmitter?, position: Vector3): ()
	if template == nil then
		return
	end
	InstantSkill.Burst(template, CFrame.new(position), 1)
end

local function pauseCustomerTracks(model: Model, visual: FrozenVisual): ()
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local animator = if humanoid then humanoid:FindFirstChildOfClass("Animator") else nil
	if animator == nil then
		return
	end
	for _, track in animator:GetPlayingAnimationTracks() do
		if visual.Tracks[track] == nil then
			visual.Tracks[track] = track.Speed
		end
		track:AdjustSpeed(0)
	end
end

local function resumeCustomerTracks(visual: FrozenVisual): ()
	for track, speed in visual.Tracks do
		if track.IsPlaying then
			track:AdjustSpeed(speed)
		end
	end
	table.clear(visual.Tracks)
end

local function beginFrozen(instance: Instance, isTool: boolean, startedAt: number): ()
	local highlight: Highlight? = nil
	local fill = Color3.new(1, 1, 1)
	local fillTransparency = 1
	local outlineTransparency = 1
	if isTool and highlightTemplate ~= nil then
		local clone = highlightTemplate:Clone()
		fill = clone.FillColor
		fillTransparency = clone.FillTransparency
		outlineTransparency = clone.OutlineTransparency
		clone.Adornee = instance
		clone.FillColor = Color3.new(1, 1, 1)
		clone.FillTransparency = 1
		clone.OutlineTransparency = 1
		clone.Parent = instance
		highlight = clone
	end
	local cap: MeshPart? = nil
	if isTool and capTemplate ~= nil and visuals.FrostCapFit > 0 then
		local clone = capTemplate:Clone()
		clone.Anchored = true
		clone.CanCollide = false
		clone.CanQuery = false
		clone.CanTouch = false
		clone.CastShadow = false
		clone.Parent = workspace
		cap = clone
	end
	local block: BasePart? = nil
	if not isTool and iceBlockTemplate ~= nil then
		local clone = iceBlockTemplate:Clone()
		clone.Anchored = true
		clone.CanCollide = false
		clone.CanQuery = false
		clone.CanTouch = false
		clone.CastShadow = false
		local box, size = bounds(instance)
		if box ~= nil and size ~= nil then
			local pad = visuals.IceBlockPad
			clone.Size = Vector3.new(size.X + 2 * pad, size.Y + pad, size.Z + 2 * pad)
			local foot = box.Position - box.UpVector * (size.Y / 2)
			clone.CFrame = CFrame.new(foot + box.UpVector * (clone.Size.Y / 2)) * box.Rotation
			InstantSkill.Burst(snowTemplate, CFrame.new(box.Position), visuals.IceBlockBurstCount)
			emitAt(glintTemplate, box.Position)
		end
		clone.Parent = workspace
		block = clone
	end
	frozen[instance] = {
		Highlight = highlight, Cap = cap, Block = block, BlockTransparency = if block then block.Transparency else 1,
		Tracks = {}, NextShiver = workspace:GetServerTimeNow() + visuals.ShiverInterval + random:NextNumber(-visuals.ShiverTime, visuals.ShiverTime), ShiverAt = nil,
		IsTool = isTool, StartedAt = startedAt, ThawAt = nil,
		Fill = fill, FillTransparency = fillTransparency, OutlineTransparency = outlineTransparency,
		NextBreath = startedAt + visuals.BreathInterval, NextGlint = startedAt + visuals.GlintInterval,
	}
	if not isTool then
		pauseCustomerTracks(instance :: Model, frozen[instance])
	end
end

local function stepFrozen(now: number): ()
	for instance, visual in frozen do
		local thawAt = visual.ThawAt
		local elapsed = if thawAt ~= nil then now - thawAt else now - visual.StartedAt
		local fade = if thawAt ~= nil then quartIn(math.clamp(elapsed / math.max(visuals.HighlightOutTime, 0.001), 0, 1)) else 0
		local capFade = if thawAt ~= nil then quartIn(math.clamp(elapsed / math.max(visuals.FrostCapOutTime, 0.001), 0, 1)) else 0
		local flash = if visuals.FreezeFlashTime > 0 then expoOut(math.clamp((now - visual.StartedAt) / visuals.FreezeFlashTime, 0, 1)) else 1
		local highlight = visual.Highlight
		if highlight ~= nil then
			highlight.FillColor = Color3.new(1, 1, 1):Lerp(visual.Fill, flash)
			highlight.FillTransparency = 1 - (1 - visual.FillTransparency) * flash * (1 - fade)
			highlight.OutlineTransparency = 1 - (1 - visual.OutlineTransparency) * flash * (1 - fade)
		end
		local box, size = bounds(instance)
		local cap = visual.Cap
		if cap ~= nil and box ~= nil and size ~= nil and capTemplate ~= nil then
			local fit = math.min(size.X, size.Z) * visuals.FrostCapFit / math.max(capTemplate.Size.X, capTemplate.Size.Z)
			local grow = if visuals.FrostCapTime > 0 then elastic(math.clamp((now - visual.StartedAt) / visuals.FrostCapTime, 0, 1), visuals.GrowWobble) else 1
			local scale = math.max(fit * grow * (1 - capFade), 0.001)
			cap.Size = capTemplate.Size * scale
			cap.CFrame = CFrame.new(box.Position + box.UpVector * (size.Y / 2)) * box.Rotation
		end
		local block = visual.Block
		if block ~= nil and box ~= nil and size ~= nil then
			local pad = visuals.IceBlockPad
			local target = Vector3.new(size.X + 2 * pad, size.Y + pad, size.Z + 2 * pad)
			local snap = if visuals.IceBlockSnapTime > 0 then math.clamp((now - visual.StartedAt) / visuals.IceBlockSnapTime, 0, 1) else 1
			local height = elastic(snap, visuals.GrowWobble)
			local width = math.max(0.001, height - math.max(height - 1, 0) * 2)
			local out = if thawAt ~= nil then quartIn(math.clamp(elapsed / math.max(visuals.IceBlockOutTime, 0.001), 0, 1)) else 0
			local scale = math.max(1 - out, 0.001)
			local shake = 0
			if thawAt ~= nil then
				shake = math.sin(out * math.pi * 8) * visuals.ShiverAmount * (1 - out)
			elseif visuals.ShiverInterval > 0 and visuals.ShiverTime > 0 then
				if now >= visual.NextShiver then
					visual.ShiverAt = now
					visual.NextShiver = now + visuals.ShiverInterval + random:NextNumber(-visuals.ShiverTime, visuals.ShiverTime)
				end
				local shiverAt = visual.ShiverAt
				if shiverAt ~= nil then
					local phase = (now - shiverAt) / visuals.ShiverTime
					if phase >= 1 then
						visual.ShiverAt = nil
					else
						shake = math.sin(phase * math.pi * 4) * visuals.ShiverAmount * (1 - phase)
					end
				end
			end
			block.Size = Vector3.new(math.max(target.X * width * scale, 0.001), math.max(target.Y * height * scale, 0.001), math.max(target.Z * width * scale, 0.001))
			local foot = box.Position - box.UpVector * (size.Y / 2)
			block.CFrame = CFrame.new(foot + box.UpVector * (block.Size.Y / 2) + box.RightVector * shake) * box.Rotation
			block.Transparency = visual.BlockTransparency + (1 - visual.BlockTransparency) * out
		end
		if thawAt ~= nil then
			if (fade >= 1 and capFade >= 1 and (block == nil or elapsed >= visuals.IceBlockOutTime)) or instance.Parent == nil then
				if highlight ~= nil then highlight:Destroy() end
				if cap ~= nil then cap:Destroy() end
				if block ~= nil then block:Destroy() end
				frozen[instance] = nil
			end
		elseif box ~= nil and size ~= nil then
			if not visual.IsTool then
				pauseCustomerTracks(instance :: Model, visual)
			end
			if not visual.IsTool and visuals.BreathInterval > 0 and now >= visual.NextBreath then
				local model = instance :: Model
				local head = model:FindFirstChild("Head")
				if head ~= nil and head:IsA("BasePart") then
					emitAt(breathTemplate, head.Position + head.CFrame.LookVector * (head.Size.Z / 2))
				end
				visual.NextBreath = now + visuals.BreathInterval
			end
			if visuals.GlintInterval > 0 and now >= visual.NextGlint then
				local offset = Vector3.new(random:NextNumber(-0.5, 0.5) * size.X, random:NextNumber(-0.5, 0.5) * size.Y, random:NextNumber(-0.5, 0.5) * size.Z)
				emitAt(glintTemplate, box:PointToWorldSpace(offset))
				visual.NextGlint = now + visuals.GlintInterval
			end
		end
	end
end

local function updateFrozen(now: number): ()
	local seen: { [Instance]: boolean } = {}
	for _, tool in CollectionService:GetTagged(Tags.ClassTag(Tags.CookingTool)) do
		local at = tool:GetAttribute(FrozenAttribute)
		if typeof(at) == "number" then
			seen[tool] = true
			local visual = frozen[tool]
			if visual == nil then
				beginFrozen(tool, true, at)
			elseif visual.ThawAt ~= nil then
				-- Frozen again while thawing: pop back in from the new freeze time.
				visual.ThawAt = nil
				visual.StartedAt = at
			end
		end
	end
	local temp = workspace:FindFirstChild("$Temp")
	if temp ~= nil then
		for _, child in temp:GetChildren() do
			local at = child:GetAttribute(FrozenAttribute)
			if child:IsA("Model") and typeof(at) == "number" then
				seen[child] = true
				local visual = frozen[child]
				if visual == nil then
					beginFrozen(child, false, at)
				elseif visual.ThawAt ~= nil then
					visual.ThawAt = nil
					visual.StartedAt = at
					visual.NextShiver = now + visuals.ShiverInterval + random:NextNumber(-visuals.ShiverTime, visuals.ShiverTime)
					visual.ShiverAt = nil
				end
			end
		end
	end
	for instance, visual in frozen do
		if not seen[instance] and visual.ThawAt == nil then
			visual.ThawAt = now
			if not visual.IsTool then
				resumeCustomerTracks(visual)
			end
			if visual.Block ~= nil and visuals.IceBlockChunks > 0 then
				local rng = Random.new(math.floor(visual.StartedAt * 1000) % 2147483647)
				for _ = 1, visuals.IceBlockChunks do
					local angle = rng:NextNumber(0, math.pi * 2)
					spawnShard(visual.Block.Position, Vector3.new(math.cos(angle), 0, math.sin(angle)), now, rng)
				end
			end
			if visual.Cap ~= nil and visuals.UnfreezeChunkCount > 0 then
				local rng = Random.new(math.floor(visual.StartedAt * 1000) % 2147483647)
				for _ = 1, visuals.UnfreezeChunkCount do
					local angle = rng:NextNumber(0, math.pi * 2)
					spawnShard(visual.Cap.Position, Vector3.new(math.cos(angle), 0, math.sin(angle)), now, rng)
				end
			end
		end
	end
end

-- The move input in world space, flat (what the default controls would walk toward).
local function inputDirection(humanoid: Humanoid): Vector3
	local camera = workspace.CurrentCamera
	if controls == nil or camera == nil then
		return humanoid.MoveDirection
	end
	local ok, vector = pcall(function(): any
		return controls:GetMoveVector()
	end)
	if not ok or typeof(vector) ~= "Vector3" or vector.Magnitude < 0.01 then
		return Vector3.zero
	end
	local look = camera.CFrame.LookVector
	local forward = Vector3.new(look.X, 0, look.Z)
	if forward.Magnitude < 0.01 then
		local up = camera.CFrame.UpVector
		forward = Vector3.new(up.X, 0, up.Z)
	end
	if forward.Magnitude < 0.01 then
		return Vector3.zero
	end
	local world = CFrame.lookAt(Vector3.zero, forward.Unit):VectorToWorldSpace(vector)
	local flat = Vector3.new(world.X, 0, world.Z)
	return if flat.Magnitude > 1 then flat.Unit else flat
end

-- Runs after default controls so another player's ice gives the local player some drift.
local function stepIce(dt: number): ()
	local character = localPlayer.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local root = if character then InstantSkill.Root(character) else nil
	if character == nil or humanoid == nil or root == nil then
		return
	end
	local zone = SkillEffects.ZoneAt(root.Position, currentZones(workspace:GetServerTimeNow()))
	local own = zone ~= nil and zone.Owner == character
	SpeedController.SetMultiplier("Ice", if own then FreezeConfig.PenguinIceSpeed else nil)
	if zone == nil or own or not FreezeConfig.IceFloor or SpeedController.IsRooted() then
		slide = humanoid.MoveDirection
		return
	end
	local target = inputDirection(humanoid)
	local alpha = 1 - math.exp(-FreezeConfig.IceResponse * FreezeConfig.IceGrip * dt)
	slide = slide:Lerp(target, alpha)
	humanoid:Move(slide, false)
end

local function step(): ()
	local now = workspace:GetServerTimeNow()
	updateCircles(currentZones(now), now)
	stepStomps(now)
	stepShards(now)
	if os.clock() >= highlightScanAt then
		highlightScanAt = os.clock() + FreezeConfig.ScanInterval
		updateFrozen(now)
	end
	stepFrozen(now)
end

local DeepFreeze: InstantSkill.InstantSkill = {
	RequiresEmptyHands = false,
	Setup = function(): ()
		local folder = InstantSkill.Folder("DeepFreeze")
		circleTemplate = InstantSkill.Template(folder, "FrostCircle", "BasePart") :: BasePart?
		shockwaveTemplate = InstantSkill.Template(folder, "Shockwave", "BasePart") :: BasePart?
		capTemplate = InstantSkill.Template(folder, "FrostCap", "MeshPart") :: MeshPart?
		iceBlockTemplate = InstantSkill.Template(folder, "IceBlock", "BasePart") :: BasePart?
		chunkTemplate = InstantSkill.Template(folder, "IceChunk", "MeshPart") :: MeshPart?
		spikeTemplate = if visuals.SpikeCount > 0 then InstantSkill.Template(folder, "IceSpike", "MeshPart") :: MeshPart? else nil
		highlightTemplate = InstantSkill.Template(folder, "FrozenHighlight", "Highlight") :: Highlight?
		snowTemplate = InstantSkill.Template(folder, "Snow", "ParticleEmitter") :: ParticleEmitter?
		shatterTemplate = InstantSkill.Template(folder, "Shatter", "ParticleEmitter") :: ParticleEmitter?
		breathTemplate = InstantSkill.Template(folder, "Breath", "ParticleEmitter") :: ParticleEmitter?
		glintTemplate = InstantSkill.Template(folder, "Glint", "ParticleEmitter") :: ParticleEmitter?
		mistTemplate = InstantSkill.Template(folder, "Mist", "ParticleEmitter") :: ParticleEmitter?
		snowfallTemplate = InstantSkill.Template(folder, "Snowfall", "ParticleEmitter") :: ParticleEmitter?
		glowTemplate = InstantSkill.Template(folder, "PenguinGlow", "Highlight") :: Highlight?
		stationFrostTemplate = InstantSkill.Template(folder, "StationFrost", "BasePart") :: BasePart?
		local effects = SoundService:FindFirstChild("SoundEffects")
		for _, name in { "FreezeStomp", "FreezeWhoosh", "FreezeCrack", "FreezeShatter" } do
			local sound = if effects then effects:FindFirstChild(name) else nil
			if sound ~= nil and sound:IsA("Sound") then
				sounds[name] = sound
			else
				InstantSkill.WarnOnce(`SoundService.SoundEffects.{name} (Sound) is missing; that sound is skipped`)
			end
		end
		task.spawn(function(): ()
			local ok, module = pcall(function(): any
				local playerModule = localPlayer:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 10)
				return if playerModule ~= nil and playerModule:IsA("ModuleScript") then (require :: any)(playerModule) else nil
			end)
			if ok and module ~= nil then
				controls = module:GetControls()
			else
				InstantSkill.WarnOnce("PlayerModule controls not found; ice falls back to MoveDirection")
			end
		end)
		RunService.Heartbeat:Connect(step)
		RunService:BindToRenderStep("DeepFreezeIce", Enum.RenderPriority.Input.Value + 1, stepIce)
	end,
	CanUse = function(_character: Model): boolean
		return true
	end,
	Predict = function(character: Model): ()
		local root = InstantSkill.Root(character)
		if root == nil then
			return
		end
		local now = workspace:GetServerTimeNow()
		predicted = { Owner = character, Center = root.Position, StartedAt = now, Until = now + FreezeConfig.Duration }
		predictedExpiresAt = os.clock() + Config.Skills.InstantConfirmTimeout
		updateCircles(currentZones(now), now)
	end,
	Rollback = function(): ()
		predicted = nil
	end,
	IsBusy = function(): boolean
		return false
	end,
}

return DeepFreeze
