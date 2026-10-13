--!strict

-- Host chat commands (Config.Round.StartHosts; anyone in Studio while StudioAnyoneStarts). /resetgame puts the
-- server back to the boot screen before START; the server checks the same list.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))

local AdminController = {}
local player = Players.LocalPlayer

function AdminController.Start(_self: typeof(AdminController)): ()
	local tuning = Config.Round
	local allowed = (tuning.StudioAnyoneStarts and RunService:IsStudio()) or table.find(tuning.StartHosts, player.UserId) ~= nil
	local command = TextChatService:WaitForChild(tuning.ResetCommand) :: TextChatCommand
	command.Enabled = allowed
	if not allowed then
		return
	end
	command.Triggered:Connect(function(source: TextSource): ()
		if source.UserId == player.UserId then
			Net.Event("Round"):FireServer("Reset")
		end
	end)
end

return AdminController
