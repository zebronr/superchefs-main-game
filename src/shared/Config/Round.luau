--!strict

export type ServeMode = "Window" | "Manual"

local Round = {
	-- "Manual": customers sit at tables and you serve them. Change to "Window" for the legacy serving window.
	ServeMode = "Manual" :: ServeMode,
	-- true: a waiting server shows a START button and the round begins when someone presses it.
	-- false: the round begins as soon as the first client has loaded.
	StartButton = true,
	RoundEndDuration = 10,
	ReadySetGoDuration = 3,
	NPCSpawnInterval = 2,
	-- Seconds between the start and the first Ready-Set-Go frame, so the message reaches clients in time.
	IntroLead = 0.3,
}

return Round
