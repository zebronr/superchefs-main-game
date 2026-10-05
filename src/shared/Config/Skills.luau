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

local Skills = {
	-- Character model name -> skill module name (server `Skills/` and client `Skills/`). Bill has no skill yet.
	ByCharacter = {
		Gecko = "TongueGrab",
	} :: { [string]: string },

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
}

return Skills
