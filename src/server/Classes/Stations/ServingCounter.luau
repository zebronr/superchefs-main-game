--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Item = require(script.Parent.Parent.Item)
local Plate = require(script.Parent.Parent.Plate)
local Station = require(script.Parent.Parent.Station)
local PlateTable = require(script.Parent.PlateTable)
local CarryService = require(script.Parent.Parent.Parent.Services.CarryService)
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Interaction"))
local Levels = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Levels"))
local Tags = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Tags"))

local ServingCounter = setmetatable({}, { __index = Station })
ServingCounter.__index = ServingCounter

export type ServingCounter = Station.Station

function ServingCounter.new(instance: Instance): ServingCounter
	local self = Station.new(instance)
	setmetatable(self :: any, ServingCounter)
	return self
end

function ServingCounter.Handle(_self: ServingCounter, player: Player, held: Item.Item?): boolean
	local plate = Plate.Cast(held)
	if plate ~= nil then
		local dish = plate.Content
		if dish == nil then
			return false
		end
		-- TODO(game loop): complete the order for <dish>.
		local dropped = CarryService.Drop(player, true)
		if dropped ~= plate then
			return false
		end
		plate.Instance:Destroy()
		task.delay(Config.PlateReturnDelay, function(): ()
			-- TODO(game loop): use the player's team instead of team 1.
			local tableForTeam = PlateTable.ForTeam(1)
			if tableForTeam == nil then
				warn("Could not return plate: PlateTable_1 is missing")
				return
			end
			PlateTable.AddPlate(tableForTeam, Levels.GetCurrent().EnableDirtyPlates)
		end)
		return true
	end

	if held ~= nil and Tags.ClassOf(held.Instance) == Tags.Food and string.sub(held.Instance.Name, 1, 8) == "chopped_" then
		-- TODO(layer 9): "NEEDS PLATE!" notification.
		return false
	end
	return false
end

return ServingCounter
