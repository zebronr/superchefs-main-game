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

-- Station items rest on their surface through a WeldConstraint of this name (Slot.WeldOnTop); clients read it to see
-- what lies on a station.
Interaction.SlotWeldName = "objectTopWelder"

-- Action tools: the tool each action animation puts in the hand (ReplicatedStorage.Assets.Tools.<name>, a BasePart
-- with a `Grip` Attachment where the hand holds it). Every client shows them for every character from the
-- character's ActionAnimation attribute; the local player's own shows at once when it predicts the action.
Interaction.ActionTools = {
	Chop = "Cleaver",
} :: { [string]: string }
Interaction.ToolHand = "Right Arm"
Interaction.ToolHandAttachment = "RightGripAttachment"
Interaction.ToolPopTime = 0.14 -- seconds the tool grows into the hand, with an overshoot
Interaction.ToolPopOvershoot = 1.6
Interaction.ToolHideTime = 0.08 -- seconds it shrinks away when put down
-- A predicted action (or stop) the server hasn't matched within this many seconds rolls back to the server's.
Interaction.ActionPredictTimeout = 0.8
-- Catching a dine-and-dasher: Interact on a runner swings a bat, and the catch only lands when the bonk does (after
-- WindTime + SlamTime) if the runner is still within HitRange. The server stamps the swing on the character as
-- Attribute (server time, lag-compensated); every client renders the bat from it and the swinger predicts it at once.
-- The swinger's arm plays Animation (looped) for the swing. Angles turn the tool about the hand's X axis: 0 points it
-- straight ahead of the hanging arm, 90 straight up.
Interaction.CatchSwing = {
	Tool = "Bat",
	Attribute = "CatchSwingAt",
	Animation = "Chop", -- temporary, until a swing animation exists
	HitRange = 9, -- studs from the swinger's root to the runner's root when the bonk lands
	MaxLagCompensation = 0.2,
	WindTime = 0.12, -- seconds to raise the bat while it pops in
	WindAngle = 115,
	SlamTime = 0.07, -- seconds of the bonk down
	HitAngle = -35,
	HoldTime = 0.3, -- seconds it rests after the hit before shrinking away
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
-- Set on a food made by combining off a plate (Recipes.NoPlate), so the client doesn't try to chop it.
Interaction.CombinedAttribute = "Combined"
Interaction.ActionAnimationAttribute = "ActionAnimation"

-- Washing
Interaction.WashRate = 75
-- Studs the drain board counts as closer than it is when you Interact at a sink without dirty plates in hand, so
-- grabbing clean plates works from most of the sink instead of only right at the drain board.
Interaction.DrainBoardReach = 4
-- The same the other way: studs the washing end counts as closer when you Interact holding dirty plates, so dropping
-- them in the water works from most of the sink.
Interaction.WashReach = 4
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
