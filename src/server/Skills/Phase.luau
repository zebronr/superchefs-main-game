--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharacterService = require(script.Parent.Parent.Services.CharacterService)
local Types = require(script.Parent.Types)

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local PhaseConfig = Config.Skills.Phase
local Attribute = Config.Skills.Attribute

-- Ghost: Phase. See docs/design/characters/ghost-phase.md.
-- The effect is PhaseUntil on the character: while it runs, the character's parts are in the GhostPhase group (only
-- the floor, the map edge and player barriers stop it), InteractionService refuses interacting and throwing, and
-- thrown items fly through it. The owning client pops the Ghost out of anything it ends inside.
local timers: { [Model]: thread } = {}

local function stop(character: Model): ()
	local timer = timers[character]
	timers[character] = nil
	if timer ~= nil and timer ~= coroutine.running() then
		pcall(task.cancel, timer)
	end
	character:SetAttribute(Attribute.PhaseUntil, nil)
	CharacterService.RefreshGroup(character)
end

local Phase: Types.InstantSkill = {
	RequiresEmptyHands = false,
	AllowedWhileUsing = false,
	Use = function(ctx: Types.Context, startedAt: number): boolean
		local character = ctx.Character
		local phaseUntil = startedAt + PhaseConfig.Duration
		local timer = timers[character]
		if timer ~= nil then
			pcall(task.cancel, timer)
		end
		character:SetAttribute(Attribute.PhaseUntil, phaseUntil)
		CharacterService.RefreshGroup(character)
		timers[character] = task.delay(math.max(phaseUntil - workspace:GetServerTimeNow(), 0), stop, character)
		-- The cooldown counts from the end, so the use is over right away (the Ghost moves and dashes freely).
		ctx.Finish(PhaseConfig.Duration + PhaseConfig.Cooldown)
		return true
	end,
	Cancel = function(ctx: Types.Context): ()
		stop(ctx.Character)
	end,
}

return Phase
