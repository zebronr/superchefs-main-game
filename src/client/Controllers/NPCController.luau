--!strict

local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

type Route = { { PathWaypoint } }
type Starter = { Position: Vector3, Routes: { Route } }

local NPCController = {}
local npcTemplates = ReplicatedStorage:WaitForChild("NPCs")
local paths: { [string]: Starter } = {}
local activeNPCs: { [Model]: thread } = {}
local generation = 0
local mappedWaypoints: Instance? = nil

local function calculatePath(startPosition: Vector3, endPosition: Vector3): { PathWaypoint }?
	local path = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 6, AgentCanJump = false })
	local success = pcall(function(): ()
		path:ComputeAsync(startPosition, endPosition)
	end)
	if not success or path.Status ~= Enum.PathStatus.Success then
		return nil
	end
	return path:GetWaypoints()
end

local function clearNPCs(): ()
	generation += 1
	paths = {}
	mappedWaypoints = nil
	for npc, runner in activeNPCs do
		if coroutine.status(runner) == "suspended" then
			task.cancel(runner)
		end
		npc:Destroy()
		activeNPCs[npc] = nil
	end
end

local function buildPaths(waypoints: Instance, token: number): ()
	local starters = waypoints:FindFirstChild("Starters")
	local fillers = waypoints:FindFirstChild("Fillers")
	if starters == nil or fillers == nil then
		return
	end
	local built: { [string]: Starter } = {}
	for _, starter in starters:GetChildren() do
		if token ~= generation then
			return
		end
		if not starter:IsA("BasePart") then
			continue
		end
		local endValue = starter:FindFirstChild("EndPoint")
		local endPoint = if endValue ~= nil and endValue:IsA("ObjectValue") then endValue.Value else nil
		if endPoint == nil or not endPoint:IsA("BasePart") then
			continue
		end
		local routes: { Route } = {}
		if string.find(starter.Name, "_direct") ~= nil then
			local direct = calculatePath(starter.Position, endPoint.Position)
			if direct ~= nil then
				table.insert(routes, { direct })
			end
		else
			for _, filler in fillers:GetChildren() do
				if token ~= generation then
					return
				end
				if filler:IsA("BasePart") then
					local first = calculatePath(starter.Position, filler.Position)
					local second = calculatePath(filler.Position, endPoint.Position)
					if first ~= nil and second ~= nil then
						table.insert(routes, { first, second })
					end
				end
			end
		end
		if #routes > 0 then
			built[starter.Name] = { Position = starter.Position, Routes = routes }
		end
	end
	if token == generation and waypoints:IsDescendantOf(workspace) then
		paths = built
	end
end

local function findWaypoints(container: Instance): Instance?
	for _, map in container:GetChildren() do
		local waypoints = map:FindFirstChild("NPCWaypoints")
		if waypoints ~= nil then
			return waypoints
		end
	end
	return nil
end

local function refreshMap(container: Instance): ()
	local waypoints = findWaypoints(container)
	if waypoints == mappedWaypoints then
		return
	end
	clearNPCs()
	mappedWaypoints = waypoints
	if waypoints ~= nil then
		local token = generation
		task.spawn(buildPaths, waypoints, token)
	end
end

local function walkTo(humanoid: Humanoid, position: Vector3, token: number): boolean
	local finished = false
	local reached = false
	local connection = humanoid.MoveToFinished:Connect(function(didReach: boolean): ()
		finished = true
		reached = didReach
	end)
	humanoid:MoveTo(position)
	local deadline = os.clock() + 5
	while not finished and os.clock() < deadline and token == generation and humanoid.Parent ~= nil do
		task.wait(0.05)
	end
	connection:Disconnect()
	return finished and reached and token == generation
end

local function spawnNPC(starterName: string): ()
	local starter = paths[starterName]
	local choices = npcTemplates:GetChildren()
	local temp = workspace:FindFirstChild("$Temp")
	if starter == nil or #choices == 0 or temp == nil then
		return
	end
	local template = choices[math.random(#choices)]
	if not template:IsA("Model") then
		return
	end
	local npc = template:Clone()
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		npc:Destroy()
		return
	end
	local token = generation
	local route = starter.Routes[math.random(#starter.Routes)]
	local runner = task.spawn(function(): ()
		npc.Parent = temp
		npc:MoveTo(starter.Position)
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if animator ~= nil then
			local animation = Instance.new("Animation")
			animation.AnimationId = "rbxassetid://74792532038099"
			local track = animator:LoadAnimation(animation)
			track.Looped = true
			track:Play()
			animation:Destroy()
		end
		for _, segment in route do
			for _, waypoint in segment do
				if not walkTo(humanoid, waypoint.Position, token) then
					npc:Destroy()
					activeNPCs[npc] = nil
					return
				end
			end
		end
		task.wait(1)
		npc:Destroy()
		activeNPCs[npc] = nil
	end)
	activeNPCs[npc] = runner
end

function NPCController.Start(_self: typeof(NPCController)): ()
	local container = workspace:WaitForChild("$GAME")
	container.ChildAdded:Connect(function(): ()
		task.defer(refreshMap, container)
	end)
	container.ChildRemoved:Connect(function(): ()
		task.defer(refreshMap, container)
	end)
	refreshMap(container)
	Net.Event("Round").OnClientEvent:Connect(function(message: unknown, value: unknown): ()
		if message == "SpawnNPC" and typeof(value) == "string" then
			spawnNPC(value)
		elseif message == "ClearNPCs" then
			clearNPCs()
			refreshMap(container)
		end
	end)
end

return NPCController
