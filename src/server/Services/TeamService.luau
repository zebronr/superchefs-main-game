--!strict

local Players = game:GetService("Players")

local TeamService = {}

local function teamOf(player: Player): number
	local value = player:GetAttribute("Team")
	return if typeof(value) == "number" then value else 1
end

function TeamService.GetTeam(player: Player): number
	return teamOf(player)
end

function TeamService.GetPlayers(team: number): { Player }
	local members: { Player } = {}
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("Team") == team then
			table.insert(members, player)
		end
	end
	return members
end

function TeamService.GetSlot(player: Player): number
	local slot = 1
	for _, other in Players:GetPlayers() do
		if other == player then
			return slot
		end
		if other:GetAttribute("Team") == teamOf(player) then
			slot += 1
		end
	end
	return slot
end

function TeamService.AssignAll(count: number): ()
	local players = Players:GetPlayers()
	if count > 1 then
		for index = #players, 2, -1 do
			local chosen = math.random(index)
			players[index], players[chosen] = players[chosen], players[index]
		end
	end
	for index, player in players do
		player:SetAttribute("Team", if count == 1 then 1 else (index - 1) % count + 1)
	end
end

function TeamService.AssignJoin(player: Player, count: number): number
	local smallest = 1
	local size = math.huge
	for team = 1, count do
		local members = TeamService.GetPlayers(team)
		if #members < size then
			smallest = team
			size = #members
		end
	end
	player:SetAttribute("Team", smallest)
	return smallest
end

return TeamService
