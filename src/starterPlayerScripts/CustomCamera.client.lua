local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local CameraRemote = Remotes:WaitForChild("CameraRemote")

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local camera = game.Workspace.CurrentCamera

local coopenabled = false

local closeupservice
local cachecamerapart

local function DisableFollowUp()
	if not closeupservice or not cachecamerapart then return end
	closeupservice:Disconnect()
	cachecamerapart:Destroy()
end

local function followUp()
	local RunService = game:GetService("RunService")
	local LocalPlayer = Players.LocalPlayer
	local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
	local root = character:WaitForChild("HumanoidRootPart")
	local cameraPart = Instance.new("Part")

	local yDistance, zDistance = 20, 15
	local cameraSpeed = 5

	local FOV = 50

	camera.FieldOfView = FOV

	cameraPart.Anchored = true
	cameraPart.CanTouch = false
	cameraPart.CanCollide = false
	cameraPart.Parent = game.Workspace:WaitForChild("$CustomCameras")
	cameraPart.Name = "CustomCloseCamera"
	cameraPart.CFrame = CFrame.lookAt(root.CFrame.Position + Vector3.new(0, yDistance, zDistance), root.Position)
	cachecamerapart = cameraPart
	camera.CameraType = Enum.CameraType.Scriptable
	
	closeupservice = RunService.PostSimulation:Connect(function(dt)
		cameraPart.Position = cameraPart.Position:Lerp(root.Position + Vector3.new(0, yDistance, zDistance), dt * cameraSpeed)
		camera.CFrame = cameraPart.CFrame	
	end)
end

local function CoopCamera(CameraCFrame)
	coopenabled = true
	local FOV = 50
	camera.FieldOfView = FOV
	
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CameraCFrame
	
	local originPosition = CameraCFrame
	while coopenabled do
		local randomx = ((math.random(0,100)/100) * 1)
		local randomy = ((math.random(0,100)/100) * 1)
		
		local target = originPosition * CFrame.new(randomx, randomy, 0)
		local movement = TweenService:Create(camera, TweenInfo.new(2), {CFrame = target})
		movement:Play()
		movement.Completed:Wait()
	end
end

local function DisableAllCameras()
	DisableFollowUp()
	camera.CameraType = Enum.CameraType.Follow
end

CameraRemote.OnClientEvent:Connect(function(cameraType, CameraCFrame)
	if cameraType == "coOp" then
		CoopCamera(CameraCFrame)
	elseif cameraType == "FollowUp" then
		followUp()
    elseif cameraType == "disable" then
        DisableAllCameras()
	end
end)