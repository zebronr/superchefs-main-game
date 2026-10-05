--!strict

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local CameraController = require(script.Parent.Parent.Controllers.CameraController)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local TongueConfig = Config.Skills.TongueGrab
local Attribute = Config.Skills.Attribute
local FireAttribute = Config.Interaction.Cooking.FireAttribute
local Tags = require(Shared:WaitForChild("Tags"))
local TongueTargeting = require(Shared:WaitForChild("Util"):WaitForChild("TongueTargeting"))

-- Client half of the Gecko's Tongue Grab: the aim (spin, guide, camera) for the local player, and
-- the tongue and the flying item for every character. The server decides the result.
local TongueGrab = {}

TongueGrab.HoldLimit = TongueConfig.HoldLimit
TongueGrab.ActiveTime = TongueConfig.ExtendTime + TongueConfig.RetractTime

local localPlayer = Players.LocalPlayer
local tongueBodyTemplate: Beam? = nil
local tongueTipTemplate: MeshPart? = nil
local effectTemplates: { [string]: ParticleEmitter? } = {}
local itemTrailTemplate: Trail? = nil
local guideTemplate: BasePart? = nil
local highlightTemplate: Highlight? = nil
local visuals = TongueConfig.Visuals

-- Item classes the tongue can take (hints only; the server stays authoritative).
local ITEM_CLASSES = { Tags.Food, Tags.Plate, Tags.DirtyPlate, Tags.CookingTool, Tags.FireExtinguisher }
local BLOCKING_TAGS = { Tags.Locked, Tags.FireLocked, Tags.Grabbed, Tags.Projectile }
local LOS_REFRESH = 0.25

local function playSound(name: string): ()
	local folder = SoundService:FindFirstChild("SoundEffects")
	local sound = if folder then folder:FindFirstChild(name) else nil
	if sound ~= nil and sound:IsA("Sound") then
		sound:Play()
	end
end

local function hasBlockingTag(instance: Instance): boolean
	for _, tag in BLOCKING_TAGS do
		if CollectionService:HasTag(instance, tag) then
			return true
		end
	end
	return false
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

-- Stretches a tongue part along its Z axis between the mouth and the tip.
local function stretch(part: BasePart, template: BasePart, mouth: Vector3, tip: Vector3): ()
	local length = (tip - mouth).Magnitude
	part.Size = Vector3.new(template.Size.X, template.Size.Y, math.max(length, 0.05))
	if length < 0.05 then
		part.CFrame = CFrame.new(mouth)
	else
		part.CFrame = CFrame.lookAt(mouth:Lerp(tip, 0.5), tip)
	end
end

-- Every character's tongue and grabbed item

type TongueVisual = {
	Mouth: Attachment,
	End: Attachment,
	Body: Beam?,
	Tip: MeshPart?,
	Impacted: boolean,
	Popped: boolean,
}

type ItemVisual = {
	Top: Attachment,
	Bottom: Attachment,
	Trail: Trail,
}

local tongues: { [Model]: TongueVisual } = {}
local itemTrails: { [BasePart]: ItemVisual } = {}
local effectAttachments: { [string]: Attachment? } = {}
local lastStates: { [Model]: string } = setmetatable({}, { __mode = "k" }) :: any
local sawItem: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local predictedThwips: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any

type Prediction = {
	Character: Model,
	StartedAt: number,
	Tip: Vector3,
	HasTarget: boolean,
}

local prediction: Prediction? = nil

local function directionTo(character: Model, mouth: Vector3, tip: Vector3): Vector3
	local offset = tip - mouth
	if offset.Magnitude >= 0.05 then
		return offset.Unit
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	return if root ~= nil and root:IsA("BasePart") then root.CFrame.LookVector else character:GetPivot().LookVector
end

local function emit(name: string, worldCFrame: CFrame, count: number): ()
	local template = effectTemplates[name]
	if template == nil then
		return
	end
	local attachment = effectAttachments[name]
	if attachment == nil then
		local created = Instance.new("Attachment")
		created.Name = "Tongue" .. name
		created.Parent = workspace.Terrain
		effectAttachments[name] = created
		local emitter = template:Clone()
		emitter.Parent = created
		attachment = created
	end
	local destination = assert(attachment)
	destination.WorldCFrame = worldCFrame
	local emitter = destination:FindFirstChildWhichIsA("ParticleEmitter")
	if emitter ~= nil then
		emitter:Emit(count)
	end
end

local function newTongue(character: Model, mouth: Vector3, tip: Vector3): TongueVisual
	local startAttachment = Instance.new("Attachment")
	startAttachment.Name = "TongueMouth"
	startAttachment.Parent = workspace.Terrain
	local endAttachment = Instance.new("Attachment")
	endAttachment.Name = "TongueEnd"
	endAttachment.Parent = workspace.Terrain
	local body: Beam? = nil
	if tongueBodyTemplate ~= nil then
		local clone = tongueBodyTemplate:Clone()
		clone.Attachment0 = startAttachment
		clone.Attachment1 = endAttachment
		clone.Parent = workspace.Terrain
		body = clone
	end
	local tipPart: MeshPart? = nil
	if tongueTipTemplate ~= nil then
		local clone = tongueTipTemplate:Clone()
		clone.Anchored = true
		clone.CanCollide = false
		clone.CanQuery = false
		clone.CanTouch = false
		clone.CastShadow = false
		clone.Parent = workspace
		tipPart = clone
	end
	local record: TongueVisual = {
		Mouth = startAttachment,
		End = endAttachment,
		Body = body,
		Tip = tipPart,
		Impacted = false,
		Popped = false,
	}
	tongues[character] = record
	local dir = directionTo(character, mouth, tip)
	emit("Thwip", CFrame.lookAt(mouth, mouth + dir), visuals.ThwipCount)
	return record
end

local function updateTongue(record: TongueVisual, character: Model, mouth: Vector3, tip: Vector3, wobble: number): ()
	local dir = directionTo(character, mouth, tip)
	record.Mouth.WorldCFrame = CFrame.lookAt(mouth, mouth + dir)
	local tipPart = record.Tip
	if tipPart ~= nil then
		tipPart.CFrame = CFrame.lookAt(tip, tip + dir)
	end
	local bodyEnd = tip - dir * (if tipPart ~= nil then tipPart.Size.Z * 0.3 else 0)
	record.End.WorldCFrame = CFrame.lookAt(bodyEnd, bodyEnd + dir)
	local body = record.Body
	if body ~= nil then
		body.CurveSize0 = wobble
		body.CurveSize1 = -wobble * 0.5
	end
end

local function renderTongue(character: Model, mouth: Vector3, tip: Vector3, now: number, phaseFactor: number): TongueVisual
	local record = tongues[character]
	if record == nil then
		record = newTongue(character, mouth, tip)
	end
	local lengthFactor = math.clamp((tip - mouth).Magnitude / TongueConfig.Range, 0, 1)
	local wobble = visuals.WobbleAmplitude * lengthFactor * phaseFactor * math.sin(now * visuals.WobbleFrequency)
	updateTongue(record, character, mouth, tip, wobble)
	return record
end

local function impact(record: TongueVisual, character: Model, mouth: Vector3, tip: Vector3, hasTarget: boolean): ()
	if record.Impacted then
		return
	end
	record.Impacted = true
	local dir = directionTo(character, mouth, tip)
	if hasTarget then
		emit("Splat", CFrame.lookAt(tip, tip - dir), visuals.SplatCount)
	else
		local hit = workspace:Raycast(mouth, dir * ((tip - mouth).Magnitude + 1), TongueTargeting.LosParams({ character }))
		if hit ~= nil then
			emit("Dust", CFrame.lookAt(hit.Position, hit.Position + hit.Normal), visuals.DustCount)
		end
	end
end

local function addItemTrail(part: BasePart): ()
	local template = itemTrailTemplate
	if template == nil or itemTrails[part] ~= nil then
		return
	end
	local top = Instance.new("Attachment")
	top.Name = "TongueTrailTop"
	top.Position = Vector3.new(0, visuals.TrailWidth / 2, 0)
	top.Parent = part
	local bottom = Instance.new("Attachment")
	bottom.Name = "TongueTrailBottom"
	bottom.Position = Vector3.new(0, -visuals.TrailWidth / 2, 0)
	bottom.Parent = part
	local trail = template:Clone()
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Parent = part
	itemTrails[part] = { Top = top, Bottom = bottom, Trail = trail }
end

local function removeTongue(character: Model): ()
	local record = tongues[character]
	if record ~= nil then
		tongues[character] = nil
		if record.Body ~= nil then
			record.Body:Destroy()
		end
		if record.Tip ~= nil then
			record.Tip:Destroy()
		end
		record.Mouth:Destroy()
		record.End:Destroy()
	end
end

local function renderAll(): ()
	local now = workspace:GetServerTimeNow()

	-- Items flying to a mouth.
	local grabbedBy: { [number]: BasePart? } = {}
	local grabbedThisFrame: { [BasePart]: boolean } = {}
	for _, instance in CollectionService:GetTagged(Tags.Grabbed) do
		if not instance:IsA("BasePart") or not instance:IsDescendantOf(workspace) then
			continue
		end
		local userId = instance:GetAttribute(Attribute.GrabByUserId)
		local from = instance:GetAttribute(Attribute.GrabFrom)
		local startedAt = instance:GetAttribute(Attribute.GrabStartedAt)
		if typeof(userId) ~= "number" or typeof(from) ~= "Vector3" or typeof(startedAt) ~= "number" then
			continue
		end
		grabbedThisFrame[instance] = true
		addItemTrail(instance)
		grabbedBy[userId] = instance
		local grabber = Players:GetPlayerByUserId(userId)
		local character = if grabber then grabber.Character else nil
		local mouth = if character then TongueTargeting.Mouth(character) else from
		local alpha = TongueTargeting.RetractAlpha(now - startedAt)
		instance.CFrame = CFrame.new(from:Lerp(mouth, alpha)) * instance.CFrame.Rotation
	end
	for part, visual in itemTrails do
		if not grabbedThisFrame[part] then
			visual.Trail:Destroy()
			visual.Top:Destroy()
			visual.Bottom:Destroy()
			itemTrails[part] = nil
		end
	end

	local active: { [Model]: boolean } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character == nil then
			continue
		end
		local state = character:GetAttribute(Attribute.TongueState)
		local startedAt = character:GetAttribute(Attribute.TongueStartedAt)
		local localPrediction = if player == localPlayer then prediction else nil
		if localPrediction ~= nil and localPrediction.Character == character then
			if
				(state == "Extending" or state == "Retracting")
				and typeof(startedAt) == "number"
				and startedAt >= localPrediction.StartedAt - TongueConfig.MaxLagCompensation - 0.1
			then
				prediction = nil
				localPrediction = nil
			elseif now - localPrediction.StartedAt > TongueConfig.ExtendTime + TongueConfig.RetractTime + TongueConfig.PredictionTimeout then
				prediction = nil
				localPrediction = nil
			end
		end
		local previous = lastStates[character]
		if localPrediction ~= nil and localPrediction.Character == character then
			local mouth = TongueTargeting.Mouth(character)
			local elapsed = now - localPrediction.StartedAt
			local resolved: Vector3?
			local phaseFactor = visuals.ExtendWobble
			if elapsed < TongueConfig.ExtendTime then
				resolved = mouth:Lerp(localPrediction.Tip, TongueTargeting.ExtendAlpha(elapsed))
			elseif localPrediction.HasTarget then
				resolved = localPrediction.Tip
			elseif elapsed < TongueConfig.ExtendTime + TongueConfig.RetractTime then
				local retractAlpha = TongueTargeting.RetractAlpha(elapsed - TongueConfig.ExtendTime)
				resolved = localPrediction.Tip:Lerp(mouth, retractAlpha)
				phaseFactor = 1 - retractAlpha
			end
			if resolved ~= nil then
				local record = renderTongue(character, mouth, resolved, now, phaseFactor)
				active[character] = true
				if elapsed >= TongueConfig.ExtendTime then
					impact(record, character, mouth, localPrediction.Tip, localPrediction.HasTarget)
				end
			end
			continue
		end
		if state ~= "Extending" and state ~= "Retracting" then
			if previous == "Retracting" then
				if sawItem[character] then
					playSound("TonguePop")
					local record = tongues[character]
					if record ~= nil and not record.Popped then
						record.Popped = true
						local mouth = TongueTargeting.Mouth(character)
						local dir = directionTo(character, mouth, mouth)
						emit("Pop", CFrame.lookAt(mouth, mouth + dir), visuals.PopCount)
					end
				else
					playSound("TongueWhiff")
				end
			end
			lastStates[character] = nil
			sawItem[character] = nil
			continue
		end
		if state ~= previous then
			lastStates[character] = state
			if state == "Extending" then
				local predictedAt = predictedThwips[character]
				if predictedAt == nil or typeof(startedAt) ~= "number" or startedAt < predictedAt - TongueConfig.MaxLagCompensation - 0.1 then
					playSound("TongueThwip")
				end
				predictedThwips[character] = nil
			end
		end

		local tipAttribute = character:GetAttribute(Attribute.TongueTip)
		if typeof(startedAt) ~= "number" then
			continue
		end
		local mouth = TongueTargeting.Mouth(character)
		local tip = if typeof(tipAttribute) == "Vector3" then tipAttribute else mouth
		local resolved: Vector3
		local phaseFactor = visuals.ExtendWobble
		if state == "Extending" then
			local alpha = TongueTargeting.ExtendAlpha(now - startedAt)
			resolved = mouth:Lerp(tip, alpha)
		else
			local item = grabbedBy[player.UserId]
			local retractAlpha = TongueTargeting.RetractAlpha(now - startedAt)
			phaseFactor = 1 - retractAlpha
			if item ~= nil then
				sawItem[character] = true
				resolved = item.Position
			else
				resolved = tip:Lerp(mouth, retractAlpha)
			end
		end
		local record = renderTongue(character, mouth, resolved, now, phaseFactor)
		active[character] = true
		if state == "Retracting" then
			impact(record, character, mouth, tip, grabbedBy[player.UserId] ~= nil)
		end
	end

	for character in tongues do
		if not active[character] then
			removeTongue(character)
		end
	end
end

-- The local player's aim

type Aim = {
	Character: Model,
	Root: BasePart,
	Humanoid: Humanoid,
	Guide: BasePart?,
	Highlight: Highlight?,
	Params: RaycastParams,
	ParamsAt: number,
	PressMoveDirection: Vector3?,
	AimYaw: number,
	Target: BasePart?,
	Released: boolean,
}

local aim: Aim? = nil

-- The surface part an item rests on (the Slot weld's Part0), if it is resting.
local function restingOn(part: BasePart): BasePart?
	for _, joint in part:GetJoints() do
		if joint.Name == "objectTopWelder" and joint:IsA("WeldConstraint") then
			return joint.Part0
		end
	end
	return nil
end

local function heldParts(): { [BasePart]: boolean }
	local held: { [BasePart]: boolean } = {}
	for _, player in Players:GetPlayers() do
		local root = if player.Character then player.Character:FindFirstChild("HumanoidRootPart") else nil
		local weld = if root then root:FindFirstChild("ObjectHolder") else nil
		if weld ~= nil and weld:IsA("WeldConstraint") and weld.Part1 ~= nil then
			held[weld.Part1] = true
		end
	end
	return held
end

-- Items the tongue might take, from the replicated hints.
local function candidatesNear(origin: Vector3): { BasePart }
	local held = heldParts()
	local reach = TongueConfig.Range + TongueConfig.LineRadius
	local candidates: { BasePart } = {}
	for _, className in ITEM_CLASSES do
		for _, instance in CollectionService:GetTagged(Tags.ClassTag(className)) do
			if not instance:IsA("BasePart") or held[instance] or not instance:IsDescendantOf(workspace) then
				continue
			end
			local offset = instance.Position - origin
			if Vector3.new(offset.X, 0, offset.Z).Magnitude > reach or hasBlockingTag(instance) then
				continue
			end
			if instance:GetAttribute(FireAttribute) ~= nil then
				continue
			end
			if Tags.IsInteractionDisabled(instance) then
				-- Items resting on a station are disabled by design; the station's lock decides.
				local surface = restingOn(instance)
				if surface == nil or hasBlockingTag(surface) then
					continue
				end
			end
			table.insert(candidates, instance)
		end
	end
	return candidates
end

local function flatLook(root: BasePart): Vector3
	return TongueTargeting.Flat(root.CFrame.LookVector)
end

local function yawOf(direction: Vector3): number
	return math.atan2(-direction.X, -direction.Z)
end

local function yawDifference(from: number, to: number): number
	return (to - from + math.pi) % (2 * math.pi) - math.pi
end

local function turnRoot(root: BasePart, wantedYaw: number, maxStep: number): ()
	local step = math.clamp(yawDifference(yawOf(flatLook(root)), wantedYaw), -maxStep, maxStep)
	root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, step, 0) * root.CFrame.Rotation
end

local function aimTip(current: Aim): Vector3
	local mouth = TongueTargeting.Mouth(current.Character)
	local target = current.Target
	return if target ~= nil then target.Position else TongueTargeting.WhiffTip(mouth, flatLook(current.Root), current.Params)
end

function TongueGrab.BeginAim(character: Model): ()
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if root == nil or not root:IsA("BasePart") or humanoid == nil then
		return
	end
	local params = TongueTargeting.LosParams({})
	local origin = TongueTargeting.AimOrigin(character)
	local target = TongueTargeting.Best(origin, flatLook(root), candidatesNear(origin), params)
	if target ~= nil then
		local direction = TongueTargeting.Flat(target.Position - root.Position)
		if direction ~= Vector3.zero then
			root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, yawOf(direction), 0)
		end
	end
	local highlight: Highlight? = nil
	if highlightTemplate ~= nil then
		highlight = highlightTemplate:Clone()
		if highlight ~= nil then
			-- Without an Adornee a Highlight covers its parent, so keep it off until there is a target.
			highlight.Enabled = false
			highlight.Parent = workspace
		end
	end
	aim = {
		Character = character,
		Root = root,
		Humanoid = humanoid,
		Guide = newVisual(guideTemplate),
		Highlight = highlight,
		Params = params,
		ParamsAt = os.clock(),
		PressMoveDirection = TongueTargeting.Flat(humanoid.MoveDirection),
		AimYaw = yawOf(flatLook(root)),
		Target = target,
		Released = false,
	}
end

function TongueGrab.StepAim(dt: number): boolean
	local current = aim
	if current == nil or current.Released then
		return false
	end
	local root = current.Root
	-- Humanoid.MoveDirection is the camera-relative input for keys and the joystick alike.
	local wanted = TongueTargeting.Flat(current.Humanoid.MoveDirection)
	local pressDirection = current.PressMoveDirection
	if pressDirection ~= nil then
		if pressDirection:Dot(wanted) > 0.99 then
			wanted = Vector3.zero
		else
			current.PressMoveDirection = nil
		end
	end
	-- Point to select: with input, the lock is the item closest to the input direction. Without input
	-- the lock stays. AimYaw only drives the free spin when nothing is in reach.
	local hasInput = wanted ~= Vector3.zero
	local selectYaw = if hasInput then yawOf(wanted) else yawOf(flatLook(root))
	if hasInput then
		local difference = yawDifference(current.AimYaw, selectYaw)
		local maxStep = math.rad(TongueConfig.SpinSpeed) * dt
		current.AimYaw += math.clamp(difference, -maxStep, maxStep)
	end

	local now = os.clock()
	if now - current.ParamsAt >= LOS_REFRESH then
		current.Params = TongueTargeting.LosParams({})
		current.ParamsAt = now
	end
	local mouth = TongueTargeting.Mouth(current.Character)
	local origin = TongueTargeting.AimOrigin(current.Character)
	local best: BasePart? = nil
	local bestAngle = math.huge
	local lockedAngle = math.huge
	local lockReachable = false
	for _, part in candidatesNear(origin) do
		if not TongueTargeting.Reachable(origin, part, current.Params) then
			continue
		end
		local bearing = TongueTargeting.Flat(part.Position - root.Position)
		if bearing == Vector3.zero then
			continue
		end
		local angle = math.abs(yawDifference(selectYaw, yawOf(bearing)))
		if part == current.Target then
			lockReachable = true
			lockedAngle = angle
		end
		if angle < bestAngle then
			best = part
			bestAngle = angle
		end
	end
	local previousTarget = current.Target
	if not lockReachable or (hasInput and lockedAngle - bestAngle > math.rad(TongueConfig.LockSwitchMargin)) then
		current.Target = best
	end
	local target = current.Target
	if target ~= nil then
		local bearing = TongueTargeting.Flat(target.Position - root.Position)
		-- Keep the free-spin aim on the lock, so losing the lock resumes from where the Gecko faces.
		current.AimYaw = yawOf(bearing)
		turnRoot(root, current.AimYaw, math.rad(TongueConfig.LockTurnSpeed) * dt)
	else
		turnRoot(root, current.AimYaw, math.huge)
	end
	local direction = flatLook(root)
	local tip = aimTip(current)
	local guide = current.Guide
	local template = guideTemplate
	if guide ~= nil and template ~= nil then
		stretch(guide, template, mouth, tip)
	end
	local highlight = current.Highlight
	if highlight ~= nil then
		highlight.Adornee = target
		highlight.Enabled = target ~= nil
	end
	CameraController.SetAimOffset(
		direction * TongueConfig.CameraAimDistance - Vector3.yAxis * TongueConfig.CameraAimDrop,
		TongueConfig.CameraEaseSpeed
	)
	return current.Target ~= nil and current.Target ~= previousTarget
end

-- The key was let go: freeze the aim and hide the guide.
function TongueGrab.ReleaseAim(predict: boolean): ()
	local current = aim
	if current == nil then
		return
	end
	current.Released = true
	-- Finish any turn toward the lock, so the tongue and the direction sent to the server point at it.
	local target = current.Target
	if target ~= nil then
		local bearing = TongueTargeting.Flat(target.Position - current.Root.Position)
		if bearing ~= Vector3.zero then
			turnRoot(current.Root, yawOf(bearing), math.huge)
		end
	end
	if predict then
		local tip = aimTip(current)
		local startedAt = workspace:GetServerTimeNow()
		prediction = {
			Character = current.Character,
			StartedAt = startedAt,
			Tip = tip,
			HasTarget = current.Target ~= nil,
		}
		predictedThwips[current.Character] = startedAt
		playSound("TongueThwip")
	end
	if current.Guide ~= nil then
		current.Guide:Destroy()
		current.Guide = nil
	end
	if current.Highlight ~= nil then
		current.Highlight.Enabled = false
		current.Highlight.Adornee = nil
	end
	CameraController.SetAimOffset(Vector3.zero, TongueConfig.CameraEaseSpeed)
end

function TongueGrab.EndAim(): ()
	local current = aim
	if current == nil then
		return
	end
	aim = nil
	prediction = nil
	predictedThwips[current.Character] = nil
	if current.Guide ~= nil then
		current.Guide:Destroy()
	end
	if current.Highlight ~= nil then
		current.Highlight:Destroy()
	end
	CameraController.SetAimOffset(Vector3.zero, TongueConfig.CameraEaseSpeed)
end

-- The flat direction to send with the release.
function TongueGrab.GetDirection(): Vector3
	local current = aim
	return if current ~= nil then flatLook(current.Root) else Vector3.zero
end

function TongueGrab.GetTarget(): BasePart?
	local current = aim
	return if current ~= nil then current.Target else nil
end

-- Loads the skill visuals and starts drawing every character's tongue.
function TongueGrab.Setup(): ()
	task.spawn(function(): ()
		local assets = ReplicatedStorage:WaitForChild("Assets", 10)
		local skillAssets = if assets then assets:WaitForChild("Skills", 10) else nil
		local skills = if skillAssets then skillAssets:WaitForChild("TongueGrab", 10) else nil
		local body = if skills then skills:WaitForChild("TongueBody", 10) else nil
		if body ~= nil and body:IsA("Beam") then
			tongueBodyTemplate = body
		else
			warn("ReplicatedStorage.Assets.Skills.TongueGrab.TongueBody is missing, so tongue bodies are not drawn")
		end
		local effects = if skills then skills:WaitForChild("VFX", 10) else nil
		if effects ~= nil and effects:IsA("Folder") then
			for _, name in { "Thwip", "Splat", "Dust", "Pop" } do
				local emitter = effects:WaitForChild(name, 10)
				if emitter ~= nil and emitter:IsA("ParticleEmitter") then
					effectTemplates[name] = emitter
				else
					warn("ReplicatedStorage.Assets.Skills.TongueGrab.VFX." .. name .. " is missing, so that effect is not drawn")
				end
			end
			local trail = effects:WaitForChild("ItemTrail", 10)
			if trail ~= nil and trail:IsA("Trail") then
				itemTrailTemplate = trail
			else
				warn("ReplicatedStorage.Assets.Skills.TongueGrab.VFX.ItemTrail is missing, so grabbed items have no trail")
			end
		else
			warn("ReplicatedStorage.Assets.Skills.TongueGrab.VFX is missing, so tongue effects are not drawn")
		end
		local guide = if skills then skills:WaitForChild("TongueGuide", 10) else nil
		if guide ~= nil and guide:IsA("BasePart") then
			guideTemplate = guide
		else
			warn("ReplicatedStorage.Assets.Skills.TongueGrab.TongueGuide is missing, so the aim guide is not drawn")
		end
		local highlight = if skills then skills:WaitForChild("TongueHighlight", 10) else nil
		if highlight ~= nil and highlight:IsA("Highlight") then
			highlightTemplate = highlight
		else
			warn("ReplicatedStorage.Assets.Skills.TongueGrab.TongueHighlight is missing, so the aim target is not highlighted")
		end
		local tip = if skills then skills:WaitForChild("TongueTip", 10) else nil
		if tip ~= nil and tip:IsA("MeshPart") then
			tongueTipTemplate = tip
		else
			warn("ReplicatedStorage.Assets.Skills.TongueGrab.TongueTip is missing, so tongue tips are not drawn")
		end
	end)
	RunService.RenderStepped:Connect(renderAll)
	localPlayer.CharacterRemoving:Connect(function(character: Model): ()
		removeTongue(character)
	end)
end

return TongueGrab
