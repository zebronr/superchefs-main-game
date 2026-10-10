--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CookingTool = require(script.Parent.Parent.Classes.CookingTool)
local BinderService = require(script.Parent.BinderService)
local CustomerService = require(script.Parent.CustomerService)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local FreezeConfig = Config.Skills.DeepFreeze
local SkillEffects = require(Shared:WaitForChild("Util"):WaitForChild("SkillEffects"))
local Tags = require(Shared:WaitForChild("Tags"))

-- Applies the Penguin's frost circles: cooking tools inside one are frozen, and customers inside it
-- when it is cast. Each thaws when it leaves the circle or the circle ends. Fire spread checks the circles itself (FireService).
local FreezeService = {}

-- Typed loosely: the CookingTool method types do not unify through the binder's Interactable type.
local frozenTools: { [any]: true } = {}
local frozenCustomers: { [Model]: true } = {}
-- Circles already seen, keyed by owner and start time; customers who walk in later are not caught.
local seenZones: { [string]: true } = {}

local function zoneKey(zone: SkillEffects.Zone): string
	return zone.Owner:GetFullName() .. "@" .. tostring(zone.StartedAt)
end

local function positionOf(instance: Instance): Vector3?
	if instance:IsA("BasePart") then
		return instance.Position
	elseif instance:IsA("Model") then
		return instance:GetPivot().Position
	end
	return nil
end

local function inside(instance: Instance, zones: { SkillEffects.Zone }): boolean
	if #zones == 0 or not instance:IsDescendantOf(workspace) then
		return false
	end
	local position = positionOf(instance)
	return position ~= nil and SkillEffects.IsFrozen(position, zones)
end

local function scanTools(zones: { SkillEffects.Zone }): ()
	local binder = BinderService.Get(Tags.CookingTool)
	if #zones > 0 and binder ~= nil then
		for _, object in binder:GetAll() do
			local tool: any = CookingTool.Cast(object :: any)
			if tool ~= nil and inside(tool.Instance, zones) and frozenTools[tool] == nil then
				frozenTools[tool] = true
				tool:Freeze()
			end
		end
	end
	for tool: any in table.clone(frozenTools) do
		if not inside(tool.Instance, zones) then
			frozenTools[tool] = nil
			tool:Unfreeze()
		end
	end
end

local function scanCustomers(zones: { SkillEffects.Zone }): ()
	local running: { [string]: true } = {}
	for _, zone in zones do
		local key = zoneKey(zone)
		running[key] = true
		if seenZones[key] == nil then
			seenZones[key] = true
			for _, model in CustomerService.GetModels() do
				if frozenCustomers[model] == nil and inside(model, { zone }) then
					frozenCustomers[model] = true
					CustomerService.SetFrozen(model, true)
				end
			end
		end
	end
	for key in table.clone(seenZones) do
		if running[key] == nil then
			seenZones[key] = nil
		end
	end
	for model in table.clone(frozenCustomers) do
		if not inside(model, zones) then
			frozenCustomers[model] = nil
			CustomerService.SetFrozen(model, false)
		end
	end
end

function FreezeService.Start(_self: typeof(FreezeService)): ()
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt: number): ()
		elapsed += dt
		if elapsed < FreezeConfig.ScanInterval then
			return
		end
		elapsed = 0
		local zones = SkillEffects.FreezeZones()
		if #zones == 0 and next(frozenTools) == nil and next(frozenCustomers) == nil then
			return
		end
		scanTools(zones)
		scanCustomers(zones)
	end)
end

return FreezeService
