--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local CharacterConfig = Config.Character
local TeamService = require(script.Parent.TeamService)
local SkillEffects = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("SkillEffects"))

local CharacterService = {}
local tracked: { [Player]: boolean } = {}
local lastDash: { [Player]: number } = {}

local function playerColor(player: Player): Color3
	local colors = CharacterConfig.Colors[TeamService.GetTeam(player)] or CharacterConfig.Colors[1]
	local slot = TeamService.GetSlot(player)
	return colors[(slot - 1) % #colors + 1]
end

function CharacterService.RefreshColors(): ()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if TeamService.IsActive(player) and character ~= nil and character:GetAttribute("CustomCharacter") == true then
			character:SetAttribute("PlayerColor", playerColor(player))
		end
	end
end

local function setGroup(character: Model, instance: Instance): ()
	if instance:IsA("BasePart") then
		instance.CollisionGroup = SkillEffects.CollisionGroup(character)
		-- Sturdy characters (the Bear) are too heavy for others to push.
		if SkillEffects.Sturdy(character) then
			local current = instance.CurrentPhysicalProperties
			instance.CustomPhysicalProperties = PhysicalProperties.new(
				CharacterConfig.SturdyDensity,
				current.Friction,
				current.Elasticity,
				current.FrictionWeight,
				current.ElasticityWeight
			)
		end
	end
end

-- Puts every part back in the group SkillEffects.CollisionGroup picks (after Phased or PhaseUntil changes).
function CharacterService.RefreshGroup(character: Model): ()
	for _, descendant in character:GetDescendants() do
		setGroup(character, descendant)
	end
end

function CharacterService.SetPhased(character: Model, phased: boolean): ()
	character:SetAttribute("Phased", if phased then true else nil)
	CharacterService.RefreshGroup(character)
end

local function setupCharacter(player: Player, character: Model): ()
	if not TeamService.IsActive(player) then
		character:Destroy()
		return
	end
	if character:GetAttribute("CustomCharacter") ~= true then
		local characters = ServerStorage:WaitForChild("Characters")
		local override = CharacterConfig.StudioOverride
		local chosen = player:GetAttribute("ChosenCharacter")
		local modelName = if typeof(chosen) == "string" and table.find(CharacterConfig.Selectable, chosen) ~= nil
			then chosen
			elseif override ~= nil and RunService:IsStudio()
			then override
			else CharacterConfig.CharacterModels[player.Name] or CharacterConfig.DefaultCharacterModel
		local template = characters:FindFirstChild(modelName)
		if template == nil or not template:IsA("Model") then
			warn(`Character model {modelName} is missing for {player.Name}`)
			return
		end
		local clone = template:Clone()
		clone.Name = player.Name
		clone:SetAttribute("CustomCharacter", true)
		clone:SetAttribute(Config.Skills.Attribute.CharacterModel, modelName)
		clone:SetAttribute("PlayerColor", playerColor(player))
		clone:PivotTo(character:GetPivot())
		clone.Parent = workspace
		player.Character = clone
		character:Destroy()
		return
	end
	for _, descendant in character:GetDescendants() do
		setGroup(character, descendant)
	end
	-- Accessories and tools add parts after spawn.
	character.DescendantAdded:Connect(function(descendant: Instance): ()
		setGroup(character, descendant)
	end)

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid ~= nil then
		humanoid.UseJumpPower = true
		humanoid.JumpPower = 0
	end
end

-- Boot screen pick (demo): remembers the chef and respawns the player as it.
function CharacterService.Pick(player: Player, modelName: unknown): ()
	if typeof(modelName) ~= "string" or table.find(CharacterConfig.Selectable, modelName) == nil then
		return
	end
	if not TeamService.IsActive(player) or player:GetAttribute("ChosenCharacter") == modelName then
		return
	end
	player:SetAttribute("ChosenCharacter", modelName)
	player:LoadCharacterAsync()
end

function CharacterService.Dash(player: Player): ()
	local character = player.Character
	if character == nil or character:GetAttribute("CustomCharacter") ~= true then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if root == nil or not root:IsA("BasePart") or humanoid == nil or humanoid.Health <= 0 then
		return
	end
	local now = workspace:GetServerTimeNow()
	if now - (lastDash[player] or -math.huge) < CharacterConfig.DashEffectCooldown then
		return
	end
	lastDash[player] = now
	character:SetAttribute("DashedAt", now)
end

local function setupPlayer(player: Player): ()
	if tracked[player] then
		return
	end
	tracked[player] = true
	player:GetAttributeChangedSignal("Team"):Connect(function(): ()
		local character = player.Character
		if TeamService.IsActive(player) and character ~= nil and character:GetAttribute("CustomCharacter") == true then
			character:SetAttribute("PlayerColor", playerColor(player))
		end
	end)
	player.CharacterAdded:Connect(function(character: Model): ()
		setupCharacter(player, character)
	end)
	local character = player.Character
	if character then
		setupCharacter(player, character)
	end
end

function CharacterService.Start(_self: typeof(CharacterService)): ()
	Players.PlayerAdded:Connect(setupPlayer)
	Players.PlayerRemoving:Connect(function(player: Player): ()
		tracked[player] = nil
		lastDash[player] = nil
		task.defer(CharacterService.RefreshColors)
	end)
	for _, player in Players:GetPlayers() do
		setupPlayer(player)
	end
end

return CharacterService
