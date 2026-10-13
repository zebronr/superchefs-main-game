--!strict

export type AnglePreset = {
	Name: string,
	Offset: Vector3,
	LookOffset: Vector3,
	Fov: number,
	World: boolean?,
	Orbit: boolean?,
	Up: Vector3?,
}

local CinematicCamera = {
	Command = "CinematicCameraCommand", -- TextChatCommand authored in Studio.
	UserIds = { 5845362590 }, -- Developers who can use /cinecam in any server.
	Attribute = "Cinematic", -- Player attribute that excludes the filmer from gameplay.
	Keys = {
		Free = Enum.KeyCode.Zero, -- Return to free flight.
		Focus = { -- Focus slots in join order.
			Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three,
			Enum.KeyCode.Four, Enum.KeyCode.Five, Enum.KeyCode.Six,
			Enum.KeyCode.Seven, Enum.KeyCode.Eight, Enum.KeyCode.Nine,
		},
		NextTarget = Enum.KeyCode.Tab, -- Cycle focused players.
		PreviousModifier = Enum.KeyCode.LeftShift, -- Hold with Tab or C to cycle backward.
		Wide = Enum.KeyCode.V, -- Orbit the map.
		NextAngle = Enum.KeyCode.C, -- Cycle focus angles.
		Forward = Enum.KeyCode.W, -- Fly forward.
		Backward = Enum.KeyCode.S, -- Fly backward.
		Left = Enum.KeyCode.A, -- Fly left.
		Right = Enum.KeyCode.D, -- Fly right.
		Up = Enum.KeyCode.Space, -- Fly upward.
		Down = Enum.KeyCode.LeftShift, -- Fly downward.
		LookUp = Enum.KeyCode.Up, -- Tilt upward.
		LookDown = Enum.KeyCode.Down, -- Tilt downward.
		LookLeft = Enum.KeyCode.Left, -- Turn left.
		LookRight = Enum.KeyCode.Right, -- Turn right.
		SlowModifier = Enum.KeyCode.LeftAlt, -- Slow free flight and looking.
		FastModifier = Enum.KeyCode.LeftControl, -- Fast free flight.
		SpeedDown = Enum.KeyCode.LeftBracket, -- Lower base flight speed.
		SpeedUp = Enum.KeyCode.RightBracket, -- Raise base flight speed.
		ZoomIn = Enum.KeyCode.Z, -- Narrow the field of view.
		ZoomOut = Enum.KeyCode.X, -- Widen the field of view.
		ResetFov = Enum.KeyCode.R, -- Reset zoom for this mode.
		HideHud = Enum.KeyCode.H, -- Toggle screen and core UI.
		Pause = Enum.KeyCode.P, -- Freeze the shot.
		PauseTimer = Enum.KeyCode.T, -- Pause or resume the round clock.
	},
	BaseSpeed = 28, -- Free camera studs per second.
	MinSpeed = 2, -- Lowest adjustable free camera speed.
	MaxSpeed = 120, -- Highest adjustable free camera speed.
	SpeedStep = 1.35, -- Multiplier for each bracket press.
	SlowMultiplier = 0.22, -- Left Alt movement multiplier.
	SlowLookMultiplier = 0.3, -- Left Alt mouse and arrow key look multiplier.
	FastMultiplier = 3, -- Left Control movement multiplier.
	MoveSmoothing = 7, -- Free camera velocity response per second.
	PositionSmoothing = 4, -- Focus and wide shot position response per second.
	LookSmoothing = 5, -- Aim point and target yaw response per second.
	FovSmoothing = 5, -- Field of view response per second.
	MinLookDistance = 0.01, -- Minimum gap between camera and aim point.
	LookSpeed = math.rad(95), -- Arrow key rotation radians per second.
	MouseSensitivity = 0.003, -- Free cam mouse look radians per mouse pixel.
	PitchLimit = math.rad(85), -- Maximum free camera pitch.
	MinFov = 15, -- Tightest zoom in degrees.
	MaxFov = 90, -- Widest zoom in degrees.
	ZoomSpeed = 35, -- Held zoom degrees per second.
	WideFov = 55, -- Default map orbit field of view.
	WideMargin = 1.15, -- Extra distance around the map bounds.
	WideHeight = 0.55, -- Orbit height as a fraction of its radius.
	WideOrbitSpeed = math.rad(5), -- Map orbit radians per second.
	OrbitSpeed = math.rad(12), -- Player orbit radians per second.
	OrbitRadius = 12, -- Player orbit radius in studs.
	OrbitHeight = 6, -- Player orbit height in studs.
	Angles = { -- Focus shots; local offsets use the target's smoothed flat yaw.
		{ Name = "Game view", Offset = Vector3.zero, LookOffset = Vector3.zero, Fov = 50, World = true },
		{ Name = "Over shoulder", Offset = Vector3.new(2, 5, 9), LookOffset = Vector3.new(0, 2, -4), Fov = 45 },
		{ Name = "Front hero", Offset = Vector3.new(0, 2, -8), LookOffset = Vector3.new(0, 3, 0), Fov = 42 },
		{ Name = "Side tracking", Offset = Vector3.new(10, 3, 0), LookOffset = Vector3.new(0, 2, 0), Fov = 48 },
		{ Name = "Top down", Offset = Vector3.new(0, 20, 0), LookOffset = Vector3.zero, Fov = 50, Up = Vector3.new(0, 0, -1) },
		{ Name = "Slow orbit", Offset = Vector3.zero, LookOffset = Vector3.new(0, 2, 0), Fov = 45, Orbit = true },
	} :: { AnglePreset },
}

return CinematicCamera
