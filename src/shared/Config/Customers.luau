--!strict

local Customers = {
	-- Looping walk animation, played on customers and on window NPCs.
	WalkAnimation = "rbxassetid://74792532038099",
	-- Looping R6 sit pose (Roblox's default R6 sit), played while a customer is seated.
	SitAnimation = "rbxassetid://178130996",
	-- Studs from the top of a table's Seat part to a seated customer's HumanoidRootPart (R6).
	SitHeight = 1.5,
	-- Collision groups (docs/COLLISION-GROUPS.md): customers walk in their template's group and switch to the seated
	-- one at the table, so players (a dashing Bear) pass through instead of shoving into an anchored body.
	CollisionGroup = "NPCs",
	SeatedCollisionGroup = "SeatedNPCs",
	-- Team number customers are scored under.
	Team = 1,
	-- Seconds between customer state checks (waiting for food, waiting to finish eating).
	Poll = 0.1,
	-- Seconds a Humanoid:MoveTo may take per path waypoint before giving up.
	WaypointTimeout = 5,
	-- Studs (ignoring height) from a path waypoint at which a customer turns to the next one without slowing down.
	-- The last waypoint is walked all the way to.
	WaypointReach = 2,
	-- A customer that moves less than StuckDistance studs in StuckTime seconds gives up on its current waypoint
	-- (instead of pushing into a wall until WaypointTimeout).
	StuckTime = 1,
	StuckDistance = 0.5,
	-- Studs from the target (ignoring height) that count as having arrived.
	ArriveDistance = 5,
	-- Runner movement and walk-track speed.
	DashSpeed = 22,
	DashAnimSpeed = 1.5,
	-- Seconds a caught runner lies ragdolled before vanishing (the server then removes them).
	CaughtPause = 2.4,
	-- The caught runner's ragdoll, a client-only copy flung away from the catcher (studs/s, radians/s), fading out
	-- over the last FadeTime seconds of CaughtPause.
	Ragdoll = {
		Fling = 26,
		Lift = 24,
		Spin = 10,
		FadeTime = 0.4,
	},
	-- Where the bottom of the cash pile sits, in the table's space from the centre of its top face:
	-- the corner away from the seat (+X), turned to fit beside the round plate.
	CashOffset = CFrame.new(-1.35, 0, 1.35) * CFrame.Angles(0, math.rad(45), 0),
	CashFlyTime = 0.55,
	CashFlyHeight = 2.5,
	CashPopTime = 0.45,
	CashPopOvershoot = 0.35,
	CashPopWaves = 2.5,
	PredictTimeout = 1,
	-- Small cash pieces in the catch burst.
	CatchBurstCount = 5,
	CatchBurstSpeed = 7,
	CatchBurstScale = 0.45,
}

return Customers
