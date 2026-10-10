--!strict

local UI = {
	-- Shows PlayerGui.SkillHUD (the desktop skill button). Off for now; the key and mobile button still work.
	ShowSkillHud = false,
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
	-- Order ticket icon tints when the ticket leaves.
	Ticket = {
		-- Order served in time.
		Success = Color3.fromRGB(150, 210, 166),
		-- Order expired: icons flash between this and white.
		Fail = Color3.fromRGB(255, 124, 124),
	},
	Coins = {
		-- Coin counter tint while it pops after a gain.
		Pop = Color3.fromRGB(14, 255, 14),
		-- Floating "+N" text color.
		Notification = Color3.fromRGB(47, 255, 10),
	},
}

return UI
