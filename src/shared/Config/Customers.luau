--!strict

local Customers = {
	-- Looping walk animation, played on customers and on window NPCs.
	WalkAnimation = "rbxassetid://74792532038099",
	-- Team number customers are scored under.
	Team = 1,
	-- Seconds between customer state checks (waiting for food, waiting to finish eating).
	Poll = 0.1,
	-- Seconds a Humanoid:MoveTo may take per path waypoint before giving up.
	WaypointTimeout = 5,
	-- Studs from the target (ignoring height) that count as having arrived.
	ArriveDistance = 5,
	-- Runner movement and walk-track speed.
	DashSpeed = 19,
	DashAnimSpeed = 1.5,
	-- Seconds a caught runner pauses before leaving.
	CaughtPause = 1.2,
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
