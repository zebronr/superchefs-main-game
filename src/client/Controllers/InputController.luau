--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local TargetController = require(script.Parent.TargetController)
local MovementController = require(script.Parent.MovementController)
local ProjectileController = require(script.Parent.ProjectileController)
local SkillController = require(script.Parent.SkillController)
local CashController = require(script.Parent.CashController)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local InteractionConfig = Config.Interaction
local Net = require(Shared:WaitForChild("Net"))
local Tags = require(Shared:WaitForChild("Tags"))

-- Keyboard and touch share the same action functions.
local InputController = {}
local stopUseSent = false

local function actionCharacter(): Model?
	local character = Players.LocalPlayer.Character
	return if character ~= nil and character:GetAttribute(InteractionConfig.ActionAnimationAttribute) ~= nil then character else nil
end

local function stopUse(): ()
	stopUseSent = true
	Net.Event("Interact"):FireServer("StopUse")
end

local function throwHeld(): ()
	if SkillController.IsBusy() then
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
	if SkillController.IsBusy() then
		return
	end
	local target = TargetController.GetTarget()
	CashController.Predict(target)
	fire("Interact")
end

local function use(held: boolean): ()
	-- Releasing is always sent; starting is not allowed while a skill is aiming or running.
	if held and SkillController.IsBusy() then
		return
	end
	if held then
		stopUseSent = false
	end
	fire("Use", held)
end

local function dash(): ()
	if SkillController.IsBusy() then
		return
	end
	if actionCharacter() ~= nil and not stopUseSent then
		stopUse()
	end
	MovementController.Dash()
end

local function bindMobile(): ()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui", 10)
	local gui = if playerGui then playerGui:WaitForChild("MobileControls", 10) else nil
	if gui == nil or not gui:IsA("ScreenGui") then
		warn("PlayerGui.MobileControls is missing")
		return
	end
	gui.Enabled = UserInputService.TouchEnabled
	if not UserInputService.TouchEnabled then
		return
	end
	local interactButton = gui:FindFirstChild("Interact")
	local useButton = gui:FindFirstChild("Use")
	local dashButton = gui:FindFirstChild("Dash")
	local throwButton = gui:FindFirstChild("Throw")
	if not (interactButton and interactButton:IsA("TextButton") and useButton and useButton:IsA("TextButton") and dashButton and dashButton:IsA("TextButton") and throwButton and throwButton:IsA("TextButton")) then
		warn("MobileControls is missing a button")
		return
	end
	interactButton.MouseButton1Click:Connect(interact)
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
		if gameProcessed then
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
		if gameProcessed then
			return
		end
		if input.KeyCode == InteractionConfig.Controls.Use then
			use(false)
		end
	end)
	task.spawn(bindMobile)
end

return InputController
