--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CarryService = require(script.Parent.CarryService)
local CharacterService = require(script.Parent.CharacterService)
local InteractionService = require(script.Parent.InteractionService)
local RoundService = require(script.Parent.RoundService)
local TeamService = require(script.Parent.TeamService)
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))

local CinematicService = {}

local function onRequest(player: Player, action: unknown, value: unknown): ()
	local tuning = Config.CinematicCamera
	if typeof(value) ~= "boolean" or table.find(tuning.UserIds, player.UserId) == nil then
		return
	end
	if action == "PauseTimer" then
		if player:GetAttribute(tuning.Attribute) == true then
			RoundService.SetTimerPaused(value)
		end
		return
	elseif action ~= "Toggle" then
		return
	end
	local on = value
	if (player:GetAttribute(tuning.Attribute) == true) == on then
		return
	end
	if on then
		player:SetAttribute(tuning.Attribute, true)
		InteractionService.StopUse(player)
		local held = CarryService.Release(player)
		if held ~= nil then
			held.Instance:Destroy()
		end
		player:SetAttribute("Team", nil)
		local character = player.Character
		if character ~= nil then
			character:Destroy()
		end
		CharacterService.RefreshColors()
	else
		player:SetAttribute(tuning.Attribute, nil)
		TeamService.AssignJoin(player, Config.Levels.GetCurrent().Teams)
		player:LoadCharacterAsync()
		CharacterService.RefreshColors()
	end
	RoundService.PlayerActivityChanged(player)
end

function CinematicService.Start(_self: typeof(CinematicService)): ()
	Net.Event("CinematicCamera").OnServerEvent:Connect(onRequest)
end

return CinematicService
