local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local TimeSync = Remotes:WaitForChild("TimeSync") 

TimeSync.OnServerInvoke = function(player)
    return tick()
end