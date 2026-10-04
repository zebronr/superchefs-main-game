--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"):WaitForChild("Interaction")).Throw
local Projectile = require(Shared:WaitForChild("Util"):WaitForChild("Projectile"))
local Tags = require(Shared:WaitForChild("Tags"))

local ProjectileController = {}

type Tracked = {
	Part: BasePart,
	Trail: Trail,
	First: Attachment,
	Second: Attachment,
	Destroying: RBXScriptConnection,
}

local tracked: { [Instance]: Tracked } = {}
local trailTemplate: Trail

local function destroyTrail(state: Tracked): ()
	state.Trail:Destroy()
	state.First:Destroy()
	state.Second:Destroy()
end

local function untrack(instance: Instance, destroyed: boolean): ()
	local state = tracked[instance]
	if state == nil then
		return
	end
	tracked[instance] = nil
	state.Destroying:Disconnect()
	if destroyed then
		destroyTrail(state)
	else
		task.delay(Config.TrailLinger, function(): ()
			destroyTrail(state)
		end)
	end
end

local function track(instance: Instance): ()
	if tracked[instance] ~= nil or not instance:IsA("BasePart") then
		return
	end
	local trail = trailTemplate:Clone()
	local first = Instance.new("Attachment")
	local second = Instance.new("Attachment")
	first.Position = Vector3.new(-1, 0, 0)
	second.Position = Vector3.new(1, 0, 0)
	first.Parent = instance
	second.Parent = instance
	trail.Attachment0 = first
	trail.Attachment1 = second
	trail.Parent = instance
	tracked[instance] = {
		Part = instance,
		Trail = trail,
		First = first,
		Second = second,
		Destroying = instance.Destroying:Connect(function(): ()
			untrack(instance, true)
		end),
	}
end

local function render(state: Tracked): ()
	local part = state.Part
	local start = part:GetAttribute(Config.ThrowStartAttribute)
	if typeof(start) ~= "CFrame" then
		return
	end
	local fallStartedAt = part:GetAttribute(Config.FallStartedAtAttribute)
	if typeof(fallStartedAt) == "number" then
		local from = part:GetAttribute(Config.FallFromAttribute)
		local to = part:GetAttribute(Config.FallToAttribute)
		if typeof(from) == "Vector3" and typeof(to) == "Vector3" then
			local duration = Projectile.FallDuration(from, to)
			local t = if duration > 0 then math.clamp((workspace:GetServerTimeNow() - fallStartedAt) / duration, 0, 1) else 1
			part.CFrame = Projectile.At(start, from:Lerp(to, t))
		end
		return
	end
	local finish = part:GetAttribute(Config.ThrowEndAttribute)
	local startedAt = part:GetAttribute(Config.ThrowStartedAtAttribute)
	if typeof(finish) ~= "Vector3" or typeof(startedAt) ~= "number" then
		return
	end
	local duration = Projectile.Duration(start.Position, finish)
	local t = if duration > 0 then math.clamp((workspace:GetServerTimeNow() - startedAt) / duration, 0, 1) else 1
	part.CFrame = Projectile.At(start, Projectile.Bezier(start.Position, finish, t))
end

function ProjectileController.Start(_self: typeof(ProjectileController)): ()
	local template = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("ProjectileTrail")
	assert(template:IsA("Trail"), "ProjectileTrail must be a Trail")
	trailTemplate = template
	CollectionService:GetInstanceAddedSignal(Tags.Projectile):Connect(track)
	CollectionService:GetInstanceRemovedSignal(Tags.Projectile):Connect(function(instance: Instance): ()
		untrack(instance, false)
	end)
	for _, instance in CollectionService:GetTagged(Tags.Projectile) do
		track(instance)
	end
	RunService.RenderStepped:Connect(function(): ()
		for _, state in tracked do
			render(state)
		end
	end)
end

return ProjectileController
