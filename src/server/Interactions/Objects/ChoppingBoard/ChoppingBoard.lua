local ChoppingBoard = {}

local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local Assets = ServerStorage:WaitForChild("Assets")
local Foods = Assets:WaitForChild("Foods")
local ChoppedFoods = Foods:WaitForChild("ChoppedFoods")

local Modules = ServerStorage:WaitForChild("Modules")
local CoreFunctions = ServerScriptService:WaitForChild("Server"):WaitForChild("CoreFunctions")
local InteractionScriptsFolder = ServerScriptService:WaitForChild("Server"):WaitForChild("Interactions")

local Cache = require(Modules:WaitForChild("Systems"):WaitForChild("Cache"))
local CountertopModule = require(InteractionScriptsFolder:WaitForChild("Objects"):WaitForChild("Countertop"):WaitForChild("Countertop"))
local Welds = require(CoreFunctions:WaitForChild("Welds"))

local ChoppingProgress = Cache.RegisterCache(`{script.Name}_ChoppingProgress`)
local isBeingChopped = Cache.RegisterCache(`{script.Name}_isBeingChopped`)

local ProgressAmount = 10
local ChopDelay = .5

function ChoppingBoard.Interact(player, objectCarried, choppingBoard)
    CountertopModule.Interact(player, objectCarried, choppingBoard)
end

function ChoppingBoard.Use(player, objectCarried, choppingBoard, heldState)
    local objectOnTop = Welds.isObjectOnTop(choppingBoard)

    if objectOnTop then
        if heldState then
            local chopped = ChoppedFoods:FindFirstChild(`chopped_{(objectOnTop.Name)}`)
            if chopped then
                isBeingChopped[objectOnTop] = true
                ChoppingProgress[objectOnTop] = ChoppingProgress[objectOnTop] or 0
                while isBeingChopped[objectOnTop] and ChoppingProgress[objectOnTop] < 100 do
                    ChoppingProgress[objectOnTop] += ProgressAmount
                    --print(ChoppingProgress[objectOnTop])
                    task.wait(ChopDelay)
                end
                if ChoppingProgress[objectOnTop] and ChoppingProgress[objectOnTop] >= 100 then
                    ChoppingProgress[objectOnTop] = nil
                    Welds.unweldObjectOnTop(choppingBoard)
                    objectOnTop:Destroy()
                    chopped = chopped:Clone()
                    chopped:WaitForChild("InteractionPrompt").Enabled = false
                    chopped.Parent = workspace:FindFirstChild("$FoodContainers")
                    Welds.PlaceObjectOnTop(chopped, choppingBoard)
                end
            end
        else
            isBeingChopped[objectOnTop] = nil
        end
    end
end

return ChoppingBoard