--!strict

export type TongueGrabTuning = {
	Range: number,
	DeadZone: number,
	LineRadius: number,
	MaxHeightDifference: number,
	SpinSpeed: number,
	LockSwitchMargin: number,
	LockTurnSpeed: number,
	HintMaxAngle: number,
	HoldLimit: number,
	HoldLimitMargin: number,
	Cooldown: number,
	MissCooldown: number,
	CancelCooldown: number,
	ExtendTime: number,
	RetractTime: number,
	ExtendEasingStyle: Enum.EasingStyle,
	ExtendEasingDirection: Enum.EasingDirection,
	RetractEasingStyle: Enum.EasingStyle,
	RetractEasingDirection: Enum.EasingDirection,
	AutoAimTurnPenalty: number,
	MaxLagCompensation: number,
	PredictionTimeout: number,
	InterceptRadius: number,
	CameraAimDistance: number,
	CameraAimDrop: number,
	CameraEaseSpeed: number,
	Visuals: {
		WobbleAmplitude: number,
		WobbleFrequency: number,
		ExtendWobble: number,
		TrailWidth: number,
		ThwipCount: number,
		SplatCount: number,
		DustCount: number,
		PopCount: number,
	},
}

export type HustleTuning = {
	Duration: number,
	MoveMultiplier: number,
	WorkMultiplier: number,
	Cooldown: number,
	Visuals: {
		StartCount: number,
		EndCount: number,
		TrailWidth: number,
	},
}

export type DeepFreezeTuning = {
	Radius: number,
	Height: number,
	Duration: number,
	Cooldown: number,
	ScanInterval: number,
	IceFloor: boolean,
	IceGrip: number,
	IceResponse: number,
	PenguinIceSpeed: number,
	Visuals: {
		StompTime: number,
		StompDip: number,
		GrowTime: number,
		GrowWobble: number,
		FrostScale: number,
		SpikeCount: number,
		SpikeClearance: number,
		SpikeLean: number,
		SpikeScaleMin: number,
		SpikeScaleMax: number,
		SpikeSpreadTime: number,
		SpikeRiseTime: number,
		SpikeBurstCount: number,
		SpikeShards: number,
		ShockwaveTime: number,
		ShockwaveScale: number,
		IdleBreathe: number,
		IdleBreatheSpeed: number,
		FreezeFlashTime: number,
		HighlightOutTime: number,
		FrostCapFit: number,
		FrostCapTime: number,
		FrostCapOutTime: number,
		IceBlockPad: number,
		IceBlockSnapTime: number,
		ShiverInterval: number,
		ShiverTime: number,
		ShiverAmount: number,
		IceBlockOutTime: number,
		IceBlockChunks: number,
		IceBlockBurstCount: number,
		BreathInterval: number,
		GlintInterval: number,
		CrackTime: number,
		CrackSpread: number,
		MeltShrink: number,
		SnowfallHeight: number,
		StationFrostFit: number,
		CrackShake: number,
		CrackSteps: number,
		ShatterTime: number,
		CutFadeTime: number,
		ShatterPop: number,
		ShardCount: number,
		ShardTime: number,
		ShardSizeMin: number,
		ShardSizeMax: number,
		ShardSpeed: number,
		ShardUpSpeed: number,
		ShardGravity: number,
		UnfreezeChunkCount: number,
		BurstCount: number,
		ShatterCount: number,
		GroundOffset: number,
	},
}

export type OrderRushTuning = {
	MaxCustomers: number,
	VanishTime: number,
	StepTime: number,
	ReturnTime: number,
	Cooldown: number,
	StopOffset: number,
	StopForward: number,
	PredictionTimeout: number,
	Visuals: {
		CollisionGroup: string,
		AfterimageTransparency: number,
		SparkleCount: number,
		UfoHeight: number,
		UfoEnterHeight: number,
		UfoExitTime: number,
		UfoFlyShare: number,
		BeamDownShare: number,
		VanishDropShare: number,
		VanishRiseShare: number,
		ReturnFlyShare: number,
		ReturnDownShare: number,
		UfoBob: number,
		UfoBobSpeed: number,
		UfoSpinSpeed: number,
		UfoTilt: number,
		UfoLeanSpeed: number,
		UfoCurve: number,
		UfoOvershoot: number,
		UfoSettleTime: number,
		UfoSettleWobbles: number,
		UfoSpeedSquash: number,
		UfoLandSquash: number,
		UfoDrift: number,
		UfoDriftSpeed: number,
		BeamTopOffset: number,
		BeamWidth: number,
		BeamTime: number,
		BeamSpinSpeed: number,
		BeamBreathe: number,
		BeamBreatheSpeed: number,
		BeamLandSquash: number,
		BeamLandTime: number,
		BeamUpShare: number,
		BeamPulse: number,
		BeamPulseSpeed: number,
		ImageShrink: number,
		ImageStretch: number,
		ImageLandSquash: number,
		ImageLandTime: number,
		ImageGlitch: number,
		ImageGlitchTilt: number,
		ImageGlitchRate: number,
	},
}

local Skills = {
	-- Character model name -> skill module name (server `Skills/` and client `Skills/`).
	-- "Alien" is a working name: rename the key together with the character model.
	ByCharacter = {
		Gecko = "TongueGrab",
		Bill = "Hustle",
		Penguin = "DeepFreeze",
		Alien = "OrderRush",
	} :: { [string]: string },

	-- TEMPORARY test mode, Studio only (ignored on live servers): KeyCode name -> skill. These keys use
	-- that skill on any character, and no skill has a cooldown. Set nil to turn it off.
	StudioTestKeys = {
		R = "TongueGrab",
		T = "Hustle",
		Y = "DeepFreeze",
		U = "OrderRush",
	} :: { [string]: string }?,

	-- Seconds of client-to-server delay compensated when an instant skill starts (half the ping, at most this).
	MaxLagCompensation = 0.2,
	-- Seconds an instant skill's local prediction waits for the server before rolling back.
	InstantConfirmTimeout = 1.5,

	-- Skill messages from one player: at most MaxRequests per RequestWindow seconds.
	MaxRequests = 8,
	RequestWindow = 1,
	-- Seconds between "Retarget" messages (an aim switching targets restarts the hold limit).
	RetargetInterval = 0.25,

	-- Attribute names. Character: set by CharacterService / SkillService. Item: set while a grabbed item flies back.
	Attribute = {
		CharacterModel = "CharacterModel",
		State = "SkillState",
		ReadyAt = "SkillReadyAt",
		Cooldown = "SkillCooldown",
		TongueState = "TongueState",
		TongueStartedAt = "TongueStartedAt",
		TongueTip = "TongueTip",
		GrabFrom = "GrabFrom",
		GrabStartedAt = "GrabStartedAt",
		GrabByUserId = "GrabByUserId",
		-- Bill: server time Hustle ends.
		HustleUntil = "HustleUntil",
		-- Penguin: the frost circle's centre and its start and end (server time).
		FreezeCenter = "FreezeCenter",
		FreezeStartedAt = "FreezeStartedAt",
		FreezeUntil = "FreezeUntil",
		-- Cooking tools and customers: server time they were frozen (nil when not frozen).
		FrozenAt = "FrozenAt",
		-- Alien: start time (server, lag-compensated) and the stops, encoded by SkillEffects.EncodeStops.
		RushStartedAt = "RushStartedAt",
		RushOrigin = "RushOrigin",
		RushStops = "RushStops",
	},

	TongueGrab = {
		-- Studs the tongue reaches from the mouth.
		Range = 25,
		-- Studs: items closer than this (along the aim line) are ignored. That is Interact range.
		DeadZone = 4,
		-- Studs: how far to the side of the aim line an item can be and still be targeted.
		LineRadius = 1.5,
		-- Studs: largest height difference between the mouth and a target.
		MaxHeightDifference = 6,
		-- Degrees per second the Gecko spins toward the aimed direction.
		SpinSpeed = 180,
		-- Degrees closer another item must be to replace the current lock.
		LockSwitchMargin = 10,
		-- Degrees per second the Gecko turns toward the locked item.
		LockTurnSpeed = 900,
		-- Degrees of slack between release direction and a hinted item.
		HintMaxAngle = 25,
		-- Seconds the aim can be held without switching targets before it cancels; each switch restarts it.
		HoldLimit = 3,
		-- Seconds of slack before the server cancels a missing release.
		HoldLimitMargin = 0.5,
		-- Seconds of cooldown after a grab, counted from when the item lands in the hands.
		Cooldown = 8,
		-- Seconds of cooldown after a miss.
		MissCooldown = 2.5,
		-- Seconds of cooldown after holding until the time limit.
		CancelCooldown = 0.5,
		-- Seconds for the tongue to reach the tip, and for the grabbed item (or the empty tongue) to come back.
		ExtendTime = 0.2,
		RetractTime = 0.3,
		-- Easing used as the tongue shoots out and slows near its tip.
		ExtendEasingStyle = Enum.EasingStyle.Exponential,
		ExtendEasingDirection = Enum.EasingDirection.Out,
		-- Easing used as the tongue and grabbed item snap back.
		RetractEasingStyle = Enum.EasingStyle.Quart,
		RetractEasingDirection = Enum.EasingDirection.In,
		-- Studs added to auto-aim score per radian of turning.
		AutoAimTurnPenalty = 8,
		-- Seconds of client-to-server delay compensated when firing.
		MaxLagCompensation = 0.2,
		-- Seconds to keep an unconfirmed local tongue after its full flight.
		PredictionTimeout = 1,
		-- Studs: extra reach of the extending tongue against thrown items (added to Throw.CastRadius).
		InterceptRadius = 1,
		-- Camera shift while aiming: studs forward along the aim, studs down, and how fast it eases in and out.
		CameraAimDistance = 6,
		CameraAimDrop = 3,
		CameraEaseSpeed = 8,
		Visuals = {
			WobbleAmplitude = 0.8, -- studs of sideways bend at full range
			WobbleFrequency = 22, -- radians per second
			ExtendWobble = 0.25, -- fraction of the wobble while shooting out
			TrailWidth = 0.6, -- studs between the item's trail attachments
			ThwipCount = 6, -- particles when the tongue fires
			SplatCount = 1, -- particles when the tongue catches an item
			DustCount = 8, -- particles when a whiff hits a wall
			PopCount = 8, -- particles when an item arrives
		},
	} :: TongueGrabTuning,

	-- Bill. See docs/design/characters/bill-hustle.md.
	Hustle = {
		-- Seconds Hustle lasts.
		Duration = 5,
		-- Walk speed multiplier while hustling.
		MoveMultiplier = 1.3,
		-- Chopping and washing speed multiplier while hustling.
		WorkMultiplier = 1.5,
		-- Seconds of cooldown, counted from when Hustle ends.
		Cooldown = 15,
		Visuals = {
			StartCount = 10, -- steam puff particles when Hustle starts
			EndCount = 8, -- exhale puff particles when it ends
			TrailWidth = 1.2, -- studs between the speed trail's attachments
		},
	} :: HustleTuning,

	-- Penguin. See docs/design/characters/penguin-deep-freeze.md.
	DeepFreeze = {
		-- Studs from the centre (flat distance) that are frozen.
		Radius = 12,
		-- Studs above and below the centre that count as inside.
		Height = 8,
		-- Seconds the freeze lasts.
		Duration = 6,
		-- Seconds of cooldown, counted from when the freeze ends.
		Cooldown = 20,
		-- Seconds between the server's checks of what is inside a circle.
		ScanInterval = 0.1,
		-- Test knob: other players slide on the frozen circle.
		IceFloor = true,
		-- Fraction of normal grip other players keep on ice (1 = no slide).
		IceGrip = 0.5,
		-- How fast (per second) full grip steers the slide toward the input; scaled by IceGrip.
		IceResponse = 10,
		-- Walk speed multiplier for the Penguin on its own ice.
		PenguinIceSpeed = 1.15,
		Visuals = {
			StompTime = 0.35, -- seconds for the root joint dip and recovery
			StompDip = 0.6, -- studs of root joint dip
			GrowTime = 0.45, -- seconds for the frost burst
			GrowWobble = 0.12, -- relative elastic overshoot
			FrostScale = 1.28, -- art diameter relative to the gameplay circle
			SpikeCount = 12, -- ice spikes around the superskill circle; 0 disables them
			SpikeClearance = 3.5, -- minimum studs from the centre
			SpikeLean = 20, -- maximum outward lean in degrees
			SpikeScaleMin = 0.7, -- smallest uniform spike scale
			SpikeScaleMax = 1.5, -- largest uniform spike scale
			SpikeSpreadTime = 0.3, -- seconds for the rise to reach the edge
			SpikeRiseTime = 0.3, -- seconds for each spike to grow
			SpikeBurstCount = 3, -- snow particles at each spike's base; 0 disables
			SpikeShards = 2, -- ice chunks thrown by each spike at shatter; 0 disables
			ShockwaveTime = 0.4, -- seconds for the ring to spread and fade
			ShockwaveScale = 1.4, -- ring diameter relative to the frost circle
			IdleBreathe = 0.015, -- relative circle size pulse
			IdleBreatheSpeed = 3, -- radians per second for the circle pulse
			FreezeFlashTime = 0.25, -- seconds for frozen highlights to settle
			HighlightOutTime = 0.15, -- seconds for thawed highlights to fade
			FrostCapFit = 0.9, -- cap width relative to the smaller tool footprint
			FrostCapTime = 0.3, -- seconds for cap pop in
			FrostCapOutTime = 0.15, -- seconds for cap shrink out
			IceBlockPad = 0.25, -- studs around customer sides and above the head
			IceBlockSnapTime = 0.3, -- seconds for the ice shell to snap on
			ShiverInterval = 2, -- seconds between small shell shivers
			ShiverTime = 0.16, -- seconds each shell shiver lasts
			ShiverAmount = 0.08, -- studs of side-to-side shell movement
			IceBlockOutTime = 0.22, -- seconds for the shell to crack and shrink away
			IceBlockChunks = 5, -- chunks shed by a thawing customer shell
			IceBlockBurstCount = 4, -- snow particles when a customer shell appears
			BreathInterval = 1.2, -- seconds between customer breath puffs
			GlintInterval = 0.5, -- seconds between frozen sparkles
			CrackTime = 1, -- seconds before the end that the cracks finish showing fully
			CrackSpread = 0.6, -- crack opacity reached by spreading over the whole freeze (the last CrackTime adds the rest)
			StationFrostFit = 1.02, -- frost slab footprint relative to each station inside the circle (0 = none)
			SnowfallHeight = 9, -- studs above the floor that snow starts falling from inside the circle (0 = none)
			MeltShrink = 0.12, -- fraction of the circle's size that melts away from the rim by the end
			CrackShake = 0.08, -- studs of final circle shiver
			CrackSteps = 20, -- shiver poses per second
			ShatterTime = 0.2, -- seconds for the circle to pop and fade
			CutFadeTime = 0.12, -- seconds for a cancelled circle to fade
			ShatterPop = 0.06, -- extra circle scale as it breaks
			ShardCount = 10, -- flying chunks when a circle ends
			ShardTime = 0.6, -- seconds each flying chunk remains
			ShardSizeMin = 0.5, -- each chunk gets a random size between these (x the IceChunk template)
			ShardSizeMax = 1.5,
			ShardSpeed = 12, -- studs per second outward
			ShardUpSpeed = 9, -- studs per second upward
			ShardGravity = 30, -- studs per second squared downward
			UnfreezeChunkCount = 3, -- chunks shed by a thawing cap
			BurstCount = 16, -- snow puff particles on the stomp
			ShatterCount = 20, -- ice chunks when it ends
			GroundOffset = 0.05, -- studs the circle's top face sits above the floor (kept under the player indicator)
		},
	} :: DeepFreezeTuning,

	-- Alien. See docs/design/characters/alien-order-rush.md.
	OrderRush = {
		-- Most customers visited per use.
		MaxCustomers = 4,
		-- Seconds to vanish before the first stop.
		VanishTime = 1.1,
		-- Seconds per customer (the order is taken halfway).
		StepTime = 1.5,
		-- Seconds to come back after the last stop.
		ReturnTime = 1.2,
		-- Seconds of cooldown after the chain.
		Cooldown = 25,
		-- Studs beside the customer where the afterimage appears.
		StopOffset = 3,
		-- Studs toward the table from the customer's side.
		StopForward = 0.75,
		-- Seconds an unconfirmed local chain is kept past its end.
		PredictionTimeout = 1,
		Visuals = {
			CollisionGroup = "Afterimage", -- registered in Studio; collides with nothing, even if the copy's Humanoid enables part collisions
			AfterimageTransparency = 0.45, -- the Alien copy riding the beam
			SparkleCount = 10, -- particles each time the beam lands
			-- The UFO (Assets.Skills.OrderRush.Ufo, a Model or a part) flies at the Alien's root height plus this.
			UfoHeight = 12,
			-- Studs above its flying height it drops in from at the start and leaves to at the end.
			UfoEnterHeight = 30,
			UfoExitTime = 0.5, -- seconds to leave after the chain
			-- Per step: fly + down should be 0.5 (the copy lands when the server takes the order), then it stands
			-- still until the last `BeamUpShare`; fly + down + up must be < 1 (the rest is standing time).
			UfoFlyShare = 0.32, -- share of each step spent flying to the next customer
			BeamDownShare = 0.18, -- share of each step spent descending to the order-taking midpoint
			VanishDropShare = 0.45, -- share of vanish time spent dropping the UFO into place
			VanishRiseShare = 0.4, -- final share of vanish time spent beaming the Alien up
			ReturnFlyShare = 0.35, -- share of return time spent flying back to the origin
			ReturnDownShare = 0.35, -- share of return time spent descending to the origin
			UfoBob = 0.35, -- studs of hover bob
			UfoBobSpeed = 4,
			UfoSpinSpeed = 1.5, -- radians per second
			UfoTilt = 10, -- peak degrees of lean, easing in and out with flight speed
			UfoLeanSpeed = 30, -- flat studs per second for full lean and speed squash; 0 disables both
			UfoCurve = 0.22, -- fraction of flight distance offset sideways at the Bezier control point
			UfoOvershoot = 1.6, -- maximum studs past an arrival target; 0 disables the settle
			UfoSettleTime = 0.45, -- seconds for the arrival wobble and jelly squash; 0 disables both
			UfoSettleWobbles = 1.5, -- half-swings during an arrival settle; 0 disables the settle
			UfoSpeedSquash = 0.12, -- vertical compression at full UfoLeanSpeed; 0 disables it
			UfoLandSquash = 0.18, -- arrival jelly compression, then stretch; 0 disables it
			UfoDrift = 0.5, -- studs of horizontal figure-eight hover drift; 0 disables it
			UfoDriftSpeed = 1.3, -- radians per second for hover drift; 0 disables it
			BeamTopOffset = 1, -- studs below the UFO's pivot where the beam starts
			BeamWidth = 6, -- studs across at the ground
			BeamTime = 0.2, -- seconds the beam takes to shoot or retract
			BeamSpinSpeed = 3, -- radians per second, opposite the UFO's spin
			BeamBreathe = 0.08, -- fraction of ground width added by the breath
			BeamBreatheSpeed = 6, -- radians per second for the width breath
			BeamLandSquash = 0.25, -- fraction of extra width when the beam lands
			BeamLandTime = 0.15, -- seconds for the landing squash to settle
			BeamUpShare = 0.22, -- share of each step at its end spent beaming the Alien back up
			BeamPulse = 0.12, -- transparency wobble
			BeamPulseSpeed = 14,
			ImageShrink = 0.35, -- the Alien's scale once beamed up into the UFO
			ImageStretch = 0.35, -- extra height while in the beam; 0 disables
			ImageLandSquash = 0.25, -- compression when the copy lands; 0 disables
			ImageLandTime = 0.35, -- seconds for the copy's landing jelly and glitch tail; 0 disables
			ImageGlitch = 0.6, -- studs of per-part positional jitter; 0 disables
			ImageGlitchTilt = 12, -- degrees of per-part rotation jitter; 0 disables
			ImageGlitchRate = 20, -- stepped glitches per second; 0 disables
		},
	} :: OrderRushTuning,
}

return Skills
