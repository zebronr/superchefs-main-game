--!strict

local Interaction = {}

-- Targeting (client)
Interaction.TargetRadius = 8
Interaction.DefaultMinDistance = 6
Interaction.MinDistance = {} :: { [string]: number }
Interaction.TargetPriority = {
	Food = 1.15,
	ServingCounter = 1.3,
} :: { [string]: number }
Interaction.DefaultPriority = 1
Interaction.PriorityWeight = 100

-- Request validation (server)
Interaction.ServerDistanceMargin = 10
Interaction.MaxRequests = 10
Interaction.RequestWindow = 0.5

-- Carrying
Interaction.CarryDistance = 2
Interaction.DropReenableDelay = 0.5
Interaction.NetworkOwnerResetDelay = 0.5
Interaction.PlateReturnDelay = 1.5

-- Chopping
Interaction.ProgressPerChop = 20
Interaction.ChopDelay = 0.3
Interaction.UseTimeoutMargin = 0.2
Interaction.ChopAnimationId = "rbxassetid://74695809221721"
Interaction.ChopProgressAttribute = "ChopProgress"
Interaction.ActionAnimationAttribute = "ActionAnimation"

-- Washing
Interaction.WashRate = 75
Interaction.MaxDisplayedDirtyPlates = 3
Interaction.WashProgressAttribute = "WashProgress"
Interaction.WashAnimationId = "rbxassetid://77309393012974"

-- Cooking and fire
Interaction.Cooking = {
	CookRate = 20,
	CookSafeTime = 5,
	CookAlertDuration = 5,
	CookProgressDeduction = 50,
	-- Cooking tool classes the stove heats (legacy cookingToolClassesAllowed); each tool's station keeps its own list.
	StoveToolClasses = { "Pot", "Pan" },
	FireSpreadInterval = 8,
	FireSpreadDistance = 5,
	FireStart = 100,
	ExtinguisherRange = 13.5,
	ExtinguisherDeduction = 10,
	ExtinguisherTick = 1,
	CookContentAttribute = "CookContent",
	CookProgressAttribute = "CookProgress",
	CookStartedAtAttribute = "CookStartedAt",
	CookedAtAttribute = "CookedAt",
	FireAttribute = "Fire",
	SprayingAttribute = "Spraying",
}

Interaction.Throw = {
	Distance = 30,
	Height = 7,
	Speed = 45,
	Gravity = 20,
	FloorRayLength = 100,
	CollisionRayLength = 100,
	CollisionRadius = 3,
	CollisionAngles = { -45, 0, 45 },
	MarginOfError = 10,
	TrailLinger = 0.5,
	ThrowStartAttribute = "ThrowStart",
	ThrowEndAttribute = "ThrowEnd",
	ThrowStartedAtAttribute = "ThrowStartedAt",
	FallFromAttribute = "FallFrom",
	FallToAttribute = "FallTo",
	FallStartedAtAttribute = "FallStartedAt",
}

-- Same-class pairs listed here do not swap on a counter.
Interaction.AllowInteractionWithSelf = {
	Plate = true,
	DirtyPlate = true,
} :: { [string]: boolean }

Interaction.Controls = {
	Interact = Enum.KeyCode.Space,
	Use = Enum.KeyCode.LeftControl,
	Throw = Enum.KeyCode.LeftAlt,
	Dash = Enum.KeyCode.LeftShift,
}

return Interaction
