--!strict

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SpeedController = require(script.Parent.Parent.Controllers.SpeedController)
local InstantSkill = require(script.Parent.InstantSkill)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local FreezeConfig = Config.Skills.DeepFreeze
local visuals = FreezeConfig.Visuals
local FrozenAttribute = Config.Skills.Attribute.FrozenAt
local SkillEffects = require(Shared:WaitForChild("Util"):WaitForChild("SkillEffects"))
local Tags = require(Shared:WaitForChild("Tags"))

-- Penguin: Deep Freeze, client side. Every client draws every frost circle from the Penguin's
-- attributes and tints whatever the server froze (FrozenAt); the local player slides on ice that is
-- not theirs, and a Penguin on its own ice is faster. The Penguin's own circle is predicted on press.
local localPlayer = Players.LocalPlayer
local circleTemplate: BasePart? = nil
local highlightTemplate: Highlight? = nil
local snowTemplate: ParticleEmitter? = nil
local shatterTemplate: ParticleEmitter? = nil

type Circle = {
	Part: BasePart?,
	Cracks: { Decal },
	Floor: Vector3,
	Until: number,
}

-- The local prediction: the circle the server will make, until its attributes arrive.
local predicted: SkillEffects.Zone? = nil
local predictedExpiresAt = 0
local circles: { [Model]: Circle } = {}
local highlights: { [Instance]: Highlight } = {}
local highlightScanAt = 0
local controls: any = nil
local slide = Vector3.zero

local function backOut(t: number): number
	local c1 = 1.70158
	local c3 = c1 + 1
	return 1 + c3 * (t - 1) ^ 3 + c1 * (t - 1) ^ 2
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

local function removeCircle(owner: Model, shatter: boolean): ()
	local circle = circles[owner]
	if circle == nil then
		return
	end
	circles[owner] = nil
	if circle.Part ~= nil then
		circle.Part:Destroy()
	end
	if shatter then
		InstantSkill.Burst(shatterTemplate, CFrame.lookAt(circle.Floor, circle.Floor + Vector3.yAxis), visuals.ShatterCount)
	end
end

local function addCircle(zone: SkillEffects.Zone): Circle
	local floor = floorBelow(zone.Center, zone.Owner)
	local circle: Circle = { Part = nil, Cracks = {}, Floor = floor, Until = zone.Until }
	if circleTemplate ~= nil then
		local part = circleTemplate:Clone()
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		for _, descendant in part:GetDescendants() do
			if descendant:IsA("Decal") and descendant.Name == "Cracks" then
				descendant.Transparency = 1
				table.insert(circle.Cracks, descendant)
			end
		end
		part.Parent = workspace
		circle.Part = part
	end
	circles[zone.Owner] = circle
	InstantSkill.Burst(snowTemplate, CFrame.lookAt(floor, floor + Vector3.yAxis), visuals.BurstCount)
	return circle
end

-- Grows out with an overshoot, then shows cracks just before it ends.
local function drawCircle(circle: Circle, zone: SkillEffects.Zone, now: number): ()
	circle.Until = zone.Until
	local part = circle.Part
	if part == nil then
		return
	end
	local grow = math.clamp((now - zone.StartedAt) / visuals.GrowTime, 0, 1)
	local diameter = FreezeConfig.Radius * 2 * math.max(backOut(grow), 0.01)
	local template = circleTemplate :: BasePart
	part.Size = Vector3.new(diameter, template.Size.Y, diameter)
	part.CFrame = CFrame.new(circle.Floor + Vector3.new(0, template.Size.Y / 2 + visuals.GroundOffset, 0))
	local crack = math.clamp(1 - (zone.Until - now) / visuals.CrackTime, 0, 1)
	for _, decal in circle.Cracks do
		decal.Transparency = 1 - crack
	end
end

local function currentZones(now: number): { SkillEffects.Zone }
	local zones = SkillEffects.FreezeZones(now)
	local guess = predicted
	if guess ~= nil then
		local confirmed = false
		for _, zone in zones do
			if zone.Owner == guess.Owner then
				confirmed = true
			end
		end
		if confirmed or os.clock() >= predictedExpiresAt or guess.Owner.Parent == nil then
			-- The server's circle took over (or the local one ran out on local time).
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
		local circle = circles[zone.Owner] or addCircle(zone)
		drawCircle(circle, zone, now)
	end
	for owner, circle in table.clone(circles) do
		if not seen[owner] then
			-- Ran its full time: shatter. Cut short (a rollback or the Penguin left): just vanish.
			removeCircle(owner, now >= circle.Until - 0.1)
		end
	end
end

local function setHighlighted(instance: Instance, on: boolean): ()
	local highlight: Highlight? = highlights[instance]
	if on and highlight == nil and highlightTemplate ~= nil then
		local clone = highlightTemplate:Clone()
		clone.Adornee = instance
		clone.Parent = instance
		highlights[instance] = clone
	elseif not on and highlight ~= nil then
		highlights[instance] = nil
		highlight:Destroy()
	end
end

-- Tints frozen cooking tools and customers (the server sets FrozenAt on them).
local function updateHighlights(): ()
	local seen: { [Instance]: boolean } = {}
	for _, tool in CollectionService:GetTagged(Tags.ClassTag(Tags.CookingTool)) do
		if typeof(tool:GetAttribute(FrozenAttribute)) == "number" then
			seen[tool] = true
		end
	end
	local temp = workspace:FindFirstChild("$Temp")
	if temp ~= nil then
		for _, child in temp:GetChildren() do
			if child:IsA("Model") and typeof(child:GetAttribute(FrozenAttribute)) == "number" then
				seen[child] = true
			end
		end
	end
	for instance in seen do
		setHighlighted(instance, true)
	end
	for instance in table.clone(highlights) do
		if not seen[instance] or instance.Parent == nil then
			setHighlighted(instance, false)
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
		-- Looking straight down: the top of the screen is "forward".
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

-- Runs right after the default controls: on someone else's ice the walk direction only drifts toward
-- the input, so the local player slides.
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
	if os.clock() >= highlightScanAt then
		highlightScanAt = os.clock() + FreezeConfig.ScanInterval
		updateHighlights()
	end
end

local DeepFreeze: InstantSkill.InstantSkill = {
	RequiresEmptyHands = false,
	Setup = function(): ()
		local folder = InstantSkill.Folder("DeepFreeze")
		circleTemplate = InstantSkill.Template(folder, "FrostCircle", "BasePart") :: BasePart?
		highlightTemplate = InstantSkill.Template(folder, "FrozenHighlight", "Highlight") :: Highlight?
		snowTemplate = InstantSkill.Template(folder, "Snow", "ParticleEmitter") :: ParticleEmitter?
		shatterTemplate = InstantSkill.Template(folder, "Shatter", "ParticleEmitter") :: ParticleEmitter?
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
		predictedExpiresAt = os.clock() + FreezeConfig.Duration
	end,
	Rollback = function(): ()
		predicted = nil
	end,
	IsBusy = function(): boolean
		return false
	end,
}

return DeepFreeze
