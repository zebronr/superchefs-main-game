--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

local EffectService = {}

function EffectService.PlaySound(name: string): ()
	Net.Event("Effect"):FireAllClients("Sound", name)
end

function EffectService.Notify(player: Player, instance: Instance, message: string): ()
	Net.Event("Effect"):FireClient(player, "Notify", instance, message)
end

return EffectService
