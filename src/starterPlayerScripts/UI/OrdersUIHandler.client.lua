local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local OrderListUI = PlayerGui:WaitForChild("OrderList")
local ListFrame = OrderListUI:WaitForChild("list")

local UIs = ReplicatedStorage:WaitForChild("UIs")
local OrdersUIs = UIs:WaitForChild("OrdersUIs")
local bigFrame = OrdersUIs:WaitForChild("bigFrame")
local smallFrame = OrdersUIs:WaitForChild("smallFrame")
local noprocess1slot = OrdersUIs:WaitForChild("noprocess1slot")
local process1slot = OrdersUIs:WaitForChild("process1slot")
local process2slot = OrdersUIs:WaitForChild("process2slot")
local process3slot = OrdersUIs:WaitForChild("process3slot")

local Shared = ReplicatedStorage:WaitForChild("Modules")
local Cache = require(Shared:WaitForChild("Cache"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local OrderRemotes = Remotes:WaitForChild("OrderRemotes")
local ClearOrdersRE = OrderRemotes:WaitForChild("ClearOrders")
local CacheOrdersRE = OrderRemotes:WaitForChild("CacheOrders")
local CompleteOrderRE = OrderRemotes:WaitForChild("CompleteOrder")
local AddOrderRE = OrderRemotes:WaitForChild("AddOrder")

local positionList = {
    noprocess1slot = {
        big_pos1 = UDim2.new(0.845, 0,0.5, 0),
        big_pos2 = UDim2.new(0.5, 0,0.5, 0),
        big_pos3 = UDim2.new(0.143, 0,0.5, 0),
        big_pos1_2 = UDim2.new(0.802, 0,0.5, 0),
        big_pos2_2 = UDim2.new(0.185, 0,0.5, 0),
        small_pos1 = UDim2.new(0.734, 0,0.5, 0),
        small_pos2 = UDim2.new(0.256, 0,0.5, 0)
    },
    process1slot = {
        big_pos1 = UDim2.new(0.845, 0,0.5, 0),
        big_pos2 = UDim2.new(0.5, 0,0.5, 0),
        big_pos3 = UDim2.new(0.143, 0,0.5, 0),
        small_pos1 = UDim2.new(0.734, 0,0.5, 0),
        small_pos2 = UDim2.new(0.256, 0,0.5, 0)
    },
    process2slot = {
        big_pos1 = UDim2.new(0.678, 0,0.5, 0),
        big_pos2 = UDim2.new(0.311, 0,0.5, 0),
        small_pos1 = UDim2.new(0.5, 0,0.5, 0)
    },
    process3slot = {
        big_pos1 = UDim2.new(0.5, 0,0.5, 0)
    }
}

local smallSizing = {
    noprocess1slot = UDim2.new(0.436, 0,1, 0),
    process1slot = UDim2.new(0.436, 0,1, 0),
    process2slot = UDim2.new(0.81, 0,1.01, 0)
}

local CachedOrders = Cache.RegisterCache(`{script.Name}_CachedImages`)
local orderUIThread = Cache.RegisterCache(`{script.Name}_orderUIThread`)

---
local shakeTimes = 5
local shakeMagnitude = 0.03
local shakeSpeed = 0.05

local function completeOrder(ui, orderNum) --success
    task.cancel(orderUIThread[orderNum])
	local mainFrame = ui:WaitForChild("Frame")

    for _, f:Frame in pairs(mainFrame:GetDescendants()) do
        if f:IsA("ImageLabel") then
            f.ImageColor3 = Color3.fromRGB(150, 210, 166)
        end
    end
    local frameOut = TweenService:Create(mainFrame, TweenInfo.new(.5, Enum.EasingStyle.Back), {Position = UDim2.new(.5,0,-.7,0)})
    frameOut:Play()
    frameOut.Completed:Wait()
    ui:Destroy()
end

local function removeOrder(ui) -- fail
    --print("removing")
    if not ui then print("removing cancelled because ui does not exist"); return end
	local mainFrame = ui:WaitForChild("Frame")
	local defaultPosition = mainFrame.Position

	for i = 1, shakeTimes do
        for _, f:Frame in pairs(mainFrame:GetDescendants()) do
            if f:IsA("ImageLabel") then
                if i % 2 == 0 then
                    f.ImageColor3 = Color3.fromRGB(255,124,124)
                else
                    f.ImageColor3 = Color3.fromRGB(255, 255, 255)
                end
            end
        end

        local tweenInfo = TweenInfo.new(shakeSpeed, Enum.EasingStyle.Linear)

        local tweenRight = TweenService:Create(mainFrame, tweenInfo, {
            Position = defaultPosition + UDim2.new(shakeMagnitude, 0, 0, 0)
        })
        tweenRight:Play()
        tweenRight.Completed:Wait()

        local tweenLeft = TweenService:Create(mainFrame, tweenInfo, {
            Position = defaultPosition - UDim2.new(shakeMagnitude, 0, 0, 0)
        })
        tweenLeft:Play()
        tweenLeft.Completed:Wait()
    end

    local tweenReset = TweenService:Create(mainFrame, TweenInfo.new(shakeSpeed, Enum.EasingStyle.Linear), {
        Position = defaultPosition
    })
    tweenReset:Play()

    local frameOut = TweenService:Create(mainFrame, TweenInfo.new(.4, Enum.EasingStyle.Linear), {Position = UDim2.new(.5,0,-.7,0)})
    frameOut:Play()
    frameOut.Completed:Wait()
    ui:Destroy()
end
---

local function addOrder(data)
    orderUIThread[data.orderNum] = task.spawn(function()
        local stepsWeight = 0

        for _, step in pairs(data.steps) do
            stepsWeight += #step.ingredient_images
        end

        local delay = 0
        
        local frame --called "ui" in other functions. didnt change it because im lazy. sorry
        local frameSize

        if stepsWeight <= 2 then
            frame = smallFrame:Clone()
            frameSize = "small"
        else
            frame =  bigFrame:Clone()
            frameSize = "big"
        end
        frame.Name = data.orderNum
        frame.LayoutOrder = -data.orderNum
        frame.Visible = false  
        frame.Parent = ListFrame

        local mainFrame = frame:WaitForChild("Frame")
        mainFrame:WaitForChild("foodDisplay").Image = data.foodImage

        local frameIn = TweenService:Create(mainFrame, TweenInfo.new(.4, Enum.EasingStyle.Back), {Position = mainFrame.Position})
        delay += .4

        mainFrame.Position = UDim2.new(0.5,0,-.1,0)
        frame.Visible = true  
        frameIn:Play()

        frameIn.Completed:Wait()
        --
        for i, step in pairs(data.steps) do
            local ui 

            if #step.ingredient_images == 1 then
                if step.processImage then
                    ui = process1slot
                else
                    ui = noprocess1slot
                end
            elseif #step.ingredient_images == 2 then
                ui = process2slot
            elseif #step.ingredient_images == 3 then
                ui = process3slot
            end

            for i, image in pairs(step.ingredient_images) do
                local label = ui:FindFirstChild(`ingredient{i}`)
                if label then
                    label.Image = image
                end
            end

            ui = ui:Clone()
            ui.Visible = false

            if frameSize == "small" then
                ui.Size = smallSizing[ui.Name]
            end

            local position = `{frameSize}_pos{i}`

            if frameSize == "big" and stepsWeight == 2 and ui.Name == "noprocess1slot" then --this is only possible if the step list is made of one 1slot and one 2slot 
                position ..= "_2"
            end

            position = positionList[ui.Name][position]

            ui.Position = position

            ui.Parent = mainFrame:WaitForChild("stepsDisplay")

            if ui.Name == "noprocess1slot" then
                ui.Position = UDim2.new(ui.Position.X.Scale, 0,0, 0)
            else
                ui.Position = UDim2.new(ui.Position.X.Scale, 0,-0.29, 0)
            end
            ui.Visible = true

            local in2 = TweenService:Create(ui, TweenInfo.new(.25, Enum.EasingStyle.Linear), {Position = position})

            delay += .25
            in2:Play()
        end

        --
        local totalTime = data.time - delay
        local halfway = totalTime / 2

        local timerFill = mainFrame:WaitForChild("timer"):WaitForChild("fill")
        local tweenToHalf = TweenService:Create(timerFill, TweenInfo.new(halfway, Enum.EasingStyle.Linear), {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundColor3 = Color3.fromRGB(184, 180, 46)
        })

        local tweenToEnd = TweenService:Create(timerFill, TweenInfo.new(halfway, Enum.EasingStyle.Linear), {
            Size = UDim2.new(0, 0, 1, 0),
            BackgroundColor3 = Color3.fromRGB(163, 37, 46)
        })

        tweenToHalf:Play()
        tweenToHalf.Completed:Wait()

        tweenToEnd:Play()
        tweenToEnd.Completed:Wait()

        removeOrder(frame)
    end)
end

CacheOrdersRE.OnClientEvent:Connect(function(data)
    CachedOrders = data
end)

AddOrderRE.OnClientEvent:Connect(function(id, changedParameters, timeSent)
    local data = CachedOrders[id]

    if changedParameters then
        for i, v in pairs(changedParameters) do
            data[i] = v
        end
    end

    data.time -= tick() + ReplicatedStorage:GetAttribute("timeOffset") - timeSent-- sync the timer more accurately to the server
    
    addOrder(data)
end)

CompleteOrderRE.OnClientEvent:Connect(function(orderNum)
    local ui = ListFrame:FindFirstChild(tostring(orderNum))
    if ui then
        completeOrder(ui, orderNum)
    end
end)