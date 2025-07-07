local module = {}

local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bindables = ServerStorage:WaitForChild("Bindables")
local ToggleUseLock = Bindables:WaitForChild("ToggleUseLock")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ProgressBarRemote = Remotes:WaitForChild("ProgressBar")

local Assets = ServerStorage:WaitForChild("Assets")
local Foods = Assets:WaitForChild("Foods")
local ChoppedFoods = Foods:WaitForChild("ChoppedFoods")

local Shared = ReplicatedStorage:WaitForChild("Modules")
local CoreFunctions = ServerScriptService:WaitForChild("Server"):WaitForChild("CoreFunctions")
local InteractionScriptsFolder = ServerScriptService:WaitForChild("Server"):WaitForChild("Interactions")

local Cache = require(Shared:WaitForChild("Cache"))
local CountertopModule = require(InteractionScriptsFolder:WaitForChild("Objects"):WaitForChild("Countertop"):WaitForChild("Countertop"))
local Welds = require(CoreFunctions:WaitForChild("Welds"))

local ChoppingProgress = Cache.RegisterCache(`{script.Name}_ChoppingProgress`)
local isBeingChopped = Cache.RegisterCache(`{script.Name}_isBeingChopped`)
local Debounce = Cache.RegisterCache(`{script.Name}_Debounce`)

local ProgressAmount = 20
local ChopDelay = .3    

module.UseTimeout = (100/ProgressAmount)*ChopDelay

function module.Interact(player, objectCarried, choppingBoard)
    CountertopModule.Interact(player, objectCarried, choppingBoard)
end

function module.Use(player, objectCarried, choppingBoard, heldState)
    local objectOnTop = Welds.isObjectOnTop(choppingBoard)

    if objectOnTop then
        if heldState then
            if Debounce[objectOnTop] then return end
            Debounce[objectOnTop] = true
            choppingBoard:AddTag("LOCKED")

            local chopped = ChoppedFoods:FindFirstChild(`chopped_{(objectOnTop.Name)}`)
            if chopped then
                isBeingChopped[objectOnTop] = true
                ChoppingProgress[objectOnTop] = ChoppingProgress[objectOnTop] or 0
                ProgressBarRemote:FireAllClients("ChoppingProgress", {
                    s = true, cD = ChopDelay, pPC = ProgressAmount, o = objectOnTop, sT = tick()
                })
                while ChoppingProgress[objectOnTop] and isBeingChopped[objectOnTop] and ChoppingProgress[objectOnTop] < 100 do
                    ChoppingProgress[objectOnTop] += ProgressAmount
                    --print(ChoppingProgress[objectOnTop])
                    task.wait(ChopDelay)
                end
                if ChoppingProgress[objectOnTop] and ChoppingProgress[objectOnTop] >= 100 then
                    ProgressBarRemote:FireAllClients("ChoppingProgress", {
                        s = false, o = objectOnTop, d = true
                    })
                    ToggleUseLock:Fire(choppingBoard, nil)
                    ChoppingProgress[objectOnTop] = nil
                    isBeingChopped[objectOnTop] = nil
                    Welds.unweldObjectOnTop(choppingBoard)
                    objectOnTop:Destroy()
                    chopped = chopped:Clone()
                    chopped:WaitForChild("InteractionPrompt").Enabled = false
                    chopped.Parent = workspace:FindFirstChild("$FoodContainers")
                    Welds.PlaceObjectOnTop(chopped, choppingBoard)
                    choppingBoard:RemoveTag("LOCKED")
                end
                Debounce[objectOnTop] = nil
            end
        else
            if (not ChoppingProgress[objectOnTop]) or ChoppingProgress[objectOnTop] < 100 then
                choppingBoard:RemoveTag("LOCKED")
                ProgressBarRemote:FireAllClients("ChoppingProgress", {
                    s = false, o = objectOnTop
                })
                isBeingChopped[objectOnTop] = nil
            end
        end
    end
end

return module