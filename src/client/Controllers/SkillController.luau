--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local BearToss = require(script.Parent.Parent.Skills.BearToss)
local DeepFreeze = require(script.Parent.Parent.Skills.DeepFreeze)
local Hustle = require(script.Parent.Parent.Skills.Hustle)
local InstantSkill = require(script.Parent.Parent.Skills.InstantSkill)
local OrderRush = require(script.Parent.Parent.Skills.OrderRush)
local Phase = require(script.Parent.Parent.Skills.Phase)
local TongueGrab = require(script.Parent.Parent.Skills.TongueGrab)
local CinematicCameraController = require(script.Parent.CinematicCameraController)
local SpeedController = require(script.Parent.SpeedController)
local RadialRing = require(script.Parent.Parent.Util.RadialRing)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local SkillsConfig = Config.Skills
local Attribute = SkillsConfig.Attribute
local Net = require(Shared:WaitForChild("Net"))
local TossPath = require(Shared:WaitForChild("Util"):WaitForChild("TossPath"))

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
	-- Optional: false makes the press do nothing (nothing in reach), with no aim and no request.
	CanAim: ((character: Model) -> boolean)?,
	-- Optional: true releases the aim on the client's own (a Bear catching a dasher, or throwing before the limit).
	AutoRelease: (() -> boolean)?,
}

local clientSkills: { [string]: ClientSkill } = {
	-- Cast: a module without the optional hooks doesn't match the table type exactly.
	TongueGrab = TongueGrab :: any,
	BearToss = BearToss,
}

-- Press-once skills (no aim): predicted on press, confirmed or rolled back by the server.
local instantSkills: { [string]: InstantSkill.InstantSkill } = {
	Hustle = Hustle,
	DeepFreeze = DeepFreeze,
	OrderRush = OrderRush,
	Phase = Phase,
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
local pending: Pending? = nil
local connectedButtons: { [GuiButton]: boolean } = setmetatable({}, { __mode = "k" }) :: any
-- When the superskill last came off cooldown (os.clock), for the card's pop.
local cameReadyAt = -math.huge
local wasCooling = false
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

-- Whole seconds of cooldown left, rounded up.
local function cooldownSeconds(character: Model): number
	local readyAt = character:GetAttribute(Attribute.ReadyAt)
	return if typeof(readyAt) == "number" then math.max(math.ceil(readyAt - workspace:GetServerTimeNow()), 0) else 0
end

-- True while the local character can't interact (or, with `throwing`, throw): a skill holds it, or one blocks it
-- (Phase blocks throwing).
function SkillController.InteractBlocked(throwing: boolean?): boolean
	for _, instant in instantSkills do
		local blocks = instant.BlocksInteract
		local blocksThrow = instant.BlocksThrow
		if (blocks ~= nil and blocks()) or (throwing and blocksThrow ~= nil and blocksThrow()) then
			return true
		end
	end
	return SkillController.IsBusy()
end

-- Whether an instant skill keeps the local character's run animation off (the Ghost floating while phased).
function SkillController.RunAnimationStopped(): boolean
	for _, instant in instantSkills do
		local stops = instant.StopsRunAnimation
		if stops ~= nil and stops() then
			return true
		end
	end
	return false
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
	-- Held or thrown by a Bear counts as busy too.
	return character ~= nil and (character:GetAttribute(Attribute.State) ~= nil or TossPath.Busy(character))
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
	Net.Event("Skill"):FireServer("Use")
end

local function pressSkill(): ()
	if CinematicCameraController.IsActive() then
		return
	end
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
	local canAim = skill.CanAim
	if canAim ~= nil and not canAim(character) then
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
	Net.Event("Skill"):FireServer("Aim")
end

local function releaseSkill(): ()
	if CinematicCameraController.IsActive() then
		return
	end
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
		local autoRelease = current.Skill.AutoRelease
		if autoRelease ~= nil and autoRelease() then
			releaseSkill()
		elseif now - current.HoldStartedAt >= current.Skill.HoldLimit then
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

type CardView = {
	Fraction: number,
	Seconds: number,
	Lit: boolean,
	Scale: number,
	Icon: string,
	Color: Color3,
}

-- Draws one superskill card (the desktop one or the mobile button's): ready = icon and ring in the superskill's
-- colour; cooldown = the ring fills back clockwise with the seconds left on a faded icon; can't use = grey.
local function drawCard(card: Instance, view: CardView): ()
	local tuning = Config.UI.Superskill
	local color = if view.Lit then view.Color else tuning.OffColor
	local cooling = view.Fraction > 0
	local pop = card:FindFirstChild("Pop")
	if pop ~= nil and pop:IsA("UIScale") then
		pop.Scale = view.Scale
	end
	local key = card:FindFirstChild("Key")
	local label = if key ~= nil then key:FindFirstChild("Label") else nil
	if label ~= nil and label:IsA("TextLabel") then
		label.Text = Config.Interaction.Controls.Skill.Name
	end
	local slot = card:FindFirstChild("Slot")
	if slot == nil then
		return
	end
	local icon = slot:FindFirstChild("Icon")
	if icon ~= nil and icon:IsA("ImageLabel") then
		icon.Image = view.Icon
		icon.ImageColor3 = if cooling then tuning.OffColor else color
		icon.ImageTransparency = if cooling then tuning.CooldownIconTransparency else 0
	end
	local ring = RadialRing.Find(slot)
	if ring ~= nil then
		RadialRing.Set(ring, 1 - view.Fraction, if cooling then view.Color else color)
	end
	local time = slot:FindFirstChild("Time")
	if time ~= nil and time:IsA("TextLabel") then
		time.Text = if cooling then tostring(view.Seconds) else ""
	end
end

-- Shows the superskill card only for characters that have one: on the HUD with a keyboard, as the touch button on
-- touch screens.
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

	local tuning = Config.UI.Superskill
	local name = currentName()
	local look = if name ~= nil then tuning.Looks[name] else nil
	if hasSkill and look == nil then
		warnOnce(`Config.UI.Superskill.Looks has no entry for {name}`)
	end
	local clock = os.clock()
	if wasCooling and fraction <= 0 then
		cameReadyAt = clock
	end
	wasCooling = fraction > 0
	local pressed = aim ~= nil or pending ~= nil
	local popAge = (clock - cameReadyAt) / tuning.PopTime
	local view: CardView = {
		Fraction = fraction,
		Seconds = if character ~= nil then cooldownSeconds(character) else 0,
		Lit = pressed or not unavailable,
		Scale = if pressed
			then tuning.PressedScale
			elseif popAge < 1 then 1 + (tuning.PopScale - 1) * math.sin(popAge * math.pi)
			else 1,
		Icon = if look ~= nil then look.Icon else "",
		Color = if look ~= nil then look.Color else tuning.OffColor,
	}
	local touch = UserInputService.TouchEnabled

	local gameInfo = playerGui:FindFirstChild("GameInfo")
	local infoFrame = if gameInfo ~= nil then gameInfo:FindFirstChild("InfoFrame") else nil
	local card = if infoFrame ~= nil then infoFrame:FindFirstChild("Superskill") else nil
	if card ~= nil and card:IsA("GuiObject") then
		card.Visible = hasSkill and not touch
		if card.Visible then
			drawCard(card, view)
		end
	elseif hasSkill and not touch then
		warnOnce("PlayerGui.GameInfo.InfoFrame.Superskill is missing")
	end

	if touch then
		local mobile = playerGui:FindFirstChild("MobileControls")
		local button = if mobile then mobile:FindFirstChild("Skill", true) else nil
		if button ~= nil and button:IsA("TextButton") then
			button.Visible = hasSkill
			bindMobileButton(button)
			local mobileCard = button:FindFirstChild("Superskill")
			if hasSkill and mobileCard ~= nil then
				drawCard(mobileCard, view)
			end
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
		if gameProcessed or CinematicCameraController.IsActive() then
			return
		end
		if input.KeyCode == Config.Interaction.Controls.Skill then
			pressSkill()
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject): ()
		if CinematicCameraController.IsActive() then
			return
		end
		-- Letting go always counts, even over a GUI.
		if input.KeyCode == Config.Interaction.Controls.Skill then
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
