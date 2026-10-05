--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Item = require(script.Parent.Parent.Classes.Item)
local CookingTool = require(script.Parent.Parent.Classes.CookingTool)
local CarryService = require(script.Parent.Parent.Services.CarryService)
local InteractionService = require(script.Parent.Parent.Services.InteractionService)
local Types = require(script.Parent.Types)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local TongueConfig = Config.Skills.TongueGrab
local Attribute = Config.Skills.Attribute
local FireAttribute = Config.Interaction.Cooking.FireAttribute
local ThrowConfig = Config.Interaction.Throw
local Tags = require(Shared:WaitForChild("Tags"))
local TongueTargeting = require(Shared:WaitForChild("Util"):WaitForChild("TongueTargeting"))

-- Gecko: Tongue Grab. See docs/design/characters/gecko-tongue-grab.md.
local TongueGrab = {}

type Run = {
	Ctx: Types.Context,
	Phase: "Extending" | "Retracting",
	StartedAt: number,
	-- Where the tongue reaches while extending.
	Tip: Vector3,
	-- The item the tongue is going for (nil on a whiff).
	Target: Item.Item?,
	-- The item flying back, if any, and where it started.
	Item: Item.Item?,
	From: Vector3,
	Intercepted: boolean,
	ItemDestroyed: RBXScriptConnection?,
}

local runs: { [Player]: Run } = {}

TongueGrab.HoldTimeout = TongueConfig.HoldLimit + TongueConfig.HoldLimitMargin

-- Closest distance between the segments start1-end1 and start2-end2.
local function segmentDistance(start1: Vector3, end1: Vector3, start2: Vector3, end2: Vector3): number
	local epsilon = 1e-6
	local d1 = end1 - start1
	local d2 = end2 - start2
	local r = start1 - start2
	local a = d1:Dot(d1)
	local e = d2:Dot(d2)
	local f = d2:Dot(r)
	local s = 0
	local t = 0
	if a <= epsilon and e <= epsilon then
		return r.Magnitude
	elseif a <= epsilon then
		t = math.clamp(f / e, 0, 1)
	else
		local c = d1:Dot(r)
		if e <= epsilon then
			s = math.clamp(-c / a, 0, 1)
		else
			local b = d1:Dot(d2)
			local denominator = a * e - b * b
			if denominator > epsilon then
				s = math.clamp((b * f - c * e) / denominator, 0, 1)
			end
			t = (b * s + f) / e
			if t < 0 then
				t = 0
				s = math.clamp(-c / a, 0, 1)
			elseif t > 1 then
				t = 1
				s = math.clamp((b - c) / a, 0, 1)
			end
		end
	end
	return ((start1 + d1 * s) - (start2 + d2 * t)).Magnitude
end

local function rootOf(character: Model): BasePart?
	local root = character:FindFirstChild("HumanoidRootPart")
	return if root ~= nil and root:IsA("BasePart") then root else nil
end

local BLOCKING_TAGS = { Tags.Locked, Tags.FireLocked, Tags.Grabbed, Tags.Projectile }

local function hasBlockingTag(instance: Instance): boolean
	for _, tag in BLOCKING_TAGS do
		if CollectionService:HasTag(instance, tag) then
			return true
		end
	end
	return false
end

-- Whether the tongue could take this item right now.
local function isGrabbable(item: Item.Item): boolean
	local part = item.Part
	if item.Holder ~= nil or not part:IsDescendantOf(workspace) or hasBlockingTag(part) then
		return false
	end
	-- A burning pot.
	if part:GetAttribute(FireAttribute) ~= nil and CookingTool.Cast(item) ~= nil then
		return false
	end
	if item.Surface == nil then
		return not Tags.IsInteractionDisabled(part)
	end
	-- A resting item is interaction-disabled by design (you use the station), so the station decides.
	local station = InteractionService.StationOf(item)
	return station ~= nil and not station:IsLocked()
end

local function findTarget(origin: Vector3, direction: Vector3, params: RaycastParams): Item.Item?
	local candidates: { BasePart } = {}
	local byPart: { [BasePart]: Item.Item } = {}
	for _, bound in Item.GetAll() do
		local item: Item.Item = bound :: any
		if isGrabbable(item) then
			table.insert(candidates, item.Part)
			byPart[item.Part] = item
		end
	end
	local part = TongueTargeting.Find(origin, direction, candidates, params)
	return if part ~= nil then byPart[part] else nil
end

local function clearTongue(character: Model): ()
	character:SetAttribute(Attribute.TongueState, nil)
	character:SetAttribute(Attribute.TongueStartedAt, nil)
	character:SetAttribute(Attribute.TongueTip, nil)
end

local function setTongue(run: Run, state: "Extending" | "Retracting", tip: Vector3?, backdate: number?): ()
	local character = run.Ctx.Character
	run.Phase = state
	run.StartedAt = workspace:GetServerTimeNow() - (backdate or 0)
	character:SetAttribute(Attribute.TongueState, state)
	character:SetAttribute(Attribute.TongueStartedAt, run.StartedAt)
	if tip ~= nil then
		character:SetAttribute(Attribute.TongueTip, tip)
	end
end

local function clearGrab(part: BasePart): ()
	CollectionService:RemoveTag(part, Tags.Grabbed)
	part:SetAttribute(Attribute.GrabFrom, nil)
	part:SetAttribute(Attribute.GrabStartedAt, nil)
	part:SetAttribute(Attribute.GrabByUserId, nil)
end

-- Where the flying item is now on its way to the mouth.
local function flyingPosition(run: Run): Vector3
	local alpha = TongueTargeting.RetractAlpha(workspace:GetServerTimeNow() - run.StartedAt)
	return run.From:Lerp(TongueTargeting.Mouth(run.Ctx.Character), alpha)
end

local function disconnectItem(run: Run): ()
	local connection = run.ItemDestroyed
	if connection ~= nil then
		run.ItemDestroyed = nil
		connection:Disconnect()
	end
end

-- Drops the flying item where it is and gives it back to the world.
local function dropFlying(run: Run, position: Vector3): ()
	local item = run.Item
	if item == nil then
		return
	end
	run.Item = nil
	disconnectItem(run)
	local part = item.Part
	clearGrab(part)
	part.CFrame = CFrame.new(position) * part.CFrame.Rotation
	part.Massless = false
	part.CanCollide = true
	part.Anchored = false
	pcall(function()
		part:SetNetworkOwner(nil)
	end)
	Tags.SetInteractionDisabled(part, false)
end

local function endRun(run: Run, cooldown: number): ()
	local player = run.Ctx.Player
	if runs[player] ~= run then
		return
	end
	runs[player] = nil
	clearTongue(run.Ctx.Character)
	run.Ctx.Finish(cooldown)
end

local function isCurrent(run: Run): boolean
	return runs[run.Ctx.Player] == run and run.Ctx.IsCurrent()
end

-- Sends `item` flying from `from` to the mouth; it lands in the hands when the tongue is back.
local function retractWith(run: Run, item: Item.Item, from: Vector3): ()
	local ctx = run.Ctx
	local part = item.Part
	run.Item = item
	run.From = from
	setTongue(run, "Retracting", nil)

	part.CFrame = CFrame.new(from) * part.CFrame.Rotation
	part.AssemblyLinearVelocity = Vector3.zero
	part.AssemblyAngularVelocity = Vector3.zero
	part.Anchored = true
	Tags.SetInteractionDisabled(part, true)
	part:SetAttribute(Attribute.GrabFrom, from)
	part:SetAttribute(Attribute.GrabStartedAt, run.StartedAt)
	part:SetAttribute(Attribute.GrabByUserId, ctx.Player.UserId)
	CollectionService:AddTag(part, Tags.Grabbed)
	-- A map reset can destroy the item mid-flight: just clean up.
	run.ItemDestroyed = part.Destroying:Connect(function(): ()
		run.Item = nil
		endRun(run, 0)
	end)

	task.delay(TongueConfig.RetractTime, function(): ()
		if not isCurrent(run) or run.Item ~= item then
			return
		end
		disconnectItem(run)
		clearGrab(part)
		if not CarryService.Pickup(ctx.Player, item) then
			-- Hands are somehow busy: leave it at the mouth instead of losing it.
			dropFlying(run, TongueTargeting.Mouth(ctx.Character))
		end
		run.Item = nil
		endRun(run, TongueConfig.Cooldown)
	end)
end

local function retractEmpty(run: Run): ()
	setTongue(run, "Retracting", nil)
	task.delay(TongueConfig.RetractTime, function(): ()
		if isCurrent(run) and run.Item == nil then
			endRun(run, TongueConfig.MissCooldown)
		end
	end)
end

local function finishExtend(run: Run): ()
	if not isCurrent(run) or run.Phase ~= "Extending" or run.Intercepted then
		return
	end
	local target = run.Target
	if target == nil or not isGrabbable(target) then
		retractEmpty(run)
		return
	end
	local player = run.Ctx.Player
	local from = target.Part.Position
	local taken = InteractionService.TakeFor(player, target)
	if taken == nil then
		retractEmpty(run)
		return
	end
	-- No physics side effects: the item leaves the hands and flies back on its own.
	CarryService.Release(player)
	retractWith(run, taken, from)
end

function TongueGrab.Aim(_ctx: Types.Context): boolean
	return true
end

function TongueGrab.Release(ctx: Types.Context, direction: Vector3?, hint: Instance?): ()
	if direction == nil then
		ctx.Finish(TongueConfig.CancelCooldown)
		return
	end
	local root = rootOf(ctx.Character)
	if root == nil then
		ctx.Finish(TongueConfig.MissCooldown)
		return
	end
	local aim = TongueTargeting.Flat(direction)
	if aim == Vector3.zero then
		aim = TongueTargeting.Flat(root.CFrame.LookVector)
	end
	local mouth = TongueTargeting.Mouth(ctx.Character)
	local origin = TongueTargeting.AimOrigin(ctx.Character)
	local params = TongueTargeting.LosParams({})
	local target: Item.Item? = nil
	if hint ~= nil then
		local item = Item.Get(hint)
		if item ~= nil and isGrabbable(item) and TongueTargeting.Reachable(origin, item.Part, params) then
			local bearing = TongueTargeting.Flat(item.Part.Position - origin)
			if bearing ~= Vector3.zero and math.deg(math.acos(math.clamp(aim:Dot(bearing), -1, 1))) <= TongueConfig.HintMaxAngle then
				target = item
			end
		end
	end
	if target == nil then
		target = findTarget(origin, aim, params)
	end

	ctx.SetState("Active")
	local run: Run = {
		Ctx = ctx,
		Phase = "Extending",
		StartedAt = 0,
		Tip = if target ~= nil then target.Part.Position else TongueTargeting.WhiffTip(mouth, aim, params),
		Target = target,
		Item = nil,
		From = mouth,
		Intercepted = false,
		ItemDestroyed = nil,
	}
	runs[ctx.Player] = run
	local pingOk, ping = pcall(function(): number
		return ctx.Player:GetNetworkPing()
	end)
	local compensation = if pingOk then math.min(ping / 2, TongueConfig.MaxLagCompensation) else 0
	setTongue(run, "Extending", run.Tip, compensation)
	task.delay(TongueConfig.ExtendTime - compensation, function(): ()
		local success, message = pcall(function(): boolean
			finishExtend(run)
			return true
		end)
		if not success then
			warn(`Tongue grab for {ctx.Player.Name} failed: {message}`)
			endRun(run, TongueConfig.MissCooldown)
		end
	end)
end

-- Aiming has nothing to undo on the server.
function TongueGrab.Interrupt(_ctx: Types.Context): ()
end

function TongueGrab.Cancel(ctx: Types.Context): ()
	local run = runs[ctx.Player]
	if run == nil then
		return
	end
	runs[ctx.Player] = nil
	if run.Item ~= nil then
		dropFlying(run, flyingPosition(run))
	end
	clearTongue(ctx.Character)
end

-- The player whose extending tongue passes within reach of a thrown item's step.
function TongueGrab.FindIntercept(from: Vector3, to: Vector3): Player?
	local now = workspace:GetServerTimeNow()
	local reach = TongueConfig.InterceptRadius + ThrowConfig.CastRadius
	for player, run in runs do
		if run.Phase ~= "Extending" or run.Intercepted or not run.Ctx.IsCurrent() then
			continue
		end
		local mouth = TongueTargeting.Mouth(run.Ctx.Character)
		local extended = TongueTargeting.ExtendAlpha(now - run.StartedAt)
		if segmentDistance(from, to, mouth, mouth:Lerp(run.Tip, extended)) <= reach then
			return player
		end
	end
	return nil
end

-- The thrown item replaces the target: the tongue retracts with it, the target stays put.
function TongueGrab.TakeThrown(ctx: Types.Context, item: Item.Item, position: Vector3): ()
	local run = runs[ctx.Player]
	if run == nil or run.Phase ~= "Extending" then
		-- FindIntercept only returns extending tongues; if that changed, let the item fall instead of freezing it.
		item.Part.Anchored = false
		Tags.SetInteractionDisabled(item.Part, false)
		return
	end
	run.Intercepted = true
	run.Target = nil
	retractWith(run, item, position)
end

return TongueGrab :: Types.Skill
