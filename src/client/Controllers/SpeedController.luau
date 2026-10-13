--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

-- Owns the local character's WalkSpeed and AutoRotate. Anything that changes speed (skills, ice) sets a
-- named multiplier, and anything that roots the character sets a named root; this module combines them
-- with the character's own speed, so effects never overwrite each other's saved values. Chefs also stand still
-- until the round starts (Config.Round.FrozenStates).
local SpeedController = {}

local localPlayer = Players.LocalPlayer
local multipliers: { [string]: number } = {}
local roots: { [string]: boolean } = {}
local tracked: Humanoid? = nil
local baseWalkSpeed = 16
local baseAutoRotate = true

-- True while the round hasn't started yet: no walking or dashing.
function SpeedController.RoundFrozen(): boolean
	local state = ReplicatedStorage:GetAttribute("RoundState")
	return typeof(state) == "string" and Config.Round.FrozenStates[state] == true
end

local function apply(): ()
	local character = localPlayer.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid == nil then
		return
	end
	if humanoid ~= tracked then
		-- A new character: its spawned values are the base.
		tracked = humanoid
		baseWalkSpeed = humanoid.WalkSpeed
		baseAutoRotate = humanoid.AutoRotate
	end
	if next(roots) ~= nil or SpeedController.RoundFrozen() then
		humanoid.WalkSpeed = 0
		humanoid.AutoRotate = false
		return
	end
	local speed = baseWalkSpeed
	for _, multiplier in multipliers do
		speed *= multiplier
	end
	humanoid.WalkSpeed = speed
	humanoid.AutoRotate = baseAutoRotate
end

-- nil removes the multiplier.
function SpeedController.SetMultiplier(name: string, value: number?): ()
	if multipliers[name] == value then
		return
	end
	if value == nil then
		multipliers[name] = nil
	else
		multipliers[name] = value
	end
	apply()
end

function SpeedController.SetRooted(name: string, rooted: boolean): ()
	if rooted then
		roots[name] = true
	else
		roots[name] = nil
	end
	apply()
end

function SpeedController.IsRooted(): boolean
	return next(roots) ~= nil
end

function SpeedController.Start(_self: typeof(SpeedController)): ()
	localPlayer.CharacterAdded:Connect(function(): ()
		-- Effects from the old character do not carry over.
		table.clear(multipliers)
		table.clear(roots)
	end)
	RunService.Heartbeat:Connect(apply)
end

return SpeedController
