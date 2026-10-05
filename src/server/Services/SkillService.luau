--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DeepFreeze = require(script.Parent.Parent.Skills.DeepFreeze)
local Hustle = require(script.Parent.Parent.Skills.Hustle)
local OrderRush = require(script.Parent.Parent.Skills.OrderRush)
local TongueGrab = require(script.Parent.Parent.Skills.TongueGrab)
local Types = require(script.Parent.Parent.Skills.Types)
local CarryService = require(script.Parent.CarryService)
local InteractionService = require(script.Parent.InteractionService)
local ThrowService = require(script.Parent.ThrowService)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local SkillsConfig = Config.Skills
local Attribute = SkillsConfig.Attribute
local Net = require(Shared:WaitForChild("Net"))

-- Owns the "Skill" remote and every player's super-skill state. The skills themselves live in
-- `Skills/`; to add one, write the module, register it here and map a character to it in Config.Skills.ByCharacter.
local SkillService = {}

-- Skill modules by the names used in Config.Skills.ByCharacter.
local skills: { [string]: Types.Skill } = {
	TongueGrab = TongueGrab,
}

-- Press-once skills, used through the "Use" action.
local instantSkills: { [string]: Types.InstantSkill } = {
	Hustle = Hustle,
	DeepFreeze = DeepFreeze,
	OrderRush = OrderRush,
}

-- Runtimes hold a Skill; an instant skill runs behind this stand-in, which only forwards Cancel.
-- Instant skills never reach "Aiming", so Release, Interrupt and the hold timer never apply to them.
local function asSkill(instant: Types.InstantSkill): Types.Skill
	return {
		HoldTimeout = 0,
		Aim = function(_ctx: Types.Context): boolean
			return false
		end,
		Release = function(_ctx: Types.Context, _direction: Vector3?, _target: Instance?): () end,
		Interrupt = instant.Cancel,
		Cancel = instant.Cancel,
	}
end

local instantAdapters: { [Types.InstantSkill]: Types.Skill } = {}
for _, instant in instantSkills do
	instantAdapters[instant] = asSkill(instant)
end

type Runtime = {
	Player: Player,
	Skill: Types.Skill,
	Ctx: Types.Context,
	State: Types.State,
	AimStartedAt: number,
	Timer: thread?,
	Ended: boolean,
}

local runtimes: { [Player]: Runtime } = {}
-- Studio test mode (Config.Skills.StudioTestKeys): the client names the skill, and there are no cooldowns.
local testMode = RunService:IsStudio() and SkillsConfig.StudioTestKeys ~= nil
local requestWindows: { [Player]: { Start: number, Count: number } } = {}

local function consumeRequest(player: Player): boolean
	local now = os.clock()
	local window = requestWindows[player]
	if window == nil or now - window.Start >= SkillsConfig.RequestWindow then
		requestWindows[player] = { Start = now, Count = 1 }
		return true
	end
	if window.Count >= SkillsConfig.MaxRequests then
		return false
	end
	window.Count += 1
	return true
end

-- `requested` is the skill the client named; only test mode honours it.
local function skillName(character: Model, requested: unknown): string?
	if testMode and typeof(requested) == "string" then
		return requested
	end
	local model = character:GetAttribute(Attribute.CharacterModel)
	return if typeof(model) == "string" then SkillsConfig.ByCharacter[model] else nil
end

local function skillFor(character: Model, requested: unknown): Types.Skill?
	local name = skillName(character, requested)
	return if name ~= nil then skills[name] else nil
end

local function instantFor(character: Model, requested: unknown): Types.InstantSkill?
	local name = skillName(character, requested)
	return if name ~= nil then instantSkills[name] else nil
end

local function cancelTimer(runtime: Runtime): ()
	local timer = runtime.Timer
	if timer ~= nil then
		runtime.Timer = nil
		task.cancel(timer)
	end
end

-- Ends a use without a cooldown. `cancel` tells the skill to drop everything first.
local function teardown(runtime: Runtime, callback: (Types.Context) -> ()): ()
	if runtimes[runtime.Player] ~= runtime then
		return
	end
	runtimes[runtime.Player] = nil
	runtime.Ended = true
	cancelTimer(runtime)
	local success, message = pcall(function(): boolean
		callback(runtime.Ctx)
		return true
	end)
	if not success then
		warn(`Skill cleanup for {runtime.Player.Name} failed: {message}`)
	end
	runtime.Ctx.Character:SetAttribute(Attribute.State, nil)
end

local function reset(player: Player): ()
	local runtime = runtimes[player]
	if runtime ~= nil then
		teardown(runtime, runtime.Skill.Cancel)
	end
end

local function finish(runtime: Runtime, cooldown: number): ()
	if runtimes[runtime.Player] ~= runtime then
		return
	end
	runtimes[runtime.Player] = nil
	runtime.Ended = true
	cancelTimer(runtime)
	if testMode then
		cooldown = 0
	end
	local character = runtime.Ctx.Character
	character:SetAttribute(Attribute.ReadyAt, workspace:GetServerTimeNow() + cooldown)
	character:SetAttribute(Attribute.Cooldown, cooldown)
	character:SetAttribute(Attribute.State, nil)
end

local function release(runtime: Runtime, direction: Vector3?, target: Instance?): ()
	if runtimes[runtime.Player] ~= runtime or runtime.State ~= "Aiming" then
		return
	end
	cancelTimer(runtime)
	local success, message = pcall(function(): boolean
		runtime.Skill.Release(runtime.Ctx, direction, target)
		return true
	end)
	if not success then
		warn(`Skill release for {runtime.Player.Name} failed: {message}`)
		reset(runtime.Player)
	end
end

local function interrupt(player: Player): ()
	local runtime = runtimes[player]
	if runtime == nil or runtime.State ~= "Aiming" then
		return
	end
	teardown(runtime, runtime.Skill.Interrupt)
	Net.Event("Skill"):FireClient(player, "Interrupted")
end

local function newContext(player: Player, character: Model): (Types.Context, Runtime)
	local runtime: Runtime
	local ctx: Types.Context = {
		Player = player,
		Character = character,
		SetState = function(state: Types.State): ()
			if runtimes[player] == runtime then
				runtime.State = state
				character:SetAttribute(Attribute.State, state)
			end
		end,
		Finish = function(cooldown: number): ()
			finish(runtime, cooldown)
		end,
		IsCurrent = function(): boolean
			return runtimes[player] == runtime
		end,
	}
	runtime = {
		Player = player,
		Skill = nil :: any,
		Ctx = ctx,
		State = "Aiming",
		AimStartedAt = 0,
		Timer = nil,
		Ended = false,
	}
	return ctx, runtime
end

-- Starts (or restarts, on a target switch) the hold limit. No release in time cancels the aim.
local function restartHold(runtime: Runtime): ()
	cancelTimer(runtime)
	runtime.AimStartedAt = workspace:GetServerTimeNow()
	runtime.Timer = task.delay(runtime.Skill.HoldTimeout, function(): ()
		runtime.Timer = nil
		release(runtime, nil, nil)
	end)
end

local function aim(player: Player, requested: unknown): ()
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if
		character == nil
		or character:GetAttribute("CustomCharacter") ~= true
		or humanoid == nil
		or humanoid.Health <= 0
		or root == nil
	then
		return
	end
	local skill = skillFor(character, requested)
	local readyAt = character:GetAttribute(Attribute.ReadyAt)
	local ready = typeof(readyAt) ~= "number" or workspace:GetServerTimeNow() >= readyAt
	if runtimes[player] ~= nil then
		return
	end
	if
		skill == nil
		or not ready
		or CarryService.GetHeld(player) ~= nil
		or InteractionService.IsUsing(player)
	then
		-- The client is already aiming locally; tell it to stop.
		Net.Event("Skill"):FireClient(player, "Interrupted")
		return
	end

	local ctx, runtime = newContext(player, character)
	runtime.Skill = skill
	runtimes[player] = runtime
	local success, accepted = pcall(skill.Aim, ctx)
	if not success or not accepted then
		if not success then
			warn(`Skill aim for {player.Name} failed: {accepted}`)
		end
		runtimes[player] = nil
		runtime.Ended = true
		Net.Event("Skill"):FireClient(player, "Interrupted")
		return
	end
	character:SetAttribute(Attribute.State, "Aiming")
	restartHold(runtime)
end

-- An instant skill. The client already plays it locally, so every refusal tells it to roll back.
local function use(player: Player, requested: unknown): ()
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if
		character == nil
		or character:GetAttribute("CustomCharacter") ~= true
		or humanoid == nil
		or humanoid.Health <= 0
		or character:FindFirstChild("HumanoidRootPart") == nil
	then
		Net.Event("Skill"):FireClient(player, "Interrupted")
		return
	end
	local instant = instantFor(character, requested)
	local now = workspace:GetServerTimeNow()
	local readyAt = character:GetAttribute(Attribute.ReadyAt)
	local ready = typeof(readyAt) ~= "number" or now >= readyAt
	if
		instant == nil
		or runtimes[player] ~= nil
		or not ready
		or (instant.RequiresEmptyHands and CarryService.GetHeld(player) ~= nil)
		or (not instant.AllowedWhileUsing and InteractionService.IsUsing(player))
	then
		Net.Event("Skill"):FireClient(player, "Interrupted")
		return
	end

	local ctx, runtime = newContext(player, character)
	runtime.Skill = instantAdapters[instant]
	runtime.State = "Active"
	runtimes[player] = runtime
	local startedAt = now - math.min(player:GetNetworkPing() / 2, SkillsConfig.MaxLagCompensation)
	local success, accepted = pcall(instant.Use, ctx, startedAt)
	if not success or not accepted then
		if not success then
			warn(`Skill use for {player.Name} failed: {accepted}`)
			pcall(instant.Cancel, ctx)
		end
		if runtimes[player] == runtime then
			runtimes[player] = nil
			runtime.Ended = true
			character:SetAttribute(Attribute.State, nil)
		end
		Net.Event("Skill"):FireClient(player, "Interrupted")
	end
end

local function onRequest(player: Player, action: unknown, payload: unknown, hint: unknown): ()
	if not consumeRequest(player) then
		return
	end
	if action == "Aim" then
		aim(player, payload)
		return
	elseif action == "Use" then
		use(player, payload)
		return
	end
	local runtime = runtimes[player]
	if runtime == nil or runtime.State ~= "Aiming" then
		return
	end
	if action == "Release" then
		local late = workspace:GetServerTimeNow() - runtime.AimStartedAt > runtime.Skill.HoldTimeout
		local direction = if not late and typeof(payload) == "Vector3" then payload else nil
		-- A late release or a missing direction cancels the aim.
		release(runtime, direction, if typeof(hint) == "Instance" then hint else nil)
	elseif action == "Retarget" then
		restartHold(runtime)
	elseif action == "Timeout" then
		release(runtime, nil, nil)
	end
end

local function watchCharacter(player: Player, character: Model): ()
	reset(player)
	task.spawn(function(): ()
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid and humanoid:IsA("Humanoid") then
			humanoid.Died:Connect(function(): ()
				reset(player)
			end)
		end
	end)
end

local function watchPlayer(player: Player): ()
	player.CharacterAdded:Connect(function(character: Model): ()
		watchCharacter(player, character)
	end)
	player.CharacterRemoving:Connect(function(): ()
		reset(player)
	end)
	local character = player.Character
	if character ~= nil then
		watchCharacter(player, character)
	end
end

function SkillService.Start(_self: typeof(SkillService)): ()
	Net.Event("Skill").OnServerEvent:Connect(onRequest)
	Players.PlayerAdded:Connect(watchPlayer)
	Players.PlayerRemoving:Connect(function(player: Player): ()
		reset(player)
		requestWindows[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end

	ThrowService.SetInterceptor(function(from: Vector3, to: Vector3): Player?
		for _, skill in skills do
			local find = skill.FindIntercept
			local player = if find ~= nil then find(from, to) else nil
			if player ~= nil then
				return player
			end
		end
		return nil
	end, function(player: Player, item, position: Vector3): ()
		local runtime = runtimes[player]
		local take = if runtime ~= nil then runtime.Skill.TakeThrown else nil
		if runtime == nil or take == nil then
			item.Part.Anchored = false
			return
		end
		take(runtime.Ctx, item, position)
	end)
	-- A thrown item that hits or is caught by a player interrupts their aim.
	ThrowService.SetCharacterHitHandler(interrupt)
end

return SkillService
