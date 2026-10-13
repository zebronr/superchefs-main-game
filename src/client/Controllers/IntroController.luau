--!strict

-- The round's opening shot after START (Config.Round.Cinematic). The server only sends when it began;
-- every client plays it from that time. The presser predicts it at once and adopts the server's time.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CameraController = require(script.Parent.CameraController)
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))

local IntroController = {}
local player = Players.LocalPlayer
local irisGui = player:WaitForChild("PlayerGui"):WaitForChild("IntroIris") :: ScreenGui
local hole = irisGui:WaitForChild("Hole") :: ImageLabel
-- Server time the shot began; nil while no shot plays.
local startedAt: number? = nil
local connection: RBXScriptConnection? = nil
local wideShot: CFrame? = nil

local function backOut(p: number, strength: number): number
	local q = p - 1
	return 1 + (strength + 1) * q ^ 3 + strength * q ^ 2
end

local function quartInOut(p: number): number
	return if p < 0.5 then 8 * p ^ 4 else 1 - (-2 * p + 2) ^ 4 / 2
end

local function findMap(): Instance?
	local container = workspace:FindFirstChild("$GAME")
	if container == nil then
		return nil
	end
	for _, child in container:GetChildren() do
		if child:FindFirstChild("SpawnPoints") ~= nil then
			return child
		end
	end
	return nil
end

-- A wide view of the whole map from the gameplay camera's angle. A BasePart named IntroCamera in the map
-- replaces it with its own CFrame.
local function computeWideShot(): CFrame?
	local map = findMap()
	if map == nil then
		return nil
	end
	local marker = map:FindFirstChild("IntroCamera")
	if marker ~= nil and marker:IsA("BasePart") then
		return marker.CFrame
	end
	-- Bounds of the playable area: the map edge (MapBarrier) when the map has one, so the scenery outside it
	-- doesn't widen the shot; otherwise the visible parts (invisible barriers would stretch the box).
	local edge = map:FindFirstChild("MapBarrier")
	local useEdge = edge ~= nil and edge:FindFirstChildWhichIsA("BasePart", true) ~= nil
	local low: Vector3? = nil
	local high: Vector3? = nil
	for _, part in (if useEdge then (edge :: Instance) else map):GetDescendants() do
		if part:IsA("BasePart") and (useEdge or part.Transparency < 1) then
			local cf = part.CFrame
			local half = part.Size / 2
			local extent = Vector3.new(
				math.abs(cf.XVector.X) * half.X + math.abs(cf.YVector.X) * half.Y + math.abs(cf.ZVector.X) * half.Z,
				math.abs(cf.XVector.Y) * half.X + math.abs(cf.YVector.Y) * half.Y + math.abs(cf.ZVector.Y) * half.Z,
				math.abs(cf.XVector.Z) * half.X + math.abs(cf.YVector.Z) * half.Y + math.abs(cf.ZVector.Z) * half.Z
			)
			low = if low then low:Min(cf.Position - extent) else cf.Position - extent
			high = if high then high:Max(cf.Position + extent) else cf.Position + extent
		end
	end
	if low == nil or high == nil then
		return nil
	end
	local center = (low + high) / 2
	local radius = (high - low).Magnitude / 2 * Config.Round.Cinematic.WideMargin
	local distance = radius / math.tan(math.rad(Config.Character.CameraFov / 2))
	local direction = Config.Levels.GetCameraOffset().Unit
	local flat = Vector3.new(direction.X, 0, direction.Z)
	local aim = if flat.Magnitude > 1e-4 then center + flat.Unit * radius * Config.Round.Cinematic.WideShift else center
	return CFrame.lookAt(aim + direction * distance, aim)
end

local function stop(): ()
	startedAt = nil
	wideShot = nil
	irisGui.Enabled = false
	CameraController.SetShot(nil)
	if connection ~= nil then
		connection:Disconnect()
		connection = nil
	end
end

-- Overlay image height (screen heights) at `t` seconds into the shot; nil once the hole is past the screen.
local function holeScale(t: number): number?
	local tuning = Config.Round.Cinematic
	local peekAt = tuning.BlackHold
	local holdAt = peekAt + tuning.PeekTime
	local zoomAt = holdAt + tuning.PeekHold
	local doneAt = zoomAt + tuning.IrisTime
	if t < peekAt then
		return 0
	elseif t < holdAt then
		return tuning.PeekScale * math.max(backOut((t - peekAt) / tuning.PeekTime, tuning.PeekOvershoot), 0)
	elseif t < zoomAt then
		return tuning.PeekScale
	elseif t < doneAt then
		local p = (t - zoomAt) / tuning.IrisTime
		return tuning.PeekScale + (tuning.IrisScale - tuning.PeekScale) * p ^ 4
	end
	return nil
end

local function step(): ()
	local began = startedAt
	if began == nil then
		return
	end
	local tuning = Config.Round.Cinematic
	local now = workspace:GetServerTimeNow()
	local t = now - began
	if t >= Config.Round.CinematicLength then
		stop()
		return
	end
	local scale = holeScale(t)
	irisGui.Enabled = scale ~= nil
	if scale ~= nil then
		hole.Size = UDim2.fromScale(scale, scale)
	end
	if wideShot == nil then
		wideShot = computeWideShot()
	end
	local wide = wideShot
	if wide == nil then
		CameraController.SetShot(nil)
		return
	end
	local zoomAt = Config.Round.CinematicLength - tuning.ZoomTime
	local alpha = quartInOut(math.clamp((t - zoomAt) / tuning.ZoomTime, 0, 1))
	CameraController.SetShot(function(normal: CFrame): CFrame
		return wide:Lerp(normal, alpha)
	end)
end

local function play(at: number): ()
	startedAt = at
	if connection == nil then
		connection = RunService.RenderStepped:Connect(step)
	end
	step()
end

function IntroController.Start(_self: typeof(IntroController)): ()
	irisGui.Enabled = false
	Net.Event("Round").OnClientEvent:Connect(function(message: unknown, value: unknown): ()
		if message == "Cinematic" and typeof(value) == "number" then
			play(value)
		elseif message == "RoundEnd" then
			stop()
		end
	end)
	ReplicatedStorage:GetAttributeChangedSignal("RoundState"):Connect(function(): ()
		-- Back to Waiting (everyone left) drops the shot.
		if ReplicatedStorage:GetAttribute("RoundState") == "Waiting" then
			stop()
		end
	end)
end

return IntroController
