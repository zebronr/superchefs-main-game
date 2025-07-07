local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

local Bindables = ServerStorage:WaitForChild("Bindables")
local ToggleUseLock = Bindables:WaitForChild("ToggleUseLock")

local Shared = ReplicatedStorage:WaitForChild("Modules")
local Cache = require(Shared:WaitForChild("Cache"))
local PlayerValues = require(Shared:WaitForChild("PlayerValues"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local InteractionRemotes = Remotes:WaitForChild("Interactions")
local InteractionRequest:RemoteEvent = InteractionRemotes:WaitForChild("InteractionRequest")
local InteractionRequestFunction:BindableFunction = InteractionRemotes:WaitForChild("InteractionRequestFunction")

local useLock = Cache.RegisterCache(`{script.Name}_useLock`)
local interactLock = Cache.RegisterCache(`{script.Name}_interactLock`)
local playerLock = Cache.RegisterCache(`{script.Name}_playerLock`)
local requestCooldown = Cache.RegisterCache(`{script.Name}_requestCooldown`)

local maxRequest = 10

local interactableClasses = {"Countertop", "CookingTool", "Food", "Plate", "ChoppingBoard", "Stove", "FireExtinguisher", "DirtyPlate", "Sink", "FoodContainer"}
local useableClasses = {"Countertop", "Tool", "ChoppingBoard", "FireExtinguisher", "Sink"}

local ObjectsFolder = script.Parent:WaitForChild("Objects")

--

local positionMarginOfError = 10

local timeoutMOE = .2

--

local useProximityWatch = {}
local useTimeoutWatch = {}

local functions = {}

local function verifyRequest(parameters)
    local player = parameters.requestOrigin

    requestCooldown[player] = requestCooldown[player] or 0

    if requestCooldown[player] >= maxRequest then
        warn("SENT TOO MUCH REQUEST! RETURNING")
        return
    end

    if playerLock[player] and not parameters.bypassPlayerLock then
        return
    end
    
    requestCooldown[player] += 1
    --print(requestCooldown[player])

    task.delay(.5, function()
        requestCooldown[player] -= 1
        --print(requestCooldown[player])
        if requestCooldown[player] <= 0 then
            requestCooldown[player] = nil
        end
    end)

    local visibleObject = parameters.vO
    local objectCarried = PlayerValues.RetrieveValue(player, "ObjectCarried")
    local interactionPrompt
    
    if visibleObject then
        interactionPrompt = visibleObject:FindFirstChild("InteractionPrompt")
        if (not interactionPrompt) or (not interactionPrompt.Enabled) then
            return false
        end
    end

    local character = player.Character or player.CharacterAdded:Wait()
    local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

    if (visibleObject and interactionPrompt) and ((humanoidRootPart.Position - visibleObject.Position).Magnitude <= interactionPrompt.MaxActivationDistance+positionMarginOfError) then
        return true
    elseif objectCarried then
        return true
    end
    
    return false
end

function functions.Interact(parameters, serverRequest)
    local player = parameters.requestOrigin
    local visibleObject = parameters.vO
    local objectCarried
    if serverRequest then
        objectCarried = parameters.oC or PlayerValues.RetrieveValue(player, "ObjectCarried")
    else
        objectCarried = PlayerValues.RetrieveValue(player, "ObjectCarried")
    end

    if not visibleObject and not objectCarried then return end

    local objectToInteractWith = visibleObject or objectCarried

    if visibleObject and objectCarried then
        if (objectCarried:GetAttribute("interactionPriority") or 1) > (visibleObject:GetAttribute("interactionPriority") or 1) then
            objectToInteractWith = objectCarried
        end
    end
    
    if (not objectToInteractWith) or (useLock[objectToInteractWith]) or interactLock[objectToInteractWith] then return end

    interactLock[objectToInteractWith] = true

    local objectClass = objectToInteractWith:GetAttribute("objectClass")

    local interactionFailed 
    if objectClass and table.find(interactableClasses, objectClass) then
        if ObjectsFolder:FindFirstChild(objectClass) then
            local main = require(ObjectsFolder:WaitForChild(objectClass):WaitForChild(objectClass))
            if main.Interact then
                interactionFailed = main.Interact(player, objectCarried, visibleObject)
            end
        end
    end

    interactLock[objectToInteractWith] = nil

    return interactionFailed
end

function functions.Use(parameters, serverRequest)
    local player = parameters.requestOrigin
    local visibleObject = parameters.vO
    local heldState = parameters.hS
    local objectCarried
    if serverRequest then
        objectCarried = parameters.oC or PlayerValues.RetrieveValue(player, "ObjectCarried")
    else
        objectCarried = PlayerValues.RetrieveValue(player, "ObjectCarried")
    end

    if not objectCarried and not visibleObject then return end

    local objectToUse = objectCarried or visibleObject

    if (not objectToUse) or (useLock[objectToUse] and useLock[objectToUse] ~= player) then return end

    if not heldState then
        playerLock[player] = nil
        useLock[objectToUse] = nil
        if useProximityWatch[objectToUse] then
            useProximityWatch[objectToUse]:Disconnect()
        end
        if useTimeoutWatch[objectToUse] then
            task.cancel(useTimeoutWatch[objectToUse])
        end
    else
        playerLock[player] = true
        useLock[objectToUse] = player
    end

    local objectClass = objectToUse:GetAttribute("objectClass")

    if objectClass and table.find(useableClasses, objectClass) then
        if ObjectsFolder:FindFirstChild(objectClass) then
            local main = require(ObjectsFolder:WaitForChild(objectClass):WaitForChild(objectClass))
            if main.Use then
                if heldState then
                    if main.ProximitySensitive then
                        local character = player.Character or player.CharacterAdded:Wait()
                        local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
                        local objectHolder = humanoidRootPart:FindFirstChild("ObjectHolder")
    
                        if objectHolder then
                            useProximityWatch[objectToUse] = RunService.Heartbeat:Connect(function(dt)
                                objectHolder = humanoidRootPart:FindFirstChild("ObjectHolder")
                                if objectHolder and objectHolder.Part1 == objectToUse and objectToUse then
                                    return
                                end
                                useProximityWatch[objectToUse]:Disconnect()
                                main.Use(player, objectCarried, visibleObject, false)
                            end)
                        else
                            useLock[objectToUse] = nil
                            return
                        end
                    elseif main.UseTimeout then
                        useTimeoutWatch[objectToUse] = task.delay(main.UseTimeout+timeoutMOE, function()
                            main.Use(player, objectCarried, visibleObject, false)
                        end)
                    end
                end

                local interactionFailed = main.Use(player, objectCarried, visibleObject, heldState)
                if interactionFailed then
                    useLock[objectToUse] = nil
                end
            end
        end
    end
end

local function requestInteraction(player, request, parameters, serverRequest)
    parameters = parameters or {}
    parameters.requestOrigin = player

    if request == "Use" and not parameters.hS then
        parameters.bypassPlayerLock = true
    end 

    if functions[request] and (serverRequest or verifyRequest(parameters)) then

        functions[request](parameters, serverRequest)
    end--replace this with the commented snippet below on launch
    --[[local _success, error = pcall(function()
        parameters = parameters or {}
        parameters.requestOrigin = player

        if functions[request] and (serverRequest or verifyRequest(parameters)) then
            functions[request](parameters) 
        end
    end)
    if error then
        warn("=====================================================================")
        warn("ERROR CATCHED FROM INTERACTION REQUEST")
        warn(`REQUEST INFO:`)
        warn(`REQUEST: {request}`)
        warn(`REQUEST FROM: {player}`)
        warn("REQUEST PARAMETERS:")
        warn("---------------")
        for id, value in pairs(parameters) do
            warn(`{id} : {value}`)
        end
        warn("---------------")
        warn(`ERROR INFO: {error}`)
        warn("=====================================================================")
    end]]--
end

InteractionRequest.OnServerEvent:Connect(function(player, request, parameters)
    requestInteraction(player, request, parameters)
end)

InteractionRequestFunction.OnInvoke = function(player, request, parameters)
    local interactionFailed = requestInteraction(player, request, parameters, true)
    return interactionFailed
end

ToggleUseLock.Event:Connect(function(object, state)
    useLock[object] = state
end)