--!strict

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CustomerService = require(script.Parent.Parent.Services.CustomerService)
local InteractionService = require(script.Parent.Parent.Services.InteractionService)
local TeamService = require(script.Parent.Parent.Services.TeamService)
local Types = require(script.Parent.Types)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Tuning = Config.Skills.BearToss
local Attribute = Config.Skills.Attribute
local Tags = require(Shared:WaitForChild("Tags"))
local Util = Shared:WaitForChild("Util")
local TossPath = require(Util:WaitForChild("TossPath"))

-- Bear: Bear Toss. See docs/design/characters/bear-toss.md.
-- Aim grabs the nearest free teammate in front (TossHeldBy on them) and the release throws them to the landing the
-- client picked, after checking it: the flight is TossStartedAt, TossFrom and TossTo on the thrown character, which
-- its own client flies along and every other client draws. With no teammate in reach, a dine-and-dasher in reach
-- is caught on the spot and flung.
local BearToss = {}

BearToss.HoldTimeout = Tuning.HoldLimit + Tuning.HoldLimitMargin

type Hold = { Thrown: Player, Character: Model }

-- Who each Bear holds overhead; nil for a dasher catch.
local holds: { [Player]: Hold } = {}
-- The flight timer per thrown character, so a newer throw replaces it.
local flights: { [Model]: thread } = {}

local function rootOf(character: Model?): BasePart?
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	return if root ~= nil and root:IsA("BasePart") then root else nil
end

local function alive(character: Model?): boolean
	local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	return humanoid ~= nil and humanoid.Health > 0
end

-- Whether `point` is within reach of the Bear's grab, in front of it. Returns the flat distance.
local function inGrab(root: BasePart, point: Vector3): number?
	local offset = Vector3.new(point.X - root.Position.X, 0, point.Z - root.Position.Z)
	local distance = offset.Magnitude
	if distance > Tuning.GrabReach + Tuning.GrabMargin then
		return nil
	end
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	-- Right on top of the Bear counts as in front.
	if distance > 1 and look.Magnitude > 1e-3 then
		local angle = math.deg(math.acos(math.clamp(look.Unit:Dot(offset.Unit), -1, 1)))
		if angle > Tuning.GrabAngle then
			return nil
		end
	end
	return distance
end

-- The nearest teammate the Bear can grab: alive, not busy (chopping, washing, using a superskill or already tossed).
local function findTeammate(player: Player, root: BasePart): (Player?, Model?)
	local team = TeamService.GetTeam(player)
	local best: Player? = nil
	local bestCharacter: Model? = nil
	local bestDistance = math.huge
	for _, other in Players:GetPlayers() do
		local character = other.Character
		local otherRoot = rootOf(character)
		if
			other == player
			or character == nil
			or otherRoot == nil
			or TeamService.GetTeam(other) ~= team
			or character:GetAttribute("CustomCharacter") ~= true
			or not alive(character)
			or character:GetAttribute(Attribute.State) ~= nil
			or InteractionService.IsUsing(other)
			or TossPath.Busy(character)
		then
			continue
		end
		local distance = inGrab(root, otherRoot.Position)
		if distance ~= nil and distance < bestDistance then
			best = other
			bestCharacter = character
			bestDistance = distance
		end
	end
	return best, bestCharacter
end

-- The nearest running dine-and-dasher in reach.
local function findRunner(root: BasePart): Model?
	local best: Model? = nil
	local bestDistance = math.huge
	for _, runnerRoot in CollectionService:GetTagged(Tags.ClassTag(Tags.Runner)) do
		local model = runnerRoot.Parent
		if not runnerRoot:IsA("BasePart") or model == nil or not model:IsA("Model") then
			continue
		end
		local distance = inGrab(root, runnerRoot.Position)
		if distance ~= nil and distance < bestDistance then
			best = model
			bestDistance = distance
		end
	end
	return best
end

-- Puts a held teammate down: their own client drops them in front of the Bear.
local function putDown(player: Player): ()
	local hold = holds[player]
	holds[player] = nil
	if hold ~= nil and TossPath.HeldBy(hold.Character) == player.UserId then
		hold.Character:SetAttribute(Attribute.TossHeldBy, nil)
	end
end

local function clearFlight(character: Model): ()
	flights[character] = nil
	character:SetAttribute(Attribute.TossStartedAt, nil)
	character:SetAttribute(Attribute.TossFrom, nil)
	character:SetAttribute(Attribute.TossTo, nil)
end

local function throw(character: Model, from: Vector3, to: Vector3): ()
	local timer = flights[character]
	if timer ~= nil then
		pcall(task.cancel, timer)
	end
	local startedAt = workspace:GetServerTimeNow()
	character:SetAttribute(Attribute.TossFrom, from)
	character:SetAttribute(Attribute.TossTo, to)
	character:SetAttribute(Attribute.TossStartedAt, startedAt)
	-- Cleared a moment after the landing, so a late client still finishes the flight from the data.
	flights[character] = task.delay(Tuning.FlightTime + Tuning.GetUpTime + 1, function(): ()
		if character:GetAttribute(Attribute.TossStartedAt) == startedAt then
			clearFlight(character)
		end
	end)
end

function BearToss.Aim(ctx: Types.Context): boolean
	local root = rootOf(ctx.Character)
	if root == nil or TossPath.Busy(ctx.Character) then
		return false
	end
	local thrown, character = findTeammate(ctx.Player, root)
	if thrown ~= nil and character ~= nil then
		holds[ctx.Player] = { Thrown = thrown, Character = character }
		character:SetAttribute(Attribute.TossHeldBy, ctx.Player.UserId)
		return true
	end
	local runner = findRunner(root)
	if runner ~= nil and CustomerService.CatchRunner(runner, ctx.Player, true) then
		-- The client releases right away; the release (or the hold timeout) ends the use.
		holds[ctx.Player] = nil
		return true
	end
	return false
end

function BearToss.Release(ctx: Types.Context, direction: Vector3?, _target: Instance?): ()
	local hold = holds[ctx.Player]
	if hold == nil then
		-- A dasher catch: the throw follow-through, then the cooldown.
		ctx.SetState("Active")
		task.delay(Tuning.ThrowTime, function(): ()
			if ctx.IsCurrent() then
				ctx.Finish(Tuning.RunnerCooldown)
			end
		end)
		return
	end
	local root = rootOf(ctx.Character)
	local character = hold.Character
	local valid = direction ~= nil
		and root ~= nil
		and hold.Thrown.Character == character
		and alive(character)
		and TossPath.HeldBy(character) == ctx.Player.UserId
	if not valid or direction == nil or root == nil then
		putDown(ctx.Player)
		ctx.Finish(Tuning.CancelCooldown)
		return
	end
	local from = root.Position + Vector3.yAxis * Tuning.LiftHeight
	local queries = TossPath.Queries(character)
	if queries == nil or not TossPath.Valid(root.Position, from, direction, queries, Tuning.RangeMargin) then
		putDown(ctx.Player)
		ctx.Finish(Tuning.CancelCooldown)
		return
	end
	holds[ctx.Player] = nil
	character:SetAttribute(Attribute.TossHeldBy, nil)
	throw(character, from, direction)
	-- The cooldown counts from the landing; the Bear itself is free right away.
	ctx.Finish(Tuning.Cooldown + Tuning.FlightTime)
end

-- Sturdy: SkillService never interrupts a Bear, so this only runs if that changes.
function BearToss.Interrupt(ctx: Types.Context): ()
	putDown(ctx.Player)
end

function BearToss.Cancel(ctx: Types.Context): ()
	putDown(ctx.Player)
end

return BearToss :: Types.Skill
