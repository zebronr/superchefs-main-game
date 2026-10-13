--!strict

export type ServeMode = "Window" | "Manual"

-- Opening shot after START (client-rendered, PlayerGui.IntroIris): the screen holds black, the Superchefs
-- icon opens as a peephole and zooms past the screen, then the camera eases from a wide shot of the whole
-- map down to the gameplay camera. Ready-Set-Go follows. Rounds after the first skip it.
local Cinematic = {
	Enabled = true,
	BlackHold = 2.6, -- seconds of plain black (the loading screen slides away during the first ~1.5)
	PeekTime = 0.5, -- seconds for the icon hole to pop open
	PeekScale = 0.45, -- overlay image height in screen heights once open (the hole is 70% of the image)
	PeekOvershoot = 1.1, -- back-ease strength of that pop
	PeekHold = 0.8, -- seconds the small hole holds before zooming
	IrisTime = 0.9, -- seconds for the hole to zoom past the screen edges
	IrisScale = 12, -- overlay image height in screen heights at the end of the zoom, enough to clear every corner
	WideHold = 0.7, -- seconds on the wide shot after the hole is gone
	ZoomTime = 2.2, -- seconds to ease from the wide shot to the gameplay camera
	WideMargin = 0.95, -- extra room around the map in the wide shot (1 = map fills the view)
	-- Moves the wide shot's aim toward the camera (fraction of the map radius, flat), so the map sits higher on screen:
	-- more of the near road at the bottom, less of the far buildings at the top.
	WideShift = 0.25,
}

local Round = {
	-- "Manual": customers sit at tables and you serve them. Change to "Window" for the legacy serving window.
	ServeMode = "Manual" :: ServeMode,
	-- true: a waiting server (no map yet) shows START on the loading screen; pressing it loads the map, and the
	-- round begins once every chef has loaded it. false: the map loads as soon as the first client is ready.
	StartButton = true,
	-- Only these players see START and can start the round (demo: the developer). In Studio anyone can.
	StartHosts = { 5845362590 } :: { number },
	StudioAnyoneStarts = true,
	-- TextChatCommand authored in Studio (/resetgame): the hosts above put the server back to the boot screen.
	ResetCommand = "ResetGameCommand",
	-- Seconds the server waits for every chef to load the map before starting without the stragglers.
	LoadTimeout = 30,
	-- Round states in which chefs can't walk or dash (before the round starts, through the intro).
	FrozenStates = { Waiting = true, Loading = true, Intro = true } :: { [string]: boolean },
	RoundEndDuration = 10,
	ReadySetGoDuration = 3,
	NPCSpawnInterval = 2,
	-- Seconds between the start and the first Ready-Set-Go frame, so the message reaches clients in time.
	IntroLead = 0.3,
	Cinematic = Cinematic,
	-- Total seconds of the opening shot; the server waits this long before Ready-Set-Go.
	CinematicLength = Cinematic.BlackHold
		+ Cinematic.PeekTime
		+ Cinematic.PeekHold
		+ Cinematic.IrisTime
		+ Cinematic.WideHold
		+ Cinematic.ZoomTime,
}

return Round
