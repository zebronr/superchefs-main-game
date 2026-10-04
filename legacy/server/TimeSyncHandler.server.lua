local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local NetworkRemotes = Remotes:WaitForChild("Network")
local TimeSync = NetworkRemotes:WaitForChild("TimeSync") 

TimeSync.OnServerInvoke = function(player)
    return tick()
end