--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local DeepFreeze = require(script.Parent.Parent.Skills.DeepFreeze)
local Hustle = require(script.Parent.Parent.Skills.Hustle)
local InstantSkill = require(script.Parent.Parent.Skills.InstantSkill)
local OrderRush = require(script.Parent.Parent.Skills.OrderRush)
local TongueGrab = require(script.Parent.Parent.Skills.TongueGrab)
local SpeedController = require(script.Parent.SpeedController)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local SkillsConfig = Config.Skills
local Attribute = SkillsConfig.Attribute
local Net = require(Shared:WaitForChild("Net"))

-- The super skill of the local character: key and button, the HUD, and the aiming flow. The look of
-- each skill lives in `Skills/`; to add one, write the module and register it here.
local SkillController = {}

type ClientSkill = {
	-- Seconds of holding before the aim times out.
	HoldLimit: number,
	-- Seconds from a release until the use is over (the client frees movement then, without waiting for the server).
	ActiveTime: number,
	Setup: () -> (),
	BeginAim: (character: Model) -> (),
	-- Returns true when the aim switched to a new target, which restarts the hold limit.
	StepAim: (dt: number) -> boolean,
	ReleaseAim: (predict: boolean) -> (),
	EndAim: () -> (),
	GetDirection: () -> Vector3,
	GetTarget: () -> Instance?,
}

local clientSkills: { [string]: ClientSkill } = {
	TongueGrab = TongueGrab,
}

-- Press-once skills (no aim): predicted on press, confirmed or rolled back by the server.
local instantSkills: { [string]: InstantSkill.InstantSkill } = {
	Hustle = Hustle,
	DeepFreeze = DeepFreeze,
	OrderRush = OrderRush,
}

-- An instant use the server has not answered yet.
type Pending = {
	Skill: InstantSkill.InstantSkill,
	Character: Model,
	SentAt: number,
	Connections: { RBXScriptConnection },
}

type Aim = {
	Skill: ClientSkill,
	Character: Model,
	Humanoid: Humanoid,
	StartedAt: number,
	-- When the hold limit started counting: the press, or the last target switch.
	HoldStartedAt: number,
	-- A target switch the server hasn't heard about yet, and when it was last told.
	RetargetPending: boolean,
	RetargetSentAt: number,
	Released: boolean,
	-- When the release was predicted to finish (os.clock), and whether movement was given back.
	FreeAt: number?,
	Freed: boolean,
	SawState: boolean,
}

local localPlayer = Players.LocalPlayer
local aim: Aim? = nil
-- Studio test mode (Config.Skills.StudioTestKeys): the skill picked by the last test key; nil = the character's own.
local testKeys = if RunService:IsStudio() then SkillsConfig.StudioTestKeys else nil
local override: string? = nil
local pending: Pending? = nil
local connectedButtons: { [GuiButton]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local warnedMissing: { [string]: boolean } = {}

local function warnOnce(message: string): ()
	if not warnedMissing[message] then
		warnedMissing[message] = true
		warn(message)
	end
end

local function currentName(): (string?, Model?)
	local character = localPlayer.Character
	if character == nil then
		return nil, nil
	end
	if override ~= nil then
		return override, character
	end
	local model = character:GetAttribute(Attribute.CharacterModel)
	return if typeof(model) == "string" then SkillsConfig.ByCharacter[model] else nil, character
end

local function currentSkill(): (ClientSkill?, Model?)
	local name, character = currentName()
	return if name ~= nil then clientSkills[name] else nil, character
end

local function currentInstant(): (InstantSkill.InstantSkill?, Model?)
	local name, character = currentName()
	return if name ~= nil then instantSkills[name] else nil, character
end

local function handsFull(character: Model): boolean
	local root = character:FindFirstChild("HumanoidRootPart")
	local weld = if root then root:FindFirstChild("ObjectHolder") else nil
	if weld == nil or not weld:IsA("WeldConstraint") then
		return false
	end
	local held: BasePart? = weld.Part1
	return held ~= nil
end

-- Fraction of the cooldown left, 0 when ready.
local function cooldownFraction(character: Model): number
	local readyAt = character:GetAttribute(Attribute.ReadyAt)
	local total = character:GetAttribute(Attribute.Cooldown)
	if typeof(readyAt) ~= "number" or typeof(total) ~= "number" or total <= 0 then
		return 0
	end
	return math.clamp((readyAt - workspace:GetServerTimeNow()) / total, 0, 1)
end

function SkillController.IsBusy(): boolean
	if aim ~= nil then
		return true
	end
	local instant = currentInstant()
	if instant ~= nil and instant.IsBusy() then
		return true
	end
	local character = localPlayer.Character
	return character ~= nil and character:GetAttribute(Attribute.State) ~= nil
end

-- Gives movement back. Rooting is client-only, so this never waits for the server; the server still
-- blocks actions (SkillState) until the use is really over, and a refused or interrupted use ends the
-- aim through `endAim` as before.
local function freeMovement(current: Aim): ()
	if current.Freed then
		return
	end
	current.Freed = true
	SpeedController.SetRooted("Aim", false)
end

local function endAim(): ()
	local current = aim
	if current == nil then
		return
	end
	aim = nil
	current.Skill.EndAim()
	freeMovement(current)
end

local function settle(): ()
	local current = pending
	if current == nil then
		return
	end
	pending = nil
	for _, connection in current.Connections do
		connection:Disconnect()
	end
end

-- The server refused (or never answered): undo the local prediction.
local function rollback(): ()
	local current = pending
	if current == nil then
		return
	end
	settle()
	current.Skill.Rollback()
end

local function useInstant(skill: InstantSkill.InstantSkill, character: Model): ()
	if pending ~= nil or SkillController.IsBusy() then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if
		humanoid == nil
		or humanoid.Health <= 0
		or cooldownFraction(character) > 0
		or (skill.RequiresEmptyHands and handsFull(character))
		or not skill.CanUse(character)
	then
		return
	end
	local current: Pending = {
		Skill = skill,
		Character = character,
		SentAt = os.clock(),
		Connections = {},
	}
	pending = current
	-- Any sign the server accepted (a new cooldown, or the skill state) confirms the prediction.
	local function confirm(): ()
		if pending == current then
			settle()
		end
	end
	table.insert(current.Connections, character:GetAttributeChangedSignal(Attribute.ReadyAt):Connect(confirm))
	table.insert(current.Connections, character:GetAttributeChangedSignal(Attribute.State):Connect(confirm))
	skill.Predict(character)
	Net.Event("Skill"):FireServer("Use", override)
end

local function pressSkill(): ()
	local instant, instantCharacter = currentInstant()
	if instant ~= nil and instantCharacter ~= nil then
		useInstant(instant, instantCharacter)
		return
	end
	local skill, character = currentSkill()
	if skill == nil or character == nil or aim ~= nil or SkillController.IsBusy() then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil or humanoid.Health <= 0 or handsFull(character) or cooldownFraction(character) > 0 then
		return
	end
	aim = {
		Skill = skill,
		Character = character,
		Humanoid = humanoid,
		StartedAt = os.clock(),
		HoldStartedAt = os.clock(),
		RetargetPending = false,
		RetargetSentAt = 0,
		Released = false,
		FreeAt = nil,
		Freed = false,
		SawState = false,
	}
	-- Rooted until the server says the use is over.
	SpeedController.SetRooted("Aim", true)
	skill.BeginAim(character)
	Net.Event("Skill"):FireServer("Aim", override)
end

local function releaseSkill(): ()
	local current = aim
	if current == nil or current.Released then
		return
	end
	current.Released = true
	if os.clock() - current.HoldStartedAt >= current.Skill.HoldLimit then
		current.Skill.ReleaseAim(false)
		Net.Event("Skill"):FireServer("Timeout")
		-- A cancel fires nothing: free right away.
		freeMovement(current)
		return
	end
	current.FreeAt = os.clock() + current.Skill.ActiveTime
	current.Skill.ReleaseAim(true)
	Net.Event("Skill"):FireServer("Release", current.Skill.GetDirection(), current.Skill.GetTarget())
end

local function stepPending(): ()
	local current = pending
	if current == nil then
		return
	end
	if localPlayer.Character ~= current.Character then
		rollback()
	elseif os.clock() - current.SentAt >= SkillsConfig.InstantConfirmTimeout then
		-- No answer at all: treat it as refused.
		rollback()
	end
end

local function stepAim(dt: number): ()
	local current = aim
	if current == nil then
		return
	end
	if
		localPlayer.Character ~= current.Character
		or current.Humanoid.Health <= 0
		or current.Humanoid.Parent == nil
	then
		endAim()
		return
	end
	local now = os.clock()
	local state = current.Character:GetAttribute(Attribute.State)
	if state ~= nil then
		current.SawState = true
	end
	if not current.Released then
		if current.Skill.StepAim(dt) then
			current.HoldStartedAt = now
			current.RetargetPending = true
		end
		-- Throttled so fast switching stays inside the remote's rate limit.
		if current.RetargetPending and now - current.RetargetSentAt >= SkillsConfig.RetargetInterval then
			current.RetargetPending = false
			current.RetargetSentAt = now
			Net.Event("Skill"):FireServer("Retarget")
		end
		if now - current.HoldStartedAt >= current.Skill.HoldLimit then
			current.Released = true
			current.Skill.ReleaseAim(false)
			Net.Event("Skill"):FireServer("Timeout")
			freeMovement(current)
		end
	end
	local freeAt = current.FreeAt
	if freeAt ~= nil and now >= freeAt then
		freeMovement(current)
	end
	-- Done when the server is back to idle; give up if it never started (a refused aim).
	if current.SawState and state == nil then
		endAim()
	elseif not current.SawState and now - current.StartedAt >= 1 then
		endAim()
	end
end

local function bindMobileButton(button: GuiButton): ()
	if connectedButtons[button] then
		return
	end
	connectedButtons[button] = true
	button.MouseButton1Down:Connect(pressSkill)
	button.MouseButton1Up:Connect(releaseSkill)
end

local function setCooldownFrame(parent: Instance, fraction: number): ()
	local frame = parent:FindFirstChild("Cooldown")
	if frame ~= nil and frame:IsA("GuiObject") then
		frame.Size = UDim2.new(frame.Size.X.Scale, frame.Size.X.Offset, fraction, 0)
	end
end

-- Shows the HUD only for characters that have a skill, with the cooldown fill and a greyed-out look.
local function updateHud(): ()
	local skill, character = currentSkill()
	local instant = currentInstant()
	local hasSkill = (skill ~= nil or instant ~= nil) and character ~= nil
	local fraction = if character ~= nil and hasSkill then cooldownFraction(character) else 0
	local needsEmptyHands = if instant ~= nil then instant.RequiresEmptyHands else true
	local unavailable = fraction > 0
		or (needsEmptyHands and character ~= nil and handsFull(character))
		or (instant ~= nil and character ~= nil and not instant.CanUse(character))
		or pending ~= nil
		or SkillController.IsBusy()
	local playerGui = localPlayer:FindFirstChild("PlayerGui")
	if playerGui == nil then
		return
	end

	local hud = playerGui:FindFirstChild("SkillHUD")
	if hud ~= nil and hud:IsA("ScreenGui") then
		hud.Enabled = hasSkill and Config.UI.ShowSkillHud
		local button = hud:FindFirstChild("Button")
		if button ~= nil and button:IsA("Frame") then
			local key = button:FindFirstChild("Key")
			if key ~= nil and key:IsA("TextLabel") then
				key.Text = Config.Interaction.Controls.Skill.Name
				key.TextTransparency = if unavailable then 0.5 else 0
			end
			button.BackgroundTransparency = if unavailable then 0.6 else 0
			setCooldownFrame(button, fraction)
		end
	elseif hasSkill and Config.UI.ShowSkillHud then
		warnOnce("PlayerGui.SkillHUD is missing")
	end

	if UserInputService.TouchEnabled then
		local mobile = playerGui:FindFirstChild("MobileControls")
		local button = if mobile then mobile:FindFirstChild("Skill") else nil
		if button ~= nil and button:IsA("TextButton") then
			button.Visible = hasSkill
			button.TextTransparency = if unavailable then 0.5 else 0
			bindMobileButton(button)
			setCooldownFrame(button, fraction)
		elseif hasSkill then
			warnOnce("PlayerGui.MobileControls.Skill is missing")
		end
	end
end

function SkillController.Start(_self: typeof(SkillController)): ()
	for _, skill in clientSkills do
		skill.Setup()
	end
	for _, skill in instantSkills do
		skill.Setup()
	end
	-- Input already consumed by the game (text boxes, GUI) is ignored.
	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean): ()
		if gameProcessed then
			return
		end
		local test = if testKeys ~= nil then testKeys[input.KeyCode.Name] else nil
		if input.KeyCode == Config.Interaction.Controls.Skill or test ~= nil then
			-- A test key picks its skill until the next press; the skill key goes back to the character's own.
			if aim == nil and pending == nil and not SkillController.IsBusy() then
				override = test
			end
			pressSkill()
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject): ()
		-- Letting go always counts, even over a GUI.
		local test = testKeys ~= nil and testKeys[input.KeyCode.Name] ~= nil
		if input.KeyCode == Config.Interaction.Controls.Skill or test then
			releaseSkill()
		end
	end)
	Net.Event("Skill").OnClientEvent:Connect(function(message: unknown): ()
		if message == "Interrupted" then
			endAim()
			rollback()
		end
	end)
	localPlayer.CharacterRemoving:Connect(function(): ()
		endAim()
		rollback()
	end)
	RunService.RenderStepped:Connect(function(dt: number): ()
		stepAim(dt)
		stepPending()
		updateHud()
	end)
end

return SkillController
