local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Modules = ServerStorage:WaitForChild("Modules")
local Cache = require(Modules:WaitForChild("Systems"):WaitForChild("Cache"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Interactions = Remotes:WaitForChild("Interactions")
local InteractionRequest:RemoteEvent = Interactions:WaitForChild("InteractionRequest")

local playerData = Cache.RegisterCache(`{script.Name}_playerData`)
local useLock = Cache.RegisterCache(`{script.Name}_useLock`)

local interactableClasses = {"Countertop", "CookingTool", "Food", "Plate"}
local useableClasses = {"Countertop", "Tool"}

local ObjectsFolder = script.Parent:WaitForChild("Objects")

--

local positionMarginOfError = 5

--

local functions = {}

local function verifyRequest(parameters)
    local player = parameters.requestOrigin
    local objectCarried = parameters.objectCarried
    local visibleObject = parameters.visibleObject
    local interactionPrompt
    
    if visibleObject then
        interactionPrompt = visibleObject:FindFirstChild("InteractionPrompt")
        if not interactionPrompt:GetAttribute("GloballyEnabled") then
            return false
        end
    end

    local character = player.Character or player.CharacterAdded:Wait()
    local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

    if (visibleObject and interactionPrompt and not objectCarried) and ((humanoidRootPart.Position - visibleObject.Position).Magnitude <= interactionPrompt.MaxActivationDistance+positionMarginOfError) then
        return true
    end

    return false
end

function functions.Interact(parameters)
    local player = parameters.requestOrigin
    local objectCarried = parameters.objectCarried
    local visibleObject = parameters.visibleObject
    
    if (not visibleObject) or (useLock[visibleObject]) then return end

    local objectClass = visibleObject:GetAttribute("objectClass")

    if objectClass and table.find(interactableClasses, objectClass) then
        if ObjectsFolder:FindFirstChild(objectClass) then
            local main = require(ObjectsFolder:WaitForChild(objectClass):WaitForChild(objectClass))
            if main.Interact then
                main.Interact(player, objectCarried, visibleObject)
            end
        end
    end
end

function functions.Use(parameters)
    local player = parameters.requestOrigin
    local objectCarried = parameters.objectCarried
    local visibleObject = parameters.visibleObject
    local heldState = parameters.heldState

    local objectToUse = objectCarried or visibleObject

    if (not objectToUse) or (useLock[objectToUse] and useLock[objectToUse] ~= player) then return end

    if not heldState then
        useLock[objectToUse] = false
    else
        useLock[visibleObject] = player
    end

    local objectClass = objectToUse:GetAttribute("objectClass")

    if objectClass and table.find(useableClasses, objectClass) then
        if ObjectsFolder:FindFirstChild(objectClass) then
            local main = require(ObjectsFolder:WaitForChild(objectClass):WaitForChild(objectClass))
            if main.Use then
                main.Use(player, objectCarried, visibleObject, heldState)
            end
        end
    end
end

InteractionRequest.OnServerEvent:Connect(function(player, request, parameters)
    local _success, error = pcall(function()
        parameters.requestOrigin = player
        if functions[request] and verifyRequest(parameters) then
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
end)