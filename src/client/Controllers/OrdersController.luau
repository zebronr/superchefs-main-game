--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Levels = Config.Levels
local patience = Config.UI.Patience
local Net = require(Shared:WaitForChild("Net"))

type Order = { OrderNum: number, Recipe: number, StartedAt: number, Duration: number }
type Card = { Ui: GuiObject, Main: GuiObject, Fill: Frame, Order: Order, Generation: number, Tweens: { Tween } }

local OrdersController = {}
local templates = ReplicatedStorage:WaitForChild("UIs"):WaitForChild("OrdersUIs")
local list = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("OrderList"):WaitForChild("list")
local cards: { [number]: Card } = {}
local generation = 0

local positions: { [string]: { [string]: UDim2 } } = {
	noprocess1slot = {
		big_pos1 = UDim2.new(0.845, 0, 0.5, 0), big_pos2 = UDim2.new(0.5, 0, 0.5, 0),
		big_pos3 = UDim2.new(0.143, 0, 0.5, 0), big_pos1_2 = UDim2.new(0.802, 0, 0.5, 0),
		big_pos2_2 = UDim2.new(0.185, 0, 0.5, 0), small_pos1 = UDim2.new(0.734, 0, 0.5, 0),
		small_pos2 = UDim2.new(0.256, 0, 0.5, 0),
	},
	process1slot = {
		big_pos1 = UDim2.new(0.845, 0, 0.5, 0), big_pos2 = UDim2.new(0.5, 0, 0.5, 0),
		big_pos3 = UDim2.new(0.143, 0, 0.5, 0), small_pos1 = UDim2.new(0.734, 0, 0.5, 0),
		small_pos2 = UDim2.new(0.256, 0, 0.5, 0),
	},
	process2slot = {
		big_pos1 = UDim2.new(0.678, 0, 0.5, 0), big_pos2 = UDim2.new(0.311, 0, 0.5, 0),
		small_pos1 = UDim2.new(0.5, 0, 0.5, 0),
	},
	process3slot = { big_pos1 = UDim2.new(0.5, 0, 0.5, 0) },
}
local smallSizing = {
	noprocess1slot = UDim2.new(0.436, 0, 1, 0),
	process1slot = UDim2.new(0.436, 0, 1, 0),
	process2slot = UDim2.new(0.81, 0, 1.01, 0),
}

local function cancelTweens(card: Card): ()
	card.Generation += 1
	for _, tween in card.Tweens do
		tween:Cancel()
	end
	table.clear(card.Tweens)
end

local function clearCards(): ()
	generation += 1
	for number, card in cards do
		cancelTweens(card)
		card.Ui:Destroy()
		cards[number] = nil
	end
end

local function tween(card: Card, object: Instance, info: TweenInfo, target: { [string]: any }): Tween
	local animation = TweenService:Create(object, info, target)
	table.insert(card.Tweens, animation)
	animation:Play()
	return animation
end

local function animateSteps(card: Card, steps: { { ingredient_images: { string } } }, sizeName: string, weight: number, animate: boolean): ()
	local display = card.Main:WaitForChild("stepsDisplay")
	for index, step in steps do
		local count = #step.ingredient_images
		local slotName = if count == 1 then "noprocess1slot" else if count == 2 then "process2slot" else "process3slot"
		local template = templates:FindFirstChild(slotName)
		if template == nil or not template:IsA("GuiObject") then
			continue
		end
		local slot = template:Clone()
		for ingredientIndex, image in step.ingredient_images do
			local label = slot:FindFirstChild(`ingredient{ingredientIndex}`)
			if label ~= nil and label:IsA("ImageLabel") then
				label.Image = image
			end
		end
		if sizeName == "small" then
			local size = smallSizing[slotName]
			slot.Size = size
		end
		local key = `{sizeName}_pos{index}`
		if sizeName == "big" and weight == 2 and slotName == "noprocess1slot" then
			key ..= "_2"
		end
		local position = positions[slotName][key]
		slot.Position = if animate then UDim2.new(position.X.Scale, 0, if slotName == "noprocess1slot" then 0 else -0.29, 0) else position
		slot.Parent = display
		if animate then
			tween(card, slot, TweenInfo.new(0.25), { Position = position })
			task.wait(0.25)
		end
	end
end

local function addOrder(order: Order, animate: boolean): ()
	local recipe = Levels.GetCurrent().Recipes[order.Recipe]
	if recipe == nil or cards[order.OrderNum] ~= nil then
		return
	end
	local weight = 0
	for _, step in recipe.Steps do
		weight += #step.ingredient_images
	end
	local sizeName = if weight <= 2 then "small" else "big"
	local template = templates:FindFirstChild(`{sizeName}Frame`)
	if template == nil or not template:IsA("GuiObject") then
		return
	end
	local ui = template:Clone()
	local main = ui:FindFirstChild("Frame")
	local food = if main then main:FindFirstChild("foodDisplay") else nil
	local timer = if main then main:FindFirstChild("timer") else nil
	local fill = if timer then timer:FindFirstChild("fill") else nil
	if main == nil or not main:IsA("GuiObject") or food == nil or not food:IsA("ImageLabel") or fill == nil or not fill:IsA("Frame") then
		ui:Destroy()
		return
	end
	ui.Name = tostring(order.OrderNum)
	ui.LayoutOrder = -order.OrderNum
	ui.Parent = list
	ui.Visible = true
	food.Image = recipe.FoodImage
	local card: Card = { Ui = ui, Main = main, Fill = fill, Order = order, Generation = 0, Tweens = {} }
	cards[order.OrderNum] = card
	local listGeneration = generation
	task.spawn(function(): ()
		local cardGeneration = card.Generation
		if animate then
			local home = main.Position
			main.Position = UDim2.new(0.5, 0, -0.1, 0)
			tween(card, main, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Position = home }).Completed:Wait()
		end
		if listGeneration ~= generation or cardGeneration ~= card.Generation then
			return
		end
		animateSteps(card, recipe.Steps, sizeName, weight, animate)
	end)
end

local function removeOrder(number: number, success: boolean): ()
	local card = cards[number]
	if card == nil then
		return
	end
	cards[number] = nil
	cancelTweens(card)
	task.spawn(function(): ()
		local main = card.Main
		local images: { ImageLabel } = {}
		for _, descendant in main:GetDescendants() do
			if descendant:IsA("ImageLabel") then
				table.insert(images, descendant)
			end
		end
		if success then
			for _, image in images do
				image.ImageColor3 = Config.UI.Ticket.Success
			end
			tween(card, main, TweenInfo.new(0.5, Enum.EasingStyle.Back), { Position = UDim2.new(0.5, 0, -0.7, 0) }).Completed:Wait()
		else
			local home = main.Position
			for index = 1, 5 do
				for _, image in images do
					image.ImageColor3 = if index % 2 == 0 then Config.UI.Ticket.Fail else Color3.new(1, 1, 1)
				end
				for _, direction in { 1, -1 } do
					tween(card, main, TweenInfo.new(0.05), { Position = home + UDim2.new(0.03 * direction, 0, 0, 0) }).Completed:Wait()
				end
			end
			tween(card, main, TweenInfo.new(0.4), { Position = UDim2.new(0.5, 0, -0.7, 0) }).Completed:Wait()
		end
		card.Ui:Destroy()
	end)
end

local function isOrder(value: unknown): boolean
	if typeof(value) ~= "table" then
		return false
	end
	local data = value :: { [string]: any }
	return typeof(data.OrderNum) == "number" and typeof(data.Recipe) == "number"
		and typeof(data.StartedAt) == "number" and typeof(data.Duration) == "number"
end

function OrdersController.Start(_self: typeof(OrdersController)): ()
	Net.Event("Round").OnClientEvent:Connect(function(message: unknown, value: unknown): ()
		if message == "Orders" and typeof(value) == "table" then
			clearCards()
			for _, entry in value :: { unknown } do
				if isOrder(entry) then
					addOrder(entry :: Order, false)
				end
			end
		elseif message == "AddOrder" and isOrder(value) then
			addOrder(value :: Order, true)
		elseif message == "CompleteOrder" and typeof(value) == "number" then
			removeOrder(value, true)
		elseif message == "ExpireOrder" and typeof(value) == "number" then
			removeOrder(value, false)
		elseif message == "RoundEnd" then
			clearCards()
		end
	end)
	RunService.Heartbeat:Connect(function(): ()
		for _, card in cards do
			local order = card.Order
			local fraction = math.clamp((order.StartedAt + order.Duration - workspace:GetServerTimeNow()) / math.max(order.Duration, 0.001), 0, 1)
			local progress = 1 - fraction
			-- Legacy tweened from the template fill (width 2, green) to width 1 and yellow, then to 0 and red.
			card.Fill.Size = UDim2.new(if progress <= 0.5 then 2 - progress * 2 else (1 - progress) * 2, 0, 1, 0)
			card.Fill.BackgroundColor3 = if progress <= 0.5
				then patience.Green:Lerp(patience.Yellow, progress * 2)
				else patience.Yellow:Lerp(patience.Red, (progress - 0.5) * 2)
		end
	end)
end

return OrdersController
