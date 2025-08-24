local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local EffectsRemotes = Remotes:WaitForChild("Effects")
local RequestEffectToServerRE = EffectsRemotes:WaitForChild("RequestEffectToServer")
local EffectsRE = EffectsRemotes:WaitForChild("Effects")

local onCooldown = {}

local cooldowns = {
    dash = .30
}

RequestEffectToServerRE.OnServerEvent:Connect(function(player, requestType)
    if onCooldown[player] or not cooldowns[requestType] then return end
    task.delay(cooldowns[requestType], function()
        onCooldown[player] = nil
    end)

    for _, p in pairs(Players:GetPlayers()) do
        if p == player then continue end

        EffectsRE:FireClient(p, requestType, {
            s = true,
            pc = player.Character or player.CharacterAdded:Wait()
        })
    end
end)