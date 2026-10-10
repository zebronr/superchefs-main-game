--!strict

local Interaction = {}

-- Targeting (client)
Interaction.TargetRadius = 8
Interaction.DefaultMinDistance = 6
Interaction.MinDistance = {} :: { [string]: number }
Interaction.MinDistance.Runner = 7
Interaction.TargetPriority = {
	Food = 1.15,
	ServingCounter = 1.3,
	Runner = 2,
} :: { [string]: number }
Interaction.DefaultPriority = 1
Interaction.PriorityWeight = 100

-- Request validation (server)
Interaction.ServerDistanceMargin = 10
Interaction.MaxRequests = 10
Interaction.RequestWindow = 0.5
-- Flat distance from the use start before an automatic station use stops.
Interaction.AutoUse = {
	MoveTolerance = 2,
}

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
	-- Studs/s^2: the fall after an impact accelerates.
	FallGravity = 120,
	FloorRayLength = 100,
	-- Sphere radius of the swept collision cast.
	CastRadius = 0.5,
	-- Studs: how close a player's root must be to the flight path to catch.
	CatchRadius = 3.5,
	-- The catcher's flat look must dot the flat direction toward the thrower at least this much.
	CatchFacingDot = 0.3,
	-- Seconds: cap on back-dating the server start by half the thrower's ping.
	MaxLagCompensation = 0.2,
	-- Seconds the thrower's client waits for the server to confirm before rolling back.
	PredictionTimeout = 1,
	-- Seconds to blend the predicted position into the server timeline.
	ReconcileTime = 0.12,
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
	-- Temporarily E: LeftAlt unfocuses the Studio window. Restore LeftAlt for release.
	Throw = Enum.KeyCode.E,
	Dash = Enum.KeyCode.LeftShift,
	Skill = Enum.KeyCode.Q,
}

return Interaction
