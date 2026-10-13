--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AnimationController = require(script.Parent.AnimationController)
local CharacterEffectsController = require(script.Parent.CharacterEffectsController)
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local CharacterConfig = Config.Character
local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))
local SpeedController = require(script.Parent.SpeedController)
local SkillEffects = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("SkillEffects"))

local MovementController = {}
local nextDashAt = 0

function MovementController.Dash(): ()
	local now = os.clock()
	if now < nextDashAt or SpeedController.RoundFrozen() then
		return
	end
	local character = Players.LocalPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if root == nil or not root:IsA("BasePart") or humanoid == nil or humanoid.Health <= 0 then
		return
	end
	nextDashAt = now + CharacterConfig.DashCooldown
	local sturdy = SkillEffects.Sturdy(character)
	local attachment = Instance.new("Attachment")
	local velocity = Instance.new("LinearVelocity")
	velocity.Attachment0 = attachment
	local upright: AlignOrientation? = nil
	-- A sturdy chef (the Bear) is so heavy that its own ground friction outweighs any sane force limit. The unlimited
	-- push acts on the centre of mass and only flat (so it can't tip the Bear over against a counter), and an
	-- upright hold keeps it standing; its X axis points up for that hold.
	if sturdy then
		attachment.CFrame = CFrame.fromMatrix(
			root.CFrame:PointToObjectSpace(root.AssemblyCenterOfMass),
			Vector3.yAxis,
			Vector3.zAxis
		)
		velocity.ForceLimitsEnabled = false
		velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
		velocity.PrimaryTangentAxis = Vector3.xAxis
		velocity.SecondaryTangentAxis = Vector3.zAxis
		local align = Instance.new("AlignOrientation")
		align.Mode = Enum.OrientationAlignmentMode.OneAttachment
		align.AlignType = Enum.AlignType.PrimaryAxisParallel
		align.PrimaryAxis = Vector3.yAxis
		align.Attachment0 = attachment
		align.RigidityEnabled = true
		align.Parent = root
		upright = align
	else
		velocity.MaxForce = CharacterConfig.DashMaxForce
	end
	attachment.Parent = root
	local function setVelocity(speed: number): ()
		local flat = root.CFrame.LookVector * Vector3.new(1, 0, 1) * speed
		if sturdy then
			velocity.PlaneVelocity = Vector2.new(flat.X, flat.Z)
		else
			velocity.VectorVelocity = flat
		end
	end
	setVelocity(CharacterConfig.DashStrength)
	velocity.Parent = root
	AnimationController.PlayDash()
	CharacterEffectsController.PlayLocalDash()
	Net.Event("Interact"):FireServer("Dash")
	local elapsed = 0
	local heartbeat: RBXScriptConnection? = nil
	heartbeat = RunService.Heartbeat:Connect(function(dt: number): ()
		elapsed += dt
		if elapsed >= CharacterConfig.DashLength or root.Parent == nil then
			if heartbeat then
				heartbeat:Disconnect()
			end
			velocity:Destroy()
			if upright ~= nil then
				upright:Destroy()
			end
			attachment:Destroy()
			return
		end
		setVelocity(CharacterConfig.DashStrength * CharacterConfig.DashFollowupFactor)
	end)
end

return MovementController
