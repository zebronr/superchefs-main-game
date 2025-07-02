local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

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

local function addOrder(data)
    local stepsWeight = 0

    for _, step in pairs(data.steps) do
        stepsWeight += #step.ingredient_images
    end
    
    local frame
    local frameSize

    if stepsWeight <= 2 then
        frame = smallFrame:Clone()
        frameSize = "small"
    else
        frame =  bigFrame:Clone()
        frameSize = "big"
    end
    frame.LayoutOrder = -data.orderNum
    frame.Visible = false  
    frame.Parent = ListFrame

    local mainFrame = frame:WaitForChild("Frame")

    local frameIn = TweenService:Create(mainFrame, TweenInfo.new(.3, Enum.EasingStyle.Back), {Position = mainFrame.Position})

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

        ui = ui:Clone()
        ui.Visible = false

        if frameSize == "small" then
            ui.Size = smallSizing[ui.Name]
        end

        local position = `{frameSize}_pos{i}`

        if frameSize == "big" and stepsWeight == 3 then --this is only possible if the step list is made of one 1slot and one 2slot 
            position ..= "_2"
        end

        position = positionList[ui.Name][position]

        ui.Position = position

        ui.Parent = frame:WaitForChild("Frame"):WaitForChild("stepsDisplay")

        if ui.Name == "noprocess1slot" then
            ui.Position = UDim2.new(ui.Position.X.Scale, 0,0, 0)
        else
            ui.Position = UDim2.new(ui.Position.X.Scale, 0,-0.29, 0)
        end
        ui.Visible = true

        local in2 = TweenService:Create(ui, TweenInfo.new(.25), {Position = position})
        in2:Play()
    end
end

local orderData = {
    orderNum = 1,
    time = 30,
    steps = {
        [1] = {ingredient_images = {[1] = ""}, processImage = ""},
        [2] = {ingredient_images = {[1] = ""}}
    },
    foodImage = ""
}

task.wait(5)
addOrder(orderData)