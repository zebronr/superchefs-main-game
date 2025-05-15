local module = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CoreFunctions = ServerScriptService:WaitForChild("Server"):WaitForChild("CoreFunctions")
local Actions = CoreFunctions:WaitForChild("Actions")
local Shared = ReplicatedStorage:WaitForChild("Modules")

local ObjectsFolder = ServerScriptService:WaitForChild("Server"):WaitForChild("Interactions"):WaitForChild("Objects")

local DirtyPlateModule = require(ObjectsFolder:WaitForChild("DirtyPlate"):WaitForChild("DirtyPlate"))
local ObjectAction = require(Actions:WaitForChild("ObjectAction"))
local Cache = require(Shared:WaitForChild("Cache"))

local dirtyPlatesCount = Cache.RegisterCache(`{script.Name}_dirtyPlatesCount`) 

local function renderDisplayPlates(sink)
    local PlateDisplays = sink:WaitForChild("PlateDisplays")

    local plateCount = dirtyPlatesCount[sink]

    if plateCount <= 0 then
        for _, p in pairs(PlateDisplays:GetChildren()) do
            p.Transparency = 1
        end
    elseif plateCount > 0 then
        for i=1, plateCount do
            if i>3 then
                break   
            end
            PlateDisplays:WaitForChild(tostring(i)).Transparency = 0
        end
    end
end

function module.Interact(player, objectCarried, sink)
    local washPartMartker = sink:WaitForChild("WashPartMarker")
    local drainBoard = sink:WaitForChild("DrainBoard")

    local character = player.Character or player.CharacterAdded:Wait()
    local hrp = character:WaitForChild("HumanoidRootPart")

    if (hrp.Position-washPartMartker.Position).Magnitude < (hrp.Position-drainBoard.Position).Magnitude then
        if objectCarried:GetAttribute("objectClass") == "DirtyPlate" then
            local amount = DirtyPlateModule.countStack(objectCarried)
            dirtyPlatesCount[sink] = dirtyPlatesCount[sink] or 0
            dirtyPlatesCount[sink] += amount

            renderDisplayPlates(sink)

            ObjectAction.DropObject(player, true)
            objectCarried:Destroy()
        end
    else
        --drain board
    end
end

function module.Use(player, objectCarried, sink, heldState)
    local washPartMartker = sink:WaitForChild("WashPartMarker")
    local drainBoard = sink:WaitForChild("DrainBoard")

    local character = player.Character or player.CharacterAdded:Wait()
    local hrp = character:WaitForChild("HumanoidRootPart")

    if (hrp.Position-washPartMartker.Position).Magnitude < (hrp.Position-drainBoard.Position).Magnitude then
        
    end
end

return module