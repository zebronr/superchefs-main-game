local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

local Bindables = ReplicatedStorage:WaitForChild("Bindables")
local ControlsBindables = Bindables:WaitForChild("Controls")

local InteractBE = ControlsBindables:WaitForChild("Interact")
local UseBE = ControlsBindables:WaitForChild("Use")
local DashBE = ControlsBindables:WaitForChild("Dash")
local ThrowBE = ControlsBindables:WaitForChild("Throw")

local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local MobileControlsGUI = PlayerGui:WaitForChild("MobileControls")

local InteractButton = MobileControlsGUI:WaitForChild("Interact")
local UseButton:TextButton = MobileControlsGUI:WaitForChild("Use")
local DashButton = MobileControlsGUI:WaitForChild("Dash")
local ThrowButton = MobileControlsGUI:WaitForChild("Throw")

print(UserInputService.TouchEnabled)

if UserInputService.TouchEnabled then
	MobileControlsGUI.Enabled = true
end

InteractButton.MouseButton1Click:Connect(function()
    InteractBE:Fire()
end)

UseButton.MouseButton1Down:Connect(function()
    UseBE:Fire(true)
end)

UseButton.MouseButton1Up:Connect(function()
    UseBE:Fire(false)
end)

DashButton.MouseButton1Click:Connect(function()
    DashBE:Fire()
end)

ThrowButton.MouseButton1Click:Connect(function()
    ThrowBE:Fire()
end)