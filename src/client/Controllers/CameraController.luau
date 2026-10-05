--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Character"))

local CameraController = {}
local localPlayer = Players.LocalPlayer
local followed: Model? = nil
local cameraPosition: Vector3? = nil

function CameraController.Start(_self: typeof(CameraController)): ()
	localPlayer.CharacterAdded:Connect(function(character: Model): ()
		followed = character
		cameraPosition = nil
	end)
	localPlayer.CharacterRemoving:Connect(function(character: Model): ()
		if followed == character then
			followed = nil
			cameraPosition = nil
		end
	end)
	followed = localPlayer.Character
	-- RenderStepped places the camera after the character's simulation and before the frame draws.
	RunService.RenderStepped:Connect(function(dt: number): ()
		local character = followed
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		local camera = workspace.CurrentCamera
		if root == nil or not root:IsA("BasePart") or camera == nil then
			return
		end
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = Config.CameraFov
		local target = root.Position + Config.CameraOffset
		cameraPosition = if cameraPosition then cameraPosition:Lerp(target, math.clamp(dt * Config.CameraSpeed, 0, 1)) else target
		local position = cameraPosition :: Vector3
		local focus = if Config.CameraMode == "Track" then root.Position else position - Config.CameraOffset
		camera.CFrame = CFrame.lookAt(position, focus)
	end)
end

return CameraController
