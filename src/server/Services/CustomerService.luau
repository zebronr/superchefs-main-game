--!strict

local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Item = require(script.Parent.Parent.Classes.Item)
local CustomerTable = require(script.Parent.Parent.Classes.Stations.CustomerTable)
local PlateTable = require(script.Parent.Parent.Classes.Stations.PlateTable)
local LevelService = require(script.Parent.LevelService)
local OrderService = require(script.Parent.OrderService)
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local InteractionConfig = Config.Interaction
local Levels = Config.Levels
local RoundConfig = Config.Round
local CustomerConfig = Config.Customers
local Net = require(Shared:WaitForChild("Net"))

type CustomerState = CustomerTable.CustomerState

type Session = {
	Model: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	Table: CustomerTable.CustomerTable,
	Interface: CustomerTable.Customer,
	Team: number,
	Generation: number,
	State: CustomerState,
	Recipe: Config.Recipe?,
	OrderNumber: number?,
	Thread: thread?,
}

local CustomerService = {}
local BIND_TIMEOUT = 5
local dirtyPlateTemplate = ServerStorage:WaitForChild("Assets"):WaitForChild("Plates"):WaitForChild("DirtyPlate")

local activeGeneration: number? = nil
local sessions: { [Model]: Session } = {}
local sessionCount = 0

local function isActive(session: Session): boolean
	return activeGeneration == session.Generation and session.Model.Parent ~= nil
end

-- Read through a call so the type checker does not narrow a state other threads change.
local function stateOf(session: Session): CustomerState
	return session.State
end

local function setState(session: Session, state: CustomerState): ()
	session.State = state
	session.Model:SetAttribute("CustomerState", state)
end

local function setPatience(session: Session, startedAt: number?, duration: number?): ()
	session.Model:SetAttribute("PatienceStartedAt", startedAt)
	session.Model:SetAttribute("PatienceDuration", duration)
end

local function clearTable(session: Session): ()
	if CustomerTable.GetCustomer(session.Table) == session.Interface then
		CustomerTable.SetCustomer(session.Table, nil)
	end
end

local function release(session: Session): ()
	if sessions[session.Model] == session then
		sessions[session.Model] = nil
		sessionCount -= 1
	end
	clearTable(session)
end

local function moveTo(humanoid: Humanoid, position: Vector3, timeout: number): boolean
	local finished = false
	local reached = false
	local connection = humanoid.MoveToFinished:Connect(function(didReach: boolean): ()
		finished = true
		reached = didReach
	end)
	humanoid:MoveTo(position)
	local deadline = os.clock() + timeout
	while not finished and os.clock() < deadline and humanoid.Parent ~= nil do
		task.wait(0.05)
	end
	connection:Disconnect()
	return finished and reached
end

local function computePath(startPosition: Vector3, endPosition: Vector3): { PathWaypoint }?
	local path = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 6, AgentCanJump = false })
	local success = pcall(function(): ()
		path:ComputeAsync(startPosition, endPosition)
	end)
	if not success or path.Status ~= Enum.PathStatus.Success then
		return nil
	end
	return path:GetWaypoints()
end

local function flatDistance(from: Vector3, to: Vector3): number
	return (Vector3.new(from.X, 0, from.Z) - Vector3.new(to.X, 0, to.Z)).Magnitude
end

local function loadWalkTrack(humanoid: Humanoid): AnimationTrack?
	local animator: Animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = humanoid
	local animation = Instance.new("Animation")
	animation.AnimationId = CustomerConfig.WalkAnimation
	local track = animator:LoadAnimation(animation)
	animation:Destroy()
	track.Looped = true
	return track
end

-- Walks along a computed path, or straight at the target when no path exists. True once close to the target.
local function walkTo(session: Session, target: Vector3): boolean
	local humanoid = session.Humanoid
	local track = loadWalkTrack(humanoid)
	if track ~= nil then
		track:Play()
	end

	local waypoints = computePath(session.Root.Position, target)
	if waypoints ~= nil then
		for _, waypoint in waypoints do
			if not isActive(session) then
				break
			end
			moveTo(humanoid, waypoint.Position, CustomerConfig.WaypointTimeout)
		end
	end
	if isActive(session) and flatDistance(session.Root.Position, target) > CustomerConfig.ArriveDistance then
		moveTo(humanoid, target, CustomerConfig.WaypointTimeout * 2)
	end

	if track ~= nil then
		track:Stop()
	end
	return isActive(session) and flatDistance(session.Root.Position, target) <= CustomerConfig.ArriveDistance
end

local function findSpawn(): BasePart?
	local map = LevelService.GetMap()
	local spawnPart = if map then map:FindFirstChild("CustomerSpawn") else nil
	if spawnPart ~= nil and spawnPart:IsA("BasePart") then
		return spawnPart
	end
	return nil
end

local function leave(session: Session, angry: boolean): ()
	setState(session, "Leaving")
	setPatience(session, nil, nil)
	session.Root.Anchored = false
	if angry then
		Net.Event("Effect"):FireAllClients("ObjError", session.Table.Instance)
	end
	-- The table stays occupied only by whatever is on its slot (the dirty plate).
	clearTable(session)
	local spawnPart = findSpawn()
	if spawnPart ~= nil and isActive(session) then
		walkTo(session, spawnPart.Position)
	end
	release(session)
	session.Model:Destroy()
end

-- Swaps the served plate for a dirty one, or returns a clean one to the plate table.
local function finishEating(session: Session): ()
	local customerTable = session.Table
	local onTop = customerTable.Slot:Take()
	if onTop ~= nil then
		onTop.Instance:Destroy()
	end
	if Levels.GetCurrent().EnableDirtyPlates then
		local clone = dirtyPlateTemplate:Clone()
		clone.Parent = workspace:FindFirstChild("$GAME") or workspace
		local plate = Item.Await(clone, BIND_TIMEOUT)
		if
			plate == nil
			or not isActive(session)
			or not customerTable.Alive
			or not customerTable.Instance:IsDescendantOf(workspace)
			or not customerTable.Slot:Place(plate)
		then
			clone:Destroy()
		end
		return
	end
	local generation = session.Generation
	local team = session.Team
	task.delay(InteractionConfig.PlateReturnDelay, function(): ()
		if activeGeneration ~= generation then
			return
		end
		local plateTable = PlateTable.ForTeam(team)
		if plateTable == nil then
			warn(`Could not return plate: PlateTable_{team} is missing`)
			return
		end
		PlateTable.AddPlate(plateTable, false)
	end)
end

local function takeOrder(session: Session): ()
	if stateOf(session) ~= "WaitingToOrder" or not isActive(session) then
		return
	end
	local recipes = Levels.GetCurrent().Recipes
	local recipe = recipes[math.random(#recipes)]
	local number = OrderService.Open(session.Team, recipe.Id, function(): ()
		-- The ticket expired: the customer gives up.
		if stateOf(session) == "WaitingForFood" then
			setState(session, "Leaving")
		end
	end)
	if number == nil then
		return
	end
	session.Recipe = recipe
	session.OrderNumber = number
	session.Model:SetAttribute("Recipe", recipe.Id)
	setPatience(session, workspace:GetServerTimeNow(), recipe.Time)
	setState(session, "WaitingForFood")
end

local function serveCustomer(session: Session): ()
	local number = session.OrderNumber
	if stateOf(session) ~= "WaitingForFood" or number == nil then
		return
	end
	OrderService.Close(session.Team, number, true, session.Table.Instance)
	setPatience(session, nil, nil)
	setState(session, "Eating")
end

local function run(session: Session, tuning: Config.CustomerTuning): ()
	local seat = CustomerTable.GetSeat(session.Table)
	if seat == nil then
		warn(`{session.Table.Instance:GetFullName()} has no Seat`)
		release(session)
		session.Model:Destroy()
		return
	end

	walkTo(session, seat.Position)
	if not isActive(session) then
		return
	end
	-- Sit at the table: face it and stay put.
	session.Model:MoveTo(seat.Position)
	local tablePosition = session.Table.Part.Position
	local rootPosition = session.Root.Position
	session.Root.CFrame = CFrame.lookAt(rootPosition, Vector3.new(tablePosition.X, rootPosition.Y, tablePosition.Z))
	session.Root.Anchored = true

	setState(session, "WaitingToOrder")
	local startedAt = workspace:GetServerTimeNow()
	setPatience(session, startedAt, tuning.OrderPatience)
	while
		isActive(session)
		and stateOf(session) == "WaitingToOrder"
		and workspace:GetServerTimeNow() - startedAt < tuning.OrderPatience
	do
		task.wait(CustomerConfig.Poll)
	end
	if not isActive(session) then
		return
	end
	if stateOf(session) == "WaitingToOrder" then
		leave(session, true)
		return
	end

	while isActive(session) and stateOf(session) == "WaitingForFood" do
		task.wait(CustomerConfig.Poll)
	end
	if not isActive(session) then
		return
	end
	if stateOf(session) ~= "Eating" then
		leave(session, true)
		return
	end

	task.wait(tuning.EatDuration.Min + math.random() * (tuning.EatDuration.Max - tuning.EatDuration.Min))
	if not isActive(session) then
		return
	end
	finishEating(session)
	if not isActive(session) then
		return
	end
	leave(session, false)
end

local function spawnCustomer(customerTable: CustomerTable.CustomerTable, tuning: Config.CustomerTuning, generation: number): ()
	local temp = workspace:FindFirstChild("$Temp")
	local spawnPart = findSpawn()
	local choices = ReplicatedStorage:WaitForChild("NPCs"):GetChildren()
	if temp == nil or spawnPart == nil or #choices == 0 then
		warn("Cannot spawn a customer: $Temp, CustomerSpawn or NPC templates are missing")
		return
	end
	local template = choices[math.random(#choices)]
	if not template:IsA("Model") then
		return
	end
	local model = template:Clone()
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	if humanoid == nil or root == nil or not root:IsA("BasePart") then
		model:Destroy()
		return
	end

	local session: Session
	local interface: CustomerTable.Customer = {
		GetState = function(): CustomerState
			return session.State
		end,
		GetDish = function(): string?
			local recipe = session.Recipe
			return if recipe then recipe.Name else nil
		end,
		TakeOrder = function(): ()
			takeOrder(session)
		end,
		Serve = function(): ()
			serveCustomer(session)
		end,
	}
	session = {
		Model = model,
		Humanoid = humanoid,
		Root = root,
		Table = customerTable,
		Interface = interface,
		Team = CustomerConfig.Team,
		Generation = generation,
		State = "Walking",
		Recipe = nil,
		OrderNumber = nil,
		Thread = nil,
	}
	model:SetAttribute("CustomerState", "Walking")
	model:SetAttribute("Team", CustomerConfig.Team)
	CustomerTable.SetCustomer(customerTable, interface)
	sessions[model] = session
	sessionCount += 1

	session.Thread = task.spawn(function(): ()
		model.Parent = temp
		model:MoveTo(spawnPart.Position)
		-- Server-owned so physics never depends on a client.
		pcall(function(): ()
			root:SetNetworkOwner(nil)
		end)
		run(session, tuning)
	end)
end

function CustomerService.Stop(): ()
	activeGeneration = nil
	local models: { Model } = {}
	for model in sessions do
		table.insert(models, model)
	end
	for _, model in models do
		local session = sessions[model]
		if session == nil then
			continue
		end
		local thread = session.Thread
		-- An eating customer may be parked in Item.Await, which resumes its thread later; that thread
		-- ends on its own at the next isActive check because the model is destroyed below.
		if
			thread ~= nil
			and thread ~= coroutine.running()
			and coroutine.status(thread) == "suspended"
			and stateOf(session) ~= "Eating"
		then
			task.cancel(thread)
		end
		release(session)
		model:Destroy()
	end
end

function CustomerService.StartRound(generation: number): ()
	CustomerService.Stop()
	if RoundConfig.ServeMode ~= "Manual" then
		return
	end
	local tuning = Levels.GetCurrent().Customers
	if tuning == nil then
		warn("Manual serve mode needs Customers tuning on the level")
		return
	end
	activeGeneration = generation
	task.spawn(function(): ()
		while activeGeneration == generation do
			local tables = CustomerTable.All()
			if sessionCount < math.min(tuning.MaxCustomers, #tables) then
				local free: { number } = {}
				for index, customerTable in tables do
					if CustomerTable.IsFree(customerTable :: any) then
						table.insert(free, index)
					end
				end
				if #free > 0 then
					spawnCustomer(tables[free[math.random(#free)]], tuning, generation)
				end
			end
			task.wait(tuning.SpawnInterval)
		end
	end)
end

return CustomerService
