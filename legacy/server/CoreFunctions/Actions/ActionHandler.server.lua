local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Actions = Remotes:WaitForChild("Actions")
local ActionRequest:RemoteEvent = Actions:WaitForChild("ActionRequest")

local Throw = require(script.Parent:WaitForChild("ThrowAction"))

ActionRequest.OnServerEvent:Connect(function(player, action, params)
    if action == "throw" and params.localCFrame then
        Throw.ThrowObject(player, params.localCFrame)
    end 
end)