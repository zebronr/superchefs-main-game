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
		SpringTime: number,
		SpringDip: number,
		SpringWobble: number,
		LineMinSpeed: number,
		SweatInterval: { number },
		SweatCount: number,
		ExhaleForward: number,
		SteamForward: number,
		FuelMin: number,
		SputterTime: number,
		SputterRate: number,
		SputterOn: number,
		BlinkAt: { number },
		BlinkLength: number,
		BlinkColor: Color3,
		BlinkTransparency: number,
	},
}

export type PhaseTuning = {
	Duration: number,
	Cooldown: number,
	CanInteract: boolean,
	PushOutRadius: number,
	PushOutStep: number,
	PushOutAngles: number,
	PushOutFloorDrop: number,
	Visuals: {
		Transparency: number,
		FadeTime: number,
		TintColor: Color3,
		TintTransparency: number,
		InsideTintTransparency: number,
		GlowBrightness: number,
		GlowRange: number,
		AuraRate: number,
		StartTime: number,
		StartShrink: number,
		StartSnap: number,
		StartWobble: number,
		StartCount: number,
		RingCount: number,
		RingRadius: number,
		FloatHeight: number,
		FloatBob: number,
		FloatPeriod: number,
		LeanPerSpeed: number,
		LeanMax: number,
		LeanStiffness: number,
		LeanDamping: number,
		WispMinSpeed: number,
		EchoMinSpeed: number,
		EchoInterval: number,
		EchoTime: number,
		EchoTransparency: number,
		EchoShrink: number,
		EchoRise: number,
		EchoCollisionGroup: string,
		FlickerTime: number,
		FlickerRateStart: number,
		FlickerRateEnd: number,
		FlickerSolid: number,
		PopCount: number,
		PopTime: number,
		PopStretch: number,
		WarpTime: number,
		WarpSquash: number,
		WarpStretch: number,
		WarpWobble: number,
		WarpGap: number,
		WarpProbe: number,
		SplashCount: number,
		SplashRadius: number,
		SpitJump: number,
		SpitWindow: number,
		SpitCount: number,
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

export type BearTossTuning = {
	GrabReach: number,
	GrabAngle: number,
	GrabMargin: number,
	HoldLimit: number,
	HoldLimitMargin: number,
	MinRange: number,
	MaxRange: number,
	RangeMargin: number,
	StartDistance: number,
	RingSpeed: number,
	LandingSearchRadius: number,
	LandingSearchStep: number,
	LandingFloorDrop: number,
	FlightTime: number,
	GetUpTime: number,
	ArcHeight: number,
	ArcSamples: number,
	LiftHeight: number,
	LiftTime: number,
	DropDistance: number,
	ThrowTime: number,
	Cooldown: number,
	CancelCooldown: number,
	RunnerCooldown: number,
	RunnerFling: number,
	RunnerLift: number,
	CameraAimShare: number,
	CameraEaseSpeed: number,
	Visuals: {
		RingColor: Color3,
		GuideColor: Color3,
		GuideDash: number,
		GuideGap: number,
		GuideSpeed: number,
		BlockedColor: Color3,
		RingPulse: number,
		RingPulseSpeed: number,
		AimSmoothing: number,
		HeldTilt: number,
		HeldWiggle: number,
		HeldWiggleSpeed: number,
		TumbleSpeed: number,
		LandSpin: number,
		LandCarry: number,
		GetUpFade: number,
		LiftDip: number,
		ThrowDip: number,
		DipTime: number,
		DipWobble: number,
		DustCount: number,
		DustRingCount: number,
		DustRingRadius: number,
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
		Ghost = "Phase",
		Bear = "BearToss",
	} :: { [string]: string },

	-- Studio only: no superskill has a cooldown (for spamming skills while testing). Off shows the real cooldown.
	StudioNoCooldown = false,

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
		-- Ghost: server time Phase ends.
		PhaseUntil = "PhaseUntil",
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
		-- Bear: on the player being thrown. TossHeldBy is the Bear's UserId while it holds them overhead; the flight
		-- is TossStartedAt (server time), TossFrom and TossTo (root positions).
		TossHeldBy = "TossHeldBy",
		TossStartedAt = "TossStartedAt",
		TossFrom = "TossFrom",
		TossTo = "TossTo",
		-- Customers: a runner the Bear caught (its ragdoll flies further).
		CaughtByToss = "CaughtByToss",
	},

	TongueGrab = {
		-- Studs the tongue reaches from the mouth.
		Range = 25,
		-- Studs: items closer than this (along the aim line) are ignored. That is Interact range.
		DeadZone = 2,
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
			StartCount = 10, -- steam puff particles from the head when Hustle starts
			EndCount = 8, -- exhale puff particles in front of the face when it ends
			TrailWidth = 1.2, -- studs between the speed trail's attachments
			-- Start: Bill squashes down and springs up (the root joint dips, then overshoots with a wobble).
			SpringTime = 0.45, -- seconds
			SpringDip = 0.55, -- studs down at the deepest
			SpringWobble = 0.35, -- overshoot of the spring back up
			-- Speed lines (Assets.Skills.Hustle.SpeedLines, rate on the template) stream only while moving faster than this.
			LineMinSpeed = 4, -- studs per second
			SweatInterval = { 0.5, 0.9 }, -- seconds between sweat flicks (min, max)
			SweatCount = 2, -- drops per flick
			ExhaleForward = 1.6, -- studs in front of the head's centre where the exhale puff starts
			SteamForward = 1.6, -- studs in front of the head's centre where the start steam puffs up
			-- Time left, without a bar: the speed lines and trail run out like fuel, sputter near the end, and Bill
			-- blinks white just before it's over.
			FuelMin = 0.25, -- speed line rate and trail width at the very end, as a fraction of full
			SputterTime = 1.5, -- seconds left when the trail and lines start cutting out
			SputterRate = 6, -- cuts per second while sputtering
			SputterOn = 0.55, -- fraction of each cut the trail stays on
			BlinkAt = { 1, 0.55, 0.25 }, -- seconds left at each white blink (closer together: speeding up)
			BlinkLength = 0.09, -- seconds each blink stays white
			BlinkColor = Color3.new(1, 1, 1),
			BlinkTransparency = 0.25, -- fill transparency at a blink
		},
	} :: HustleTuning,

	-- Ghost. See docs/design/characters/ghost-phase.md.
	Phase = {
		-- Seconds the Ghost walks through walls, counters and stations.
		Duration = 4,
		-- Seconds of cooldown, counted from when Phase ends.
		Cooldown = 12,
		-- The Ghost can pick up, put down and use stations while phased, also through walls. Throwing stays blocked
		-- (a throw from inside a wall would start inside it).
		CanInteract = true,
		-- Ending inside something: the Ghost pops out to the nearest open floor within this many studs (flat),
		-- searching rings PushOutStep apart with PushOutAngles spots each. Nothing open: back where Phase started.
		PushOutRadius = 10,
		PushOutStep = 0.75,
		PushOutAngles = 16,
		-- Studs below the feet a spot's floor may be (a spot over a hole doesn't count).
		PushOutFloorDrop = 3,
		Visuals = {
			Transparency = 0.6, -- how see-through the Ghost (and what it carries) gets
			FadeTime = 0.25, -- seconds to fade in and out (the float and lean blend in and out with it)
			-- The ghostly glow: a faint pale fill on the character's player-color Highlight, a soft haze around the body
			-- (Assets.Skills.Phase.Aura) and a pale light on what's around it (Assets.Skills.Phase.Glow). Inside a wall
			-- or counter the fill gets stronger and draws through it, so the Ghost always sees where it is.
			TintColor = Color3.fromRGB(170, 215, 255),
			TintTransparency = 0.85, -- fill transparency at full strength, in the open
			InsideTintTransparency = 0.45, -- fill transparency at full strength, inside a wall (the silhouette)
			GlowBrightness = 1.5, -- light brightness at full strength
			GlowRange = 10, -- studs the light reaches
			AuraRate = 14, -- haze particles per second
			-- Start: the body shrinks in, then bursts out bigger and wobbles back like jelly, with a puff and a ring of
			-- puffs on the floor at the burst.
			StartTime = 0.55, -- seconds
			StartShrink = 0.12, -- fraction the body shrinks at the smallest
			StartSnap = 0.25, -- fraction of StartTime spent shrinking in (the burst is at the end of it)
			StartWobble = 2, -- how fast the burst's wobble dies out (lower: bigger and longer)
			StartCount = 12, -- puff particles at the burst
			RingCount = 10, -- puffs in the floor ring at the burst
			RingRadius = 2.2, -- studs
			-- Float: lifted off the floor with a slow bob (timed from the server's start, so every client bobs in step),
			-- leaning into its movement on a spring so it sways back when it stops.
			FloatHeight = 0.6, -- studs
			FloatBob = 0.2, -- studs up and down
			FloatPeriod = 1.4, -- seconds per bob
			LeanPerSpeed = 0.025, -- radians of lean per stud per second
			LeanMax = 0.35, -- radians
			LeanStiffness = 90, -- lean spring pull
			LeanDamping = 9, -- lean spring damping (lower sways more)
			WispMinSpeed = 4, -- studs per second: wisps (Assets.Skills.Phase.Wisps, rate on the template) trail only when moving
			-- Echoes: tinted copies of the body peel off behind while moving fast, shrinking, rising and fading.
			EchoMinSpeed = 10, -- studs per second
			EchoInterval = 0.08, -- seconds between echoes
			EchoTime = 0.35, -- seconds an echo lasts
			EchoTransparency = 0.5, -- transparency at the start
			EchoShrink = 0.3, -- fraction an echo shrinks by the end
			EchoRise = 0.6, -- studs an echo floats up by the end
			EchoCollisionGroup = "Afterimage", -- registered in Studio; collides with nothing
			-- Ending soon: in the last FlickerTime seconds it flickers toward solid, faster and faster, so the player
			-- gets out of walls before the pop. Timed from the time left, so every client flickers in step.
			FlickerTime = 1.2, -- seconds
			FlickerRateStart = 3, -- flickers per second at the start of the warning
			FlickerRateEnd = 12, -- flickers per second at the end
			FlickerSolid = 0.25, -- see-through and glow while flickered solid, as a fraction of full
			PopCount = 10, -- pop particles when Phase ends
			-- End: a quick lift up and back, the "pop" back to solid.
			PopTime = 0.35, -- seconds
			PopStretch = 0.45, -- studs up at the highest
			-- Through a wall: the body warps like jelly. Going in it squashes flat along its heading (bulging out to the
			-- sides), coming out it stretches long (thinning), then it wobbles back. A ring of puffs splashes on the wall
			-- face at each crossing.
			WarpTime = 0.5, -- seconds from the hit to settled
			WarpSquash = 0.12, -- going in: fraction the body shortens along its heading at the deepest (0 turns it off)
			WarpStretch = 0.15, -- coming out (and spat out): fraction the body lengthens along its heading (0 turns it off)
			WarpWobble = 2.5, -- how fast the spring-back wobble dies out (lower: bigger and longer)
			WarpGap = 0.2, -- seconds before another wall crossing can restart the warp
			WarpProbe = 4, -- studs along the Ghost's heading to look for the wall face it crossed (for the splash)
			SplashCount = 8, -- puffs in the ring on the wall face
			SplashRadius = 1.5, -- studs
			-- Pushed out of a wall at the end: spat out, stretching toward where it was pushed, with a puff left at the
			-- old spot. Seen on every client as the character jumping more than SpitJump studs in one frame within
			-- SpitWindow seconds of the end.
			SpitJump = 1.5, -- studs
			SpitWindow = 0.3, -- seconds
			SpitCount = 8, -- puff particles at the old spot
		},
	} :: PhaseTuning,

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

	-- Bear. See docs/design/characters/bear-toss.md.
	BearToss = {
		-- Grab: the nearest free teammate in front of the Bear, at most GrabReach studs (flat) and GrabAngle degrees
		-- off its facing. The server allows GrabMargin extra studs (lag).
		GrabReach = 5,
		GrabAngle = 70,
		GrabMargin = 2,
		-- Seconds the Bear can hold someone overhead before it throws at the current ring.
		HoldLimit = 4,
		HoldLimitMargin = 0.5,
		-- Studs (flat) from the Bear to the landing spot; the server allows RangeMargin extra.
		MinRange = 6,
		MaxRange = 30,
		RangeMargin = 2,
		-- Where the landing ring starts (studs in front), and how fast the movement keys or stick slide it.
		StartDistance = 15,
		RingSpeed = 30,
		-- A ring that lands on a counter or in a wall snaps to the nearest open floor this close (flat studs).
		LandingSearchRadius = 4,
		LandingSearchStep = 1,
		-- Studs below the feet the landing spot looks for the floor.
		LandingFloorDrop = 3,
		-- The flight: seconds in the air and studs the arc rises above the straight line at its middle.
		FlightTime = 0.9,
		-- Seconds the thrown player lies as a ragdoll after landing before getting up (can't act meanwhile).
		GetUpTime = 0.6,
		ArcHeight = 9,
		-- Segments the arc is checked in for walls.
		ArcSamples = 12,
		-- Studs above the Bear's root the lifted teammate's root sits, and seconds to get there.
		LiftHeight = 4.5,
		LiftTime = 0.2,
		-- Studs in front of the Bear a teammate is put down when the toss is cancelled.
		DropDistance = 3,
		-- Seconds the Bear stays rooted after the throw.
		ThrowTime = 0.3,
		-- Seconds of cooldown, counted from the landing.
		Cooldown = 14,
		-- Cooldown when the Bear puts the teammate down (cancelled, timed out or no valid landing).
		CancelCooldown = 1,
		-- Catching a dine-and-dasher: the cooldown, and how hard its ragdoll flies (studs per second).
		RunnerCooldown = 8,
		RunnerFling = 55,
		RunnerLift = 45,
		-- The camera eases this share of the way toward the ring while aiming.
		CameraAimShare = 0.35,
		CameraEaseSpeed = 8,
		Visuals = {
			RingColor = Color3.new(1, 1, 1), -- landing ring Decal tint on a valid spot
			GuideColor = Color3.new(1, 1, 1), -- the dashed arc guide on a valid spot (white, like the Gecko's guide)
			GuideDash = 0.8, -- studs per dash of the arc guide (the Gecko guide's dashes)
			GuideGap = 0.5, -- studs between dashes
			GuideSpeed = 1.5, -- studs per second the dashes march toward the landing
			BlockedColor = Color3.fromRGB(235, 80, 70), -- no valid landing near the ring
			RingPulse = 0.12, -- fraction the ring grows and shrinks
			RingPulseSpeed = 8, -- radians per second
			AimSmoothing = 18, -- how fast the drawn ring and arc glide to the landing (per second)
			HeldTilt = 80, -- degrees the held teammate's body tips back, lying across the Bear's raised arms
			HeldWiggle = 12, -- degrees the held teammate squirms side to side
			HeldWiggleSpeed = 9, -- radians per second
			TumbleSpeed = 10, -- radians per second a thrown ragdoll spins head over heels
			LandSpin = 6, -- radians per second the ragdoll keeps rolling with after landing
			LandCarry = 0.3, -- share of the flight's sideways speed the ragdoll keeps (low, so the get-up spot stays close)
			GetUpFade = 0.15, -- seconds the ragdoll fades out as the player stands back up
			LiftDip = 0.5, -- studs the Bear squats when it lifts
			ThrowDip = 0.7, -- studs the Bear squats into the throw
			DipTime = 0.35, -- seconds for a dip to wobble back
			DipWobble = 2, -- jelly overshoot of the dip
			DustCount = 8, -- puffs at the landing (Assets.Skills.BearToss.Dust)
			DustRingCount = 10, -- puffs in the floor ring at the landing
			DustRingRadius = 2,
		},
	} :: BearTossTuning,
}

return Skills
