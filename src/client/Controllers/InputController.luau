--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local TargetController = require(script.Parent.TargetController)
local MovementController = require(script.Parent.MovementController)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"):WaitForChild("Interaction"))
local Net = require(Shared:WaitForChild("Net"))

-- Keyboard and touch share the same action functions.
local InputController = {}

local function throwHeld(): ()
	local character = Players.LocalPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local holder = if root then root:FindFirstChild("ObjectHolder") else nil
	if holder == nil or not holder:IsA("WeldConstraint") then
		return
	end
	local part = holder.Part1
	if part ~= nil then
		Net.Event("Interact"):FireServer("Throw", part.CFrame)
	end
end

local function fire(action: string, heldState: boolean?): ()
	local target, node = TargetController.GetTarget()
	Net.Event("Interact"):FireServer(action, target, node, heldState)
end

local function interact(): ()
	fire("Interact")
end

local function use(held: boolean): ()
	fire("Use", held)
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
	dashButton.MouseButton1Click:Connect(MovementController.Dash)
	throwButton.MouseButton1Click:Connect(throwHeld)
end

function InputController.Start(_self: typeof(InputController)): ()
	-- Input already consumed by the game (text boxes, GUI) is ignored, as in legacy.
	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean): ()
		if gameProcessed then
			return
		end
		if input.KeyCode == Config.Controls.Interact then
			interact()
		elseif input.KeyCode == Config.Controls.Use then
			use(true)
		elseif input.KeyCode == Config.Controls.Throw then
			throwHeld()
		elseif input.KeyCode == Config.Controls.Dash then
			MovementController.Dash()
		end
	end)

	UserInputService.InputEnded:Connect(function(input: InputObject, gameProcessed: boolean): ()
		if gameProcessed then
			return
		end
		if input.KeyCode == Config.Controls.Use then
			use(false)
		end
	end)
	task.spawn(bindMobile)
end

return InputController
