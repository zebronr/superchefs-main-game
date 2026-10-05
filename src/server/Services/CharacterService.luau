--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Character"))
local TeamService = require(script.Parent.TeamService)

local CharacterService = {}
local COLLISION_GROUP = "Character"
local tracked: { [Player]: boolean } = {}
local lastDash: { [Player]: number } = {}

local function playerColor(player: Player): Color3
	local colors = Config.Colors[TeamService.GetTeam(player)] or Config.Colors[1]
	local slot = TeamService.GetSlot(player)
	return colors[(slot - 1) % #colors + 1]
end

function CharacterService.RefreshColors(): ()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character ~= nil and character:GetAttribute("CustomCharacter") == true then
			character:SetAttribute("PlayerColor", playerColor(player))
		end
	end
end

local function setGroup(instance: Instance): ()
	if instance:IsA("BasePart") then
		instance.CollisionGroup = COLLISION_GROUP
	end
end

local function setupCharacter(player: Player, character: Model): ()
	if character:GetAttribute("CustomCharacter") ~= true then
		local characters = ServerStorage:WaitForChild("Characters")
		local modelName = Config.CharacterModels[player.Name] or Config.DefaultCharacterModel
		local template = characters:FindFirstChild(modelName)
		if template == nil or not template:IsA("Model") then
			warn(`Character model {modelName} is missing for {player.Name}`)
			return
		end
		local clone = template:Clone()
		clone.Name = player.Name
		clone:SetAttribute("CustomCharacter", true)
		clone:SetAttribute("PlayerColor", playerColor(player))
		clone:PivotTo(character:GetPivot())
		clone.Parent = workspace
		player.Character = clone
		character:Destroy()
		return
	end
	for _, descendant in character:GetDescendants() do
		setGroup(descendant)
	end
	-- Accessories and tools add parts after spawn.
	character.DescendantAdded:Connect(setGroup)

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid ~= nil then
		humanoid.UseJumpPower = true
		humanoid.JumpPower = 0
	end
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
	if now - (lastDash[player] or -math.huge) < Config.DashEffectCooldown then
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
		if character ~= nil and character:GetAttribute("CustomCharacter") == true then
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
