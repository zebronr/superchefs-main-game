--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AnimationController = require(script.Parent.AnimationController)
local CharacterEffectsController = require(script.Parent.CharacterEffectsController)
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Character"))
local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

local MovementController = {}
local nextDashAt = 0

function MovementController.Dash(): ()
	local now = os.clock()
	if now < nextDashAt then
		return
	end
	local character = Players.LocalPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if root == nil or not root:IsA("BasePart") or humanoid == nil or humanoid.Health <= 0 then
		return
	end
	nextDashAt = now + Config.DashCooldown
	local attachment = Instance.new("Attachment")
	attachment.Parent = root
	local velocity = Instance.new("LinearVelocity")
	velocity.Attachment0 = attachment
	velocity.MaxForce = Config.DashMaxForce
	velocity.VectorVelocity = root.CFrame.LookVector * Vector3.new(1, 0, 1) * Config.DashStrength
	velocity.Parent = root
	AnimationController.PlayDash()
	CharacterEffectsController.PlayLocalDash()
	Net.Event("Interact"):FireServer("Dash")
	local elapsed = 0
	local heartbeat: RBXScriptConnection? = nil
	heartbeat = RunService.Heartbeat:Connect(function(dt: number): ()
		elapsed += dt
		if elapsed >= Config.DashLength or root.Parent == nil then
			if heartbeat then
				heartbeat:Disconnect()
			end
			velocity:Destroy()
			attachment:Destroy()
			return
		end
		velocity.VectorVelocity = root.CFrame.LookVector * Vector3.new(1, 0, 1) * (Config.DashStrength * Config.DashFollowupFactor)
	end)
end

return MovementController
