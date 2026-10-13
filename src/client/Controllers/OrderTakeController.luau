--!strict

-- A local table press predicts the take-order puff. The server's CustomerState change draws it for everyone else;
-- a prediction absorbs that confirmation inside ConfirmWindow, and an unconfirmed prediction just ends cosmetically.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local CustomerController = require(script.Parent.CustomerController)
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Tags = require(Shared:WaitForChild("Tags"))
local tuning = Config.UI.TakeOrder

type Warp = {
	StartedAt: number,
	Sizes: { [BasePart]: Vector3 },
	Meshes: { [SpecialMesh]: Vector3 },
	Joints: { [JointInstance]: { C0: CFrame, C1: CFrame } },
	RootJoint: Motor6D?,
	RootC0: CFrame?,
}

local OrderTakeController = {}
local temp = workspace:WaitForChild("$Temp")
local lastStates: { [Model]: string? } = {}
local predicted: { [Model]: number } = {}
local warps: { [Model]: Warp } = {}
local puffTemplate: ParticleEmitter? = nil
local sound: Sound? = nil
local puffAttachment: Attachment? = nil
local puffEmitter: ParticleEmitter? = nil

local function rootOf(model: Model): BasePart?
	local root = model:FindFirstChild("HumanoidRootPart")
	return if root ~= nil and root:IsA("BasePart") then root else nil
end

-- R6 and R15 put the body joint in different places; its C0 moves the body in root space.
local function rootJointOf(model: Model): Motor6D?
	local root = rootOf(model)
	local r6 = if root then root:FindFirstChild("RootJoint") else nil
	if r6 ~= nil and r6:IsA("Motor6D") then
		return r6
	end
	local torso = model:FindFirstChild("LowerTorso")
	local r15 = if torso then torso:FindFirstChild("Root") else nil
	return if r15 ~= nil and r15:IsA("Motor6D") then r15 else nil
end

local function warpsJoint(model: Model, joint: JointInstance, rootJoint: Motor6D?): boolean
	local part0 = joint.Part0
	local part1 = joint.Part1
	if joint == rootJoint or part0 == nil or part1 == nil then
		return false
	end
	if not part0:IsDescendantOf(model) or not part1:IsDescendantOf(model) then
		return false
	end
	local holder = part1.Parent
	return joint:IsA("Motor6D") or (joint:IsA("Weld") and holder ~= nil and holder:IsA("Accessory"))
end

local function axisScale(frame: CFrame, heading: Vector3, along: number, across: number): Vector3
	local x = frame.RightVector:Dot(heading)
	local y = frame.UpVector:Dot(heading)
	local z = frame.LookVector:Dot(heading)
	local spread = along - across
	return Vector3.new(across + spread * x * x, across + spread * y * y, across + spread * z * z)
end

local function startWarp(model: Model): ()
	if typeof(model:GetAttribute(Config.Skills.Attribute.FrozenAt)) == "number" then
		return
	end
	local running = warps[model]
	if running ~= nil then
		running.StartedAt = os.clock()
		return
	end
	local root = rootOf(model)
	local rootJoint = rootJointOf(model)
	local warp: Warp = {
		StartedAt = os.clock(),
		Sizes = {},
		Meshes = {},
		Joints = {},
		RootJoint = rootJoint,
		RootC0 = if rootJoint then rootJoint.C0 else nil,
	}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			if descendant ~= root and not descendant.Anchored then
				warp.Sizes[descendant] = descendant.Size
			end
		elseif descendant:IsA("SpecialMesh") then
			warp.Meshes[descendant] = descendant.Scale
		elseif descendant:IsA("JointInstance") and warpsJoint(model, descendant, rootJoint) then
			warp.Joints[descendant] = { C0 = descendant.C0, C1 = descendant.C1 }
		end
	end
	warps[model] = warp
end

local function restoreWarp(model: Model, warp: Warp): ()
	warps[model] = nil
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
	local rootJoint = warp.RootJoint
	if rootJoint ~= nil and rootJoint.Parent ~= nil and warp.RootC0 ~= nil then
		rootJoint.C0 = warp.RootC0
	end
end

local function stepWarp(model: Model, warp: Warp, clock: number): ()
	local t = (clock - warp.StartedAt) / tuning.SquashTime
	if t >= 1 then
		restoreWarp(model, warp)
		return
	end
	local amount: number
	if t < tuning.SquashSnap then
		amount = 1 - 2 ^ (-10 * t / tuning.SquashSnap)
	else
		local s = (t - tuning.SquashSnap) / (1 - tuning.SquashSnap)
		amount = math.cos(s * math.pi * 3) * (1 - s) ^ tuning.SquashWobble
	end
	local along = math.max(if amount >= 0 then 1 - tuning.Squash * amount else 1 - tuning.Stretch * amount, 0.2)
	local across = 1 / math.sqrt(along)
	local scales: { [BasePart]: Vector3 } = {}
	local function scaleOf(part: BasePart): Vector3
		local cached: Vector3? = scales[part]
		if cached ~= nil then
			return cached
		end
		local scale = axisScale(part.CFrame, Vector3.yAxis, along, across)
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
	local rootJoint = warp.RootJoint
	local original = warp.RootC0
	if rootJoint ~= nil and rootJoint.Parent ~= nil and original ~= nil then
		rootJoint.C0 = CFrame.new(0, -tuning.Dip * amount * (if amount >= 0 then 1 else tuning.Stretch / tuning.Squash), 0) * original
	end
end

local function ring(model: Model): ()
	local root = rootOf(model)
	local template = puffTemplate
	if root == nil or template == nil or model.Parent ~= temp then
		return
	end
	if puffAttachment == nil or puffAttachment.Parent == nil then
		local attachment = Instance.new("Attachment")
		attachment.Name = "OrderPuffBurst"
		local emitter = template:Clone()
		emitter.Enabled = false
		emitter.Parent = attachment
		attachment.Parent = workspace.Terrain
		puffAttachment = attachment
		puffEmitter = emitter
	end
	local attachment = puffAttachment :: Attachment
	local emitter = puffEmitter :: ParticleEmitter
	local centre = root.Position + Vector3.new(0, tuning.PuffHeight, 0)
	local offset = math.random() * math.pi * 2
	for i = 1, tuning.PuffCount do
		local angle = (i - 1) / tuning.PuffCount * math.pi * 2 + offset
		attachment.WorldCFrame = CFrame.new(centre) * CFrame.Angles(0, angle, 0) * CFrame.Angles(math.rad(tuning.PuffTilt), 0, 0)
		emitter:Emit(1)
	end
end

local function play(model: Model): ()
	if sound ~= nil and sound.SoundId ~= "" then
		sound.PlaybackSpeed = tuning.SoundPitch[1] + math.random() * (tuning.SoundPitch[2] - tuning.SoundPitch[1])
		sound:Play()
	end
	CustomerController.Repop(model, os.clock() + tuning.BubbleDelay)
	startWarp(model)
	task.delay(tuning.PuffDelay, function(): ()
		ring(model)
	end)
end

function OrderTakeController.Predict(target: Instance?): ()
	if target == nil or not target:IsA("BasePart") or not Tags.IsClass(target, Tags.CustomerTable)
		or target:GetAttribute("CustomerState") ~= "WaitingToOrder" then
		return
	end
	local nearest: Model? = nil
	local distance = tuning.PredictRadius
	for _, child in temp:GetChildren() do
		if child:IsA("Model") and child:GetAttribute("CustomerState") == "WaitingToOrder" then
			local root = rootOf(child)
			if root ~= nil then
				local gap = (root.Position - target.Position).Magnitude
				if gap <= distance then
					nearest = child
					distance = gap
				end
			end
		end
	end
	if nearest == nil then
		return
	end
	local clock = os.clock()
	local last = predicted[nearest]
	if last ~= nil and clock - last <= tuning.ConfirmWindow then
		return
	end
	predicted[nearest] = clock
	play(nearest)
end

function OrderTakeController.Start(_self: typeof(OrderTakeController)): ()
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local effects = if assets then assets:FindFirstChild("Effects") else nil
	local puff = if effects then effects:FindFirstChild("OrderPuff") else nil
	if puff ~= nil and puff:IsA("ParticleEmitter") then
		puffTemplate = puff
	else
		warn("ReplicatedStorage.Assets.Effects.OrderPuff (ParticleEmitter) is missing; the take-order ring is skipped")
	end
	local sounds = SoundService:FindFirstChild("SoundEffects")
	local orderIn = if sounds then sounds:FindFirstChild("OrderIn") else nil
	if orderIn ~= nil and orderIn:IsA("Sound") then
		sound = orderIn
	else
		warn("SoundService.SoundEffects.OrderIn (Sound) is missing; the take-order sound is skipped")
	end
	temp.ChildRemoved:Connect(function(child: Instance): ()
		if child:IsA("Model") then
			lastStates[child] = nil
			predicted[child] = nil
			warps[child] = nil
		end
	end)
	RunService.RenderStepped:Connect(function(): ()
		local clock = os.clock()
		for _, child in temp:GetChildren() do
			if child:IsA("Model") then
				local state = child:GetAttribute("CustomerState")
				local current = if typeof(state) == "string" then state else ""
				local previous = lastStates[child]
				if previous ~= nil and previous == "WaitingToOrder" and current == "WaitingForFood" then
					local at = predicted[child]
					if at == nil or clock - at > tuning.ConfirmWindow then
						play(child)
					end
					predicted[child] = nil
				end
				lastStates[child] = current
			end
		end
		for model, at in predicted do
			if clock - at > tuning.ConfirmWindow or model.Parent ~= temp then
				predicted[model] = nil
			end
		end
		for model, warp in warps do
			if model.Parent ~= temp then
				warps[model] = nil
			else
				stepWarp(model, warp, clock)
			end
		end
	end)
end

return OrderTakeController
