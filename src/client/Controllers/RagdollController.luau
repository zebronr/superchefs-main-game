--!strict

-- Caught dine-and-dashers go flying. The server only marks the customer Caught (CaughtAt, CaughtBy) and keeps them
-- anchored where they stood; every client hides that model and ragdolls a local copy of it, flung away from the
-- catcher, fading out before the server removes the customer CaughtPause seconds after the catch.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local RagdollCopy = require(script.Parent.Parent.Util.RagdollCopy)
local tuning = Config.Customers

type Ragdoll = {
	Copy: RagdollCopy.Copy,
	CaughtAt: number,
}

local RagdollController = {}
local ragdolls: { [Model]: Ragdoll } = {}

local function hide(model: Model): ()
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.LocalTransparencyModifier = 1
		elseif descendant:IsA("Decal") then
			descendant.LocalTransparencyModifier = 1
		end
	end
end

-- Which way the catcher knocks them: away from the catcher, flat, or backwards if the catcher is gone.
local function flingDirection(model: Model, root: BasePart): Vector3
	local by = model:GetAttribute("CaughtBy")
	local catcher = if typeof(by) == "number" then Players:GetPlayerByUserId(by) else nil
	local catcherRoot = if catcher ~= nil and catcher.Character ~= nil then catcher.Character:FindFirstChild("HumanoidRootPart") else nil
	local away = if catcherRoot ~= nil and catcherRoot:IsA("BasePart") then root.Position - catcherRoot.Position else -root.CFrame.LookVector
	away = Vector3.new(away.X, 0, away.Z)
	return if away.Magnitude > 1e-3 then away.Unit else -root.CFrame.LookVector
end

local function ragdoll(model: Model, caughtAt: number): Ragdoll?
	local root = model:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return nil
	end
	local direction = flingDirection(model, root)
	local copy = RagdollCopy.Make(model)
	if copy == nil then
		return nil
	end
	hide(model)
	local ragdollTuning = tuning.Ragdoll
	-- The Bear's catch throws them harder.
	local tossed = model:GetAttribute(Config.Skills.Attribute.CaughtByToss) == true
	local fling = if tossed then Config.Skills.BearToss.RunnerFling else ragdollTuning.Fling
	local lift = if tossed then Config.Skills.BearToss.RunnerLift else ragdollTuning.Lift
	local velocity = direction * fling + Vector3.yAxis * lift
	local spin = Vector3.yAxis:Cross(direction) * ragdollTuning.Spin
	for _, part in copy.Parts do
		part.AssemblyLinearVelocity = velocity
		part.AssemblyAngularVelocity = spin
	end
	return { Copy = copy, CaughtAt = caughtAt }
end

local function fade(view: Ragdoll, now: number): ()
	local fadeTime = tuning.Ragdoll.FadeTime
	local p = math.clamp((now - (view.CaughtAt + tuning.CaughtPause - fadeTime)) / fadeTime, 0, 1)
	if p > 0 then
		RagdollCopy.Fade(view.Copy, p)
	end
end

function RagdollController.Start(_self: typeof(RagdollController)): ()
	local temp = workspace:WaitForChild("$Temp")
	RunService.Heartbeat:Connect(function(): ()
		local now = workspace:GetServerTimeNow()
		for _, child in temp:GetChildren() do
			if child:IsA("Model") and ragdolls[child] == nil and child:GetAttribute("CustomerState") == "Caught" then
				local caughtAt = child:GetAttribute("CaughtAt")
				local view = if typeof(caughtAt) == "number" then ragdoll(child, caughtAt) else nil
				if view ~= nil then
					ragdolls[child] = view
				end
			end
		end
		for model, view in ragdolls do
			if model.Parent == nil or now - view.CaughtAt >= tuning.CaughtPause then
				view.Copy.Model:Destroy()
				if model.Parent ~= nil then
					hide(model)
				end
				if model.Parent == nil then
					ragdolls[model] = nil
				end
			else
				fade(view, now)
			end
		end
	end)
end

return RagdollController
