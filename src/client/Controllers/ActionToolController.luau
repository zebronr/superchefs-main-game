--!strict

-- Puts each action's tool in the hand (the cleaver while chopping) for every character. The server only sets the
-- character's ActionAnimation attribute; every client renders the tool from it. The local player's own action
-- comes from AnimationController, so its tool shows at once on a predicted chop and rolls back with it.
-- One-shot swings (the bat when catching a dine-and-dasher) take over the hand: the server stamps them on the
-- character (CatchSwing.Attribute) and the local player predicts its own with Swing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AnimationController = require(script.Parent.AnimationController)
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local InteractionConfig = Config.Interaction
local swingTuning = InteractionConfig.CatchSwing

-- The action name a swing shows under; never an ActionAnimation value.
local SWING = "$CatchSwing"

type Held = {
	Action: string,
	Part: BasePart,
	Weld: Weld,
	Size: Vector3,
	Grip: CFrame,
	Base: CFrame,
	SwingAt: number?,
	ShownAt: number,
	HiddenAt: number?,
}

local ActionToolController = {}
local tools: Instance? = nil
local held: { [Model]: Held } = {}
local swings: { [Model]: number } = {}
-- The last swing stamp seen on each character (false: none), so only new swings play.
local seenStamps: { [Model]: number | false } = {}
-- When the local player last predicted a swing (os.clock()), so the server's stamp confirms it instead of replaying.
local predictedAt: number? = nil

local function swingLength(): number
	return swingTuning.WindTime + swingTuning.SlamTime + swingTuning.HoldTime
end

local function toolFor(action: string): string?
	return if action == SWING then swingTuning.Tool else InteractionConfig.ActionTools[action]
end

local function startSwing(character: Model, startedAt: number): ()
	swings[character] = startedAt
	if character == Players.LocalPlayer.Character then
		AnimationController.PlayUntil(swingTuning.Animation, startedAt + swingLength())
	end
end

-- Plays swings the server stamped: from their server start time, unless it confirms the local prediction.
local function readStamp(character: Model, clock: number): ()
	local value = character:GetAttribute(swingTuning.Attribute)
	local stamp: number | false = if typeof(value) == "number" then value else false
	local seen = seenStamps[character]
	seenStamps[character] = stamp
	if seen == nil or seen == stamp or stamp == false then
		return
	end
	if character == Players.LocalPlayer.Character and predictedAt ~= nil
		and clock - predictedAt < InteractionConfig.ActionPredictTimeout then
		predictedAt = nil
		return
	end
	startSwing(character, clock - math.max(workspace:GetServerTimeNow() - stamp, 0))
end

local function actionOf(character: Model, clock: number): string?
	local swingAt = swings[character]
	if swingAt ~= nil and clock - swingAt < swingLength() then
		return SWING
	end
	if character == Players.LocalPlayer.Character then
		return AnimationController.Action()
	end
	local value = character:GetAttribute(InteractionConfig.ActionAnimationAttribute)
	return if typeof(value) == "string" then value else nil
end

local function attach(character: Model, action: string): Held?
	local toolName = toolFor(action)
	local template = if toolName ~= nil and tools ~= nil then tools:FindFirstChild(toolName) else nil
	local hand = character:FindFirstChild(InteractionConfig.ToolHand)
	local handGrip = if hand ~= nil then hand:FindFirstChild(InteractionConfig.ToolHandAttachment) else nil
	if template == nil or not template:IsA("BasePart") or hand == nil or not hand:IsA("BasePart")
		or handGrip == nil or not handGrip:IsA("Attachment") then
		return nil
	end
	local grip = template:FindFirstChild("Grip")
	local part = template:Clone()
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	-- Made on this client only, so it never replicates; the weld just carries it with the hand.
	local weld = Instance.new("Weld")
	weld.Part0 = hand
	weld.Part1 = part
	weld.C0 = handGrip.CFrame
	weld.Parent = part
	part.Parent = character
	return {
		Action = action,
		Part = part,
		Weld = weld,
		Size = template.Size,
		Grip = if grip ~= nil and grip:IsA("Attachment") then grip.CFrame else CFrame.identity,
		Base = handGrip.CFrame,
		SwingAt = nil,
		ShownAt = os.clock(),
		HiddenAt = nil,
	}
end

-- Degrees the swung tool is turned about the hand at `age` seconds: raised while it pops in, then bonked down.
local function swingAngle(age: number): number
	if age < swingTuning.WindTime then
		local p = age / swingTuning.WindTime
		return swingTuning.WindAngle * (1 - (1 - p) * (1 - p))
	end
	local p = math.clamp((age - swingTuning.WindTime) / swingTuning.SlamTime, 0, 1)
	return swingTuning.WindAngle + (swingTuning.HitAngle - swingTuning.WindAngle) * p * p
end

-- Grows in with an overshoot and shrinks away when put down, scaling about the grip so it stays in the hand.
local function draw(tool: Held, clock: number): boolean
	local scale
	local hiddenAt = tool.HiddenAt
	if hiddenAt ~= nil then
		local p = (clock - hiddenAt) / InteractionConfig.ToolHideTime
		if p >= 1 then
			return false
		end
		scale = 1 - p * p
	else
		local p = math.clamp((clock - tool.ShownAt) / InteractionConfig.ToolPopTime, 0, 1)
		local s = InteractionConfig.ToolPopOvershoot
		local q = p - 1
		scale = 1 + (s + 1) * q * q * q + s * q * q
	end
	scale = math.max(scale, 0.01)
	tool.Part.Size = tool.Size * scale
	tool.Weld.C1 = tool.Grip.Rotation + tool.Grip.Position * scale
	local swingAt = tool.SwingAt
	if swingAt ~= nil then
		tool.Weld.C0 = tool.Base * CFrame.Angles(math.rad(swingAngle(clock - swingAt)), 0, 0)
	end
	return true
end

local function step(): ()
	local clock = os.clock()
	local characters: { [Model]: boolean } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character ~= nil and character.Parent ~= nil then
			characters[character] = true
			readStamp(character, clock)
			local action = actionOf(character, clock)
			local tool = held[character]
			if tool ~= nil and tool.HiddenAt == nil and tool.Action ~= action then
				tool.HiddenAt = clock
			end
			if action ~= nil and toolFor(action) ~= nil
				and (tool == nil or tool.HiddenAt ~= nil) then
				if tool ~= nil then
					tool.Part:Destroy()
					held[character] = nil
				end
				local attached = attach(character, action)
				if attached ~= nil then
					held[character] = attached
				end
			end
			local current = held[character]
			if action == SWING and current ~= nil and current.Action == SWING then
				current.SwingAt = swings[character]
			end
		end
	end
	for character, swingAt in swings do
		if not characters[character] or clock - swingAt >= swingLength() then
			swings[character] = nil
		end
	end
	for character in seenStamps do
		if not characters[character] then
			seenStamps[character] = nil
		end
	end
	for character, tool in held do
		if not characters[character] or not draw(tool, clock) then
			tool.Part:Destroy()
			held[character] = nil
		end
	end
end

-- Predicts the local player's catch swing now; the server's stamp confirms it.
function ActionToolController.PredictSwing(): ()
	local character = Players.LocalPlayer.Character
	if character ~= nil then
		predictedAt = os.clock()
		startSwing(character, os.clock())
	end
end

function ActionToolController.IsSwinging(character: Model): boolean
	local swingAt = swings[character]
	return swingAt ~= nil and os.clock() - swingAt < swingLength()
end

function ActionToolController.Start(_self: typeof(ActionToolController)): ()
	tools = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Tools")
	RunService.RenderStepped:Connect(step)
end

return ActionToolController
