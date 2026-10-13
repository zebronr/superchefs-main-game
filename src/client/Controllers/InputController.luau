--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local TargetController = require(script.Parent.TargetController)
local MovementController = require(script.Parent.MovementController)
local ProjectileController = require(script.Parent.ProjectileController)
local SkillController = require(script.Parent.SkillController)
local CashController = require(script.Parent.CashController)
local OrderTakeController = require(script.Parent.OrderTakeController)
local AnimationController = require(script.Parent.AnimationController)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local InteractionConfig = Config.Interaction
local Net = require(Shared:WaitForChild("Net"))
local Tags = require(Shared:WaitForChild("Tags"))

-- Keyboard and touch share the same action functions.
local InputController = {}
local CinematicCameraController = require(script.Parent.CinematicCameraController)
local stopUseSent = false

local function actionCharacter(): Model?
	local character = Players.LocalPlayer.Character
	return if character ~= nil and character:GetAttribute(InteractionConfig.ActionAnimationAttribute) ~= nil then character else nil
end

local function stopUse(): ()
	stopUseSent = true
	if AnimationController.Action() ~= nil then
		AnimationController.Predict(nil)
	end
	Net.Event("Interact"):FireServer("StopUse")
end

local function throwHeld(): ()
	if CinematicCameraController.IsActive() or SkillController.InteractBlocked(true) then
		return
	end
	local character = Players.LocalPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local holder = if root then root:FindFirstChild("ObjectHolder") else nil
	if holder == nil or not holder:IsA("WeldConstraint") then
		return
	end
	local part = holder.Part1
	if part ~= nil then
		if Tags.IsClass(part, Tags.Food) then
			ProjectileController.Predict(part, holder, part.CFrame)
		end
		Net.Event("Interact"):FireServer("Throw", part.CFrame)
	end
end

local function fire(action: string, heldState: boolean?): ()
	local target, node = TargetController.GetTarget()
	Net.Event("Interact"):FireServer(action, target, node, heldState)
end

local function interact(): ()
	if CinematicCameraController.IsActive() or SkillController.InteractBlocked() then
		return
	end
	local target = TargetController.GetTarget()
	CashController.Predict(target)
	OrderTakeController.Predict(target)
	fire("Interact")
end

-- Raw food resting on the board (the client's view of the server's Slot); chopped food can't be chopped again.
local function hasRawFood(board: Instance): boolean
	for _, weld in board:GetDescendants() do
		local part = if weld:IsA("WeldConstraint") and weld.Name == InteractionConfig.SlotWeldName then weld.Part1 else nil
		if part ~= nil then
			local parent = part.Parent
			local food = if Tags.IsClass(part, Tags.Food) then part
				elseif parent ~= nil and Tags.IsClass(parent, Tags.Food) then parent
				else nil
			if food ~= nil and string.sub(food.Name, 1, 8) ~= "chopped_" and food:GetAttribute(InteractionConfig.CombinedAttribute) ~= true then
				return true
			end
		end
	end
	return false
end

-- Predicts the chop the server will start (same checks as ChoppingBoard.StartUse that the client can see), so the
-- animation and cleaver show at once; AnimationController rolls it back if the server doesn't agree in time.
local function predictUse(): ()
	local character = Players.LocalPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local holder = if root then root:FindFirstChild("ObjectHolder") else nil
	if AnimationController.Action() ~= nil or (holder ~= nil and holder:IsA("WeldConstraint") and holder.Part1 ~= nil) then
		return
	end
	local target = TargetController.GetTarget()
	if target ~= nil and Tags.IsClass(target, Tags.ChoppingBoard) and not CollectionService:HasTag(target, Tags.Locked)
		and hasRawFood(target) then
		AnimationController.Predict("Chop")
	end
end

local function use(held: boolean): ()
	if CinematicCameraController.IsActive() then
		return
	end
	-- Releasing is always sent; starting is not allowed while a skill is aiming or running.
	if held and SkillController.InteractBlocked() then
		return
	end
	if held then
		stopUseSent = false
		predictUse()
	end
	fire("Use", held)
end

local function dash(): ()
	if CinematicCameraController.IsActive() or SkillController.IsBusy() then
		return
	end
	if actionCharacter() ~= nil and not stopUseSent then
		stopUse()
	end
	MovementController.Dash()
end

-- While a finger is on a button, its Face sinks onto its Shadow, like a pressed key.
local function bindPress(button: GuiButton): ()
	local face = button:FindFirstChild("Face")
	local shadow = button:FindFirstChild("Shadow")
	if not (face ~= nil and face:IsA("GuiObject") and shadow ~= nil and shadow:IsA("GuiObject")) then
		return
	end
	local rest = face.Position
	local held = 0
	button.InputBegan:Connect(function(input: InputObject): ()
		if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end
		held += 1
		face.Position = shadow.Position
		-- The touch can end anywhere on screen, so the press ends with the input itself, not the button's events.
		local connection: RBXScriptConnection
		connection = input:GetPropertyChangedSignal("UserInputState"):Connect(function(): ()
			if input.UserInputState ~= Enum.UserInputState.End and input.UserInputState ~= Enum.UserInputState.Cancel then
				return
			end
			connection:Disconnect()
			held -= 1
			if held <= 0 then
				held = 0
				face.Position = rest
			end
		end)
	end)
end

-- The class of an item part, or of the item model it belongs to.
local function itemClass(part: Instance?): string?
	if part == nil then
		return nil
	end
	local class = Tags.ClassOf(part)
	local parent = part.Parent
	if class == nil and parent ~= nil then
		class = Tags.ClassOf(parent)
	end
	return class
end

local function heldPart(): BasePart?
	local character = Players.LocalPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local holder = if root then root:FindFirstChild("ObjectHolder") else nil
	return if holder ~= nil and holder:IsA("WeldConstraint") then holder.Part1 else nil
end

-- What sits on a station's slot (the client's view of the server's Slot weld).
local function onTopOf(station: Instance): string?
	for _, weld in station:GetDescendants() do
		local part: BasePart? = if weld:IsA("WeldConstraint") and weld.Name == InteractionConfig.SlotWeldName then weld.Part1 else nil
		if part ~= nil then
			return itemClass(part)
		end
	end
	return nil
end

-- Item pairs that combine (food onto a plate or into a pot, a pot onto a plate, burger parts, dirty plate stacks)
-- instead of swapping. A hint only: the server's Accept rules decide.
local COMBINES: { [string]: { [string]: boolean } } = {
	[Tags.Food] = { [Tags.Plate] = true, [Tags.CookingTool] = true, [Tags.Food] = true },
	[Tags.Plate] = { [Tags.Food] = true, [Tags.CookingTool] = true },
	[Tags.CookingTool] = { [Tags.Food] = true, [Tags.Plate] = true },
	[Tags.DirtyPlate] = { [Tags.DirtyPlate] = true },
}

local function combineOrSwap(held: string?, there: string?): string
	local labels = Config.UI.InteractLabels
	local partners = if held ~= nil then COMBINES[held] else nil
	return if partners ~= nil and there ~= nil and partners[there] then labels.Add else labels.Swap
end

-- The interact button's label for what the press would most likely do now.
local function interactLabel(): string
	local labels = Config.UI.InteractLabels
	local held = itemClass(heldPart())
	local target = TargetController.GetTarget()
	if target == nil then
		return if held ~= nil then labels.Drop else labels.Grab
	end
	local class = Tags.ClassOf(target)
	if class == Tags.Runner then
		return labels.Catch
	elseif class == Tags.CustomerTable then
		local state = target:GetAttribute("CustomerState")
		if state == "WaitingToOrder" then
			return labels.Order
		elseif state == "WaitingForFood" and held == Tags.Plate then
			return labels.Serve
		end
		local cash = target:GetAttribute("Cash")
		return if typeof(cash) == "number" and cash > 0 then labels.Collect else labels.Grab
	elseif class == Tags.ServingCounter then
		return labels.Serve
	elseif class == Tags.Trash then
		return if held == Tags.Food or held == nil then labels.Trash else labels.Empty
	elseif class == Tags.Sink then
		return if held == Tags.DirtyPlate then labels.Wash elseif held ~= nil then labels.Add else labels.Grab
	elseif class == Tags.PlateTable then
		return if held == nil then labels.Grab else combineOrSwap(held, Tags.Plate)
	elseif class == Tags.Countertop or class == Tags.ChoppingBoard or class == Tags.Stove or class == Tags.FoodContainer then
		if held == nil then
			return labels.Grab
		end
		local there = onTopOf(target)
		return if there == nil then labels.Place else combineOrSwap(held, there)
	end
	-- An item on its own (on the floor, or targeted directly).
	return if held == nil then labels.Grab else combineOrSwap(held, class)
end

local function bindMobile(): ()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui", 10)
	local gui = if playerGui then playerGui:WaitForChild("MobileControls", 10) else nil
	if gui == nil or not gui:IsA("ScreenGui") then
		warn("PlayerGui.MobileControls is missing")
		return
	end
	-- Touch screens only, and only once the round has started (the loading screen covers the wait).
	local mobileGui = gui
	local function refreshShown(): ()
		local state = ReplicatedStorage:GetAttribute("RoundState")
		mobileGui.Enabled = UserInputService.TouchEnabled and state ~= "Waiting" and state ~= "Loading"
	end
	refreshShown()
	ReplicatedStorage:GetAttributeChangedSignal("RoundState"):Connect(refreshShown)
	if not UserInputService.TouchEnabled then
		return
	end
	-- The arc keeps its shape on every screen (see Config.UI.MobileArc).
	local arc = gui:FindFirstChild("Arc")
	if arc ~= nil and arc:IsA("GuiObject") then
		local arcFrame = arc
		local function sizeArc(): ()
			local tuning = Config.UI.MobileArc
			local screen = mobileGui.AbsoluteSize
			local height = math.min(screen.Y * tuning.Height, screen.X * tuning.MaxWidth / tuning.Aspect)
			arcFrame.Size = UDim2.fromOffset(height * tuning.Aspect, height)
		end
		sizeArc()
		mobileGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(sizeArc)
	end
	-- Buttons can sit anywhere under the GUI (the thumb arc keeps them in a layout frame).
	local interactButton = gui:FindFirstChild("Interact", true)
	local useButton = gui:FindFirstChild("Use", true)
	local dashButton = gui:FindFirstChild("Dash", true)
	local throwButton = gui:FindFirstChild("Throw", true)
	if not (interactButton and interactButton:IsA("TextButton") and useButton and useButton:IsA("TextButton") and dashButton and dashButton:IsA("TextButton") and throwButton and throwButton:IsA("TextButton")) then
		warn("MobileControls is missing a button")
		return
	end
	for _, button in { interactButton, useButton, dashButton, throwButton } do
		bindPress(button)
	end
	interactButton.MouseButton1Click:Connect(interact)
	-- The label follows what the press would do; the old "/ drop" hint is covered by it.
	local interactFace = interactButton:FindFirstChild("Face")
	local interactText = if interactFace then interactFace:FindFirstChild("Label") else nil
	local interactHint = if interactFace then interactFace:FindFirstChild("Hint") else nil
	if interactHint ~= nil and interactHint:IsA("GuiObject") then
		interactHint.Visible = false
	end
	if interactText ~= nil and interactText:IsA("TextLabel") then
		local label = interactText
		RunService.Heartbeat:Connect(function(): ()
			if mobileGui.Enabled then
				local text = interactLabel()
				if label.Text ~= text then
					label.Text = text
				end
			end
		end)
	else
		warn("MobileControls Interact.Face.Label is missing")
	end
	useButton.MouseButton1Down:Connect(function(): ()
		use(true)
	end)
	useButton.MouseButton1Up:Connect(function(): ()
		use(false)
	end)
	dashButton.MouseButton1Click:Connect(dash)
	throwButton.MouseButton1Click:Connect(throwHeld)
end

function InputController.Start(_self: typeof(InputController)): ()
	RunService.Heartbeat:Connect(function(): ()
		local character = actionCharacter()
		if character == nil then
			stopUseSent = false
			return
		end
		if stopUseSent then
			return
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid ~= nil and humanoid.MoveDirection.Magnitude > 0 then
			stopUse()
		end
	end)
	-- Input already consumed by the game (text boxes, GUI) is ignored, as in legacy.
	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean): ()
		if gameProcessed or CinematicCameraController.IsActive() then
			return
		end
		if input.KeyCode == InteractionConfig.Controls.Interact then
			interact()
		elseif input.KeyCode == InteractionConfig.Controls.Use then
			use(true)
		elseif input.KeyCode == InteractionConfig.Controls.Throw then
			throwHeld()
		elseif input.KeyCode == InteractionConfig.Controls.Dash then
			dash()
		end
	end)

	UserInputService.InputEnded:Connect(function(input: InputObject, gameProcessed: boolean): ()
		if gameProcessed or CinematicCameraController.IsActive() then
			return
		end
		if input.KeyCode == InteractionConfig.Controls.Use then
			use(false)
		end
	end)
	task.spawn(bindMobile)
end

return InputController
