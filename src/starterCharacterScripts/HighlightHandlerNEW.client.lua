local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HRP = Character:WaitForChild("HumanoidRootPart")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local PlayerValues = require(Modules:WaitForChild("PlayerValues"))

local Configs = Modules:WaitForChild("Configs")
local VisibilityConfigs = require(Configs:WaitForChild("VisibilityConfigs"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local UpdateVisibilityParameters = Remotes:WaitForChild("UpdateVisibilityParameters")

local Assets = ReplicatedStorage:WaitForChild("Assets")
local VisibilityHighlight = Assets:WaitForChild("VisibilityHighlight")

local interactableParameters = OverlapParams.new()
interactableParameters.FilterType = Enum.RaycastFilterType.Include
interactableParameters.FilterDescendantsInstances = CollectionService:GetTagged("VISIBLE")

local ProximityRadius = 8
local PriorityWeight = 100

local lastClosest = nil
local closestObject = nil

UpdateVisibilityParameters.OnClientEvent:Connect(function()
    interactableParameters.FilterDescendantsInstances = CollectionService:GetTagged("VISIBLE")
end)

local function toggleObjectHighlight(object, state)
    if not object then return end
    
    if state and not object:FindFirstChild("VisibilityHighlight") then
        PlayerValues.ChangeValues(LocalPlayer, "VisibleObject", object)
        local HighlightClone = VisibilityHighlight:Clone()
        HighlightClone.Parent = object

        for _, p in pairs(object:GetDescendants()) do
            if p:IsA("BasePart") then
                local HighlightClone2 = VisibilityHighlight:Clone()
                HighlightClone2.Parent = p
            end
        end
    elseif not state then
        PlayerValues.ChangeValues(LocalPlayer, "VisibleObject", nil)
        local HighlightClone = object:FindFirstChild("VisibilityHighlight")
        if HighlightClone then
            HighlightClone:Destroy()
        end

        for _, p in pairs(object:GetDescendants()) do
            if p:IsA("BasePart") then
                local HighlightClone2 = p:FindFirstChild("VisibilityHighlight")
                if HighlightClone2 then
                    HighlightClone2:Destroy()
                end
            end
        end
    end
end

RunService.Heartbeat:Connect(function(deltaTime)
    local nearby = workspace:GetPartBoundsInRadius(HRP.Position, ProximityRadius, interactableParameters)
    local bestPart, bestScore = nil, -math.huge

    for _, part in ipairs(nearby) do
        if part:GetAttribute("interactionDisabled") then continue end
        if (part.Position - HRP.Position).Magnitude >= (
            VisibilityConfigs.MinimumDistance[part:GetAttribute("objectClass")] 
            or VisibilityConfigs.DefaultMinimumDistance)
        then
            continue
        end

		local priority = VisibilityConfigs.PriorityLevel[part:GetAttribute("objectClass")] or 1
		local dist = (part.Position - HRP.Position).Magnitude
		local score = priority * PriorityWeight - dist

		if score > bestScore then
			bestScore = score
			bestPart = part
		end
	end

    lastClosest = closestObject
    closestObject = bestPart
    
    if closestObject then
        toggleObjectHighlight(closestObject, true)
        PlayerValues.ChangeValues(LocalPlayer, "VisibleObject", closestObject)
    elseif not closestObject then
        PlayerValues.ChangeValues(LocalPlayer, "VisibleObject", nil)
        toggleObjectHighlight(closestObject, false)
    end

    if closestObject ~= lastClosest then
        toggleObjectHighlight(lastClosest, false)
    end
end)


