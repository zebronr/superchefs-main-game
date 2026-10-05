--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local CookingConfig = Config.Interaction.Cooking
local Tags = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Tags"))
local SkillEffects = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("SkillEffects"))

local FireService = {}

type Burnable = { Instance: Instance, Kind: string }

type Fire = {
	Object: Burnable,
	NextSpreadAt: number,
	Destroying: RBXScriptConnection,
}

local fires: { [Instance]: Fire } = {}
local burnableTags = { Tags.Countertop, Tags.ChoppingBoard, Tags.Stove, Tags.CookingTool }
local getObjects: ((string) -> { Burnable })? = nil

function FireService.SetObjectProvider(provider: (string) -> { Burnable }): ()
	getObjects = provider
end

local function isBurnable(object: Burnable): boolean
	local class = Tags.ClassOf(object.Instance)
	if class == Tags.CookingTool then
		local enabled = (object :: any).IsEnabled
		return typeof(enabled) == "function" and enabled(object)
	end
	return class == Tags.Countertop or class == Tags.ChoppingBoard or class == Tags.Stove
end

local function untrack(instance: Instance): ()
	local fire = fires[instance]
	if fire ~= nil then
		fires[instance] = nil
		fire.Destroying:Disconnect()
	end
end

function FireService.IsBurning(instance: Instance): boolean
	return fires[instance] ~= nil and typeof(instance:GetAttribute(CookingConfig.FireAttribute)) == "number"
end

function FireService.Burn(object: Burnable): ()
	local instance = object.Instance
	if not instance:IsDescendantOf(workspace) or not isBurnable(object) or FireService.IsBurning(instance) then
		return
	end
	instance:SetAttribute(CookingConfig.FireAttribute, CookingConfig.FireStart)
	CollectionService:AddTag(instance, Tags.FireLocked)
	fires[instance] = {
		Object = object,
		NextSpreadAt = workspace:GetServerTimeNow() + CookingConfig.FireSpreadInterval,
		Destroying = instance.Destroying:Connect(function(): ()
			untrack(instance)
		end),
	}
end

function FireService.Extinguish(instance: Instance, amount: number): ()
	if amount <= 0 or not FireService.IsBurning(instance) then
		return
	end
	local value = instance:GetAttribute(CookingConfig.FireAttribute)
	if typeof(value) ~= "number" then
		return
	end
	local remaining = value - amount
	if remaining > 0 then
		instance:SetAttribute(CookingConfig.FireAttribute, remaining)
	else
		instance:SetAttribute(CookingConfig.FireAttribute, nil)
		CollectionService:RemoveTag(instance, Tags.FireLocked)
		untrack(instance)
	end
end

-- Deep Freeze circles running this frame; fire neither spreads from nor into them.
local frozenZones: { SkillEffects.Zone } = {}

local function isFrozen(instance: Instance): boolean
	return #frozenZones > 0 and instance:IsA("BasePart") and SkillEffects.IsFrozen(instance.Position, frozenZones)
end

local function canSpreadTo(source: Burnable, target: Burnable): boolean
	if source == target or FireService.IsBurning(target.Instance) or not isBurnable(target) then
		return false
	end
	if not source.Instance:IsDescendantOf(workspace) or not target.Instance:IsDescendantOf(workspace) then
		return false
	end
	local sourcePart = source.Instance
	local targetPart = target.Instance
	if not sourcePart:IsA("BasePart") or not targetPart:IsA("BasePart") then
		return false
	end
	if (sourcePart.Position - targetPart.Position).Magnitude > CookingConfig.FireSpreadDistance then
		return false
	end
	if isFrozen(targetPart) then
		return false
	end
	if target.Kind == "Station" then
		local slot = (target :: any).Slot
		local onTop = slot:Get()
		local topClass = if onTop ~= nil then Tags.ClassOf(onTop.Instance) else nil
		if onTop ~= nil and (onTop == source or (topClass ~= nil and table.find(burnableTags, topClass) ~= nil)) then
			return false
		end
	end
	return true
end

function FireService.Start(_self: typeof(FireService)): ()
	RunService.Heartbeat:Connect(function(dt: number): ()
		local now = workspace:GetServerTimeNow()
		frozenZones = if next(fires) ~= nil then SkillEffects.FreezeZones(now) else {}
		-- Burn adds to `fires`, so iterate over a copy.
		for instance, fire in table.clone(fires) do
			if not instance:IsDescendantOf(workspace) then
				instance:SetAttribute(CookingConfig.FireAttribute, nil)
				CollectionService:RemoveTag(instance, Tags.FireLocked)
				untrack(instance)
			elseif isFrozen(instance) then
				-- Frozen fires keep burning but their spread countdown waits.
				fire.NextSpreadAt += dt
			elseif now >= fire.NextSpreadAt then
				fire.NextSpreadAt += CookingConfig.FireSpreadInterval
				local source = fire.Object
				local provider = getObjects
				if provider == nil then
					continue
				end
				for _, tag in burnableTags do
					for _, target in provider(tag) do
						if canSpreadTo(source, target) then
							FireService.Burn(target)
						end
					end
				end
			end
		end
	end)
end

return FireService
