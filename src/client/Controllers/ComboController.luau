--!strict

-- Combo fire on the coin card (level EnableCombo). The server keeps Combo_{team}, ComboEndsAt_{team},
-- ComboReason_{team} and FeverEndsAt_{team} on ReplicatedStorage; this draws them: a badge with the count and a
-- countdown ring, then sparks, orange fire and blue fire as the combo grows (the coin burns: an emitter of round
-- embers), a pink fever with a banner and glowing screen edges, and a puff of smoke when it breaks. Layout and
-- colors live in Studio (docs/UI-GUIDE.md).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local RadialRing = require(script.Parent.Parent.Util.RadialRing)
local Shared = ReplicatedStorage:WaitForChild("Shared")
local BitmapFont = require(Shared:WaitForChild("Util"):WaitForChild("BitmapFont"))
local Jersey15 = require(Shared:WaitForChild("Fonts"):WaitForChild("Jersey15"))
local Config = require(Shared:WaitForChild("Config"))
local Levels = Config.Levels

-- The combo as the server keeps it (or the effect tester fakes it). Times are server times.
export type State = { Combo: number, EndsAt: number?, FeverEndsAt: number?, Reason: string? }

-- Ember colors: orange fire, blue fire, fever.
type FireKind = "Orange" | "Blue" | "Fever"

-- One round ember of the coin fire, or a smoke puff once the combo breaks; positions are pixels from CoinFire's
-- bottom centre. Shown* hold where it was last drawn, so a burning ember can turn into smoke in place.
type Ember = {
	Frame: GuiObject,
	BornAt: number,
	Life: number,
	X: number,
	Y: number,
	Rise: number,
	Size: number,
	Phase: number,
	-- Transparency at birth; it fades from here to gone over the ember's life.
	Transparency: number,
	Kind: FireKind,
	-- Drawn in front of the coin (CoinFireFront) instead of behind it.
	Front: boolean,
	Smoke: boolean,
	-- Flung out when a fever ends: flies at VX, VY and falls.
	Burst: boolean,
	VX: number,
	VY: number,
	Drift: number,
	ShownX: number,
	ShownY: number,
	ShownSize: number,
}
type Spark = { Image: ImageLabel, Position: UDim2 }
type Puff = { Frame: GuiObject, Position: UDim2, Size: UDim2 }

local ComboController = {}
local player = Players.LocalPlayer
local gameInfo = player:WaitForChild("PlayerGui"):WaitForChild("GameInfo")
local infoFrame = gameInfo:WaitForChild("InfoFrame")
local fire = infoFrame:WaitForChild("ComboFire") :: GuiObject
local sparkGroup = fire:WaitForChild("Sparks") :: GuiObject
local blueSparkGroup = fire:WaitForChild("BlueSparks") :: GuiObject
local smokeGroup = fire:WaitForChild("Smoke") :: GuiObject
local coinsFrame = infoFrame:WaitForChild("CoinsFrame") :: GuiObject
local coinsShadow = infoFrame:WaitForChild("CoinsShadow") :: GuiObject
local coinsPosition = coinsFrame.Position
local coinsShadowPosition = coinsShadow.Position
local lostLabel = coinsFrame:WaitForChild("ComboLost") :: TextLabel
local lostPop = lostLabel:WaitForChild("Pop") :: UIScale
local lostStroke = lostLabel:FindFirstChildOfClass("UIStroke")
local lostPosition = lostLabel.Position
local lostColor = lostLabel.TextColor3
local coinFire = coinsFrame:WaitForChild("CoinFire") :: GuiObject
local emberTemplate = coinFire:WaitForChild("Ember") :: GuiObject
local coinFireFront = coinsFrame:WaitForChild("CoinFireFront") :: GuiObject
local badge = coinsFrame:WaitForChild("ComboBadge") :: GuiObject
local badgePop = badge:WaitForChild("Pop") :: UIScale
local badgeFace = badge:WaitForChild("Face") :: GuiObject
local badgeLabel = badge:WaitForChild("Label") :: TextLabel
local badgeShadow = badge:WaitForChild("Shadow") :: GuiObject
local badgeTimer = badge:WaitForChild("Timer") :: GuiObject
local timerRing = RadialRing.Find(badgeTimer)
local badgePosition = badge.Position
local badgeShadowTransparency = badgeShadow.BackgroundTransparency

-- Tilts the badge's face, shadow and label but never the badge itself: Roblox stops clipping under a rotated
-- GuiObject, which would break the countdown ring's clipped halves (it is round, so it needn't turn).
local function tiltBadge(degrees: number): ()
	local rotation = Config.UI.Combo.BadgeLean + degrees
	badgeFace.Rotation = rotation
	badgeShadow.Rotation = rotation
	badgeLabel.Rotation = rotation
end
local feverGui = gameInfo:WaitForChild("Fever") :: GuiObject
local feverGlow = feverGui:WaitForChild("Glow") :: GuiObject
local feverBanner = feverGui:WaitForChild("Banner") :: GuiObject
local feverBannerSize = feverBanner.Size
local glowFrames: { GuiObject } = {}
local embers: { Ember } = {}
local spareEmbers: { GuiObject } = {}
local emitCarry = 0
local lastClock = os.clock()
-- Ember scatter is cosmetic, so each client rolls its own.
local random = Random.new()
local sparks: { Spark } = {}
local blueSparks: { Spark } = {}
local puffs: { Puff } = {}
local lastCombo = 0
local lastTier = 0
local lastFever = false
local popAt = -math.huge
local smokeAt = -math.huge
local breakAt = -math.huge
local brokenCombo = 0
local breakReason = "Lapsed"
local feverAt = -math.huge
local feverOverAt = -math.huge
local feverBurst = false
-- Effect tester only: a local combo shown instead of the server's (nil = use the server's).
local simulated: State? = nil

local function tierOf(combo: number): number
	local tuning = Config.UI.Combo
	return if combo >= tuning.BlueAt then 3 elseif combo >= tuning.FireAt then 2 elseif combo >= tuning.SparksAt then 1 else 0
end

local function number(value: any): number?
	return if typeof(value) == "number" then value else nil
end

-- The team's combo as the server keeps it; nil off-level or outside a round.
local function readState(): State?
	if simulated ~= nil then
		return simulated
	end
	local team = player:GetAttribute("Team")
	if typeof(team) ~= "number" or not Levels.GetCurrent().EnableCombo
		or ReplicatedStorage:GetAttribute("RoundState") ~= "Playing" then
		return nil
	end
	local reason = ReplicatedStorage:GetAttribute(`ComboReason_{team}`)
	return {
		Combo = number(ReplicatedStorage:GetAttribute(`Combo_{team}`)) or 0,
		EndsAt = number(ReplicatedStorage:GetAttribute(`ComboEndsAt_{team}`)),
		FeverEndsAt = number(ReplicatedStorage:GetAttribute(`FeverEndsAt_{team}`)),
		Reason = if typeof(reason) == "string" then reason else nil,
	}
end

local function scaled(size: UDim2, x: number, y: number): UDim2
	return UDim2.new(size.X.Scale * x, size.X.Offset * x, size.Y.Scale * y, size.Y.Offset * y)
end

local function backOut(p: number, strength: number): number
	local q = p - 1
	return 1 + (strength + 1) * q ^ 3 + strength * q ^ 2
end

local function between(range: { number }): number
	return range[1] + (range[2] - range[1]) * random:NextNumber()
end

local function colorAt(colors: { Color3 }, p: number): Color3
	local position = math.clamp(p, 0, 1) * (#colors - 1)
	local index = math.min(math.floor(position) + 1, #colors - 1)
	return colors[index]:Lerp(colors[index + 1], position - (index - 1))
end

local function fireLook(kind: FireKind): ({ Color3 }, number)
	local tuning = Config.UI.Combo
	if kind == "Fever" then
		return tuning.FeverFireColors, tuning.FeverFireScale
	elseif kind == "Blue" then
		return tuning.BlueFireColors, tuning.BlueFireScale
	end
	return tuning.FireColors, 1
end

local function emitEmber(bornAt: number, kind: FireKind, front: boolean?): ()
	local tuning = Config.UI.Combo
	local _, scale = fireLook(kind)
	local frame = table.remove(spareEmbers) or emberTemplate:Clone()
	frame.Parent = if front then coinFireFront else coinFire
	frame.Visible = true
	local x = if front
		then (if random:NextNumber() < 0.5 then -1 else 1) * between(tuning.FireFrontSpread) * scale
		-- Two rolls bunch the embers toward the centre.
		else (random:NextNumber() + random:NextNumber() - 1) * tuning.FireSpread * scale
	table.insert(embers, {
		Frame = frame,
		BornAt = bornAt,
		Life = between(tuning.FireLife),
		X = x,
		Y = between(tuning.FireBase),
		Rise = between(tuning.FireRise) * scale,
		Size = between(tuning.FireSize) * scale * (if front then tuning.FireFrontSize else 1),
		Phase = random:NextNumber() * math.pi * 2,
		Transparency = between(if front then tuning.FireFrontTransparency else tuning.FireTransparency),
		Kind = kind,
		Front = front == true,
		Smoke = false,
		Burst = false,
		VX = 0,
		VY = 0,
		Drift = 0,
		ShownX = 0,
		ShownY = 0,
		ShownSize = 0,
	})
end

-- Turns an ember into a smoke puff that starts where it is now.
local function smokeOut(ember: Ember, clock: number): ()
	local tuning = Config.UI.Combo
	ember.Smoke = true
	ember.BornAt = clock
	ember.Life = between(tuning.SmokeLife)
	ember.X = ember.ShownX
	ember.Y = ember.ShownY
	ember.Size = math.max(ember.ShownSize, 6)
	ember.Rise = between(tuning.SmokeEmberRise)
	ember.Drift = (random:NextNumber() * 2 - 1) * tuning.SmokeDrift
end

-- The combo broke: the fire chokes into smoke, with a burst of puffs from the coin.
local function chokeFire(clock: number): ()
	local tuning = Config.UI.Combo
	for _, ember in embers do
		if not ember.Smoke then
			smokeOut(ember, clock)
		end
	end
	for _ = 1, tuning.BreakSmokeCount do
		emitEmber(clock, "Orange")
		local ember = embers[#embers]
		ember.ShownX = (random:NextNumber() * 2 - 1) * tuning.FireSpread
		ember.ShownY = between(tuning.FireBase) + 10
		ember.ShownSize = between(tuning.FireSize)
		smokeOut(ember, clock)
	end
end

-- The fever ended: fever embers fly out of the coin in every direction (mostly up) and fall.
local function burstFever(clock: number): ()
	local tuning = Config.UI.Combo
	for _ = 1, tuning.FeverBurstCount do
		emitEmber(clock, "Fever")
		local ember = embers[#embers]
		local angle = math.rad(90 + (random:NextNumber() * 2 - 1) * 110)
		local speed = between(tuning.FeverBurstSpeed)
		ember.Burst = true
		ember.X = (random:NextNumber() * 2 - 1) * tuning.FireSpread * 0.5
		ember.Y = between(tuning.FireBase)
		ember.VX = math.cos(angle) * speed
		ember.VY = math.sin(angle) * speed
		ember.Life = between(tuning.FeverBurstLife)
		ember.Size = between(tuning.FeverBurstSize)
	end
end

-- Emits while the tier burns; embers already out finish their life after it stops.
local function drawCoinFire(tier: number, clock: number, dt: number): ()
	local tuning = Config.UI.Combo
	if tier >= 2 then
		local kind: FireKind = if tier >= 4 then "Fever" elseif tier >= 3 then "Blue" else "Orange"
		emitCarry += dt * tuning.FireRate
		while emitCarry >= 1 do
			emitCarry -= 1
			emitEmber(clock - emitCarry / tuning.FireRate, kind, random:NextNumber() < tuning.FireFrontChance)
		end
	else
		emitCarry = 0
	end
	for index = #embers, 1, -1 do
		local ember = embers[index]
		local age = clock - ember.BornAt
		local p = age / ember.Life
		local frame = ember.Frame
		if p >= 1 then
			frame.Visible = false
			frame.Parent = coinFire
			table.insert(spareEmbers, frame)
			table.remove(embers, index)
			continue
		end
		-- The sway an ember shows is the flame's lean when it was born, so the wave travels up the flame.
		local sway = math.sin(clock * tuning.FireSwaySpeed - age * tuning.FireSwayLag)
			+ 0.4 * math.sin(clock * tuning.FireSwaySpeed * 2.3 - age * tuning.FireSwayLag * 1.7)
		local x, size
		local y = ember.Y + ember.Rise * age
		if ember.Burst then
			x = ember.X + ember.VX * age
			y = ember.Y + ember.VY * age - 0.5 * tuning.FeverBurstGravity * age * age
			size = ember.Size * (1 - p * p)
			frame.BackgroundColor3 = colorAt(tuning.FeverFireColors, p)
			frame.BackgroundTransparency = p * p
		elseif ember.Smoke then
			x = ember.X + ember.Drift * age + tuning.FireWobble * math.sin(age * tuning.FireWobbleSpeed + ember.Phase)
			size = ember.Size * (1 + tuning.SmokeEmberGrowth * (1 - (1 - p) ^ 2))
			frame.BackgroundColor3 = colorAt(tuning.SmokeColors, p)
			frame.BackgroundTransparency = 0.2 + 0.8 * p ^ 1.5
		else
			x = ember.X * (1 - tuning.FireTaper * p)
				+ tuning.FireWobble * math.sin(age * tuning.FireWobbleSpeed + ember.Phase)
				+ tuning.FireSway * p * sway
			size = ember.Size * (1 - p) ^ 0.6
			local colors = fireLook(ember.Kind)
			frame.BackgroundColor3 = colorAt(colors, p)
			frame.BackgroundTransparency = 1 - (1 - ember.Transparency) * (1 - 0.8 * p ^ 3)
		end
		ember.ShownX = x
		ember.ShownY = y
		ember.ShownSize = size
		frame.Position = UDim2.new(0.5, x, 1, -y)
		frame.Size = UDim2.fromOffset(size, size)
		-- Young, hot embers draw on top.
		frame.ZIndex = 10 - math.floor(p * 9)
	end
	local anyFront = false
	for _, ember in embers do
		if ember.Front then
			anyFront = true
			break
		end
	end
	coinFire.Visible = #embers > 0
	coinFireFront.Visible = anyFront
end

-- Fades the badge out (0 = solid, 1 = gone).
local function setBadgeFade(fade: number): ()
	badgeFace.BackgroundTransparency = fade
	badgeLabel.TextTransparency = fade
	badgeShadow.BackgroundTransparency = badgeShadowTransparency + (1 - badgeShadowTransparency) * fade
end

local function drawSparks(group: GuiObject, list: { Spark }, shown: boolean, clock: number): ()
	local tuning = Config.UI.Combo
	group.Visible = shown
	if not shown then
		return
	end
	for index, spark in list do
		local phase = clock * tuning.SparkSpeed + index * 2.1
		local twinkle = 0.5 + 0.5 * math.sin(phase)
		spark.Image.ImageTransparency = 0.6 * (1 - twinkle)
		spark.Image.Rotation = 20 * math.sin(phase * 0.5)
		spark.Image.Position = spark.Position + UDim2.fromOffset(0, -tuning.SparkBob * math.sin(phase * 0.7))
	end
end

-- Fever overlay: the banner pops in and out when it starts; the screen edges glow and pulse while it lasts,
-- dim and brighten near the end and fade out after. `left` is seconds of fever left (0 when none runs).
local function drawFever(clock: number, fever: boolean, left: number): ()
	local tuning = Config.UI.Combo
	local shown = if fever
		then math.clamp((clock - feverAt) / tuning.FeverFadeTime, 0, 1)
		else 1 - math.clamp((clock - feverOverAt) / tuning.FeverFadeTime, 0, 1)
	local bannerAge = clock - feverAt
	local banner = bannerAge < tuning.FeverBannerTime
	feverGui.Visible = shown > 0 or banner
	if not feverGui.Visible then
		return
	end
	if fever and left < tuning.FeverBlinkAt then
		-- A soft dim and brighten, not a hard flash.
		shown *= 1 - (1 - tuning.FeverBlinkDim) * (0.5 + 0.5 * math.sin(clock * tuning.FeverBlinkSpeed))
	end
	local pulse = 0.5 + 0.5 * math.sin(clock * tuning.FeverPulseSpeed)
	local glow = tuning.FeverGlow[2] + (tuning.FeverGlow[1] - tuning.FeverGlow[2]) * pulse
	for _, frame in glowFrames do
		frame.BackgroundTransparency = 1 - (1 - glow) * shown
	end
	feverBanner.Visible = banner
	if banner then
		local scale = math.max(backOut(math.clamp(bannerAge / tuning.FeverPopTime, 0, 1), tuning.FeverPopOvershoot), 0)
		local out = tuning.FeverBannerTime - bannerAge
		if out < tuning.FeverOutTime then
			scale *= (out / tuning.FeverOutTime) ^ 4
		end
		feverBanner.Size = scaled(feverBannerSize, scale, scale)
		feverBanner.Rotation = tuning.FeverTilt
	end
end

local function step(): ()
	local tuning = Config.UI.Combo
	local clock = os.clock()
	local now = workspace:GetServerTimeNow()
	local state = readState()
	local combo = 0
	local fever = false
	local feverLeft = 0
	-- Fraction of the window (or the fever) left, for the countdown ring; nil hides it.
	local timerLeft: number? = nil
	local endsAt = if state ~= nil then state.EndsAt else nil
	if state ~= nil and state.Combo > 0 and endsAt ~= nil and now <= endsAt then
		combo = state.Combo
		local comboTuning = Levels.GetCurrent().Combo
		local feverEndsAt = state.FeverEndsAt
		if feverEndsAt ~= nil and now < feverEndsAt then
			fever = true
			feverLeft = feverEndsAt - now
			local feverTuning = if comboTuning ~= nil then comboTuning.Fever else nil
			if feverTuning ~= nil then
				timerLeft = feverLeft / feverTuning.Time
			end
		elseif comboTuning ~= nil and comboTuning.Window > 0 then
			timerLeft = (endsAt - now) / comboTuning.Window
		end
	end
	local tier = if fever then 4 else tierOf(combo)
	if combo > lastCombo and tier >= 1 then
		popAt = clock
	end
	if fever and not lastFever then
		feverAt = clock
	elseif lastFever and not fever then
		feverOverAt = clock
		feverBurst = false
	end
	if combo < lastCombo and lastTier >= 1 then
		brokenCombo = lastCombo
		if not lastFever then
			-- A server reset names its reason; a combo that just ran out of time has none.
			local reason = if state ~= nil then state.Reason else nil
			breakReason = if reason ~= nil and reason ~= "FeverOver" then reason else "Lapsed"
			smokeAt = clock
			breakAt = clock
			chokeFire(clock)
		end
	end
	lastCombo = combo
	lastTier = tier
	lastFever = fever

	local sinceBreak = clock - breakAt
	local broken = tier == 0 and sinceBreak < tuning.BreakTime
	local sinceFeverOver = clock - feverOverAt
	local feverOver = tier == 0 and not broken and sinceFeverOver < tuning.FeverEndSwellTime + tuning.FeverEndPopTime
	local feverText = tier == 0 and not broken and sinceFeverOver < tuning.BreakTime
	badge.Visible = tier >= 1 or broken or feverOver
	badgeTimer.Visible = tier >= 1 and timerLeft ~= nil and timerRing ~= nil
	-- Cosmetic jitter, different on every client.
	local beat = clock * tuning.BadgeShakeSpeed
	if tier >= 1 then
		badgeLabel.Text = `x{combo}`
		badgeFace.BackgroundColor3 = tuning.BadgeColors[tier]
		badgeLabel.TextColor3 = tuning.BadgeTextColors[tier]
		setBadgeFade(0)
		-- Running out: shakes harder and throbs.
		local urgency = if timerLeft ~= nil then math.clamp(1 - timerLeft / tuning.TimerUrgent, 0, 1) else 0
		if timerRing ~= nil and timerLeft ~= nil then
			RadialRing.Set(timerRing, timerLeft, tuning.BadgeColors[tier])
		end
		local p = math.clamp((clock - popAt) / tuning.BadgePopTime, 0, 1)
		badgePop.Scale = 1 + tuning.BadgePop * math.sin(p * math.pi) * (1 - p)
			+ tuning.TimerThrob * urgency * math.max(0, math.sin(clock * tuning.TimerThrobSpeed))
		local shake = tuning.BadgeShake[tier] * (1 + (tuning.TimerUrgentShake - 1) * urgency)
		badge.Position = badgePosition + UDim2.fromOffset(math.noise(beat, 0.5) * 2 * shake, math.noise(beat, 7.5) * 2 * shake)
		tiltBadge(math.noise(beat, 13.5) * 2 * tuning.BadgeTilt[tier])
	elseif broken then
		-- Grey, swells with a violent shake, then tumbles down and fades.
		badgeLabel.Text = `x{brokenCombo}`
		badgeFace.BackgroundColor3 = tuning.BreakColor
		badgeLabel.TextColor3 = Color3.new(1, 1, 1)
		local swell = math.clamp(sinceBreak / tuning.BreakSwellTime, 0, 1)
		local fall = math.clamp((sinceBreak - tuning.BreakSwellTime) / (tuning.BreakTime - tuning.BreakSwellTime), 0, 1)
		badgePop.Scale = (1 + tuning.BreakSwell * math.sin(swell * math.pi / 2)) * (1 - 0.4 * fall)
		local shake = tuning.BreakShake * (1 - fall)
		badge.Position = badgePosition
			+ UDim2.fromOffset(math.noise(beat, 0.5) * 2 * shake, math.noise(beat, 7.5) * 2 * shake + tuning.BreakFall * fall * fall)
		tiltBadge(math.noise(beat, 13.5) * 30 * (1 - fall) - tuning.BreakSpin * fall * fall)
		setBadgeFade(fall * fall)
	elseif feverOver then
		-- The fever burnt out: the badge swells and shakes in its fever colors, then pops into a burst of embers.
		badgeLabel.Text = `x{brokenCombo}`
		badgeFace.BackgroundColor3 = tuning.BadgeColors[4]
		badgeLabel.TextColor3 = tuning.BadgeTextColors[4]
		setBadgeFade(0)
		local swell = math.clamp(sinceFeverOver / tuning.FeverEndSwellTime, 0, 1)
		local pop = math.clamp((sinceFeverOver - tuning.FeverEndSwellTime) / tuning.FeverEndPopTime, 0, 1)
		badgePop.Scale = (1 + tuning.FeverEndSwell * math.sin(swell * math.pi / 2)) * (1 - pop) ^ 2
		local shake = tuning.FeverEndShake * swell
		badge.Position = badgePosition + UDim2.fromOffset(math.noise(beat, 0.5) * 2 * shake, math.noise(beat, 7.5) * 2 * shake)
		tiltBadge(math.noise(beat, 13.5) * 2 * tuning.BadgeTilt[4] * swell)
	end
	if not feverBurst and tier == 0 and sinceFeverOver >= tuning.FeverEndSwellTime
		and sinceFeverOver < tuning.FeverEndSwellTime + tuning.FeverEndPopTime then
		feverBurst = true
		burstFever(clock)
	end

	-- The coin card (and its shadow) shakes when the combo breaks hard.
	local cardShake = Vector2.zero
	if sinceBreak < tuning.BreakShakeTime and tuning.BreakShakeCard[breakReason] then
		local strength = tuning.BreakShake * (1 - sinceBreak / tuning.BreakShakeTime)
		local quick = clock * tuning.BadgeShakeSpeed * 2
		cardShake = Vector2.new(math.noise(quick, 21.5), math.noise(quick, 33.5)) * 2 * strength
	end
	coinsFrame.Position = coinsPosition + UDim2.fromOffset(cardShake.X, cardShake.Y)
	coinsShadow.Position = coinsShadowPosition + UDim2.fromOffset(cardShake.X, cardShake.Y)

	-- "COMBO LOST!" (or why, or "FEVER OVER!") pops up above the card, drifts up and fades.
	lostLabel.Visible = broken or feverText
	if broken or feverText then
		local since = if broken then sinceBreak else sinceFeverOver
		local p = since / tuning.BreakTime
		local pop = math.clamp(since / tuning.BreakTextPopTime, 0, 1)
		lostLabel.Text = if broken then tuning.BreakTexts[breakReason] or tuning.BreakTexts.Lapsed else tuning.FeverEndText
		lostLabel.TextColor3 = if broken then lostColor else tuning.FeverEndTextColor
		lostPop.Scale = math.max(backOut(pop, 1.7), 0)
		lostLabel.Position = lostPosition - UDim2.fromOffset(0, tuning.BreakTextRise * p)
		local fade = math.clamp((p - 0.7) / 0.3, 0, 1)
		lostLabel.TextTransparency = fade
		if lostStroke ~= nil then
			lostStroke.Transparency = fade
		end
	end

	drawCoinFire(tier, clock, math.min(clock - lastClock, 0.1))
	lastClock = clock
	drawFever(clock, fever, feverLeft)

	local smoke = (clock - smokeAt) / tuning.SmokeTime
	fire.Visible = tier >= 1 or smoke < 1
	if not fire.Visible then
		return
	end
	drawSparks(sparkGroup, sparks, tier == 1, clock)
	drawSparks(blueSparkGroup, blueSparks, tier >= 3, clock)
	smokeGroup.Visible = smoke < 1
	for index, puff in puffs do
		local p = math.clamp(smoke * 1.2 - (index - 1) * 0.06, 0, 1)
		local grow = 0.6 + (0.4 + tuning.SmokeGrow) * (1 - (1 - p) ^ 2)
		puff.Frame.BackgroundTransparency = 0.3 + 0.7 * p * p
		puff.Frame.Position = puff.Position - UDim2.fromOffset(0, tuning.SmokeRise * p)
		puff.Frame.Size = scaled(puff.Size, grow, grow)
	end
end

local function collectSparks(group: Instance, into: { Spark }): ()
	for _, child in group:GetChildren() do
		if child:IsA("ImageLabel") then
			table.insert(into, { Image = child, Position = child.Position })
		end
	end
end

-- Effect tester: shows `state` locally instead of the server's (nil hands back to the server's).
function ComboController.Simulate(state: State?): ()
	simulated = state
end

function ComboController.Simulated(): State?
	return simulated
end

function ComboController.Start(_self: typeof(ComboController)): ()
	emberTemplate.Visible = false
	coinFire.Visible = false
	coinFireFront.Visible = false
	collectSparks(sparkGroup, sparks)
	collectSparks(blueSparkGroup, blueSparks)
	for _, child in smokeGroup:GetChildren() do
		if child:IsA("GuiObject") then
			table.insert(puffs, { Frame = child, Position = child.Position, Size = child.Size })
		end
	end
	table.sort(puffs, function(left: Puff, right: Puff): boolean
		return left.Frame.Name < right.Frame.Name
	end)
	for _, child in feverGlow:GetChildren() do
		if child:IsA("GuiObject") then
			table.insert(glowFrames, child)
		end
	end
	-- The banner's word is drawn in Jersey 15 like the Ready-Set-Go banners; the label's own text is hidden.
	local bannerLabel = feverBanner:FindFirstChildWhichIsA("TextLabel")
	if bannerLabel ~= nil and BitmapFont.IsReady(Jersey15) then
		bannerLabel.TextTransparency = 1
		BitmapFont.Render(Jersey15, bannerLabel.Text, bannerLabel, { Name = "Word", Color = bannerLabel.TextColor3 })
	end
	fire.Visible = false
	badge.Visible = false
	lostLabel.Visible = false
	feverGui.Visible = false
	RunService.RenderStepped:Connect(step)
end

return ComboController
