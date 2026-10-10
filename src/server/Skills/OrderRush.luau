--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CustomerService = require(script.Parent.Parent.Services.CustomerService)
local CharacterService = require(script.Parent.Parent.Services.CharacterService)
local Types = require(script.Parent.Types)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local RushConfig = Config.Skills.OrderRush
local Attribute = Config.Skills.Attribute
local SkillEffects = require(Shared:WaitForChild("Util"):WaitForChild("SkillEffects"))

-- Alien (working name): Order Rush. See docs/design/characters/alien-order-rush.md.
-- The chain is data on the character (start, origin, stops); clients draw the afterimages.
-- The Alien itself never moves: the owning client hides and roots it for the chain.
local threads: { [Player]: { thread } } = {}

local function clear(player: Player, character: Model): ()
	local list = threads[player]
	threads[player] = nil
	if list ~= nil then
		for _, thread in list do
			if thread ~= coroutine.running() then
				pcall(task.cancel, thread)
			end
		end
	end
	character:SetAttribute(Attribute.RushStartedAt, nil)
	character:SetAttribute(Attribute.RushOrigin, nil)
	character:SetAttribute(Attribute.RushStops, nil)
	CharacterService.SetPhased(character, false)
end

local OrderRush: Types.InstantSkill = {
	RequiresEmptyHands = true,
	AllowedWhileUsing = false,
	Use = function(ctx: Types.Context, startedAt: number): boolean
		local character = ctx.Character
		local root = character:FindFirstChild("HumanoidRootPart")
		if root == nil or not root:IsA("BasePart") then
			return false
		end
		local targets = SkillEffects.RushTargets()
		if #targets == 0 then
			return false
		end
		local origin = root.Position
		local stops: { SkillEffects.RushStop } = {}
		local customers: { Model } = {}
		local previous = origin
		for _, customer in targets do
			local stop = SkillEffects.StopPosition(customer, previous)
			if stop ~= nil then
				table.insert(stops, stop)
				table.insert(customers, customer)
				previous = stop.Position
			end
		end
		if #stops == 0 then
			return false
		end

		ctx.SetState("Active")
		character:SetAttribute(Attribute.RushStartedAt, startedAt)
		character:SetAttribute(Attribute.RushOrigin, origin)
		character:SetAttribute(Attribute.RushStops, SkillEffects.EncodeStops(stops))
		CharacterService.SetPhased(character, true)

		local player = ctx.Player
		local list: { thread } = {}
		threads[player] = list
		local now = workspace:GetServerTimeNow()
		for index, customer in customers do
			table.insert(
				list,
				task.delay(math.max(0, startedAt + SkillEffects.RushTakeTime(index) - now), function(): ()
					if ctx.IsCurrent() then
						CustomerService.TakeOrderFor(customer)
					end
				end)
			)
		end
		table.insert(
			list,
			task.delay(math.max(0, startedAt + SkillEffects.RushDuration(#stops) - now), function(): ()
				if ctx.IsCurrent() then
					clear(player, character)
					ctx.Finish(RushConfig.Cooldown)
				end
			end)
		)
		return true
	end,
	Cancel = function(ctx: Types.Context): ()
		clear(ctx.Player, ctx.Character)
	end,
}

return OrderRush
