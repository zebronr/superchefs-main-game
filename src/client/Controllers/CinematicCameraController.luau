--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")
local UserInputService = game:GetService("UserInputService")

local CameraController = require(script.Parent.CameraController)
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local tuning = Config.CinematicCamera
local keys = tuning.Keys
local player = Players.LocalPlayer

local CinematicCameraController = {}
local enabled = false
local paused = false
local frozenCFrame: CFrame? = nil
local mode = "Free"
local targetPlayer: Player? = nil
local angleIndex = 1
local held: { [Enum.KeyCode]: boolean } = {}
local oldMouseBehavior = Enum.MouseBehavior.Default
local oldMouseIcon = true
local baseSpeed = tuning.BaseSpeed
local velocity = Vector3.zero
local position = Vector3.zero
local lookPoint = Vector3.zero
local yaw = 0
local pitch = 0
local wantedYaw = 0
local wantedPitch = 0
local targetYaw = 0
local orbit = 0
local fov = Config.Character.CameraFov
local desiredFov = fov
local zoomOffset = 0
local wideCenter: Vector3? = nil
local wideRadius = 0
local hiddenGuis: { [ScreenGui]: boolean } = {}
local coreGui: { [Enum.CoreGuiType]: boolean } = {}
local hudHidden = false
local guiConnections: { [ScreenGui]: RBXScriptConnection } = {}
local descendantConnection: RBXScriptConnection? = nil

function CinematicCameraController.IsActive(): boolean
	return enabled
end

local function ease(rate: number, dt: number): number
	return 1 - math.exp(-rate * dt)
end

local function activeTargets(): { Player }
	local list: { Player } = {}
	for _, other in Players:GetPlayers() do
		if other:GetAttribute(tuning.Attribute) ~= true and other.Character ~= nil then
			table.insert(list, other)
		end
	end
	return list
end

local function watchGui(gui: ScreenGui): ()
	if guiConnections[gui] then
		return
	end
	guiConnections[gui] = gui:GetPropertyChangedSignal("Enabled"):Connect(function(): ()
		if hudHidden and gui.Enabled then
			hiddenGuis[gui] = true
			gui.Enabled = false
		end
	end)
	if gui.Enabled then
		hiddenGuis[gui] = true
		gui.Enabled = false
	end
end

local function setHudHidden(hide: boolean): ()
	hudHidden = hide
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if hide then
		if playerGui ~= nil then
			for _, child in playerGui:GetDescendants() do
				if child:IsA("ScreenGui") then
					watchGui(child)
				end
			end
			descendantConnection = playerGui.DescendantAdded:Connect(function(child: Instance): ()
				if child:IsA("ScreenGui") then
					watchGui(child)
				end
			end)
		end
		for _, kind in Enum.CoreGuiType:GetEnumItems() do
			if kind ~= Enum.CoreGuiType.All then
				local ok, wasEnabled = pcall(function(): boolean
					return StarterGui:GetCoreGuiEnabled(kind)
				end)
				if ok then
					coreGui[kind] = wasEnabled
				end
			end
		end
		pcall(function(): ()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
		end)
	else
		if descendantConnection ~= nil then
			descendantConnection:Disconnect()
			descendantConnection = nil
		end
		for gui, connection in guiConnections do
			connection:Disconnect()
			guiConnections[gui] = nil
		end
		for gui in hiddenGuis do
			if gui.Parent ~= nil then
				gui.Enabled = true
			end
		end
		table.clear(hiddenGuis)
		for kind, wasEnabled in coreGui do
			pcall(function(): ()
				StarterGui:SetCoreGuiEnabled(kind, wasEnabled)
			end)
		end
		table.clear(coreGui)
	end
end

local function hudIsHidden(): boolean
	return hudHidden
end

local function findWideBounds(): ()
	wideCenter = nil
	wideRadius = 0
	local container = workspace:FindFirstChild("$GAME")
	if container == nil then
		return
	end
	local map: Instance? = nil
	for _, child in container:GetChildren() do
		if child:FindFirstChild("MapBarrier") ~= nil or child:FindFirstChild("Objects") ~= nil then
			map = child
			break
		end
	end
	if map == nil then
		return
	end
	local edge = map:FindFirstChild("MapBarrier")
	local source = if edge ~= nil and edge:FindFirstChildWhichIsA("BasePart", true) ~= nil then edge else map
	local low: Vector3? = nil
	local high: Vector3? = nil
	for _, child in source:GetDescendants() do
		if child:IsA("BasePart") and (source == edge or child.Transparency < 1) then
			local cf = child.CFrame
			local half = child.Size / 2
			local extent = Vector3.new(
				math.abs(cf.XVector.X) * half.X + math.abs(cf.YVector.X) * half.Y + math.abs(cf.ZVector.X) * half.Z,
				math.abs(cf.XVector.Y) * half.X + math.abs(cf.YVector.Y) * half.Y + math.abs(cf.ZVector.Y) * half.Z,
				math.abs(cf.XVector.Z) * half.X + math.abs(cf.YVector.Z) * half.Y + math.abs(cf.ZVector.Z) * half.Z
			)
			low = if low then low:Min(cf.Position - extent) else cf.Position - extent
			high = if high then high:Max(cf.Position + extent) else cf.Position + extent
		end
	end
	if low ~= nil and high ~= nil then
		wideCenter = (low + high) / 2
		wideRadius = math.max((high - low).Magnitude / 2, tuning.OrbitRadius)
	elseif map:IsA("Model") then
		local cf, size = map:GetBoundingBox()
		wideCenter = cf.Position
		wideRadius = math.max(size.Magnitude / 2, tuning.OrbitRadius)
	end
end

local function defaultFov(): number
	if mode == "Wide" then
		return tuning.WideFov
	elseif mode == "Focus" then
		return tuning.Angles[angleIndex].Fov
	end
	return Config.Character.CameraFov
end

local function setMode(nextMode: string): ()
	if nextMode == "Free" and mode ~= "Free" then
		local camera = workspace.CurrentCamera
		if camera ~= nil then
			position = camera.CFrame.Position
			lookPoint = position + camera.CFrame.LookVector
			yaw = math.atan2(-camera.CFrame.LookVector.X, -camera.CFrame.LookVector.Z)
			pitch = math.asin(math.clamp(camera.CFrame.LookVector.Y, -1, 1))
			wantedYaw = yaw
			wantedPitch = pitch
			velocity = Vector3.zero
		end
	end
	mode = nextMode
	zoomOffset = 0
	desiredFov = defaultFov()
	if mode == "Wide" then
		findWideBounds()
	end
end

local function step(dt: number): ()
	local camera = workspace.CurrentCamera
	if camera == nil then
		return
	end
	camera.CameraType = Enum.CameraType.Scriptable
	if paused then
		camera.CFrame = frozenCFrame or camera.CFrame
		camera.FieldOfView = fov
		return
	end
	local typing = UserInputService:GetFocusedTextBox() ~= nil
	local zoom = if typing then 0 else (if held[keys.ZoomOut] then 1 else 0) - (if held[keys.ZoomIn] then 1 else 0)
	zoomOffset = math.clamp(zoomOffset + zoom * tuning.ZoomSpeed * dt, tuning.MinFov - defaultFov(), tuning.MaxFov - defaultFov())
	desiredFov = math.clamp(defaultFov() + zoomOffset, tuning.MinFov, tuning.MaxFov)
	fov += (desiredFov - fov) * ease(tuning.FovSmoothing, dt)
	-- Free cam: the mouse stays locked in the middle and hidden, and moving it looks around. Set every frame, since
	-- Roblox's own camera scripts reset the mouse; let go while typing so chat works.
	local mouseLook = mode == "Free" and not typing
	UserInputService.MouseBehavior = if mouseLook then Enum.MouseBehavior.LockCenter else Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = not mouseLook
	if mode == "Free" then
		if not typing then
			local lookSpeed = tuning.LookSpeed * (if held[keys.SlowModifier] then tuning.SlowLookMultiplier else 1)
			wantedYaw += ((if held[keys.LookLeft] then 1 else 0) - (if held[keys.LookRight] then 1 else 0)) * lookSpeed * dt
			wantedPitch = math.clamp(wantedPitch + ((if held[keys.LookUp] then 1 else 0) - (if held[keys.LookDown] then 1 else 0)) * lookSpeed * dt, -tuning.PitchLimit, tuning.PitchLimit)
		end
		yaw += (wantedYaw - yaw) * ease(tuning.LookSmoothing, dt)
		pitch += (wantedPitch - pitch) * ease(tuning.LookSmoothing, dt)
		local flat = CFrame.Angles(0, yaw, 0)
		local forward = flat.LookVector
		local right = flat.RightVector
		local direction = if typing then Vector3.zero else forward * ((if held[keys.Forward] then 1 else 0) - (if held[keys.Backward] then 1 else 0))
			+ right * ((if held[keys.Right] then 1 else 0) - (if held[keys.Left] then 1 else 0))
			+ Vector3.yAxis * ((if held[keys.Up] then 1 else 0) - (if held[keys.Down] then 1 else 0))
		local modifier = if held[keys.FastModifier] then tuning.FastMultiplier elseif held[keys.SlowModifier] then tuning.SlowMultiplier else 1
		local targetVelocity = (if direction.Magnitude > 0 then direction.Unit else Vector3.zero) * baseSpeed * modifier
		velocity = velocity:Lerp(targetVelocity, ease(tuning.MoveSmoothing, dt))
		position += velocity * dt
		lookPoint = position + CFrame.Angles(0, yaw, 0).LookVector * math.cos(pitch) + Vector3.yAxis * math.sin(pitch)
	else
		local wantedPosition: Vector3? = nil
		local wantedLook: Vector3? = nil
		local up = Vector3.yAxis
		if mode == "Focus" then
			local character = if targetPlayer then targetPlayer.Character else nil
			local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
			if root ~= nil and root:IsA("BasePart") then
				local target = root.Position
				local rootYaw = math.atan2(-root.CFrame.LookVector.X, -root.CFrame.LookVector.Z)
				local difference = (rootYaw - targetYaw + math.pi) % (2 * math.pi) - math.pi
				targetYaw += difference * ease(tuning.LookSmoothing, dt)
				local shot = tuning.Angles[angleIndex]
				local orientation = CFrame.Angles(0, targetYaw, 0)
				if shot.Orbit then
					orbit += tuning.OrbitSpeed * dt
					wantedPosition = target + Vector3.new(math.cos(orbit) * tuning.OrbitRadius, tuning.OrbitHeight, math.sin(orbit) * tuning.OrbitRadius)
				elseif shot.World then
					wantedPosition = target + Config.Levels.GetCameraOffset()
				else
					wantedPosition = target + orientation:VectorToWorldSpace(shot.Offset)
				end
				wantedLook = target + (if shot.World then shot.LookOffset else orientation:VectorToWorldSpace(shot.LookOffset))
				up = shot.Up or Vector3.yAxis
			end
		elseif wideCenter ~= nil then
			orbit += tuning.WideOrbitSpeed * dt
			local radius = wideRadius * tuning.WideMargin / math.tan(math.rad(tuning.WideFov / 2))
			wantedPosition = wideCenter + Vector3.new(math.cos(orbit) * radius, radius * tuning.WideHeight, math.sin(orbit) * radius)
			wantedLook = wideCenter
		end
		if wantedPosition ~= nil and wantedLook ~= nil then
			position = position:Lerp(wantedPosition, ease(tuning.PositionSmoothing, dt))
			lookPoint = lookPoint:Lerp(wantedLook, ease(tuning.LookSmoothing, dt))
		end
		if (lookPoint - position).Magnitude < tuning.MinLookDistance then
			lookPoint = position + Vector3.zAxis
		end
		camera.CFrame = CFrame.lookAt(position, lookPoint, up)
		camera.FieldOfView = fov
		return
	end
	camera.CFrame = CFrame.lookAt(position, lookPoint)
	camera.FieldOfView = fov
end

local function toggle(on: boolean): ()
	if enabled == on then
		return
	end
	local camera = workspace.CurrentCamera
	if on and camera == nil then
		return
	end
	enabled = on
	Net.Event("CinematicCamera"):FireServer("Toggle", on)
	if on then
		local start = (camera :: Camera).CFrame
		oldMouseBehavior = UserInputService.MouseBehavior
		oldMouseIcon = UserInputService.MouseIconEnabled
		position = start.Position
		lookPoint = position + start.LookVector
		yaw = math.atan2(-start.LookVector.X, -start.LookVector.Z)
		pitch = math.asin(math.clamp(start.LookVector.Y, -1, 1))
		wantedYaw = yaw
		wantedPitch = pitch
		fov = camera.FieldOfView
		velocity = Vector3.zero
		paused = false
		frozenCFrame = nil
		orbit = 0
		setMode("Free")
		CameraController.SetSuspended(true)
		setHudHidden(true)
		RunService:BindToRenderStep("CinematicCamera", Enum.RenderPriority.Camera.Value + 1, step)
	else
		RunService:UnbindFromRenderStep("CinematicCamera")
		table.clear(held)
		UserInputService.MouseBehavior = oldMouseBehavior
		UserInputService.MouseIconEnabled = oldMouseIcon
		if hudIsHidden() then
			setHudHidden(false)
		end
		if camera ~= nil then
			camera.FieldOfView = Config.Character.CameraFov
		end
		CameraController.SetSuspended(false)
	end
end

function CinematicCameraController.Start(_self: typeof(CinematicCameraController)): ()
	local allowed = table.find(tuning.UserIds, player.UserId) ~= nil
	local command = TextChatService:WaitForChild(tuning.Command) :: TextChatCommand
	command.Enabled = allowed
	if not allowed then
		return
	end
	command.Triggered:Connect(function(source: TextSource): ()
		if source.UserId == player.UserId then
			toggle(not enabled)
		end
	end)
	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean): ()
		if not enabled or gameProcessed then
			return
		end
		local key = input.KeyCode
		held[key] = true
		if key == keys.Free then
			setMode("Free")
		elseif key == keys.Wide then
			setMode("Wide")
		elseif key == keys.NextTarget then
			local targets = activeTargets()
			if #targets > 0 then
				local index = 0
				for candidateIndex, candidate in targets do
					if candidate == targetPlayer then
						index = candidateIndex
						break
					end
				end
				local delta = if held[keys.PreviousModifier] then -1 else 1
				if index == 0 and delta < 0 then
					index = 1
				end
				targetPlayer = targets[(index + delta - 1) % #targets + 1]
				setMode("Focus")
			end
		elseif key == keys.NextAngle and mode == "Focus" then
			local delta = if held[keys.PreviousModifier] then -1 else 1
			angleIndex = (angleIndex + delta - 1) % #tuning.Angles + 1
			setMode("Focus")
		elseif key == keys.SpeedDown then
			baseSpeed = math.max(tuning.MinSpeed, baseSpeed / tuning.SpeedStep)
		elseif key == keys.SpeedUp then
			baseSpeed = math.min(tuning.MaxSpeed, baseSpeed * tuning.SpeedStep)
		elseif key == keys.ResetFov then
			zoomOffset = 0
		elseif key == keys.HideHud then
			setHudHidden(not hudIsHidden())
		elseif key == keys.Pause then
			paused = not paused
			frozenCFrame = if paused and workspace.CurrentCamera ~= nil then (workspace.CurrentCamera :: Camera).CFrame else nil
		elseif key == keys.PauseTimer then
			Net.Event("CinematicCamera"):FireServer("PauseTimer", ReplicatedStorage:GetAttribute("RoundPausedLeft") == nil)
		end
		for index, focusKey in keys.Focus do
			if key == focusKey then
				local targets = activeTargets()
				if index <= #targets then
					targetPlayer = targets[index]
					setMode("Focus")
				end
				break
			end
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject): ()
		held[input.KeyCode] = nil
	end)
	UserInputService.InputChanged:Connect(function(input: InputObject, gameProcessed: boolean): ()
		if not enabled or paused or mode ~= "Free" or gameProcessed or input.UserInputType ~= Enum.UserInputType.MouseMovement then
			return
		end
		local sensitivity = tuning.MouseSensitivity * (if held[keys.SlowModifier] then tuning.SlowLookMultiplier else 1)
		wantedYaw -= input.Delta.X * sensitivity
		wantedPitch = math.clamp(wantedPitch - input.Delta.Y * sensitivity, -tuning.PitchLimit, tuning.PitchLimit)
	end)
end

return CinematicCameraController
