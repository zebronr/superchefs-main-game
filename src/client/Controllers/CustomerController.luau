--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Levels = Config.Levels

type Bubble = {
	Gui: BillboardGui,
	Icon: ImageLabel?,
	Alert: GuiObject?,
	Bar: GuiObject?,
	Fill: Frame?,
}

local CustomerController = {}
local bubbles: { [Model]: Bubble } = {}

local GREEN = Config.UI.Patience.Green
local YELLOW = Config.UI.Patience.Yellow
local RED = Config.UI.Patience.Red

local function remove(model: Model): ()
	local bubble = bubbles[model]
	if bubble ~= nil then
		bubbles[model] = nil
		bubble.Gui:Destroy()
	end
end

local function add(model: Model, template: BillboardGui): ()
	if bubbles[model] ~= nil or model:GetAttribute("CustomerState") == nil then
		return
	end
	local head = model:FindFirstChild("Head")
	if head == nil or not head:IsA("BasePart") then
		return
	end
	local gui = template:Clone()
	local icon = gui:FindFirstChild("Icon", true)
	local alert = gui:FindFirstChild("Alert", true)
	local bar = gui:FindFirstChild("Bar", true)
	local fill = if bar then bar:FindFirstChild("Fill") else nil
	bubbles[model] = {
		Gui = gui,
		Icon = if icon and icon:IsA("ImageLabel") then icon else nil,
		Alert = if alert and alert:IsA("GuiObject") then alert else nil,
		Bar = if bar and bar:IsA("GuiObject") then bar else nil,
		Fill = if fill and fill:IsA("Frame") then fill else nil,
	}
	gui.Enabled = false
	gui.Adornee = head
	gui.Parent = head
	model.Destroying:Once(function(): ()
		remove(model)
	end)
end

local function update(model: Model, bubble: Bubble): ()
	local state = model:GetAttribute("CustomerState")
	local waitingToOrder = state == "WaitingToOrder"
	local waitingForFood = state == "WaitingForFood"
	bubble.Gui.Enabled = waitingToOrder or waitingForFood
	if not bubble.Gui.Enabled then
		return
	end
	if bubble.Alert ~= nil then
		bubble.Alert.Visible = waitingToOrder
	end
	local icon = bubble.Icon
	if icon ~= nil then
		icon.Visible = waitingForFood
		if waitingForFood then
			local recipeId = model:GetAttribute("Recipe")
			local recipe = if typeof(recipeId) == "number" then Levels.GetCurrent().Recipes[recipeId] else nil
			if recipe ~= nil and icon.Image ~= recipe.FoodImage then
				icon.Image = recipe.FoodImage
			end
		end
	end
	if bubble.Bar ~= nil then
		bubble.Bar.Visible = true
	end
	local fill = bubble.Fill
	local startedAt = model:GetAttribute("PatienceStartedAt")
	local duration = model:GetAttribute("PatienceDuration")
	if fill ~= nil and typeof(startedAt) == "number" and typeof(duration) == "number" then
		local fraction = math.clamp((startedAt + duration - workspace:GetServerTimeNow()) / math.max(duration, 0.001), 0, 1)
		local progress = 1 - fraction
		fill.Size = UDim2.new(fraction, 0, 1, 0)
		fill.BackgroundColor3 = if progress <= 0.5
			then GREEN:Lerp(YELLOW, progress * 2)
			else YELLOW:Lerp(RED, (progress - 0.5) * 2)
	end
end

function CustomerController.Start(_self: typeof(CustomerController)): ()
	local template = ReplicatedStorage:WaitForChild("UIs"):WaitForChild("CustomerBubble")
	if not template:IsA("BillboardGui") then
		warn("UIs.CustomerBubble must be a BillboardGui")
		return
	end
	local temp = workspace:WaitForChild("$Temp")
	local function consider(child: Instance): ()
		if child:IsA("Model") then
			add(child, template)
		end
	end
	temp.ChildAdded:Connect(consider)
	temp.ChildRemoved:Connect(function(child: Instance): ()
		if child:IsA("Model") then
			remove(child)
		end
	end)
	for _, child in temp:GetChildren() do
		consider(child)
	end
	RunService.Heartbeat:Connect(function(): ()
		for model, bubble in bubbles do
			update(model, bubble)
		end
	end)
end

return CustomerController
