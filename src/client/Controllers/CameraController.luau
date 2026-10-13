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
-- Follows this point instead of the character while set (a skill moving the player's view away).
local focusOverride: Vector3? = nil
-- Replaces the final camera CFrame while set (the round's opening shot); gets the normal one to blend from.
local shotOverride: ((normal: CFrame) -> CFrame)? = nil
local suspended = false

function CameraController.SetSuspended(on: boolean): ()
	suspended = on
	if not on then
		cameraPosition = nil
	end
end

-- Eases the camera by `offset` studs; pass Vector3.zero to ease back.
function CameraController.SetAimOffset(offset: Vector3, easeSpeed: number?): ()
	aimTarget = offset
	aimEaseSpeed = easeSpeed or CharacterConfig.CameraSpeed
end

-- Follows `position` instead of the character, easing like normal follow; nil goes back to the character.
function CameraController.SetFocus(position: Vector3?): ()
	focusOverride = position
end

-- Lets `shot` decide the camera CFrame each frame from the normal follow CFrame; nil goes back to normal.
function CameraController.SetShot(shot: ((normal: CFrame) -> CFrame)?): ()
	shotOverride = shot
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
		if suspended then
			return
		end
		local character = followed
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		local camera = workspace.CurrentCamera
		if root == nil or not root:IsA("BasePart") or camera == nil then
			return
		end
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = CharacterConfig.CameraFov
		local followPosition = focusOverride or root.Position
		local offset = Config.Levels.GetCameraOffset()
		local target = followPosition + offset
		cameraPosition = if cameraPosition then cameraPosition:Lerp(target, math.clamp(dt * CharacterConfig.CameraSpeed, 0, 1)) else target
		aimCurrent = aimCurrent:Lerp(aimTarget, math.clamp(dt * aimEaseSpeed, 0, 1))
		local position = (cameraPosition :: Vector3) + aimCurrent
		local focus = if CharacterConfig.CameraMode == "Track" then followPosition else position - offset
		local normal = CFrame.lookAt(position, focus)
		camera.CFrame = if shotOverride then shotOverride(normal) else normal
	end)
end

return CameraController
