local module = {}

local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bindables = ServerStorage:WaitForChild("Bindables")
local ToggleUseLock = Bindables:WaitForChild("ToggleUseLock")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local EffectsRemotes = Remotes:WaitForChild("Effects")
local ProgressBarRE = EffectsRemotes:WaitForChild("ProgressBar")

local InteractionRemotes = Remotes:WaitForChild("Interactions")
local UpdateVisibilityParametersRE = InteractionRemotes:WaitForChild("UpdateVisibilityParameters")

local CharacterRemotes = Remotes:WaitForChild("Character")
local PlayAnimationRE = CharacterRemotes:WaitForChild("PlayAnimation")
local StopAnimationRE = CharacterRemotes:WaitForChild("StopAnimation")

local Assets = ServerStorage:WaitForChild("Assets")
local Foods = Assets:WaitForChild("Foods")
local ChoppedFoods = Foods:WaitForChild("ChoppedFoods")

local Shared = ReplicatedStorage:WaitForChild("Modules")
local CoreFunctions = ServerScriptService:WaitForChild("Server"):WaitForChild("CoreFunctions")
local InteractionScriptsFolder = ServerScriptService:WaitForChild("Server"):WaitForChild("Interactions")

local ToggleInteraction = require(Shared:WaitForChild("ToggleInteraction"))
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
            if Debounce[objectOnTop] then return end -- added to prevent doubling of loops
            Debounce[objectOnTop] = true
            choppingBoard:AddTag("LOCKED")

            local chopped = ChoppedFoods:FindFirstChild(`chopped_{(objectOnTop.Name)}`)
            if chopped then
                PlayAnimationRE:FireClient(player, "Chop", true)
                isBeingChopped[objectOnTop] = true
                ChoppingProgress[objectOnTop] = ChoppingProgress[objectOnTop] or 0
                ProgressBarRE:FireAllClients("ChoppingProgress", {
                    s = true, cD = ChopDelay, pPC = ProgressAmount, o = objectOnTop, sT = tick()
                })
                while ChoppingProgress[objectOnTop] and isBeingChopped[objectOnTop] and ChoppingProgress[objectOnTop] <= 100 do
                    ChoppingProgress[objectOnTop] += ProgressAmount
                    --print(ChoppingProgress[objectOnTop])
                    if ChoppingProgress[objectOnTop] <= 100 then
                        task.wait(ChopDelay)
                    end
                end
                if ChoppingProgress[objectOnTop] and ChoppingProgress[objectOnTop] > 100 then
                    StopAnimationRE:FireClient(player, "Chop")
                    ProgressBarRE:FireAllClients("ChoppingProgress", {
                        s = false, o = objectOnTop, d = true
                    })
                    ToggleUseLock:Fire(choppingBoard, nil)
                    ChoppingProgress[objectOnTop] = nil
                    isBeingChopped[objectOnTop] = nil
                    Welds.unweldObjectOnTop(choppingBoard)
                    objectOnTop:Destroy()
                    chopped = chopped:Clone()
                    ToggleInteraction.Set(chopped, false)
                    chopped.Parent = workspace:FindFirstChild("$GAME")
                    UpdateVisibilityParametersRE:FireAllClients()
                    Welds.PlaceObjectOnTop(chopped, choppingBoard)
                    choppingBoard:RemoveTag("LOCKED")
                end
                Debounce[objectOnTop] = nil
            end
        else
            StopAnimationRE:FireClient(player, "Chop")
            if (not ChoppingProgress[objectOnTop]) or ChoppingProgress[objectOnTop] <= 100 then
                choppingBoard:RemoveTag("LOCKED")
                ProgressBarRE:FireAllClients("ChoppingProgress", {
                    s = false, o = objectOnTop
                })
                isBeingChopped[objectOnTop] = nil
            end
        end
    end
end

return module