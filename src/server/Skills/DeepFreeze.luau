--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(script.Parent.Types)

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local FreezeConfig = Config.Skills.DeepFreeze
local Attribute = Config.Skills.Attribute

-- Penguin: Deep Freeze. See docs/design/characters/penguin-deep-freeze.md.
-- The circle is three attributes on the Penguin; FreezeService pauses what is inside, clients draw it.
local function clear(character: Model): ()
	character:SetAttribute(Attribute.FreezeCenter, nil)
	character:SetAttribute(Attribute.FreezeStartedAt, nil)
	character:SetAttribute(Attribute.FreezeUntil, nil)
end

local DeepFreeze: Types.InstantSkill = {
	RequiresEmptyHands = false,
	AllowedWhileUsing = false,
	Use = function(ctx: Types.Context, startedAt: number): boolean
		local character = ctx.Character
		local root = character:FindFirstChild("HumanoidRootPart")
		if root == nil or not root:IsA("BasePart") then
			return false
		end
		local freezeUntil = startedAt + FreezeConfig.Duration
		character:SetAttribute(Attribute.FreezeCenter, root.Position)
		character:SetAttribute(Attribute.FreezeStartedAt, startedAt)
		character:SetAttribute(Attribute.FreezeUntil, freezeUntil)
		ctx.Finish(FreezeConfig.Duration + FreezeConfig.Cooldown)
		task.delay(math.max(0, freezeUntil - workspace:GetServerTimeNow()), function(): ()
			-- A newer circle replaced this one's attributes; leave it.
			if character:GetAttribute(Attribute.FreezeUntil) == freezeUntil then
				clear(character)
			end
		end)
		return true
	end,
	Cancel = function(ctx: Types.Context): ()
		clear(ctx.Character)
	end,
}

return DeepFreeze
