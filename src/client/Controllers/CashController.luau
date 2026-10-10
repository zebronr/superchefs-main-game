--!strict

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Tags = require(Shared:WaitForChild("Tags"))
local tuning = Config.Customers

type TableView = {
	Visual: MeshPart?,
	CashAt: number?,
	PredictedAt: number?,
	Flight: Flight?,
	CollectedAt: number?,
	MissingAt: number?,
}
type Flight = {
	Part: MeshPart,
	From: Vector3,
	StartedAt: number,
	Duration: number,
	ToUserId: number,
	Index: number,
	Burst: boolean,
	BaseSize: Vector3,
	Model: Model?,
}

local CashController = {}
local localPlayer = Players.LocalPlayer
local template: MeshPart? = nil
local tables: { [BasePart]: TableView } = {}
local flights: { Flight } = {}
local caught: { [Model]: number } = {}
local predictedCatches: { [Model]: number } = {}
local burstPlayed: { [Model]: boolean } = {}

local function destination(userId: number, fallback: Vector3): Vector3
	local player = Players:GetPlayerByUserId(userId)
	local character = if player then player.Character else nil
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root.Position else fallback
end

-- Where the bottom of the cash pile rests on the table top.
local function place(tablePart: BasePart): CFrame
	return tablePart.CFrame * CFrame.new(0, tablePart.Size.Y / 2, 0) * tuning.CashOffset
end

local function newCash(base: CFrame): MeshPart?
	local source = template
	if source == nil then
		return nil
	end
	local part = source:Clone()
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CFrame = base * CFrame.new(0, part.Size.Y / 2, 0)
	part.Parent = workspace
	return part
end

local function fly(part: MeshPart, userId: number, burst: boolean, index: number, startedAt: number?, model: Model?): Flight
	local flight: Flight = {
		Part = part,
		From = part.Position,
		StartedAt = startedAt or workspace:GetServerTimeNow(),
		Duration = tuning.CashFlyTime,
		ToUserId = userId,
		Index = index,
		Burst = burst,
		BaseSize = part.Size,
		Model = model,
	}
	table.insert(flights, flight)
	return flight
end

local function burst(model: Model, userId: number, startedAt: number?): ()
	local root = model:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return
	end
	for index = 1, tuning.CatchBurstCount do
		local part = newCash(CFrame.new(root.Position))
		if part ~= nil then
			part.Size *= tuning.CatchBurstScale
			fly(part, userId, true, index, startedAt, model)
		end
	end
end

function CashController.Predict(target: Instance?): ()
	if target == nil then
		return
	end
	if Tags.IsClass(target, Tags.Runner) then
		local model = target.Parent
		if model ~= nil and model:IsA("Model") and model:GetAttribute("CustomerState") == "Dashing" and predictedCatches[model] == nil then
			predictedCatches[model] = workspace:GetServerTimeNow()
			burstPlayed[model] = true
			burst(model, localPlayer.UserId)
		end
		return
	end
	if not Tags.IsClass(target, Tags.CustomerTable) or not target:IsA("BasePart") then
		return
	end
	local cash = target:GetAttribute("Cash")
	local view = tables[target]
	if typeof(cash) ~= "number" or cash <= 0 or view == nil or view.PredictedAt ~= nil then
		return
	end
	local heldRoot = if localPlayer.Character then localPlayer.Character:FindFirstChild("HumanoidRootPart") else nil
	local holder = if heldRoot then heldRoot:FindFirstChild("ObjectHolder") else nil
	local held = if holder and holder:IsA("WeldConstraint") then holder.Part1 else nil
	local customer = workspace:FindFirstChild("$Temp")
	if held ~= nil and Tags.IsClass(held, Tags.Plate) and customer ~= nil then
		for _, model in customer:GetChildren() do
			if model:IsA("Model") and model:GetAttribute("CustomerState") == "WaitingForFood" then
				local root = model:FindFirstChild("HumanoidRootPart")
				if root ~= nil and root:IsA("BasePart") and (root.Position - target.Position).Magnitude <= Config.Interaction.TargetRadius then
					return
				end
			end
		end
	end
	view.PredictedAt = workspace:GetServerTimeNow()
	if view.Visual ~= nil then
		view.Flight = fly(view.Visual, localPlayer.UserId, false, 0, nil, nil)
		view.Visual = nil
	end
end

local function updateTable(part: BasePart, view: TableView, now: number): ()
	if part.Parent == nil then
		if view.Visual ~= nil then
			view.Visual:Destroy()
		end
		tables[part] = nil
		return
	end
	if not part:IsDescendantOf(workspace) then
		return
	end
	local value = part:GetAttribute("Cash")
	local collectedAt = part:GetAttribute("CashCollectedAt")
	local cashStamp = part:GetAttribute("CashAt")
	local cash = typeof(value) == "number" and value > 0
		and (typeof(collectedAt) ~= "number" or typeof(cashStamp) ~= "number" or cashStamp > collectedAt)
	if typeof(collectedAt) == "number" and collectedAt ~= view.CollectedAt then
		view.CollectedAt = collectedAt
		local by = part:GetAttribute("CashCollectedBy")
		if typeof(by) == "number" then
			if view.Flight ~= nil then
				if view.Flight.Part.Parent ~= nil then
					-- Confirmed: the predicted flight keeps its local timing and only retargets if someone else got it.
					view.Flight.ToUserId = by
				else
					local replacement = newCash(place(part))
					if replacement ~= nil then
						fly(replacement, by, false, 0, collectedAt, nil)
					end
				end
			elseif view.Visual ~= nil then
				fly(view.Visual, by, false, 0, collectedAt, nil)
				view.Visual = nil
			end
		end
		view.PredictedAt = nil
		view.Flight = nil
		view.MissingAt = nil
	end
	if view.PredictedAt ~= nil then
		if now - view.PredictedAt < tuning.PredictTimeout then
			return
		end
		view.PredictedAt = nil
		view.Flight = nil
	end
	if cash then
		view.MissingAt = nil
		local stamp = part:GetAttribute("CashAt")
		local cashAt = if typeof(stamp) == "number" then stamp else nil
		if view.Visual == nil then
			view.Visual = newCash(place(part))
		end
		if view.Visual ~= nil then
			local age = if cashAt then now - cashAt else tuning.CashPopTime
			local progress = math.clamp(age / tuning.CashPopTime, 0, 1)
			local pop = 1 + math.sin(progress * math.pi * tuning.CashPopWaves) * (1 - progress) * tuning.CashPopOvershoot
			local source = template
			if source ~= nil then
				view.Visual.Size = source.Size * pop
			end
			view.Visual.CFrame = place(part) * CFrame.new(0, view.Visual.Size.Y / 2, 0)
		end
		view.CashAt = cashAt
	elseif view.Visual ~= nil then
		local missingAt = view.MissingAt or now
		view.MissingAt = missingAt
		if ReplicatedStorage:GetAttribute("RoundState") ~= "Playing" or now - missingAt >= tuning.PredictTimeout then
			view.Visual:Destroy()
			view.Visual = nil
		end
	end
end

local function updateFlights(now: number): ()
	for index = #flights, 1, -1 do
		local flight = flights[index]
		local alpha = math.clamp((now - flight.StartedAt) / flight.Duration, 0, 1)
		if alpha >= 1 or flight.Part.Parent == nil then
			flight.Part:Destroy()
			table.remove(flights, index)
		else
			local to = destination(flight.ToUserId, flight.From)
			local angle = flight.Index * (2 * math.pi / tuning.CatchBurstCount)
			local offset = if flight.Burst then Vector3.new(math.cos(angle), 0, math.sin(angle)) * tuning.CatchBurstSpeed * math.sin(alpha * math.pi) else Vector3.zero
			local height = (if flight.Burst then tuning.CatchBurstSpeed else tuning.CashFlyHeight) * math.sin(alpha * math.pi)
			flight.Part.CFrame = CFrame.new(flight.From:Lerp(to, alpha) + offset + Vector3.new(0, height, 0))
			flight.Part.Size = flight.BaseSize * math.max(0.01, 1 - alpha)
		end
	end
end

function CashController.Start(_self: typeof(CashController)): ()
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local customers = if assets then assets:FindFirstChild("Customers") else nil
	local found = if customers then customers:FindFirstChild("Cash") else nil
	if found ~= nil and found:IsA("MeshPart") then
		template = found
	else
		warn("ReplicatedStorage.Assets.Customers.Cash is missing (MeshPart)")
	end
	local function track(instance: Instance): ()
		if instance:IsA("BasePart") and tables[instance] == nil then
			tables[instance] = { Visual = nil, CashAt = nil, PredictedAt = nil, Flight = nil, CollectedAt = nil, MissingAt = nil }
		end
	end
	CollectionService:GetInstanceAddedSignal(Tags.ClassTag(Tags.CustomerTable)):Connect(track)
	for _, instance in CollectionService:GetTagged(Tags.ClassTag(Tags.CustomerTable)) do
		track(instance)
	end
	RunService.Heartbeat:Connect(function(): ()
		local now = workspace:GetServerTimeNow()
		for part, view in tables do
			updateTable(part, view, now)
		end
		local temp = workspace:FindFirstChild("$Temp")
		if temp ~= nil then
			for _, child in temp:GetChildren() do
				if child:IsA("Model") then
					local stamp = child:GetAttribute("CaughtAt")
					if typeof(stamp) == "number" and caught[child] ~= stamp then
						caught[child] = stamp
						local by = child:GetAttribute("CaughtBy")
						if typeof(by) == "number" then
							if not burstPlayed[child] then
								burstPlayed[child] = true
								burst(child, by, stamp)
							else
								for _, flight in flights do
									if flight.Model == child then
										flight.ToUserId = by
									end
								end
							end
						end
						predictedCatches[child] = nil
					end
				end
			end
		end
		for model, predictedAt in predictedCatches do
			if now - predictedAt >= tuning.PredictTimeout then
				predictedCatches[model] = nil
				for index = #flights, 1, -1 do
					if flights[index].Model == model then
						flights[index].Part:Destroy()
						table.remove(flights, index)
					end
				end
			end
		end
		for model in burstPlayed do
			if model.Parent == nil then
				burstPlayed[model] = nil
				caught[model] = nil
				predictedCatches[model] = nil
			end
		end
		updateFlights(now)
	end)
end

return CashController
