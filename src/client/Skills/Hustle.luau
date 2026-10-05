--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SpeedController = require(script.Parent.Parent.Controllers.SpeedController)
local InstantSkill = require(script.Parent.InstantSkill)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local HustleConfig = Config.Skills.Hustle
local visuals = HustleConfig.Visuals
local SkillEffects = require(Shared:WaitForChild("Util"):WaitForChild("SkillEffects"))

-- Bill: Hustle, client side. The local player speeds up on press; every client draws the steam,
-- the speed trail and the exhale for every hustling Bill from HustleUntil.

type Visual = {
	Trail: Trail?,
	Attachments: { Attachment },
	Aura: ParticleEmitter?,
}

local localPlayer = Players.LocalPlayer
local trailTemplate: Trail? = nil
local auraTemplate: ParticleEmitter? = nil
local steamTemplate: ParticleEmitter? = nil
local exhaleTemplate: ParticleEmitter? = nil

-- Local prediction: os.clock() when the local Hustle ends.
local predictedUntil: number? = nil
local active: { [Model]: Visual } = {}

local function removeVisual(character: Model, exhale: boolean): ()
	local visual = active[character]
	if visual == nil then
		return
	end
	active[character] = nil
	if visual.Trail ~= nil then
		visual.Trail:Destroy()
	end
	for _, attachment in visual.Attachments do
		attachment:Destroy()
	end
	if visual.Aura ~= nil then
		visual.Aura:Destroy()
	end
	local root = InstantSkill.Root(character)
	if exhale and root ~= nil then
		InstantSkill.Burst(exhaleTemplate, root.CFrame, visuals.EndCount)
	end
end

local function addVisual(character: Model): ()
	local root = InstantSkill.Root(character)
	if root == nil or active[character] ~= nil then
		return
	end
	local visual: Visual = { Trail = nil, Attachments = {}, Aura = nil }
	if trailTemplate ~= nil then
		local top = Instance.new("Attachment")
		top.Name = "HustleTrailTop"
		top.Position = Vector3.new(0, visuals.TrailWidth / 2, 0)
		top.Parent = root
		local bottom = Instance.new("Attachment")
		bottom.Name = "HustleTrailBottom"
		bottom.Position = Vector3.new(0, -visuals.TrailWidth / 2, 0)
		bottom.Parent = root
		local trail = trailTemplate:Clone()
		trail.Attachment0 = top
		trail.Attachment1 = bottom
		trail.Enabled = true
		trail.Parent = root
		visual.Trail = trail
		visual.Attachments = { top, bottom }
	end
	if auraTemplate ~= nil then
		local aura = auraTemplate:Clone()
		aura.Enabled = true
		aura.Parent = root
		visual.Aura = aura
	end
	active[character] = visual
	InstantSkill.Burst(steamTemplate, root.CFrame, visuals.StartCount)
end

local function isHustling(character: Model, now: number): boolean
	if character == localPlayer.Character and predictedUntil ~= nil then
		return true
	end
	return SkillEffects.HustleActive(character, now)
end

local function step(): ()
	local now = workspace:GetServerTimeNow()
	local character = localPlayer.Character
	local endsAt = predictedUntil
	if endsAt ~= nil and os.clock() >= endsAt then
		predictedUntil = nil
	end
	-- Speed follows the prediction on local time, then whatever the server says.
	SpeedController.SetMultiplier(
		"Hustle",
		if character ~= nil and isHustling(character, now) then HustleConfig.MoveMultiplier else nil
	)

	local seen: { [Model]: boolean } = {}
	for _, player in Players:GetPlayers() do
		local other = player.Character
		if other ~= nil and isHustling(other, now) then
			seen[other] = true
			addVisual(other)
		end
	end
	for model in table.clone(active) do
		if not seen[model] then
			removeVisual(model, model.Parent ~= nil)
		end
	end
end

local Hustle: InstantSkill.InstantSkill = {
	RequiresEmptyHands = false,
	Setup = function(): ()
		local folder = InstantSkill.Folder("Hustle")
		trailTemplate = InstantSkill.Template(folder, "SpeedTrail", "Trail") :: Trail?
		auraTemplate = InstantSkill.Template(folder, "Aura", "ParticleEmitter") :: ParticleEmitter?
		steamTemplate = InstantSkill.Template(folder, "Steam", "ParticleEmitter") :: ParticleEmitter?
		exhaleTemplate = InstantSkill.Template(folder, "Exhale", "ParticleEmitter") :: ParticleEmitter?
		RunService.Heartbeat:Connect(step)
	end,
	CanUse = function(_character: Model): boolean
		return true
	end,
	Predict = function(character: Model): ()
		predictedUntil = os.clock() + HustleConfig.Duration
		SpeedController.SetMultiplier("Hustle", HustleConfig.MoveMultiplier)
		addVisual(character)
	end,
	Rollback = function(): ()
		predictedUntil = nil
		SpeedController.SetMultiplier("Hustle", nil)
		local character = localPlayer.Character
		if character ~= nil and not SkillEffects.HustleActive(character) then
			removeVisual(character, false)
		end
	end,
	IsBusy = function(): boolean
		return false
	end,
}

return Hustle
