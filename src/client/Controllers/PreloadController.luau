--!strict

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AssetIds = require(Shared:WaitForChild("Util"):WaitForChild("AssetIds"))
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Tuning = Config.Preload

local PreloadController = {}
local localPlayer = Players.LocalPlayer
local completed = 0
local seen: { [string]: boolean } = {}

function PreloadController.IsReady(tier: number): boolean
	return completed >= tier
end

function PreloadController.WhenReady(tier: number): ()
	while not PreloadController.IsReady(tier) do
		task.wait()
	end
end

local function batches(ids: { string }): { string }
	local failed: { [string]: boolean } = {}
	local batchSize = math.max(1, Tuning.BatchSize)
	for first = 1, #ids, batchSize do
		local batch: { string } = {}
		for index = first, math.min(first + batchSize - 1, #ids) do
			table.insert(batch, ids[index])
		end
		local ok = pcall(function(): ()
			ContentProvider:PreloadAsync(batch, function(id: string, status: Enum.AssetFetchStatus): ()
				if status ~= Enum.AssetFetchStatus.Success then
					failed[id] = true
				end
			end)
		end)
		if not ok then
			for _, id in batch do
				failed[id] = true
			end
		end
		if first + batchSize <= #ids then
			task.wait(Tuning.BatchDelay)
		end
	end
	local retry: { string } = {}
	for _, id in ids do
		if failed[id] then
			table.insert(retry, id)
		end
	end
	return retry
end

local function download(roots: { Instance }, extraIds: { string }?): ()
	local ids: { string } = {}
	AssetIds.Collect(roots, ids, seen)
	if extraIds ~= nil then
		for _, id in extraIds do
			if typeof(id) == "string" and id ~= "" and string.sub(id, 1, 11) ~= "rbxasset://" and not seen[id] then
				seen[id] = true
				table.insert(ids, id)
			end
		end
	end
	local retry = batches(ids)
	if #retry > 0 then
		batches(retry)
	end
end

-- Images that live only in code, never on an instance, so AssetIds.Collect can't find them:
-- the current level's recipe food and ingredient icons, and every bitmap font atlas.
local function codeImages(): { string }
	local ids: { string } = {}
	for _, recipe in Config.Levels.GetCurrent().Recipes do
		table.insert(ids, recipe.FoodImage)
		for _, step in recipe.Steps do
			for _, image in step.ingredient_images do
				table.insert(ids, image)
			end
		end
	end
	local dynamicRequire = require :: (ModuleScript) -> any
	for _, module in Shared:WaitForChild("Fonts"):GetChildren() do
		if module:IsA("ModuleScript") then
			local ok, font = pcall(dynamicRequire, module)
			if ok and typeof(font) == "table" and typeof(font.Image) == "string" and font.Image ~= "rbxassetid://0" then
				table.insert(ids, font.Image)
			end
		end
	end
	return ids
end

local function ownSkillName(): string?
	local deadline = os.clock() + Tuning.CharacterWait
	repeat
		local character = localPlayer.Character
		if character ~= nil then
			local model = character:GetAttribute(Config.Skills.Attribute.CharacterModel)
			if typeof(model) == "string" then
				return Config.Skills.ByCharacter[model]
			end
		end
		task.wait()
	until os.clock() >= deadline
	return nil
end

local function warmFolder(folder: Instance): ()
	local camera = workspace.CurrentCamera
	if camera == nil then
		return
	end
	local clones: { BasePart } = {}
	for _, template in folder:GetDescendants() do
		if template:IsA("BasePart") and (template:IsA("MeshPart") or template:FindFirstChildOfClass("SpecialMesh") ~= nil) then
			local clone = template:Clone() :: BasePart
			clone.Anchored = true
			clone.CanCollide = false
			clone.CanQuery = false
			clone.CanTouch = false
			clone.CastShadow = false
			clone.LocalTransparencyModifier = 0
			clone.Transparency = 0.98
			clone.CFrame = camera.CFrame * CFrame.new(0, 0, -Tuning.WarmUpDistance)
			for _, child in clone:GetDescendants() do
				if child:IsA("ParticleEmitter") then
					child.Enabled = false
				end
			end
			clone.Parent = camera
			table.insert(clones, clone)
		end
	end
	if #clones > 0 then
		RunService.RenderStepped:Wait()
		RunService.RenderStepped:Wait()
		for _, clone in clones do
			clone:Destroy()
		end
	end
end

local function run(): ()
	local assets = ReplicatedStorage:WaitForChild("Assets")
	local skills = assets:WaitForChild("Skills")
	local name = ownSkillName()
	local ownFolder = if name ~= nil then skills:FindFirstChild(name) else nil
	local sounds = SoundService:WaitForChild("SoundEffects")
	local first: { Instance } = {}
	if ownFolder ~= nil then
		table.insert(first, ownFolder)
	end
	table.insert(first, sounds)
	-- Recipe icons and fonts show as soon as the round starts, so they load in the first tier.
	download(first, codeImages())
	if Tuning.WarmUp and ownFolder ~= nil then
		warmFolder(ownFolder)
	end
	completed = 1

	local second: { Instance } = { assets, ReplicatedStorage:WaitForChild("UIs") }
	table.insert(second, localPlayer:WaitForChild("PlayerGui"))
	download(second)
	if Tuning.WarmUp then
		for _, folder in skills:GetChildren() do
			if folder ~= ownFolder then
				warmFolder(folder)
			end
		end
	end
	completed = 2

	local ok, result = pcall(function(): any
		return Net.Function("Preload"):InvokeServer()
	end)
	if ok and typeof(result) == "table" then
		download({}, result)
	else
		warn(`PreloadController: server asset list unavailable: {result}`)
	end
	completed = 3

	download({ ReplicatedStorage:WaitForChild("NPCs") })
	completed = 4
end

function PreloadController.Start(_self: typeof(PreloadController)): ()
	task.spawn(run)
end

return PreloadController
