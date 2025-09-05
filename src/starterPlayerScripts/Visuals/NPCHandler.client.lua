local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PathfindingService = game:GetService("PathfindingService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local NPCsRemotes = Remotes:WaitForChild("NPCs")
local LoadPathsRE = NPCsRemotes:WaitForChild("LoadPaths")
local SpawnNPCRE = NPCsRemotes:WaitForChild("SpawnNPC")
local ClearRE = NPCsRemotes:WaitForChild("Clear")

local Shared = ReplicatedStorage:WaitForChild("Modules")
local Cache = require(Shared:WaitForChild("Cache"))

local NPCs = ReplicatedStorage:WaitForChild("NPCs")

local loadedPaths = Cache.RegisterCache(`{script.Name}_loadedPaths`)
local loadedStarters
local loadedFillers

local pathSettings = PathfindingService:CreatePath({
    AgentRadius = 2,
	AgentHeight = 6,
	AgentCanJump = false,
})

local function calculatePath(start, finish)
    local succ, err = pcall(function()
        local wayPoint = pathSettings:ComputeAsync(start, finish)
    end)
    if err then
        warn(err)
        return
    end
    return pathSettings:GetWaypoints()
end

local function loadPaths(NPCWaypoints)
    loadedStarters = NPCWaypoints:WaitForChild("Starters")
    loadedFillers = NPCWaypoints:WaitForChild("Fillers")

    for _, starter in pairs(loadedStarters:GetChildren()) do
        local endPoint = starter:WaitForChild("WeldConstraint").Part1

        if string.find(starter.Name, "_direct") then
            loadedPaths[starter] =  {
                [1] = calculatePath(starter.Position, endPoint.Position)
            }
        else
            loadedPaths[starter] = {}
            for _, filler in pairs(loadedFillers:GetChildren()) do
                table.insert(loadedPaths[starter], {
                    [1] = calculatePath(starter.Position, filler.Position),
                    [2] = calculatePath(filler.Position, endPoint.Position)
                })
            end
        end
    end 

    print("paths loaded", loadedPaths)
end

local function spawnNpc(starter, npcName)
    print("spawningNPC")

    local npc = NPCs:GetChildren()[math.random(1,#NPCs:GetChildren())]
    npc = npc:Clone()
    npc.Parent = workspace["$Temp"]
    local humanoid = npc:WaitForChild("Humanoid")

    npc:MoveTo(starter.Position)

    local path

    if string.find(starter.Name, "_direct") then
        path = loadedPaths[starter]
    else
        warn("!",loadedPaths[starter])
        path = loadedPaths[starter][math.random(1,#loadedPaths[starter])]
    end

    for _, p in pairs(path) do
        for _, waypoint in pairs(p) do
            humanoid:MoveTo(waypoint.Position)
            humanoid.MoveToFinished:Wait()
        end
    end

    task.wait(1)
    npc:Destroy()
end

SpawnNPCRE.OnClientEvent:Connect(spawnNpc)
LoadPathsRE.OnClientEvent:Connect(loadPaths)