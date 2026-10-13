--!strict

local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Item = require(script.Parent.Parent.Classes.Item)
local Runner = require(script.Parent.Parent.Classes.Runner)
local CustomerTable = require(script.Parent.Parent.Classes.Stations.CustomerTable)
local PlateTable = require(script.Parent.Parent.Classes.Stations.PlateTable)
local LevelService = require(script.Parent.LevelService)
local OrderService = require(script.Parent.OrderService)
local TeamService = require(script.Parent.TeamService)
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local InteractionConfig = Config.Interaction
local Levels = Config.Levels
local RoundConfig = Config.Round
local CustomerConfig = Config.Customers
local FrozenAttribute = Config.Skills.Attribute.FrozenAt
local Net = require(Shared:WaitForChild("Net"))
local Tags = require(Shared:WaitForChild("Tags"))

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
	PaymentAmount: number?,
	WalkSpeed: number,
	Thread: thread?,
	PatienceStartedAt: number?,
	-- Server time the Penguin's Deep Freeze paused this customer's patience (nil when not frozen).
	FrozenAt: number?,
	-- Rolled at spawn so clients can show the tell (sweat) while the customer sits.
	WillDash: boolean,
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
	CustomerTable.RefreshInteraction(session.Table)
end

local function setPatience(session: Session, startedAt: number?, duration: number?): ()
	session.PatienceStartedAt = startedAt
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

local function flatDistance(from: Vector3, to: Vector3): number
	return (Vector3.new(from.X, 0, from.Z) - Vector3.new(to.X, 0, to.Z)).Magnitude
end

-- Still on the walk that started it: in play and (when given) still in the state the walk is for.
local function stillWalking(session: Session, expectedState: CustomerState?): boolean
	return isActive(session) and (expectedState == nil or stateOf(session) == expectedState)
end

-- Server-owned so physics never depends on a client. Anchoring drops a manual owner, so this runs again every
-- time a customer is unanchored (or the nearest player would take over and the walk would stutter for everyone).
local function claimPhysics(session: Session): ()
	pcall(function(): ()
		session.Root:SetNetworkOwner(nil)
	end)
end

-- Walks at a point until within `reach` studs of it (ignoring height), MoveToFinished, stuck, or the timeout.
-- Checks every frame so the next MoveTo goes out before the Humanoid stops at this one.
local function moveTo(session: Session, position: Vector3, reach: number, timeout: number, expectedState: CustomerState?): ()
	local humanoid = session.Humanoid
	local finished = false
	local connection = humanoid.MoveToFinished:Connect(function(): ()
		finished = true
	end)
	humanoid:MoveTo(position)
	local startedAt = os.clock()
	local checkAt = startedAt
	local checkPosition = session.Root.Position
	while not finished and stillWalking(session, expectedState) do
		local now = os.clock()
		local current = session.Root.Position
		if flatDistance(current, position) <= reach or now - startedAt >= timeout then
			break
		end
		if now - checkAt >= CustomerConfig.StuckTime then
			if flatDistance(current, checkPosition) < CustomerConfig.StuckDistance then
				break
			end
			checkAt = now
			checkPosition = current
		end
		task.wait()
	end
	connection:Disconnect()
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

-- Walks along a computed path, or straight at the target when no path exists. True once close to the target.
-- Passes intermediate waypoints without stopping; only the last one is walked all the way to.
local function walkTo(session: Session, target: Vector3, expectedState: CustomerState?): boolean
	local waypoints = computePath(session.Root.Position, target)
	if waypoints ~= nil then
		for index, waypoint in waypoints do
			if not stillWalking(session, expectedState) then
				break
			end
			local reach = if index < #waypoints then CustomerConfig.WaypointReach else 0
			moveTo(session, waypoint.Position, reach, CustomerConfig.WaypointTimeout, expectedState)
		end
	end
	if stillWalking(session, expectedState) and flatDistance(session.Root.Position, target) > CustomerConfig.ArriveDistance then
		moveTo(session, target, 0, CustomerConfig.WaypointTimeout * 2, expectedState)
	end

	return stillWalking(session, expectedState) and flatDistance(session.Root.Position, target) <= CustomerConfig.ArriveDistance
end

local function findSpawn(): BasePart?
	local map = LevelService.GetMap()
	local spawnPart = if map then map:FindFirstChild("CustomerSpawn") else nil
	if spawnPart ~= nil and spawnPart:IsA("BasePart") then
		return spawnPart
	end
	return nil
end

-- Seated customers are in the seated group (players pass through); standing ones in the walking group.
local function setSeated(session: Session, seated: boolean): ()
	local group = if seated then CustomerConfig.SeatedCollisionGroup else CustomerConfig.CollisionGroup
	for _, part in session.Model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CollisionGroup = group
		end
	end
end

local function leave(session: Session, angry: boolean): ()
	setState(session, "Leaving")
	setPatience(session, nil, nil)
	session.Root.Anchored = false
	claimPhysics(session)
	setSeated(session, false)
	session.Humanoid.WalkSpeed = session.WalkSpeed
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
	end, tonumber(string.match(session.Table.Instance.Name, "(%d+)$")))
	if number == nil then
		return
	end
	session.Recipe = recipe
	session.OrderNumber = number
	session.Model:SetAttribute("Recipe", recipe.Id)
	local now = workspace:GetServerTimeNow()
	setPatience(session, now, recipe.Time)
	setState(session, "WaitingForFood")
	if session.FrozenAt ~= nil then
		-- Taken inside a frost circle: the new ticket starts paused.
		session.FrozenAt = now
		session.Model:SetAttribute(FrozenAttribute, now)
		OrderService.Pause(session.Team, number)
	end
end

local function serveCustomer(session: Session): ()
	local number = session.OrderNumber
	if stateOf(session) ~= "WaitingForFood" or number == nil then
		return
	end
	local level = Levels.GetCurrent()
	local amount = OrderService.Close(session.Team, number, true, session.Table.Instance, not level.EnableTableCash)
	if level.EnableTableCash then
		-- Paid later (combo included): as cash on the table, or by catching them if they run.
		session.PaymentAmount = amount
	end
	setPatience(session, nil, nil)
	setState(session, "Eating")
end

local function setRunner(session: Session, enabled: boolean): ()
	if enabled then
		session.Root:SetAttribute(Tags.ClassAttribute, Tags.Runner)
		CollectionService:AddTag(session.Root, Tags.ClassTag(Tags.Runner))
	else
		CollectionService:RemoveTag(session.Root, Tags.ClassTag(Tags.Runner))
		session.Root:SetAttribute(Tags.ClassAttribute, nil)
	end
end

local function catch(session: Session, player: Player): ()
	local model = session.Model
	setRunner(session, false)
	setState(session, "Caught")
	session.Humanoid:MoveTo(session.Root.Position)
	session.Root.Anchored = true
	-- Clients hide them and show a ragdoll copy, so the real body stops blocking anyone. The Humanoid would
	-- turn its parts' collisions back on, so its state machine stops too.
	session.Humanoid.EvaluateStateMachine = false
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
		end
	end
	OrderService.Pay(TeamService.GetTeam(player), session.PaymentAmount or 0, model)
	model:SetAttribute("CaughtBy", player.UserId)
	model:SetAttribute("CaughtAt", workspace:GetServerTimeNow())
end

-- The Bear's catch: a running dasher caught on the spot (no swing). `byToss` makes the ragdoll fly further.
function CustomerService.CatchRunner(model: Model, player: Player, byToss: boolean): boolean
	local session = sessions[model]
	if session == nil or not isActive(session) or stateOf(session) ~= "Dashing" then
		return false
	end
	if byToss then
		model:SetAttribute(Config.Skills.Attribute.CaughtByToss, true)
	end
	catch(session, player)
	return true
end

-- When each player's last catch swing started (server time).
local swings: { [Player]: number } = {}
Players.PlayerRemoving:Connect(function(player: Player): ()
	swings[player] = nil
end)

-- Interact on a runner swings the bat; the catch lands with the bonk, only if the runner is still in reach then.
Runner.SetCatchHandler(function(model: Model, player: Player): boolean
	local session = sessions[model]
	local character = player.Character
	if session == nil or character == nil or not isActive(session) or stateOf(session) ~= "Dashing" then
		return false
	end
	local swing = Config.Interaction.CatchSwing
	local now = workspace:GetServerTimeNow()
	if now - (swings[player] or -math.huge) < swing.WindTime + swing.SlamTime + swing.HoldTime then
		return false
	end
	local pingOk, ping = pcall(function(): number
		return player:GetNetworkPing()
	end)
	local lag = if pingOk then math.clamp(ping / 2, 0, swing.MaxLagCompensation) else 0
	local startedAt = now - lag
	swings[player] = startedAt
	character:SetAttribute(swing.Attribute, startedAt)
	task.delay(math.max(swing.WindTime + swing.SlamTime - lag, 0), function(): ()
		if swings[player] ~= startedAt or player.Character ~= character or not isActive(session)
			or stateOf(session) ~= "Dashing" then
			return
		end
		local root = character:FindFirstChild("HumanoidRootPart")
		if root ~= nil and root:IsA("BasePart") and (root.Position - session.Root.Position).Magnitude <= swing.HitRange then
			catch(session, player)
		end
	end)
	return true
end)

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
	-- Sit at the table: on top of the seat, facing the table, anchored. Clients play the sit pose.
	local rootPosition = seat.Position + Vector3.new(0, seat.Size.Y / 2 + CustomerConfig.SitHeight, 0)
	local tablePosition = session.Table.Part.Position
	session.Root.Anchored = true
	session.Root.CFrame = CFrame.lookAt(rootPosition, Vector3.new(tablePosition.X, rootPosition.Y, tablePosition.Z))
	setSeated(session, true)

	setState(session, "WaitingToOrder")
	local satAt = workspace:GetServerTimeNow()
	setPatience(session, satAt, tuning.OrderPatience)
	if session.FrozenAt ~= nil then
		-- Frozen on the way in: the patience clock starts paused now, not when they froze.
		session.FrozenAt = satAt
		session.Model:SetAttribute(FrozenAttribute, satAt)
	end
	-- Deep Freeze pauses the clock (FrozenAt) and shifts PatienceStartedAt when it lets go.
	while
		isActive(session)
		and stateOf(session) == "WaitingToOrder"
		and (
			session.FrozenAt ~= nil
			or workspace:GetServerTimeNow() - (session.PatienceStartedAt or 0) < tuning.OrderPatience
		)
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
	if session.PaymentAmount == nil then
		-- Paid when served (table cash is off for this level).
		leave(session, false)
		return
	end
	if session.WillDash then
		setPatience(session, nil, nil)
		setState(session, "Dashing")
		session.Root.Anchored = false
		claimPhysics(session)
		setSeated(session, false)
		session.Humanoid.WalkSpeed = CustomerConfig.DashSpeed
		setRunner(session, true)
		clearTable(session)
		local spawnPart = findSpawn()
		while spawnPart ~= nil and isActive(session) and stateOf(session) == "Dashing" do
			if walkTo(session, spawnPart.Position, "Dashing") then
				break
			end
			task.wait(CustomerConfig.Poll)
		end
		if not isActive(session) then
			return
		end
		if stateOf(session) == "Caught" then
			-- Clients show them ragdolled (a local copy) for CaughtPause, then they're gone.
			task.wait(CustomerConfig.CaughtPause)
			if isActive(session) then
				release(session)
				session.Model:Destroy()
			end
		else
			setRunner(session, false)
			if spawnPart ~= nil then
				Net.Event("Effect"):FireAllClients("ObjError", spawnPart)
			end
			release(session)
			session.Model:Destroy()
		end
		return
	end
	CustomerTable.AddCash(session.Table, session.PaymentAmount or 0)
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
		PaymentAmount = nil,
		WalkSpeed = humanoid.WalkSpeed,
		Thread = nil,
		PatienceStartedAt = nil,
		FrozenAt = nil,
		-- Only customers who pay at the table can run off without paying.
		WillDash = Levels.GetCurrent().EnableTableCash and math.random() < tuning.DashChance,
	}
	model:SetAttribute("CustomerState", "Walking")
	if session.WillDash then
		model:SetAttribute("WillDash", true)
	end
	model:SetAttribute("Team", CustomerConfig.Team)
	CustomerTable.SetCustomer(customerTable, interface)
	sessions[model] = session
	sessionCount += 1

	session.Thread = task.spawn(function(): ()
		model.Parent = temp
		model:MoveTo(spawnPart.Position)
		claimPhysics(session)
		run(session, tuning)
	end)
end

-- Every customer model in play (for FreezeService).
function CustomerService.GetModels(): { Model }
	local models: { Model } = {}
	for model in sessions do
		table.insert(models, model)
	end
	return models
end

-- Deep Freeze: pauses a customer's patience (and their order ticket), or lets it run again.
function CustomerService.SetFrozen(model: Model, frozen: boolean): ()
	local session = sessions[model]
	if session == nil then
		return
	end
	local now = workspace:GetServerTimeNow()
	local number = if stateOf(session) == "WaitingForFood" then session.OrderNumber else nil
	if frozen then
		if session.FrozenAt ~= nil then
			return
		end
		session.FrozenAt = now
		model:SetAttribute(FrozenAttribute, now)
		if number ~= nil then
			OrderService.Pause(session.Team, number)
		end
		return
	end
	local frozenAt = session.FrozenAt
	if frozenAt == nil then
		return
	end
	session.FrozenAt = nil
	model:SetAttribute(FrozenAttribute, nil)
	local startedAt = session.PatienceStartedAt
	local duration = model:GetAttribute("PatienceDuration")
	if startedAt ~= nil and typeof(duration) == "number" then
		setPatience(session, startedAt + (now - frozenAt), duration)
	end
	if number ~= nil then
		OrderService.Resume(session.Team, number)
	end
end

-- Order Rush: takes a waiting customer's order as if a player had walked up. False if they are not waiting.
function CustomerService.TakeOrderFor(model: Model): boolean
	local session = sessions[model]
	if session == nil or stateOf(session) ~= "WaitingToOrder" then
		return false
	end
	takeOrder(session)
	return stateOf(session) == "WaitingForFood"
end

function CustomerService.Stop(): ()
	activeGeneration = nil
	for _, customerTable in CustomerTable.All() do
		CustomerTable.ClearCash(customerTable :: any)
	end
	local models: { Model } = {}
	for model in sessions do
		table.insert(models, model)
	end
	for _, model in models do
		local session = sessions[model]
		if session == nil then
			continue
		end
		if stateOf(session) == "Dashing" then
			setRunner(session, false)
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
