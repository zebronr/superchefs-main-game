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
}

return Customers
