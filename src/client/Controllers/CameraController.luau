--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local CharacterConfig = Config.Character

local CameraController = {}
local localPlayer = Players.LocalPlayer
local followed: Model? = nil
local cameraPosition: Vector3? = nil
-- A temporary shift of the camera (a skill's aim view): where it eases to, where it is, and how fast.
local aimTarget = Vector3.zero
local aimCurrent = Vector3.zero
local aimEaseSpeed = CharacterConfig.CameraSpeed

-- Eases the camera by `offset` studs; pass Vector3.zero to ease back.
function CameraController.SetAimOffset(offset: Vector3, easeSpeed: number?): ()
	aimTarget = offset
	aimEaseSpeed = easeSpeed or CharacterConfig.CameraSpeed
end

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
		camera.FieldOfView = CharacterConfig.CameraFov
		local target = root.Position + CharacterConfig.CameraOffset
		cameraPosition = if cameraPosition then cameraPosition:Lerp(target, math.clamp(dt * CharacterConfig.CameraSpeed, 0, 1)) else target
		aimCurrent = aimCurrent:Lerp(aimTarget, math.clamp(dt * aimEaseSpeed, 0, 1))
		local position = (cameraPosition :: Vector3) + aimCurrent
		local focus = if CharacterConfig.CameraMode == "Track" then root.Position else position - CharacterConfig.CameraOffset
		camera.CFrame = CFrame.lookAt(position, focus)
	end)
end

return CameraController
