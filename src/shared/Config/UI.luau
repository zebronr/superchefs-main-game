--!strict

local UI = {
	-- Studio only: PlayerGui.EffectTester, buttons that play the order, combo and coin effects locally without a
	-- round (EffectTesterController). Hidden until one of UserIds types the TextChatService.<Command> chat command
	-- (/testerui), which toggles it. Never in a live game; for everyone else the command is switched off.
	EffectTester = {
		Command = "TesterUICommand",
		UserIds = { 5845362590 } :: { number }, -- zebronr
	},
	-- The superskill card (GameInfo.InfoFrame.Superskill on desktop, inside MobileControls.Skill on touch). Every
	-- superskill shares the card; only its icon and ring colour change (Looks, keyed by the Config.Skills name).
	Superskill = {
		Looks = {
			TongueGrab = { Icon = "rbxassetid://88619397820667", Color = Color3.fromRGB(108, 200, 90) },
			Hustle = { Icon = "rbxassetid://121375788001740", Color = Color3.fromRGB(255, 165, 35) },
			DeepFreeze = { Icon = "rbxassetid://127874444600499", Color = Color3.fromRGB(70, 175, 240) },
			OrderRush = { Icon = "rbxassetid://70929787240773", Color = Color3.fromRGB(165, 105, 240) },
			-- No icons yet: these cards show the ring in the colour only.
			BearToss = { Icon = "", Color = Color3.fromRGB(190, 120, 60) },
			Phase = { Icon = "", Color = Color3.fromRGB(170, 215, 255) },
		} :: { [string]: { Icon: string, Color: Color3 } },
		OffColor = Color3.fromRGB(176, 186, 196), -- icon and ring while it can't be used
		CooldownIconTransparency = 0.75, -- the icon fades under the seconds left
		PressedScale = 0.9, -- squash while aiming or waiting for the server
		PopScale = 1.15, -- peak size when it comes off cooldown
		PopTime = 0.25, -- seconds of that pop
	},
	-- The touch button arc (MobileControls.Arc, bottom-right). Its buttons are laid out in scale inside it, so code
	-- sizes it with a fixed shape: Height of the screen height, but never wider than MaxWidth of the screen width
	-- (a tablet's squarer screen would otherwise blow it up over the HUD).
	MobileArc = {
		Aspect = 1.224, -- width / height the buttons inside were laid out for
		Height = 0.528,
		MaxWidth = 0.36,
	},
	-- The mobile interact button's label (MobileControls Interact.Face.Label), picked from what's held and targeted
	-- (InputController). Only a hint; the server still decides what the press does.
	InteractLabels = {
		Grab = "GRAB", -- empty hands (and nothing better fits)
		Drop = "DROP", -- holding something, nothing targeted
		Place = "PLACE", -- onto an empty counter, board or stove
		Add = "ADD", -- combining with what's there (food onto a plate or into a pot, plates together)
		Swap = "SWAP", -- trading what's held for what's there
		Serve = "SERVE", -- plate to the serving window or a waiting customer
		Order = "ORDER", -- taking a seated customer's order
		Collect = "COLLECT", -- table cash
		Trash = "TRASH", -- food into the bin
		Empty = "EMPTY", -- a plate or pot emptied into the bin
		Wash = "WASH", -- dirty plates into the sink
		Catch = "CATCH", -- a dine-and-dasher
	},
	-- The "you" ring under the local player sits this many studs above the floor (avoids z-fighting).
	IndicatorFloorLift = 0.05,
	-- How far down the ring looks for the floor; past this (falling off the map) it hides.
	IndicatorFloorRayLength = 50,
	-- Customer bubble motion (all cosmetic, client only).
	Bubble = {
		PopTime = 0.35, -- seconds for the bubble to pop in when it appears
		PopOvershoot = 0.22, -- elastic overshoot as a fraction of full size
		PopSquash = 0.18, -- squash and stretch while popping in (X and Y move opposite)
		OutTime = 0.14, -- seconds to shrink away when it hides
		StateBounceTime = 0.3, -- seconds of squishy bounce when the bubble's state changes
		StateBounce = 0.14, -- size of that bounce as a fraction of full size
		BobHeight = 0.08, -- studs of gentle idle float
		BobPeriod = 2.2, -- seconds per idle float cycle
		DashBobHeight = 0.12, -- studs of bob while the customer dashes
		DashBobPeriod = 0.35, -- seconds per dash bob cycle
		LowPatience = 0.25, -- patience fraction left below which the bubble urges the player
		UrgePeriod = 0.5, -- seconds per urge pulse
		UrgeScale = 0.06, -- extra size at the peak of an urge pulse
		UrgeShake = 0.04, -- studs of sideways shake while urging
	},
	-- Taking a seated customer's order (OrderTakeController): the customer squashes and springs, a ring of round
	-- puffs bursts out at seat height and the bubble pops back in out of it; then a paper ticket flies from the
	-- table to the new order card (OrdersController), which pops in when it lands. All cosmetic, client only.
	TakeOrder = {
		PredictRadius = 8, -- studs from the table to the waiting customer's root, to find who the local press hits
		ConfirmWindow = 1.5, -- seconds a local prediction absorbs the server's state change (so it plays once)
		SquashTime = 0.55, -- seconds of the whole squash and spring
		SquashSnap = 0.22, -- fraction of SquashTime spent snapping down; the rest springs and wobbles out
		SquashWobble = 2.2, -- how fast the wobble dies (higher settles sooner)
		Squash = 0.22, -- fraction the body shortens at the deepest squash
		Stretch = 0.14, -- fraction the body lengthens at the top of the spring
		Dip = 0.5, -- studs the body sinks at the deepest squash (the root joint)
		PuffCount = 10, -- puffs in the ring
		PuffHeight = -0.9, -- studs from the customer's root to the ring
		PuffTilt = 12, -- degrees the puffs aim above flat
		PuffDelay = 0.06, -- seconds after the press the ring bursts (as the squash bottoms out)
		BubbleDelay = 0.1, -- seconds the bubble stays gone before it pops back in
		SoundPitch = { 0.94, 1.08 }, -- random PlaybackSpeed range for SoundEffects.OrderIn
		-- Ticket (OrderList.Ticket, design pixels scaled with the order row).
		TicketHeight = 2.5, -- studs above the table top where the ticket starts
		TicketDelay = 0.12, -- seconds after AddOrder before the ticket leaves the table
		TicketPopTime = 0.12, -- seconds for the ticket to grow in at the table
		TicketPopOvershoot = 1.7,
		TicketFlyTime = 0.55, -- seconds from the table to the card
		TicketArc = 110, -- pixels the path bows upward
		TicketSpin = 20, -- degrees the ticket rocks each way in flight
		TicketLandScale = 0.6, -- ticket size at the card, as a fraction of its full size
		TrailInterval = 0.03, -- seconds between trail puffs (OrderList.TicketPuff)
		TrailLife = 0.3, -- seconds a trail puff lasts
		TrailGrow = 1.8, -- trail puff size at the end of its life, as a multiple of its start
		LandPuffs = 7, -- puffs that burst out where the ticket lands
		LandSpread = 34, -- pixels they fly out
		LandLife = 0.3, -- seconds they last
		CardPopTime = 0.22, -- seconds the card takes to pop in when the ticket lands
		CardPopOvershoot = 1.8, -- back-ease strength of that pop
	},
	-- Ready-Set-Go words: each pops in, holds, then shrinks away inside its one second.
	ReadySetGo = {
		PopTime = 0.3, -- seconds for a word to pop in
		PopOvershoot = 2.2, -- back-ease strength of the pop (bigger overshoots further)
		OutTime = 0.15, -- seconds for a word to shrink away before the next one
		Tilt = 6, -- degrees READY and SET lean (opposite ways); GO stays straight
		GoScale = 1.25, -- GO is drawn this much bigger than READY and SET
	},
	-- Patience and order-timer bar colors, blended green -> yellow -> red as time runs out.
	Patience = {
		Green = Color3.fromRGB(63, 111, 34),
		Yellow = Color3.fromRGB(184, 180, 46),
		Red = Color3.fromRGB(163, 37, 46),
		-- Bar color while the Penguin's Deep Freeze pauses it.
		Frozen = Color3.fromRGB(140, 220, 255),
		FrostPopTime = 0.27, -- seconds for bubble frost and snowflake to pop in
		FrostCrackTime = 0.22, -- seconds for the bubble frost to shake and fade on thaw
		FrostPopOvershoot = 0.16, -- elastic overshoot as a fraction of the settled size
		FrostCrackScale = 0.12, -- extra frost scale while cracking off
		FrostCrackShake = 3, -- pixels of horizontal frost shake on thaw
		SnowflakeSpin = 24, -- degrees per second while frozen
	},
	-- Order row (OrderList, top-right): a plate per order, ringed by its timer, with a tray per recipe step.
	-- Sizes are pixels at DesignHeight; the row scales with the screen height. All motion is client cosmetic.
	Orders = {
		DesignHeight = 720, -- screen height the sizes below are drawn for
		DesignWidth = 1280, -- on a squarer screen (a tablet) the row scales with the width instead, if that's smaller
		DesktopScale = 0.8, -- extra scale on PC
		TouchScale = 1.1, -- extra scale on touch screens (small, short screens)
		PlateSize = 92,
		StepsGap = 8, -- plate bottom to trays
		TrayHeight = 55, -- tray plus its drop shadow
		TrayGap = 8,
		TrayPadding = 5, -- each side of a tray's ingredient slots
		SlotSize = 40,
		SlotGap = 4,
		OldestScale = 1.2, -- the oldest order is drawn bigger (serve it next)
		ScaleSpeed = 10, -- how fast an order eases to its size when it becomes the oldest
		MethodIcons = { Pot = "rbxassetid://73667245425860", Pan = "rbxassetid://95343918073432" } :: { [string]: string },
		MethodColors = { Pot = Color3.fromRGB(192, 57, 43), Pan = Color3.fromRGB(217, 119, 43) } :: { [string]: Color3 },
		-- Timer ring, blended green -> yellow -> red as time runs out.
		RingGreen = Color3.fromRGB(111, 184, 58),
		RingYellow = Color3.fromRGB(217, 182, 46),
		RingRed = Color3.fromRGB(163, 37, 46),
		-- With the level's fresh-serve combo rule the ring shows flat bands instead, blended over this much of the time.
		RingBlend = 0.03,
		-- Arrival: falls in from above, squashes on landing, springs tall, wobbles to rest.
		DropHeight = 160,
		DropTime = 0.18,
		SquashTime = 0.08,
		Squash = Vector2.new(1.28, 0.72),
		StretchTime = 0.1,
		Stretch = Vector2.new(0.88, 1.14),
		SettleTime = 0.3,
		TrailFadeTime = 0.15, -- the speed lines above a falling plate fade out after it lands
		RingSweepTime = 0.5, -- the ring sweeps in clockwise over this long
		TrayDelay = 0.3, -- trays pop in after the plate lands, one after another
		TrayStagger = 0.08,
		TrayPopTime = 0.25,
		TrayPopOvershoot = 1.8, -- back-ease strength of each tray's pop
		TableLabel = "T%d", -- the table tag on a customer's plate
		-- Urgent: under this fraction of time left the plate rocks and throbs, a red glow pulses and sweat drops fly
		-- off, faster as time runs out. Only the dish and table tag rotate (rotating the plate would break the ring
		-- halves' clipping, and the ring looks the same either way).
		Urgent = 0.25,
		UrgeTilt = 12, -- degrees each way
		UrgePulse = 0.06, -- extra plate size at the peak of each throb
		UrgeSpeedMin = 9, -- radians per second at the start of urgency
		UrgeSpeedMax = 22, -- and when time is nearly out
		SweatTime = 0.6, -- seconds per sweat drop flight
		SweatDistance = 26, -- pixels a drop flies out and down
		-- Served: a check stamps on with sparkles, the plate shrinks into a coin, the coin arcs to the coin card
		-- (when paid on serve), and the row closes up.
		StampTime = 0.2,
		StampScale = 1.3,
		SparkleTime = 0.35,
		SparkleSpread = 0.25, -- how far the sparkles fly out, as a fraction of the plate
		ShrinkDelay = 0.2,
		ShrinkTime = 0.25,
		-- Paid on serve: at ShrinkDelay the plate becomes a spinning coin that hops (Coins.Fly*); at CoinDelay it
		-- flies to the coin card.
		CoinDelay = 0.45,
		-- Expired: shakes with a red tint, then shrinks away.
		ShakeTime = 0.5,
		ShakeOffset = 6, -- pixels
		ShakeSpeed = 60, -- radians per second
		Fail = Color3.fromRGB(255, 124, 124),
		-- More orders than fit: the newest ones leave the row and wait in the queue strip (OrderList.list.Queue) at
		-- its left end, one dish icon per recipe with how many are waiting, so players can prep ahead. The row stops
		-- at the screen edge, or where Roblox's top-bar buttons end when it reaches up beside them.
		EdgeMargin = 8, -- pixels kept clear at that left limit
		QueueEntrySize = 56, -- each dish icon in the strip
		QueueGap = 6,
		QueueCountLabel = "x%d", -- the count badge, shown from 2 up
		QueuePopTime = 0.25, -- seconds of a dish's pop when it joins the strip or its count changes
		QueuePop = 0.25, -- extra size at the peak of that pop
	},
	-- Combo fire on the coin card (GameInfo.InfoFrame.ComboFire and CoinsFrame.ComboBadge).
	Combo = {
		SparksAt = 2, -- combo count that shows the badge and sparks
		FireAt = 3, -- orange fire
		BlueAt = 5, -- blue fire
		-- Badge face and text per tier (4 = fever); each pair keeps text contrast at 4.5:1 or better (sparks 9.0,
		-- fire 5.0, blue fire 5.8, fever 4.9). The countdown ring (ComboBadge.Timer) takes the face color.
		BadgeColors = {
			Color3.fromRGB(255, 206, 46), -- sparks
			Color3.fromRGB(196, 70, 12), -- fire
			Color3.fromRGB(36, 88, 232), -- blue fire
			Color3.fromRGB(200, 30, 130), -- fever
		},
		BadgeTextColors = {
			Color3.fromRGB(74, 38, 0),
			Color3.fromRGB(255, 255, 255),
			Color3.fromRGB(255, 255, 255),
			Color3.fromRGB(255, 255, 255),
		},
		-- Countdown ring around the badge: the combo's window (or the fever) draining. Under TimerUrgent of it left
		-- the badge shakes up to TimerUrgentShake times harder and throbs.
		TimerUrgent = 0.3,
		TimerUrgentShake = 2,
		TimerThrob = 0.12, -- extra badge size at the peak of each throb
		TimerThrobSpeed = 14, -- radians per second
		-- The coin burns (CoinsFrame.CoinFire): an emitter of round embers cloned from CoinFire.Ember. Each rises from
		-- around the coin, drifts in toward the tip, shrinks, and cools through the colors. Ranges are { min, max }.
		-- Spark colors are set in Studio (ComboFire.Sparks, BlueSparks).
		FireRate = 110, -- embers per second
		FireLife = { 0.55, 0.9 }, -- seconds
		FireSize = { 24, 40 }, -- starting diameter in pixels
		FireRise = { 150, 220 }, -- pixels per second
		FireSpread = 32, -- pixels either side of the coin's centre an ember can start
		FireBase = { 0, 30 }, -- pixels above CoinFire's bottom an ember starts
		FireTaper = 0.85, -- how far embers drift in to the centre over their life (1 = they all meet at the tip)
		FireWobble = 3, -- pixels of sideways wobble
		FireWobbleSpeed = 9, -- radians per second
		-- The whole flame sways like a tongue: a side-to-side wave that travels up it, growing toward the tip.
		FireSway = 16, -- pixels at the tip
		FireSwaySpeed = 3.2, -- radians per second
		FireSwayLag = 5, -- radians of wave per second of ember age (higher = more S-shaped)
		-- Some embers burn in front of the coin (CoinsFrame.CoinFireFront) so the fire wraps around it instead of
		-- sitting behind it. They start out at the coin's rim, either side, and lick in over it as they rise.
		FireFrontChance = 0.18, -- share of embers drawn in front
		FireFrontSpread = { 21, 30 }, -- pixels either side of the coin's centre a front ember starts (the coin is 45 wide)
		FireFrontSize = 0.5, -- front embers are this much smaller, so they lick the rim instead of hiding the coin
		-- Each ember's own transparency at birth (it still fades out as it dies), so the flame isn't one flat blob and
		-- the coin shows through the embers in front of it.
		FireTransparency = { 0, 0.2 },
		FireFrontTransparency = { 0.35, 0.65 },
		-- The combo badge shakes harder each tier (index = tier): pixels of jitter and degrees of tilt.
		BadgeLean = 8, -- degrees the badge always leans, like a sticker on the card's corner
		BadgeShake = { 0.8, 1.6, 2.6, 3.4 },
		BadgeTilt = { 4, 7, 11, 14 },
		BadgeShakeSpeed = 18, -- noise steps per second
		FireColors = {
			Color3.fromRGB(255, 225, 110),
			Color3.fromRGB(255, 165, 35),
			Color3.fromRGB(255, 95, 20),
			Color3.fromRGB(185, 30, 10),
		},
		BlueFireColors = {
			Color3.fromRGB(170, 230, 255),
			Color3.fromRGB(70, 175, 255),
			Color3.fromRGB(35, 110, 255),
			Color3.fromRGB(25, 45, 185),
		},
		BlueFireScale = 1.25, -- blue fire burns bigger
		FeverFireColors = {
			Color3.fromRGB(255, 190, 235),
			Color3.fromRGB(250, 110, 200),
			Color3.fromRGB(220, 50, 200),
			Color3.fromRGB(120, 20, 160),
		},
		FeverFireScale = 1.5,
		-- Fever (GameInfo.Fever): Banner pops in tilted and pops out after FeverBannerTime; the Glow frames along the
		-- screen edges fade in, pulse slowly, dim and brighten for the last FeverBlinkAt seconds and fade out.
		-- Fever over (no smoke, no "combo lost"): the badge swells and shakes for FeverEndSwellTime, then pops over
		-- FeverEndPopTime with a burst of fever embers flying out of the coin and falling, and CoinsFrame.ComboLost
		-- shows FeverEndText in FeverEndTextColor (for BreakTime, like a break).
		FeverBannerTime = 1.4,
		FeverPopTime = 0.25,
		FeverPopOvershoot = 1.8,
		FeverOutTime = 0.2,
		FeverTilt = -6, -- degrees
		FeverFadeTime = 0.3,
		FeverPulseSpeed = 2.5, -- radians per second
		FeverGlow = { 0.72, 0.86 }, -- Glow frames' transparency at the pulse's peak and trough (kept soft on the eyes)
		FeverBlinkAt = 2,
		FeverBlinkSpeed = 7, -- radians per second
		FeverBlinkDim = 0.5, -- how much of the glow is left at the bottom of each end blink
		FeverEndSwellTime = 0.25,
		FeverEndSwell = 0.35, -- extra badge size at the top of the swell
		FeverEndShake = 4, -- pixels the badge shakes while it swells
		FeverEndPopTime = 0.12,
		FeverBurstCount = 28,
		FeverBurstSpeed = { 140, 280 }, -- pixels per second, flung in every direction but mostly up
		FeverBurstGravity = 520, -- pixels per second squared
		FeverBurstLife = { 0.55, 0.95 },
		FeverBurstSize = { 14, 26 },
		FeverEndText = "FEVER OVER!",
		FeverEndTextColor = Color3.fromRGB(225, 50, 150),
		SparkSpeed = 7, -- twinkle, radians per second
		SparkBob = 3, -- pixels the sparks float up and down
		BadgePop = 0.35, -- extra badge size when the combo goes up
		BadgePopTime = 0.3,
		-- Combo break: the card shakes, the badge turns grey, swells and tumbles away, the fire chokes into smoke and
		-- CoinsFrame.ComboLost pops up.
		SmokeTime = 1, -- grey puffs (ComboFire.Smoke) when the combo breaks
		SmokeRise = 55, -- pixels the puffs drift up
		SmokeGrow = 1.2, -- extra puff size by the end
		BreakTime = 1.1, -- seconds the broken badge and the "combo lost" text last
		-- Text by why the combo reset (OrderService ComboReason_{team}; Lapsed = the window ran out). Only the hard
		-- breaks in BreakShakeCard shake the coin card.
		BreakTexts = {
			Expired = "COMBO LOST!",
			Failed = "COMBO LOST!",
			Lapsed = "COMBO LOST!",
			Late = "TOO LATE!",
			OutOfOrder = "WRONG ORDER!",
		} :: { [string]: string },
		BreakShakeCard = { Expired = true, Failed = true, Lapsed = true } :: { [string]: boolean },
		BreakColor = Color3.fromRGB(105, 105, 112), -- the broken badge's face
		BreakSwellTime = 0.15, -- seconds the broken badge swells and shakes before it falls
		BreakSwell = 0.4, -- extra badge size at the top of the swell
		BreakFall = 70, -- pixels the broken badge falls
		BreakSpin = 160, -- degrees it spins as it falls
		BreakShake = 8, -- pixels the coin card shakes
		BreakShakeTime = 0.45,
		BreakTextPopTime = 0.2,
		BreakTextRise = 26, -- pixels the text drifts up
		-- Every ember left turns into smoke, plus a burst of BreakSmokeCount smoke puffs from the coin.
		BreakSmokeCount = 18,
		SmokeLife = { 0.7, 1.1 },
		SmokeEmberRise = { 30, 60 }, -- pixels per second
		SmokeDrift = 40, -- pixels per second sideways, at most
		SmokeEmberGrowth = 1.6, -- extra size by the end
		SmokeColors = { Color3.fromRGB(125, 125, 133), Color3.fromRGB(80, 80, 88) },
	},
	-- Coins and timer (GameInfo.InfoFrame): bottom-right on PC, bottom-centre on touch screens (clear of the
	-- controls). InfoFrame is laid out in pixels at DesignHeight and scales with the screen height, or with the width
	-- on a squarer screen (a tablet) when that's smaller.
	Hud = {
		DesignHeight = 720,
		DesignWidth = 1280,
		DesktopScale = 0.85,
		TouchScale = 1.2,
		DesktopPosition = UDim2.new(1, -20, 1, -19),
		DesktopAnchor = Vector2.new(1, 1),
		TouchPosition = UDim2.new(0.5, 0, 1, -12),
		TouchAnchor = Vector2.new(0.5, 1),
	},
	Coins = {
		-- A gain squashes the coin card, rolls the number up and floats a "+N" above it.
		SquashTime = 0.35,
		Squash = 0.12, -- extra card size at the peak of the squash
		RollTime = 0.4, -- seconds for the number to count up to the new total
		-- When orders pay on serve, the gain waits for the served plate's coin to reach the card.
		LandDelay = 0.75, -- paid on serve: Orders.CoinDelay + FlyTime, when the served plate's coin lands
		-- Flying coins (Util/CoinFly): pop in, hop, then fly along an arc to the card.
		FlyPopTime = 0.15, -- seconds to grow in, with an overshoot
		FlyPopOvershoot = 1.7,
		FlyHop = 34, -- pixels the coin hops up before flying
		FlyTime = 0.3,
		FlyArc = 120, -- pixels the path bows upward
		CashHopTime = 0.3, -- collected table cash: seconds the coin hops at the table before flying
		-- Floating "+N" text color.
		Notification = Color3.fromRGB(255, 210, 63),
		NotificationSize = UDim2.fromOffset(120, 44), -- pixels at the HUD's design height
		NotificationRise = 70, -- pixels it floats away from the top of the coin card
		-- Each "+N" flies off at a random angle (degrees from straight up; negative = left, kept off the combo badge
		-- on the right), starts a little off-center, and leans NotificationLean of its angle the way it flies.
		NotificationAngle = { -50, 25 },
		NotificationJitter = 24, -- pixels the start point shifts left or right
		NotificationLean = 0.35,
	},
	-- Progress bar over pots, chopped food and the sink (Assets.UI.ProgressBar, ProgressController): a blue slab bar
	-- that fills green. A cooked pot shows a full bar with a check badge for Interaction.Cooking.CookSafeTime, then
	-- warns for CookAlertDuration: the fill turns orange and drains to the burn, a "!" badge shows, a red glow pulses
	-- and the bar shakes, both faster as the burn nears. A burning pot hides it (the fire takes over).
	Progress = {
		Fill = Color3.fromRGB(111, 184, 58),
		Warn = Color3.fromRGB(217, 119, 43),
		DonePopTime = 0.35, -- seconds of the squash pop when the pot finishes cooking
		DonePop = 0.3, -- extra size at the peak of the pop
		WarnPulse = { 1.5, 6 }, -- glow pulses per second at the start and the end of the warning
		WarnGlow = { 0.85, 0.25 }, -- glow transparency at the pulse's trough and peak
		WarnShake = { 2, 9 }, -- shake (degrees) at the start and the end of the warning
		WarnShakeSpeed = 22, -- shake wobbles per second
	},
	-- Smoke off a cooking pot (Assets.Effects.BurnSmoke, EffectsController): light steam while it cooks, thickening
	-- and darkening over the burn warning, thick and dark while it's on fire. The emitter's look lives on the template.
	BurnSmoke = {
		CookingRate = 1.5, -- puffs per second of light steam while cooking (and until the warning starts)
		Rate = { 3, 16 }, -- puffs per second at the warning's start and end
		Color = { Color3.fromRGB(190, 190, 198), Color3.fromRGB(70, 70, 78) }, -- light grey steam to dark smoke (combo smoke greys)
		Size = { 0.7, 1.3 }, -- puff size multiplier over the warning
		Height = 0.6, -- studs above the pot's top where the puffs start
		FireHeight = 3, -- studs above the pot's top where the puffs start while it's on fire (above the flames)
		FireZOffset = -2, -- pushes the smoke behind the flames while it's on fire
		-- On fire: fewer, lighter puffs that shoot up and spread out, so they read as a smoke plume and don't pile up
		-- into a dark ball on top of the flames.
		FireRate = 7, -- puffs per second
		FireColor = Color3.fromRGB(115, 115, 122),
		FireSpeed = { 4.5, 6.5 }, -- studs per second upward (the template's own speed otherwise)
		FireSpread = 25, -- degrees
	},
}

return UI
