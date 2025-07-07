local module = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Assets = ServerStorage:WaitForChild("Assets")
local Plates = Assets:WaitForChild("Plates")
local Plate = Plates:WaitForChild("Plate")

local CoreFunctions = ServerScriptService:WaitForChild("Server"):WaitForChild("CoreFunctions")
local Actions = CoreFunctions:WaitForChild("Actions")
local Shared = ReplicatedStorage:WaitForChild("Modules")

local PlayerValues = require(Shared:WaitForChild("PlayerValues"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ProgressBarRemote = Remotes:WaitForChild("ProgressBar")

local ObjectsFolder = ServerScriptService:WaitForChild("Server"):WaitForChild("Interactions"):WaitForChild("Objects")

local Welds = require(CoreFunctions:WaitForChild("Welds"))
local DirtyPlateModule = require(ObjectsFolder:WaitForChild("DirtyPlate"):WaitForChild("DirtyPlate"))
local ObjectAction = require(Actions:WaitForChild("ObjectAction"))
local Cache = require(Shared:WaitForChild("Cache"))

local dirtyPlatesCount = Cache.RegisterCache(`{script.Name}_dirtyPlatesCount`)
local washingProgress = Cache.RegisterCache(`{script.Name}_washingProgress`)
local washState = Cache.RegisterCache(`{script.Name}_washState`)

local progressRate = 75
--per second

module.UseTimeout = 100/progressRate

local function renderDisplayPlates(sink)
    local PlateDisplays = sink:WaitForChild("PlateDisplays")

    for i=1, 3 do
        if i <= dirtyPlatesCount[sink] then
            PlateDisplays:WaitForChild(tostring(i)).Transparency = 0
        else
            PlateDisplays:WaitForChild(tostring(i)).Transparency = 1
        end
    end
end

function module.Interact(player, objectCarried, sink)
    local washPartMarker = sink:WaitForChild("WashPartMarker")
    local drainBoard = sink:WaitForChild("DrainBoard")

    local character = player.Character or player.CharacterAdded:Wait()
    local hrp = character:WaitForChild("HumanoidRootPart")

    if (hrp.Position-washPartMarker.Position).Magnitude < (hrp.Position-drainBoard.Position).Magnitude then
        if objectCarried and objectCarried:GetAttribute("objectClass") == "DirtyPlate" then
            local amount = DirtyPlateModule.countStack(objectCarried)
            dirtyPlatesCount[sink] = dirtyPlatesCount[sink] or 0
            dirtyPlatesCount[sink] += amount

            renderDisplayPlates(sink)

            ObjectAction.DropObject(player, true)
            objectCarried:Destroy()
        end
    else
        if PlayerValues.RetrieveValue(player, "ObjectCarried") then
            return
        end

        local originPlate = Welds.isObjectOnTop(drainBoard) 

        if originPlate then
            local plate = DirtyPlateModule.takeHighestPlate(originPlate, true)

            ObjectAction.PickupObject(player, plate)
        end
    end
end

function module.Use(player, objectCarried, sink, heldState)
    local washPartMarker = sink:WaitForChild("WashPartMarker")
    local drainBoard = sink:WaitForChild("DrainBoard")

    local character = player.Character or player.CharacterAdded:Wait()
    local hrp = character:WaitForChild("HumanoidRootPart")

    if (hrp.Position-washPartMarker.Position).Magnitude < (hrp.Position-drainBoard.Position).Magnitude then
        if heldState then
            if dirtyPlatesCount[sink] <= 0 then
                return
            end

            washState[sink] = true
            washingProgress[sink] = washingProgress[sink] or 0

            ProgressBarRemote:FireAllClients("washingProgress", {
                s = true,
                pR = progressRate,
                o = washPartMarker,
                sT = tick(),
                pA = washingProgress[sink],

            })
            while washState[sink] and washingProgress[sink] < 100 do
                local dt = RunService.Heartbeat:Wait()
                washingProgress[sink] += dt * progressRate
            end
            if washingProgress[sink] >= 100 then
                --print("done on server")
                ProgressBarRemote:FireAllClients("washingProgress", {
                    s = false,
                    o = washPartMarker,
                    d = true
                })

                washingProgress[sink] = nil
                dirtyPlatesCount[sink] -= 1

                renderDisplayPlates(sink)

                local PlateClone = Plate:Clone()

                PlateClone.Parent = workspace:WaitForChild("$GAME")
                PlateClone:WaitForChild("InteractionPrompt").Enabled = false

                local originPlate = Welds.isObjectOnTop(drainBoard)
                if originPlate then
                    DirtyPlateModule.stackPlates(originPlate, PlateClone)
                else
                    Welds.PlaceObjectOnTop(PlateClone, drainBoard)
                end
            end
        else
            if (not washingProgress[sink]) or washingProgress[sink] < 100 then
                washState[sink] = nil

                ProgressBarRemote:FireAllClients("washingProgress", {
                    s = false,
                    o = washPartMarker
                })
            end
        end
    end
end

return module