local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Modules")
local Cache = require(Shared:WaitForChild("Cache"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local OrderRemotes = Remotes:WaitForChild("OrderRemotes")
local ClearOrderRE = OrderRemotes:WaitForChild("ClearOrder")
local CacheOrdersRE = OrderRemotes:WaitForChild("CacheOrders")
local AddOrderRE = OrderRemotes:WaitForChild("AddOrder")

local CameraRemote = Remotes:WaitForChild("CameraRemote")

local LevelsData = script.Parent:WaitForChild("LevelsData")

local teams
local teamHandlingThreads = Cache.RegisterCache(`{script.Name}_teamHandlingThreads`)
local orderThreads = Cache.RegisterCache(`{script.Name}_orderThreads`)

local function setTeams(teamCount, teamOverwrite)
    teams = {} or teamOverwrite

    if not teamOverwrite then
        for i=1, teamCount do
            teams[i] = {}
        end
    end
    
    if teamCount == 1 then
        for _, player in pairs(Players:GetPlayers()) do
            table.insert(teams[1], player)
        end
    else
        local cachedPlayers = Players:GetPlayers()
        while #cachedPlayers > 0 do
            for i, _ in pairs(teams) do
                local r = math.random(1, #cachedPlayers)
                local player = cachedPlayers[r]
    
                table.remove(cachedPlayers, r)
                table.insert(teams[i], player)
                if #cachedPlayers == 0 then break end
            end
            if #cachedPlayers == 0 then break end
        end
    end
    --print(teams)
end

---

local orderLock = false
local orderNumber = 1

local function orderSequence(team_i, sequence, levelData)
    for i=1, #sequence do
        local l = sequence:sub(i,i)
        if l == "-" then
            print("locking")
            orderLock = true
            while orderLock do task.wait() end
        elseif l == "*" then
            levelData.orderDelay *= 2
        elseif l == "/" then
            levelData.orderDelay /= 2
        else
            for _, player in pairs(teams[team_i]) do
                AddOrderRE:FireClient(player, tonumber(l), {orderNum = orderNumber}, tick())
            end
            local cachedOrderNumber = orderNumber
            orderThreads[team_i][orderNumber] = task.delay(levelData.recipes[tonumber(l)].time, function()
                print("failed!!", cachedOrderNumber)
                orderThreads[team_i][cachedOrderNumber] = nil
                if #orderThreads[team_i] <= 0 then
                    print("unlocking")
                    orderLock = false
                end
            end)
            orderNumber += 1
        end
        task.wait(levelData.orderDelay)
    end
end

local function startOrders(team_i, levelData)
    teamHandlingThreads[team_i] = task.spawn(function()
        orderThreads[team_i] = {}

        orderSequence(team_i, levelData.sequence, levelData)

        while true do
            orderSequence(team_i, levelData.loopSequence, levelData)
        end
    end)
end

local function startGame(level, teamOverwrite)
    local levelData = require(level:WaitForChild("LevelData"))

    local map:Folder = (levelData.map):Clone()
    map.Parent = workspace:WaitForChild("$GAME")

    CacheOrdersRE:FireAllClients(levelData.recipes)
    print("CACHED")

    setTeams(levelData.teams, teamOverwrite)
    for team_i, team in pairs(teams) do
        for i, player in pairs(team) do
            local character = player.Character or player.CharacterAdded:Wait()
            local spawner = map:WaitForChild(`{team_i}_spawn{i}`)
            character:MoveTo(spawner.Position)
        end
    end
    ---

    for i, team in pairs(teams) do
        startOrders(i, levelData)
    end
end

task.wait(5)
CameraRemote:FireAllClients("coOp", workspace:WaitForChild("asd").CFrame)
startGame(LevelsData:WaitForChild("CoOp"):WaitForChild("Chapter1"))