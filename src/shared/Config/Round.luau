--!strict

export type ServeMode = "Window" | "Manual"

local Round = {
	-- "Manual": customers sit at tables and you serve them. Change to "Window" for the legacy serving window.
	ServeMode = "Manual" :: ServeMode,
	RoundEndDuration = 10,
	ReadySetGoDuration = 3,
	NPCSpawnInterval = 2,
	IntroLead = 0.1,
}

return Round
