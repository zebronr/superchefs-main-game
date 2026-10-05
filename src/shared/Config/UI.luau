--!strict

local UI = {
	-- Patience and order-timer bar colors, blended green -> yellow -> red as time runs out.
	Patience = {
		Green = Color3.fromRGB(63, 111, 34),
		Yellow = Color3.fromRGB(184, 180, 46),
		Red = Color3.fromRGB(163, 37, 46),
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
