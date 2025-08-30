local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local GameInfo = PlayerGui:WaitForChild("GameInfo")
local InfoFrame = GameInfo:WaitForChild("InfoFrame")
local CoinsFrame = InfoFrame:WaitForChild("CoinsFrame")
local CoinSprite = CoinsFrame:WaitForChild("CoinSprite")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local EffectsRemotes = Remotes:WaitForChild("Effects")
local EffectsRE = EffectsRemotes:WaitForChild("Effects")

local Bindables = ReplicatedStorage:WaitForChild("Bindables")
local EffectsBindable = Bindables:WaitForChild("Effects")

local Assets = ReplicatedStorage:WaitForChild("Assets")
local ProjectileTrail = Assets:WaitForChild("ProjectileTrail")
local CookingFinished = Assets:WaitForChild("CookingFinished")
local BurningWarning = Assets:WaitForChild("BurningWarning")
local FireEmitter = Assets:WaitForChild("FireEmitter")
local DashTrail = Assets:WaitForChild("DashTrail")
local ObjectNotification = Assets:WaitForChild("ObjectNotification")

local EffectsModules = script.Parent.Parent:WaitForChild("EffectsModules")
local GIFModule = require(EffectsModules:WaitForChild("GIFModule"))

local effects = {}

local effectThreads = {}
local effectDelays = {}

local debris = {}

function effects.ProjectileTrail(parameters)
    local root = parameters.r
    local state = parameters.s

    if state then
        local ProjectileTrailClone = ProjectileTrail:Clone()
        ProjectileTrailClone.Parent = root
        
        local a0:Attachment = Instance.new("Attachment")
        local a1:Attachment = Instance.new("Attachment")
        a0.Parent = root
        a1.Parent = root

        a0.Position = Vector3.new(-1,0,0)
        a1.Position = Vector3.new(1,0,0)

        debris[ProjectileTrailClone] = {a0,a1}

        ProjectileTrailClone.Attachment0 = a0
        ProjectileTrailClone.Attachment1 = a1
    else
        local ProjectileTrailClone = root:FindFirstChild("ProjectileTrail")
        if ProjectileTrailClone then
            for _, d in pairs(debris[ProjectileTrailClone]) do
                d:Destroy()
            end
            debris[ProjectileTrailClone] = nil
            task.wait(.5)
            ProjectileTrailClone:Destroy()
        end
    end
end

function effects.burningWarning(parameters)
    local object = parameters.o
    local alertDuration = parameters.aD
    local state = parameters.s

    if state then
        local uiClone = BurningWarning:Clone()
        local image = uiClone:WaitForChild("Image")
        uiClone.Parent = object

        local toggleSpeed = 0.5
        local startTime = tick()
        
        effectThreads[object] = task.spawn(function()
            while tick() - startTime < alertDuration do
                image.Visible = not image.Visible
                task.wait(toggleSpeed)
                toggleSpeed = math.max(0.05, toggleSpeed * 0.8)
            end
            print("Burning on client")
            uiClone:Destroy()
        end)
    else
        local uiClone = object:FindFirstChild("BurningWarning")
        if uiClone then
            uiClone:Destroy()
        end
    end
end

function effects.cookingFinished(parameters)
    local object = parameters.o
    local safeIntervalTime = parameters.sIT
    local alertDuration = parameters.aD
    local state = parameters.s

    if state then
        local uiClone = CookingFinished:Clone()
        local image = uiClone:WaitForChild("Image")
        image.TextTransparency = 1
        uiClone.Parent = object

        local in1 = TweenService:Create(image, TweenInfo.new(.3), {TextTransparency = 0})
        local out1 = TweenService:Create(image, TweenInfo.new(.3), {TextTransparency = 1})

        effectDelays[object] = task.delay(.1+2.5+safeIntervalTime-(.3+.1+2.5), function()
            effects.burningWarning({
                s = true,
                o = object,
                aD = alertDuration
            })
        end)

        task.wait(.1)
        in1:Play()
        in1.Completed:Wait()
        task.wait(2.5)
        out1:Play()
        out1.Completed:Connect(function()
            uiClone:Destroy()
        end)
    else
        local uiClone = object:FindFirstChild("CookingFinished")
        if uiClone then
            uiClone:Destroy()
        end
    end
end

function effects.cancel(parameters)
    local deleteables = {effects.cookingFinished, effects.burningWarning}
    for _, f in pairs(deleteables) do
        f({
            o = parameters.o,
            s = false
        })
    end

    for _, t in pairs(effectThreads) do
        task.cancel(t)
    end

    if effectDelays[parameters.o] then
        task.cancel(effectDelays[parameters.o])
    end
end

function effects.fire(parameters)
    local fireValue = parameters.fV
    local object = parameters.o

    local FireEmitterClone = FireEmitter:Clone()
    FireEmitterClone.Parent = object

    local Weld = Instance.new("Weld")
    Weld.Parent = FireEmitterClone
    Weld.Part0 = object
    Weld.Part1 = FireEmitterClone

    local Emitter:ParticleEmitter = FireEmitterClone:WaitForChild("ParticleEmitter")

    local particleAccumulator = 0 

    local particleSimulation
    particleSimulation = RunService.Heartbeat:Connect(function(dt)
        if not fireValue or not fireValue.Parent then
            particleSimulation:Disconnect()
            FireEmitterClone:Destroy()
            return
        end

        local rate = (fireValue.Value / 100) * Emitter.Rate
        local particlesToEmit = rate * dt
        particleAccumulator += particlesToEmit

        local emitCount = math.floor(particleAccumulator)
        if emitCount > 0 then
            Emitter:Emit(emitCount)
            particleAccumulator -= emitCount
        end
    end)
end

local FEFoamThreads = {}

function effects.FEFoam(parameters)
    local fireExtinguisher = parameters.fe
    local state = parameters.s

    local Emitter = fireExtinguisher:WaitForChild("Emitter"):WaitForChild("ParticleEmitter")

    if state then
        if FEFoamThreads[fireExtinguisher] then
            FEFoamThreads[fireExtinguisher]:Disconnect()
        end

        local particleAccumulator = 0 
        FEFoamThreads[fireExtinguisher] = RunService.Heartbeat:Connect(function(dt)
            local rate = Emitter.Rate
            local particlesToEmit = rate * dt
            particleAccumulator += particlesToEmit
    
            local emitCount = math.floor(particleAccumulator)
            if emitCount > 0 then
                Emitter:Emit(emitCount)
                particleAccumulator -= emitCount
            end
        end)
    else
        if FEFoamThreads[fireExtinguisher] then
            FEFoamThreads[fireExtinguisher]:Disconnect()
        end
    end
end

GIFModule.load(CoinSprite, 40, 6, 7, 24)
GIFModule.loadFrame(CoinSprite, 1)

function effects.spinCoin(parameters)
    GIFModule.playGIF(CoinSprite)
end

local dashTrailLength = 7
local trailMinSize = Vector3.new(1.94, 0.9, 1.675)
local trailMaxSize = Vector3.new(9.054, 4.201, 7.815)

function effects.dash(parameters)
	local ROOT = parameters.pc -- player character
	local state = parameters.s

    ROOT = ROOT:WaitForChild("HumanoidRootPart")
	
	if state then
		local trailCache = {}
		local finalTween
		for i=1, dashTrailLength do
			local trail = DashTrail:Clone()
			trail.Size = Vector3.new(0,0,0)
			trail.Orientation += Vector3.new(0,math.random(0,360), 0)
			trail.Position = ROOT.Position - Vector3.new(0,3,0)
			table.insert(trailCache, trail)
			
			local TSize = trailMaxSize:Lerp(trailMinSize, ((i-1) / (dashTrailLength-1)))
			local inAnimation = TweenService:Create(trail, TweenInfo.new(.2), {Size = TSize})
			local outAnimation = TweenService:Create(trail, TweenInfo.new(.8, Enum.EasingStyle.Exponential), {Size = Vector3.new(0,0,0)})

			trail.Parent = workspace["$Temp"]
			inAnimation:Play()
			task.spawn(function()
				inAnimation.Completed:Wait()
				outAnimation:Play()
			end)
			finalTween = outAnimation
			task.wait(.05)
		end
		finalTween.Completed:Wait()
		for _, cachedTrail in pairs(trailCache) do
			cachedTrail:Destroy()
		end
	end
end

function effects.objectNotif(parameters)
    local object = parameters.o
    local text = parameters.t

    local ui = ObjectNotification:Clone()
    local textLabel = ui:WaitForChild("TextLabel")

    textLabel.Text = text
    ui.Parent = object
    ui.Enabled = true

    local tweenUp = TweenService:Create(textLabel, TweenInfo.new(1.3, Enum.EasingStyle.Linear), {
        Position = UDim2.new(0.5,0,0,0)
    })
    local tweenFade = TweenService:Create(textLabel, TweenInfo.new(.5, Enum.EasingStyle.Linear), {
        TextTransparency = 1
    })

    tweenUp:Play()
    task.wait(.8)
    tweenFade:Play()

    tweenFade.Completed:Wait()
    ui:Destroy()
end

local popUpDebounce = {}

function effects.popUpText(parameters)
    local scale = parameters.sc
    local color = parameters.c
    local speed = parameters.s
    local text = parameters.l

    if popUpDebounce[text] then return end
    popUpDebounce[text] = true

    local originalColor = text.TextColor3
    local originalSize = text.Size

    local enlarge = TweenService:Create(text, TweenInfo.new(speed/2), {
        Size = UDim2.new(text.Size.X.Scale*scale,0,text.Size.Y.Scale*scale,0), 
        TextColor3 = color or originalColor
    })
    local shrink = TweenService:Create(text, TweenInfo.new(speed/2), {
        Size = originalSize, 
        TextColor3 = originalColor
    })

    enlarge:Play()
    enlarge.Completed:Wait()
    shrink:Play()
    shrink.Completed:Wait()
    popUpDebounce[text] = nil
end

EffectsRE.OnClientEvent:Connect(function(effectType, parameters)
    if effects[effectType] then
        effects[effectType](parameters)
    end
end)

EffectsBindable.Event:Connect(function(effectType, parameters)
    if effects[effectType] then
        effects[effectType](parameters)
    end
end)