local module = {}

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CoreFunctions = ServerScriptService:WaitForChild("Server"):WaitForChild("CoreFunctions")
local Shared = ReplicatedStorage:WaitForChild("Modules")

local Cache = require(Shared:WaitForChild("Cache"))
local Welds = require(CoreFunctions:WaitForChild("Welds"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local EffectsRemote = Remotes:WaitForChild("Effects")

local spreadRate = 5
local spreadDistance = 5

local burnableObjects = {"Countertop", "ChoppingBoard", "CookingTool", "Stove"}

function module.BurnObject(object)
    if not table.find(burnableObjects, object:GetAttribute("objectClass")) then return end
    local cookingToolEnabled = Cache.Retrieve("CookingTool_ToolEnabled")
    if (object:GetAttribute("objectClass") == "CookingTool") and (not cookingToolEnabled[object] and not object:HasTag("defaultEnabled")) then
        return
    end
    if object:FindFirstChild("fireValue") then return end

    local fireValue = Instance.new("NumberValue")
    fireValue.Name = "fireValue"
    fireValue.Parent = object
    fireValue.Value = 100

    object:AddTag("LOCKED")

    EffectsRemote:FireAllClients("fire", {
        fV = fireValue,
        o = object
    })

    task.spawn(function()
        while fireValue do
            task.wait(spreadRate)
            for _, distanceObject in pairs(workspace:WaitForChild("$GAME"):GetChildren()) do
                local cookingToolEnabled = Cache.Retrieve("CookingTool_ToolEnabled")
                if (distanceObject:GetAttribute("objectClass") == "CookingTool") and (not cookingToolEnabled[distanceObject] and not distanceObject:HasTag("defaultEnabled")) then
                    continue
                end

                if (not table.find(burnableObjects, distanceObject:GetAttribute("objectClass"))) or (distanceObject:FindFirstChild("fireValue")) then
                    continue
                end

                if (distanceObject.Position - object.Position).Magnitude > spreadDistance then
                    continue
                end

                local oOT = Welds.isObjectOnTop(distanceObject)
                if oOT == object or (oOT and table.find(burnableObjects, oOT:GetAttribute("objectClass"))) then
                    continue
                end

                module.BurnObject(distanceObject)
            end
        end
    end)
end

return module