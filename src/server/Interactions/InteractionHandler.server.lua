local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Modules = ServerStorage:WaitForChild("Modules")
local Cache = require(Modules:WaitForChild("Systems"):WaitForChild("Cache"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local InteractionRemotes = Remotes:WaitForChild("Interactions")
local InteractionRequest:RemoteEvent = InteractionRemotes:WaitForChild("InteractionRequest")
local InteractionRequestFunction:BindableFunction = InteractionRemotes:WaitForChild("InteractionRequestFunction")

local useLock = Cache.RegisterCache(`{script.Name}_useLock`)
local requestCooldown = Cache.RegisterCache(`{script.Name}_requestCooldown`)

local maxRequest = 10

local interactableClasses = {"Countertop", "CookingTool", "Food", "Plate", "ChoppingBoard"}
local useableClasses = {"Countertop", "Tool", "ChoppingBoard"}

local ObjectsFolder = script.Parent:WaitForChild("Objects")

--

local positionMarginOfError = 10

--

local functions = {}

local function verifyRequest(parameters)
    local player = parameters.requestOrigin

    requestCooldown[player] = requestCooldown[player] or 0

    if requestCooldown[player] >= maxRequest then
        warn("SENT TOO MUCH REQUEST! RETURNING")
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

    local objectCarried = parameters.objectCarried
    local visibleObject = parameters.visibleObject
    local interactionPrompt
    
    if visibleObject then
        interactionPrompt = visibleObject:FindFirstChild("InteractionPrompt")
        if not interactionPrompt.Enabled then
            return false
        end
    end

    local character = player.Character or player.CharacterAdded:Wait()
    local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

    if (visibleObject and interactionPrompt) and ((humanoidRootPart.Position - visibleObject.Position).Magnitude <= interactionPrompt.MaxActivationDistance+positionMarginOfError) then
        return true
    elseif (objectCarried and not visibleObject) and (objectCarried == player:WaitForChild("PlayerValues"):WaitForChild("ObjectCarried").Value) then
        print("interacting with an objectCarried")
        return true
    end

    return false
end

function functions.Interact(parameters)
    local player = parameters.requestOrigin
    local objectCarried = parameters.objectCarried
    local visibleObject = parameters.visibleObject

    if not visibleObject and not objectCarried then return end

    local objectToInteractWith = visibleObject or objectCarried

    if visibleObject and objectCarried then
        if (objectCarried:GetAttribute("interactionPriority") or 1) > (visibleObject:GetAttribute("interactionPriority") or 1) then
            objectToInteractWith = objectCarried
        end
    end
    
    if (not objectToInteractWith) or (useLock[objectToInteractWith]) then return end

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
    return interactionFailed
end

function functions.Use(parameters)
    local player = parameters.requestOrigin
    local objectCarried = parameters.objectCarried
    local visibleObject = parameters.visibleObject
    local heldState = parameters.heldState

    if not objectCarried and not visibleObject then return end

    local objectToUse = objectCarried or visibleObject

    if (not objectToUse) or (useLock[objectToUse] and useLock[objectToUse] ~= player) then return end

    if not heldState then
        useLock[objectToUse] = nil
    else
        useLock[objectToUse] = player
    end

    local objectClass = objectToUse:GetAttribute("objectClass")

    if objectClass and table.find(useableClasses, objectClass) then
        if ObjectsFolder:FindFirstChild(objectClass) then
            local main = require(ObjectsFolder:WaitForChild(objectClass):WaitForChild(objectClass))
            if main.Use then
                local interactionFailed = main.Use(player, objectCarried, visibleObject, heldState)
                if interactionFailed then
                    useLock[objectToUse] = nil
                end
            end
        end
    end
end

local function requestInteraction(player, request, parameters, serverRequest)
    local _success, error = pcall(function()
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
    end
end

InteractionRequest.OnServerEvent:Connect(function(player, request, parameters)
    requestInteraction(player, request, parameters)
end)

InteractionRequestFunction.OnInvoke = function(player, request, parameters)
    local interactionFailed = requestInteraction(player, request, parameters, true)
    return interactionFailed
end