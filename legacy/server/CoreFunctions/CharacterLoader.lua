local module = {}

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Modules")

local Configs = Shared:WaitForChild("Configs")
local CharacterColors = require(Configs:WaitForChild("CharacterColors"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local EffectsRemotes = Remotes:WaitForChild("Effects")
local EffectsRE = EffectsRemotes:WaitForChild("Effects")

local CharacterRemotes = Remotes:WaitForChild("Character")
local LoadAnimationRE = CharacterRemotes:WaitForChild("LoadAnimations")

local StarterCharacterScripts = StarterPlayer:WaitForChild("StarterCharacterScripts")

local Characters = ServerStorage:WaitForChild("Characters")

local plrchar = {
    St4rqqs = Characters:WaitForChild("Bill"),
    zebronr = Characters:WaitForChild("Gecko"),
    Player1 = Characters:WaitForChild("Bill"),
    Player2 = Characters:WaitForChild("Bill"),
    idgiveup4ever2touchu = Characters:WaitForChild("Bill"),
}

local function loadCharacter(player, character)
    character = character:Clone()
    character.Parent = workspace

    local humanoid:Humanoid = character:WaitForChild("Humanoid")
    humanoid.JumpPower = 0

    player.Character = character
    return character
end

function module.loadPlayerChar(player, playerTeam, playerNum)
    local character = loadCharacter(player, plrchar[player.Name])

    for _, s in pairs(StarterCharacterScripts:GetChildren()) do
        s:Clone().Parent = character
    end

    EffectsRE:FireClient(player, "plrIndicator", {
        c = CharacterColors.Color[playerTeam][playerNum]
    })

    EffectsRE:FireAllClients("charHighlight", {
        ch = character,
        c = CharacterColors.Color[playerTeam][playerNum]
    })

    task.wait(1)
    LoadAnimationRE:FireClient(player)
end

return module