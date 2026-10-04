local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local TweenService = game:GetService("TweenService")

local SetCameraRE = Remotes:WaitForChild("Camera"):WaitForChild("SetCamera")

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local camera = game.Workspace.CurrentCamera

local coopenabled = false

local closeupservice
local cachecamerapart

local coopCameraLoadDistance = 15

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

	local xDistance, yDistance, zDistance = 20, 25, 0
	local cameraSpeed = 5

	local FOV = 50

	camera.FieldOfView = FOV

	cameraPart.Anchored = true
	cameraPart.CanTouch = false
	cameraPart.CanCollide = false
	cameraPart.Parent = workspace:WaitForChild("$Temp")
	cameraPart.Name = "CustomCloseCamera"
	cameraPart.CFrame = CFrame.lookAt(root.CFrame.Position + Vector3.new(xDistance, yDistance, zDistance), root.Position)
	cachecamerapart = cameraPart
	camera.CameraType = Enum.CameraType.Scriptable
	
	closeupservice = RunService.PostSimulation:Connect(function(dt)
		cameraPart.Position = cameraPart.Position:Lerp(root.Position + Vector3.new(xDistance, yDistance, zDistance), dt * cameraSpeed)
		camera.CFrame = cameraPart.CFrame	
	end)
end

local function CoopCamera(CameraCFrame, params)
	coopenabled = true
	local FOV = 50
	camera.FieldOfView = FOV
	
	camera.CameraType = Enum.CameraType.Scriptable
	if params.tween then
		local tweenTo = TweenService:Create(camera, TweenInfo.new(params.s), {CFrame = CameraCFrame})
	else
		camera.CFrame = CameraCFrame
	end
	
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

local function CoopCameraLoad(CameraCFrame)
	local FOV = 50
	camera.FieldOfView = FOV

	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CameraCFrame*CFrame.new(0,0,coopCameraLoadDistance)
end

local function DisableAllCameras()
	DisableFollowUp()
	camera.CameraType = Enum.CameraType.Follow
end

SetCameraRE.OnClientEvent:Connect(function(cameraType, CameraCFrame, params)
	if cameraType == "coOp" then
		CoopCamera(CameraCFrame, params)
	elseif cameraType == "coOpLoad" then
		CoopCameraLoad(CameraCFrame)
	elseif cameraType == "FollowUp" then
		followUp()
    elseif cameraType == "disable" then
        DisableAllCameras()
	end
end)