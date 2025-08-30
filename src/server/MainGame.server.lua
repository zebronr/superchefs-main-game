local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Modules")
local Cache = require(Shared:WaitForChild("Cache"))

local Bindables = ServerStorage:WaitForChild("Bindables")
local CompleteOrderBE = Bindables:WaitForChild("CompleteOrder")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local EffectsRemotes = Remotes:WaitForChild("Effects")
local ReadySetGoRE = EffectsRemotes:WaitForChild("ReadySetGo")

local OrderRemotes = Remotes:WaitForChild("OrderRemotes")
local ClearOrdersRE = OrderRemotes:WaitForChild("ClearOrders")
local CacheOrdersRE = OrderRemotes:WaitForChild("CacheOrders")
local AddOrderRE = OrderRemotes:WaitForChild("AddOrder")
local CompleteOrderRE = OrderRemotes:WaitForChild("CompleteOrder")

local CharacterRemotes = Remotes:WaitForChild("Character")
local LoadAnimationRE = CharacterRemotes:WaitForChild("LoadAnimations")

local CameraRemotes = Remotes:WaitForChild("Camera")
local SetCameraRE = CameraRemotes:WaitForChild("SetCamera")

local GameRemotes = Remotes:WaitForChild("Game")
local SetGameUIRE = GameRemotes:WaitForChild("SetGameUI")

local GameInfoRemotes = Remotes:WaitForChild("GameInfo")
local UpdateCoinRE = GameInfoRemotes:WaitForChild("UpdateCoin")
local ResetGameInfoUIRE = GameInfoRemotes:WaitForChild("Reset")
local StartTimerRE = GameInfoRemotes:WaitForChild("StartTimer")
local EndTimerRE = GameInfoRemotes:WaitForChild("EndTimer")

local InteractionsRemotes = Remotes:WaitForChild("Interactions")
local UpdateVisibilityParametersRE = InteractionsRemotes:WaitForChild("UpdateVisibilityParameters")

local Objects = ServerScriptService:WaitForChild("Server"):WaitForChild("Interactions"):WaitForChild("Objects")
local PlateTableModule = require(Objects:WaitForChild("PlateTable"):WaitForChild("PlateTable"))

local LevelsData = script.Parent:WaitForChild("LevelsData")

local teams
local teamHandlingThreads = Cache.RegisterCache(`{script.Name}_teamHandlingThreads`)
local orderThreads = Cache.RegisterCache(`{script.Name}_orderThreads`)
local orderLock = Cache.RegisterCache(`{script.Name}_orderLock`)
local orderNumber = Cache.RegisterCache(`{script.Name}_orderNumber`)

local teamCoins = Cache.RegisterCache(`{script.Name}_teamCoins`)
local teamPoints = Cache.RegisterCache(`{script.Name}_teamPoints`)

local loadedMap
local loadedLevelData

local function setTeams(teamCount, teamOverwrite)
    teams = {} or teamOverwrite

    if not teamOverwrite then
        for i=1, teamCount do
            teams[i] = {}
        end
    else
        return
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

local function findPlayerTeam(player)
    for i, team in pairs(teams) do
        if table.find(team, player) then
            return i
        end
    end
end

---

local function orderSequence(team_i, sequence)
    for i=1, #sequence do
        local l = sequence:sub(i,i)
        if l == "-" then
            print("locking")
            orderLock[team_i] = true
            while orderLock[team_i] do task.wait() end
        elseif l == "*" then
            loadedLevelData.orderDelay *= 2
        elseif l == "/" then
            loadedLevelData.orderDelay /= 2
        else
            for _, player in pairs(teams[team_i]) do
                AddOrderRE:FireClient(player, tonumber(l), {orderNum = orderNumber[team_i]}, tick())
            end
            local cachedOrderNumber = orderNumber[team_i]

            orderThreads[team_i][cachedOrderNumber] = {}
            orderThreads[team_i][cachedOrderNumber].orderId = tonumber(l)
            orderThreads[team_i][cachedOrderNumber].orderNum = orderNumber[team_i]

            orderThreads[team_i][cachedOrderNumber].thread = task.delay(loadedLevelData.recipes[tonumber(l)].time, function()
                print("failed!!", cachedOrderNumber)
                orderThreads[team_i][cachedOrderNumber] = nil

                if not next(orderThreads[team_i]) then
                    orderLock[team_i] = false
                    print("unlocking")
                end
            end)

            orderNumber[team_i] += 1
            task.wait(loadedLevelData.orderDelay)
        end
    end
end

local function startOrders(team_i)
    orderNumber[team_i] = 1
    orderLock[team_i] = nil

    teamHandlingThreads[team_i] = task.spawn(function()
        orderThreads[team_i] = {}

        orderSequence(team_i, loadedLevelData.sequence)

        while true do
            orderSequence(team_i, loadedLevelData.loopSequence)
        end
    end)
end

local function loadMap(level)
    loadedLevelData = require(level:WaitForChild("LevelData"))

    loadedMap = (loadedLevelData.map):Clone()
    loadedMap.Parent = workspace:WaitForChild("$GAME")

    task.wait(3)
    UpdateVisibilityParametersRE:FireAllClients()
end

local function startGame(level, teamOverwrite)
    loadedLevelData = require(level:WaitForChild("LevelData"))

    CacheOrdersRE:FireAllClients(loadedLevelData.recipes)
    print("CACHED")

    setTeams(loadedLevelData.teams, teamOverwrite)
    for team_i, team in pairs(teams) do
        for i, player in pairs(team) do
            local character = player.Character or player.CharacterAdded:Wait()
            local spawner = loadedMap:WaitForChild(`{team_i}_spawn{i}`)
            character:MoveTo(spawner.Position)
        end
    end
    ---
    ReadySetGoRE:FireAllClients()
    task.wait(3)
    StartTimerRE:FireAllClients({
        s = loadedLevelData.levelDuration,
        sT = tick()
    })

    for i, team in pairs(teams) do
        startOrders(i)
    end
end

local function grantCoins(team_i, value)
    teamCoins[team_i] = teamCoins[team_i] or 0

    teamCoins[team_i] += value

    for _, player in pairs(teams[team_i]) do
        UpdateCoinRE:FireClient(player, teamCoins[team_i])
    end
end

local function completeOrder(team_i, food)
    --re arrange orders list
    local orders = orderThreads[team_i]
    local arrangedList = {}
    for _, order in pairs(orders) do
        table.insert(arrangedList, order)
    end
    table.sort(arrangedList, function(a, b)
        return a.orderNum < b.orderNum
    end)
    --

    for _, order in ipairs(arrangedList) do
        print(loadedLevelData.recipes[order.orderId].food_name  , food)
        if loadedLevelData.recipes[order.orderId].food_name == food then
            warn("FOUND EARLIEST OCCURENCE OF ", food, "IN", order.orderNum)

            task.cancel(orderThreads[team_i][order.orderNum].thread)
            orderThreads[team_i][order.orderNum] = nil

            for _, player in pairs(teams[team_i]) do
                CompleteOrderRE:FireClient(player, order.orderNum)
            end

            grantCoins(team_i, 10)

            if not next(orderThreads[team_i]) then
                orderLock[team_i] = false
                print("unlocking because completed")
            end
            return
        end
    end
    warn("NO ORDER OF THE GIVEN FOOD YET")
end

CompleteOrderBE.Event:Connect(function(player, plateContent)
    local team_i = findPlayerTeam(player)

    PlateTableModule.AddPlate(
        loadedMap:WaitForChild("Objects"):WaitForChild("PlateTable"),
        1.5,
        loadedLevelData.enableDirtyPlates
    )

    completeOrder(team_i, plateContent)
end)

task.wait(5)

--testing phase
local selectedLevel = LevelsData:WaitForChild("CoOp"):WaitForChild("Chapter1")

loadMap(selectedLevel)
LoadAnimationRE:FireAllClients()
ResetGameInfoUIRE:FireAllClients(loadedLevelData.levelDuration)

SetCameraRE:FireAllClients("coOp", workspace:WaitForChild("asd").CFrame)
SetGameUIRE:FireAllClients(true)
startGame(selectedLevel)