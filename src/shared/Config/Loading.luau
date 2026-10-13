--!strict

-- The loading screen (ReplicatedFirst.LoadingGui, driven by ReplicatedFirst.LoadingScreen), built from the Figma
-- "Loading screen" mockup (blue version). It also serves as the waiting screen until the round starts.
-- Sizes are pixels on the 1560x720 design canvas, which scales to fit the screen. All motion is client cosmetic.

local BUN_ICON = "rbxassetid://90621736229104"
local MEAT_ICON = "rbxassetid://98317071199758"
local CHEESE_ICON = "rbxassetid://84478614105150"
local BURGER_ICON = "rbxassetid://84533964238750"

export type LoadingTips = { [string]: { string } }

local Loading = {
	DesignSize = Vector2.new(1560, 720),
	-- The four progress steps build a burger: kitchen streamed, assets loaded, every chef loaded, round starting.
	StepIcons = { BUN_ICON, MEAT_ICON, CHEESE_ICON, BURGER_ICON },
	StepStatus = {
		"stacking the kitchen...",
		"heating the stoves...",
		"waiting for the other chefs...",
		"starting the shift...",
	},
	-- Before START (the empty place) a gray Roblox-style boot screen shows the logo and START. After a press the logo
	-- spins for BootTime seconds (a head start to clear the screen while recording), then the loading screen comes in.
	BootTime = 2,
	BootSpinSpeed = 360, -- degrees per second
	-- Character picker on the boot screen (demo; the chefs are Config.Character.Selectable).
	PickTimeout = 3, -- seconds a pick stays outlined before the server's character takes over
	PickShadowDarken = 0.35, -- each button's shadow is its chef colour this much toward black
	-- PreloadController tier that counts as loaded (2 = own superskill, sounds, UI and shared assets).
	AssetsTier = 2,
	-- Each step runs the bar up to the next step icon (the last one to the end); the icons' places set the shares.
	MapTimeout = 20, -- seconds after START to wait for the map before counting it as streamed anyway
	-- The bar fakes smooth progress: it creeps on by itself toward the end of the current step (this fraction of
	-- the remaining gap per second), never past it, and moves at most FillSpeed of the bar per second.
	FillCreepRate = 0.6,
	FillSpeed = 0.2, -- also sets the shortest loading: the map and asset steps (about 2/3 of the bar) take 3+ s
	FillStepMargin = 0.03, -- how far short of the step's end the creep stops
	FillMaxFrame = 1 / 30, -- a long frame (hitch) moves the bar no more than this many seconds' worth
	FillFinishSpeed = 1.2, -- bar per second once the round has started: the rest of the bar runs up to 100%
	FinishHold = 0.35, -- seconds the full bar stays on screen before the screen slides away
	StartConfirmTimeout = 3, -- seconds START stays hidden after a press while the server hasn't left Waiting
	TodoIconColor = Color3.fromRGB(120, 105, 95), -- step icons not done yet
	TodoIconTransparency = 0.35,
	DoneRing = Color3.fromRGB(255, 210, 63),
	DoneInner = Color3.fromRGB(255, 248, 232),
	CurrentRing = Color3.fromRGB(255, 255, 255),
	TodoRing = Color3.fromRGB(90, 70, 58),
	TodoInner = Color3.fromRGB(80, 60, 48),
	StepPopTime = 0.35, -- seconds of the icon pop when a step finishes
	StepPopScale = 1.18,
	CheckDelay = 0.15, -- seconds after the icon pop before the check lands
	-- The ticket swings in on its clip: drops from above, then a damped swing settles it at its resting tilt.
	SwingDropTime = 0.45,
	SwingAngle = 14, -- degrees of the first swing
	SwingDamping = 3.2, -- per second
	SwingFrequency = 9, -- radians per second
	TicketTilt = 2, -- resting rotation in degrees (Roblox: positive is clockwise)
	-- The NEW TODAY sticker slaps on last (only when the level has a NewMechanic).
	StickerDelay = 0.9, -- seconds after the ticket starts swinging
	StickerTime = 0.25,
	StickerScale = 1.6, -- starting size of the slap
	-- Background food pattern scrolls slowly up-left, along its repeat (-260, -240) design pixels.
	PatternSpeed = 14, -- design pixels per second
	TipInterval = 6, -- seconds per chef tip
	OpenTime = 0.4, -- seconds to slide the screen in after START
	CloseTime = 0.8, -- seconds to slide it away once the bar is full (slower, so the intro doesn't feel rushed)
	MaxMenu = 3, -- dishes shown on the ticket
	MaxPartyRows = 4,
	PartyHeader = 46, -- party card height above the first row
	PartyRow = 38, -- height of each chef row
	PartyFooter = 14,
	ReadyText = "READY",
	LoadingText = "...",
	ReadyFace = Color3.fromRGB(104, 160, 44),
	ReadyShadow = Color3.fromRGB(70, 112, 24),
	ReadyLabel = Color3.fromRGB(255, 255, 255),
	LoadingFace = Color3.fromRGB(255, 210, 63),
	LoadingShadow = Color3.fromRGB(196, 140, 20),
	LoadingLabel = Color3.fromRGB(60, 40, 30),
	UnknownChef = Color3.fromRGB(200, 200, 200), -- chef dot before a player's character is known
	-- Tips: Base always, plus the list named after each Enable* switch the level turns on.
	Tips = {
		Base = {
			"Throw food across the kitchen. A teammate can catch it mid-air.",
			"Chop on the boards, then plate it before the order runs out.",
			"Dash to get across the kitchen fast.",
			"Your superskill charges over time. Use it when the rush hits!",
		},
		EnableDirtyPlates = {
			"Served plates come back dirty. Wash them at the sink.",
		},
		EnableTableCash = {
			"Customers leave coins on the table. Grab them before they're gone!",
			"Watch for dine-and-dashers: catch them before they run off.",
		},
		EnableCombo = {
			"Serve orders back to back to build a combo and earn more coins.",
		},
	} :: LoadingTips,
}

return Loading
