local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
	
local Bindables = ReplicatedStorage:WaitForChild("Bindables")
local PlayerMobility = Bindables:WaitForChild("PlayerMobility")
local EffectsBE = Bindables:WaitForChild("Effects")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local EffectsRequestRE = Remotes:WaitForChild("EffectsRequest")

local actions = {}
local dashLength = .33
local dashStrength = 70

local dashCooldown = dashLength + .1
local onCooldown = false

function actions.dash(parameters)
	if onCooldown then return end
	onCooldown = true
	task.delay(dashCooldown, function()
		onCooldown = false
	end)

    local dashParams = {
        s = true,
        pc = Character
    }
    EffectsRequestRE:FireServer("dash")
    EffectsBE:Fire("dash", dashParams)

	local LinearVelocity = Instance.new("LinearVelocity")
	LinearVelocity.Parent = HumanoidRootPart
	local Attachment = Instance.new("Attachment")
	Attachment.Parent = HumanoidRootPart
	
	LinearVelocity.Attachment0 = Attachment
	LinearVelocity.MaxForce = 30000
	LinearVelocity.VectorVelocity = HumanoidRootPart.CFrame.LookVector * Vector3.new(1,0,1) * dashStrength
	
	local timeElapsed = 0
	local heartbeat
	heartbeat = RunService.Heartbeat:Connect(function(deltaTime)
		LinearVelocity.VectorVelocity = HumanoidRootPart.CFrame.lookVector * Vector3.new(1,0,1) * (dashStrength*.6)
		timeElapsed += deltaTime
		if timeElapsed >= dashLength then
			heartbeat:Disconnect()
		end
	end)
	task.wait(dashLength)
	
	LinearVelocity:Destroy()
	Attachment:Destroy()
end

PlayerMobility.Event:Connect(function(requestType, parameters)
    if actions[requestType] then
        actions[requestType](parameters)
    end
end)