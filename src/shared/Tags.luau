--!strict

local CollectionService = game:GetService("CollectionService")

local Tags = {}

Tags.Countertop = "Countertop"
Tags.ChoppingBoard = "ChoppingBoard"
Tags.FoodContainer = "FoodContainer"
Tags.PlateTable = "PlateTable"
Tags.ServingCounter = "ServingCounter"
Tags.Trash = "Trash"
Tags.Food = "Food"
Tags.Plate = "Plate"
Tags.DirtyPlate = "DirtyPlate"
Tags.Stove = "Stove"
Tags.Sink = "Sink"
Tags.CookingTool = "CookingTool"
Tags.FireExtinguisher = "FireExtinguisher"

Tags.ProximityNode = "ProximityNode"
Tags.Locked = "LOCKED"
Tags.FireLocked = "FIRELOCKED"
Tags.ThrowInteractable = "throwInteractable"
Tags.ProjectileIgnore = "projectileInteractionIgnore"
Tags.Ignore = "IGNORE"
Tags.Projectile = "Projectile"

Tags.Classes = {
	Tags.Countertop,
	Tags.ChoppingBoard,
	Tags.FoodContainer,
	Tags.PlateTable,
	Tags.ServingCounter,
	Tags.Trash,
	Tags.Food,
	Tags.Plate,
	Tags.DirtyPlate,
	Tags.Stove,
	Tags.Sink,
	Tags.CookingTool,
	Tags.FireExtinguisher,
} :: { string }

local DISABLED_ATTRIBUTE = "interactionDisabled"

function Tags.ClassOf(instance: Instance): string?
	for _, tag in Tags.Classes do
		if CollectionService:HasTag(instance, tag) then
			return tag
		end
	end
	return nil
end

function Tags.IsInteractionDisabled(instance: Instance): boolean
	return instance:GetAttribute(DISABLED_ATTRIBUTE) == true
end

function Tags.SetInteractionDisabled(instance: Instance, disabled: boolean): ()
	instance:SetAttribute(DISABLED_ATTRIBUTE, disabled)
end

-- Reads a Vector3 attribute (degrees for the offset attributes); missing or wrong type gives zero.
function Tags.GetVector3(instance: Instance, attribute: string): Vector3
	local value = instance:GetAttribute(attribute)
	if typeof(value) == "Vector3" then
		return value
	end
	return Vector3.zero
end

return Tags
