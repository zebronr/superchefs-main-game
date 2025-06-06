local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local EffectsRequestRE = Remotes:WaitForChild("EffectsRequest")
local EffectsRE = Remotes:WaitForChild("Effects")

local onCooldown = {}

EffectsRequestRE.OnServerEvent:Connect(function(player, requestType)
    for _, p in pairs(Players:GetPlayers()) do
        if p == player then continue end

        EffectsRE:FireClient(p, requestType, {
            s = true,
            pc = player.Character or player.CharacterAdded:Wait()
        })
    end
end)