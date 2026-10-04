--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Loader = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("Loader"))

Loader.Start(script:WaitForChild("Controllers"))
