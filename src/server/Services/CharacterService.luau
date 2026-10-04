--!strict

local Players = game:GetService("Players")

local CharacterService = {}

local COLLISION_GROUP = "Character"

local function setGroup(instance: Instance): ()
	if instance:IsA("BasePart") then
		instance.CollisionGroup = COLLISION_GROUP
	end
end

local function setupCharacter(character: Model): ()
	for _, descendant in character:GetDescendants() do
		setGroup(descendant)
	end
	-- Accessories and tools add parts after spawn.
	character.DescendantAdded:Connect(setGroup)

	-- Legacy CharacterLoader: no jumping, Space is the interact key.
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.UseJumpPower = true
	humanoid.JumpPower = 0
end

local function setupPlayer(player: Player): ()
	player.CharacterAdded:Connect(setupCharacter)
	local character = player.Character
	if character then
		task.spawn(setupCharacter, character)
	end
end

function CharacterService.Start(_self: typeof(CharacterService)): ()
	Players.PlayerAdded:Connect(setupPlayer)
	for _, player in Players:GetPlayers() do
		setupPlayer(player)
	end
end

return CharacterService
