--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Item = require(script.Parent.Parent.Item)
local Plate = require(script.Parent.Parent.Plate)
local Station = require(script.Parent.Parent.Station)
local PlateTable = require(script.Parent.PlateTable)
local CarryService = require(script.Parent.Parent.Parent.Services.CarryService)
local EffectService = require(script.Parent.Parent.Parent.Services.EffectService)
local OrderService = require(script.Parent.Parent.Parent.Services.OrderService)
local TeamService = require(script.Parent.Parent.Parent.Services.TeamService)
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local InteractionConfig = Config.Interaction
local Levels = Config.Levels
local Tags = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Tags"))

local ServingCounter = setmetatable({}, { __index = Station })
ServingCounter.__index = ServingCounter

export type ServingCounter = Station.Station

function ServingCounter.new(instance: Instance): ServingCounter
	local self = Station.new(instance)
	setmetatable(self :: any, ServingCounter)
	return self
end

function ServingCounter.Handle(self: ServingCounter, player: Player, held: Item.Item?): boolean
	local plate = Plate.Cast(held)
	if plate ~= nil then
		local dish = plate.Content
		if dish == nil then
			return false
		end
		local dropped = CarryService.Drop(player, true)
		if dropped ~= plate then
			return false
		end
		OrderService.Serve(player, dish, self.Instance)
		local team = TeamService.GetTeam(player)
		plate.Instance:Destroy()
		task.delay(InteractionConfig.PlateReturnDelay, function(): ()
			if not self.Instance:IsDescendantOf(workspace) then
				return
			end
			local tableForTeam = PlateTable.ForTeam(team)
			if tableForTeam == nil then
				warn(`Could not return plate: PlateTable_{team} is missing`)
				return
			end
			PlateTable.AddPlate(tableForTeam, Levels.GetCurrent().EnableDirtyPlates)
		end)
		return true
	end

	if held ~= nil and Tags.ClassOf(held.Instance) == Tags.Food and string.sub(held.Instance.Name, 1, 8) == "chopped_" then
		EffectService.Notify(player, self.Instance, "NEEDS PLATE!")
		return false
	end
	return false
end

return ServingCounter
