--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Loader = require(Shared:WaitForChild("Util"):WaitForChild("Loader"))
local Net = require(Shared:WaitForChild("Net"))

Loader.Start(script:WaitForChild("Controllers"))
-- Every controller is listening now, so the server can send the join-time messages.
Net.Event("Round"):FireServer("Ready")
