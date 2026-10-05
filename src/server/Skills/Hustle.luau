--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(script.Parent.Types)

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local HustleConfig = Config.Skills.Hustle
local Attribute = Config.Skills.Attribute

-- Bill: Hustle. See docs/design/characters/bill-hustle.md.
-- The effect is just HustleUntil on the character: SkillEffects reads it for walk, chop and wash speed.
local Hustle: Types.InstantSkill = {
	RequiresEmptyHands = false,
	AllowedWhileUsing = true,
	Use = function(ctx: Types.Context, startedAt: number): boolean
		ctx.Character:SetAttribute(Attribute.HustleUntil, startedAt + HustleConfig.Duration)
		-- The cooldown counts from the end, so the use is over (and Bill free to act) right away.
		ctx.Finish(HustleConfig.Duration + HustleConfig.Cooldown)
		return true
	end,
	Cancel = function(ctx: Types.Context): ()
		ctx.Character:SetAttribute(Attribute.HustleUntil, nil)
	end,
}

return Hustle
