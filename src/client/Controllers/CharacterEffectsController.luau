--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local CharacterConfig = Config.Character
local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

local CharacterEffectsController = {}
local assets = ReplicatedStorage:WaitForChild("Assets")
local effectAssets = assets:WaitForChild("Effects")
local uiAssets = assets:WaitForChild("UI")
local highlightAssets = assets:WaitForChild("Highlights")
local warnedSounds: { [string]: boolean } = {}
local watchers: { [Player]: { RBXScriptConnection } } = {}
local playerConnections: { [Player]: RBXScriptConnection } = {}

local function dashTrail(character: Model): ()
	local root = character:FindFirstChild("HumanoidRootPart")
	local template = effectAssets:FindFirstChild("DashTrail")
	if root == nil or not root:IsA("BasePart") or template == nil or not template:IsA("BasePart") then
		return
	end
	task.spawn(function(): ()
		for index = 1, CharacterConfig.DashTrailCount do
			if root.Parent == nil then
				return
			end
			local trail = template:Clone()
			trail.Size = Vector3.zero
			trail.Orientation += Vector3.new(0, math.random(0, 360), 0)
			trail.Position = root.Position - Vector3.new(0, 3, 0)
			trail.Parent = workspace:FindFirstChild("$Temp") or workspace
			local fraction = (index - 1) / (CharacterConfig.DashTrailCount - 1)
			local size = CharacterConfig.DashTrailMaxSize:Lerp(CharacterConfig.DashTrailMinSize, fraction)
			local grow = TweenService:Create(trail, TweenInfo.new(CharacterConfig.DashTrailGrowTime), { Size = size })
			local shrink = TweenService:Create(trail, TweenInfo.new(CharacterConfig.DashTrailShrinkTime, Enum.EasingStyle.Exponential), { Size = Vector3.zero })
			grow.Completed:Connect(function(): ()
				if trail.Parent ~= nil then
					shrink:Play()
				end
			end)
			shrink.Completed:Connect(function(): ()
				trail:Destroy()
			end)
			grow:Play()
			task.wait(CharacterConfig.DashTrailInterval)
		end
	end)
end

function CharacterEffectsController.PlayLocalDash(): ()
	local character = Players.LocalPlayer.Character
	if character then
		dashTrail(character)
	end
end

local function notify(instance: Instance, message: string): ()
	local template = uiAssets:FindFirstChild("ObjectNotification")
	if template == nil or not template:IsA("BillboardGui") or not instance:IsDescendantOf(workspace) then
		return
	end
	local ui = template:Clone()
	local label = ui:FindFirstChild("TextLabel")
	if label == nil or not label:IsA("TextLabel") then
		ui:Destroy()
		return
	end
	label.Text = message
	ui.Parent = instance
	ui.Enabled = true
	TweenService:Create(label, TweenInfo.new(1.3, Enum.EasingStyle.Linear), {
		Position = UDim2.new(0.5, 0, 0, 0),
	}):Play()
	task.delay(0.8, function(): ()
		if ui.Parent == nil then
			return
		end
		TweenService:Create(label, TweenInfo.new(0.5, Enum.EasingStyle.Linear), {
			TextTransparency = 1,
		}):Play()
	end)
	task.delay(1.3, function(): ()
		ui:Destroy()
	end)
end

local function playSound(name: string): ()
	local folder = SoundService:FindFirstChild("SoundEffects")
	local sound = if folder then folder:FindFirstChild(name) else nil
	if sound ~= nil and sound:IsA("Sound") then
		sound:Play()
	elseif not warnedSounds[name] then
		warnedSounds[name] = true
		warn(`SoundEffects.{name} is missing`)
	end
end

local function watchCharacter(player: Player, character: Model): ()
	local connections = watchers[player]
	if connections then
		for _, connection in connections do
			connection:Disconnect()
		end
	end
	connections = {}
	watchers[player] = connections
	local highlight: Highlight? = nil
	local indicator: BasePart? = nil
	local function refresh(): ()
		local color = character:GetAttribute("PlayerColor")
		if typeof(color) ~= "Color3" then
			return
		end
		if highlight == nil then
			local template = highlightAssets:FindFirstChild("CharacterHighlight")
			if template ~= nil and template:IsA("Highlight") then
				local clone = template:Clone()
				clone.Parent = character
				highlight = clone
			end
		end
		if highlight then
			highlight.OutlineColor = color
		end
		if player == Players.LocalPlayer and indicator == nil then
			local template = effectAssets:FindFirstChild("PlayerIndicator")
			local root = character:FindFirstChild("HumanoidRootPart")
			if template ~= nil and template:IsA("BasePart") and root ~= nil and root:IsA("BasePart") then
				local clone = template:Clone()
				local surface = clone:FindFirstChild("SurfaceGui")
				local image = if surface then surface:FindFirstChild("ImageLabel") else nil
				if image ~= nil and image:IsA("ImageLabel") then
					image.ImageColor3 = color
				end
				clone.Position = root.Position - Vector3.new(0, 3, 0)
				clone.Parent = character
				indicator = clone
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = root
				weld.Part1 = clone
				weld.Parent = root
			end
		end
		if indicator then
			local surface = indicator:FindFirstChild("SurfaceGui")
			local image = if surface then surface:FindFirstChild("ImageLabel") else nil
			if image ~= nil and image:IsA("ImageLabel") then
				image.ImageColor3 = color
			end
		end
	end
	table.insert(connections, character:GetAttributeChangedSignal("PlayerColor"):Connect(refresh))
	table.insert(connections, character:GetAttributeChangedSignal("DashedAt"):Connect(function(): ()
		if player ~= Players.LocalPlayer and typeof(character:GetAttribute("DashedAt")) == "number" then
			dashTrail(character)
		end
	end))
	table.insert(connections, character.Destroying:Connect(function(): ()
		for _, connection in connections do
			connection:Disconnect()
		end
		if watchers[player] == connections then
			watchers[player] = nil
		end
	end))
	refresh()
end

local function watchPlayer(player: Player): ()
	if playerConnections[player] then
		return
	end
	playerConnections[player] = player.CharacterAdded:Connect(function(character: Model): ()
		watchCharacter(player, character)
	end)
	if player.Character then
		watchCharacter(player, player.Character :: Model)
	end
end

function CharacterEffectsController.Start(_self: typeof(CharacterEffectsController)): ()
	Net.Event("Effect").OnClientEvent:Connect(function(kind: unknown, first: unknown, second: unknown): ()
		if kind == "Sound" and typeof(first) == "string" then
			playSound(first)
		elseif kind == "Notify" and typeof(first) == "Instance" and typeof(second) == "string" then
			notify(first, second)
		end
	end)
	Players.PlayerAdded:Connect(watchPlayer)
	Players.PlayerRemoving:Connect(function(player: Player): ()
		local playerConnection = playerConnections[player]
		if playerConnection then
			playerConnection:Disconnect()
			playerConnections[player] = nil
		end
		local connections = watchers[player]
		if connections then
			for _, connection in connections do
				connection:Disconnect()
			end
			watchers[player] = nil
		end
	end)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
end

return CharacterEffectsController
