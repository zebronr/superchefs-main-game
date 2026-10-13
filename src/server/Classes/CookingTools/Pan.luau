--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local CookingTool = require(script.Parent.Parent.CookingTool)
local Slot = require(script.Parent.Parent.Components.Slot)
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Recipes = Config.Recipes

-- What lies in the pan: `<content>_raw` while it cooks, `<content>` once it's done.
local panFoods = ServerStorage:WaitForChild("Assets"):WaitForChild("Foods"):WaitForChild("PanFoods")

local Pan = setmetatable({}, { __index = CookingTool })
Pan.__index = Pan

export type Pan = CookingTool.CookingTool & {
	Food: BasePart?,
	FoodWeld: WeldConstraint?,
}

Pan.Combinations = Recipes.Pan

function Pan.new(instance: Instance): Pan
	local self = CookingTool.new(instance) :: Pan
	self.Food = nil
	self.FoodWeld = nil
	setmetatable(self :: any, Pan)
	return self
end

local function clearFood(self: Pan): ()
	if self.FoodWeld ~= nil then
		self.FoodWeld:Destroy()
		self.FoodWeld = nil
	end
	if self.Food ~= nil then
		self.Food:Destroy()
		self.Food = nil
	end
end

function Pan.Display(self: Pan, content: string): ()
	clearFood(self)
	local name = if self.Progress >= 100 then content else `{content}_raw`
	local template = panFoods:FindFirstChild(name)
	if template == nil or not template:IsA("BasePart") then
		warn(`PanFoods has no {name}`)
		return
	end
	local food = template:Clone()
	food.CanCollide = false
	food.CanQuery = false
	food.CanTouch = false
	food.Massless = true
	food.Parent = self.Part
	self.Food = food
	-- Lies on the pan's top face.
	self.FoodWeld = Slot.WeldOnTop(food, self.Part)
end

function Pan.ClearDisplay(self: Pan): ()
	clearFood(self)
end

-- Done cooking: the raw food turns into the cooked one.
function Pan.Cooked(self: Pan): ()
	local content = self.Content
	if content ~= nil then
		self:Display(content)
	end
end

function Pan.Destroy(self: Pan): ()
	clearFood(self)
	CookingTool.Destroy(self)
end

return Pan
