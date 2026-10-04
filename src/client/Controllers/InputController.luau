--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local TargetController = require(script.Parent.TargetController)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"):WaitForChild("Interaction"))
local Net = require(Shared:WaitForChild("Net"))

-- Ported from legacy InteractionHandler.client. Mobile buttons come in layer 9.
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

function InputController.Start(_self: typeof(InputController)): ()
	-- Input already consumed by the game (text boxes, GUI) is ignored, as in legacy.
	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean): ()
		if gameProcessed then
			return
		end
		if input.KeyCode == Config.Controls.Interact then
			fire("Interact")
		elseif input.KeyCode == Config.Controls.Use then
			fire("Use", true)
		elseif input.KeyCode == Config.Controls.Throw then
			throwHeld()
		end
	end)

	UserInputService.InputEnded:Connect(function(input: InputObject, gameProcessed: boolean): ()
		if gameProcessed then
			return
		end
		if input.KeyCode == Config.Controls.Use then
			fire("Use", false)
		end
	end)
end

return InputController
