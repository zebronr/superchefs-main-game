--!strict

local Tags = {}

Tags.Countertop = "Countertop"
Tags.ChoppingBoard = "ChoppingBoard"
Tags.FoodContainer = "FoodContainer"
Tags.PlateTable = "PlateTable"
Tags.ServingCounter = "ServingCounter"
Tags.CustomerTable = "CustomerTable"
Tags.Trash = "Trash"
Tags.Food = "Food"
Tags.Plate = "Plate"
Tags.DirtyPlate = "DirtyPlate"
Tags.Stove = "Stove"
Tags.Sink = "Sink"
Tags.CookingTool = "CookingTool"
Tags.FireExtinguisher = "FireExtinguisher"

Tags.ClassAttribute = "objectClass"
Tags.ClassTagPrefix = "Class_"

Tags.ProximityNode = "ProximityNode"
Tags.Locked = "LOCKED"
Tags.FireLocked = "FIRELOCKED"
Tags.ThrowInteractable = "throwInteractable"
Tags.ProjectileIgnore = "projectileInteractionIgnore"
Tags.Ignore = "IGNORE"
Tags.Projectile = "Projectile"
Tags.Grabbed = "Grabbed"

Tags.Classes = {
	Tags.Countertop,
	Tags.ChoppingBoard,
	Tags.FoodContainer,
	Tags.PlateTable,
	Tags.ServingCounter,
	Tags.CustomerTable,
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

local classSet: { [string]: boolean } = {}
for _, className in Tags.Classes do
	classSet[className] = true
end

-- The generated CollectionService tag for a class name; BinderService adds it at server start.
function Tags.ClassTag(className: string): string
	return Tags.ClassTagPrefix .. className
end

-- Reads the objectClass attribute; only known class names count.
function Tags.ClassOf(instance: Instance): string?
	local value = instance:GetAttribute(Tags.ClassAttribute)
	if typeof(value) == "string" and classSet[value] then
		return value
	end
	return nil
end

function Tags.IsClass(instance: Instance, className: string): boolean
	return Tags.ClassOf(instance) == className
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
