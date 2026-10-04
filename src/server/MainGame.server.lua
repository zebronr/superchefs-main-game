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
local EffectsRE = EffectsRemotes:WaitForChild("Effects")

local OrderRemotes = Remotes:WaitForChild("OrderRemotes")
local ClearOrdersRE = OrderRemotes:WaitForChild("ClearOrders")
local CacheOrdersRE = OrderRemotes:WaitForChild("CacheOrders")
local AddOrderRE = OrderRemotes:WaitForChild("AddOrder")
local CompleteOrderRE = OrderRemotes:WaitForChild("CompleteOrder")

local CameraRemotes = Remotes:WaitForChild("Camera")
local SetCameraRE = CameraRemotes:WaitForChild("SetCamera")

local GameRemotes = Remotes:WaitForChild("Game")
local SetGameUIRE = GameRemotes:WaitForChild("SetGameUI")

local GameInfoRemotes = Remotes:WaitForChild("GameInfo")
local UpdateCoinRE = GameInfoRemotes:WaitForChild("UpdateCoin")
local ResetGameInfoUIRE = GameInfoRemotes:WaitForChild("Reset")
local StartTimerRE = GameInfoRemotes:WaitForChild("StartTimer")
local EndTimerRE = GameInfoRemotes:WaitForChild("EndTimer")

local NPCsRemotes = Remotes:WaitForChild("NPCs")
local LoadPathsRE = NPCsRemotes:WaitForChild("LoadPaths")
local SpawnNPCRE = NPCsRemotes:WaitForChild("SpawnNPC")
local ClearRE = NPCsRemotes:WaitForChild("Clear")

local InteractionsRemotes = Remotes:WaitForChild("Interactions")
local UpdateVisibilityParametersRE = InteractionsRemotes:WaitForChild("UpdateVisibilityParameters")

local Objects = ServerScriptService:WaitForChild("Server"):WaitForChild("Interactions"):WaitForChild("Objects")
local PlateTableModule = require(Objects:WaitForChild("PlateTable"):WaitForChild("PlateTable"))

local CoreFunctions = ServerScriptService:WaitForChild("Server"):WaitForChild("CoreFunctions")
local CharacterLoader = require(CoreFunctions:WaitForChild("CharacterLoader"))
local Welds = require(CoreFunctions:WaitForChild("Welds"))

local LevelsData = script.Parent:WaitForChild("LevelsData")

local teams
local teamHandlingThreads = Cache.RegisterCache(`{script.Name}_teamHandlingThreads`)
local orderThreads = Cache.RegisterCache(`{script.Name}_orderThreads`)
local orderLock = Cache.RegisterCache(`{script.Name}_orderLock`)
local orderNumber = Cache.RegisterCache(`{script.Name}_orderNumber`)
local comboMultiplier = Cache.RegisterCache(`{script.Name}_comboMultiplier`)

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
        local playerNum = table.find(team, player)
        if playerNum then
            return i, playerNum
        end
    end
end

---

local function orderSequence(team_i, sequence)
    for i=1, #sequence do
        local l = sequence:sub(i,i)
        if l == "-" then
            --print("locking")
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
                --print("failed!!", cachedOrderNumber)
                orderThreads[team_i][cachedOrderNumber] = nil

                if not next(orderThreads[team_i]) then
                    orderLock[team_i] = false
                    --print("unlocking")
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

    for _, object in pairs(loadedMap:WaitForChild("Objects"):GetChildren()) do
        local defaultObjectOnTop = object:FindFirstChild("DefObjectOnTop")
        if defaultObjectOnTop then
            local objectOnTop = defaultObjectOnTop.Value
            objectOnTop:SetAttribute("interactionDisabled", true)
            Welds.PlaceObjectOnTop(objectOnTop, object)
            defaultObjectOnTop:Destroy()
        end
    end

    task.wait(3)
    UpdateVisibilityParametersRE:FireAllClients()
end

local function teleportPlayers()
    for team_i, team in pairs(teams) do
        for i, player in pairs(team) do
            local character = player.Character or player.CharacterAdded:Wait()
            local spawner = loadedMap:WaitForChild("SpawnPoints"):WaitForChild(`{team_i}_spawn{i}`)
            character:MoveTo(spawner.Position)
        end
    end
end

local function startGame(level)
    loadedLevelData = require(level:WaitForChild("LevelData"))

    CacheOrdersRE:FireAllClients(loadedLevelData.recipes)
    --print("CACHED")

    
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
        EffectsRE:FireClient(player, "coinNotif", {
            nT = 1,
            cA = value
        })
    end
end

local function completeOrder(team_i, food, parameters)
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
        --print(loadedLevelData.recipes[order.orderId].food_name  , food)
        if loadedLevelData.recipes[order.orderId].food_name == food then
            --warn("FOUND EARLIEST OCCURENCE OF ", food, "IN", order.orderNum)
            
            EffectsRE:FireAllClients("orderFinish", {
                o = parameters.servingCounter
            })

            task.cancel(orderThreads[team_i][order.orderNum].thread)
            orderThreads[team_i][order.orderNum] = nil

            for _, player in pairs(teams[team_i]) do
                CompleteOrderRE:FireClient(player, order.orderNum)
            end

            grantCoins(team_i, 10)

            if not next(orderThreads[team_i]) then
                orderLock[team_i] = false
                --print("unlocking because completed")
            end
            return
        end
    end

    EffectsRE:FireAllClients("objError", {
        o = parameters.servingCounter
    })
    EffectsRE:FireClient(parameters.player, "objectNotif", {
        t = "NO ORDER YET!",
        o = parameters.servingCounter
    })
    --warn("NO ORDER OF THE GIVEN FOOD YET")
end

local npcsRunning = false

local function NPCLoop(state)
    if state then
        npcsRunning = true
        task.spawn(function()
            while npcsRunning do
                task.wait(2)
                local starters = loadedMap:WaitForChild("NPCWaypoints"):WaitForChild("Starters")
                SpawnNPCRE:FireAllClients(starters:GetChildren()[math.random(1,#starters:GetChildren())])
            end
        end)
    else
        npcsRunning = state
    end
end

CompleteOrderBE.Event:Connect(function(player, plateContent, parameters)
    local team_i = findPlayerTeam(player)

    PlateTableModule.AddPlate(
        loadedMap:WaitForChild("Objects"):WaitForChild(`PlateTable_{team_i}`),
        1.5,
        loadedLevelData.enableDirtyPlates
    )

    parameters.player = player
    completeOrder(team_i, plateContent, parameters)
end)

--task.wait(5)
--testing phase
Remotes:WaitForChild("TESTING"):WaitForChild("StartGame").OnServerEvent:Connect(function()
    local selectedLevel = LevelsData:WaitForChild("CoOp"):WaitForChild("Chapter1")

    loadMap(selectedLevel)

    setTeams(loadedLevelData.teams)
    print(teams)

    for _, player in pairs(Players:GetPlayers()) do
        local playerTeam, playerNum = findPlayerTeam(player)
        CharacterLoader.loadPlayerChar(player, playerTeam, playerNum)
    end

    teleportPlayers()

    LoadPathsRE:FireAllClients(loadedMap:WaitForChild("NPCWaypoints")) -- NPCS
    NPCLoop(true) -- test

    ResetGameInfoUIRE:FireAllClients(loadedLevelData.levelDuration)
    SetGameUIRE:FireAllClients(true)
    SetCameraRE:FireAllClients("FollowUp", workspace:WaitForChild("asd3").CFrame)

    --task.wait(2)

    --SetCameraRE:FireAllClients("coOp", workspace:WaitForChild("asd3").CFrame, {tween = true, s = .7})

    task.wait(1)

    startGame(selectedLevel)
end)