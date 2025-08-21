local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function(char)
        for _, p in pairs(char:GetDescendants()) do
            if p:IsA("BasePart") then
                p.CollisionGroup = "Character"
            end
        end
    end)
end)