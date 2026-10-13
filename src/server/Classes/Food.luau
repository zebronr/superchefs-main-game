--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Interactable = require(script.Parent.Interactable)
local Item = require(script.Parent.Item)
local Slot = require(script.Parent.Components.Slot)
local CarryService = require(script.Parent.Parent.Services.CarryService)
local EffectService = require(script.Parent.Parent.Services.EffectService)
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Recipes = Config.Recipes
local Tags = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Tags"))

local platedFoods = ServerStorage:WaitForChild("Assets"):WaitForChild("Foods"):WaitForChild("PlatedFoods")

-- A food item. Recipes in Recipes.NoPlate also combine without a plate (on a counter or in hand): the food keeps
-- its part, hides it, and shows the result's plated model in its place, renamed to the result.
local Food = setmetatable({}, { __index = Item })
Food.__index = Food

export type Food = Item.Item & {
	IsFood: boolean,
	Model: BasePart?,
	ModelWeld: WeldConstraint?,
	AddContent: (self: Food, name: string) -> boolean,
}

function Food.new(instance: Instance): Food
	local self = Item.new(instance) :: Food
	self.IsFood = true
	self.Model = nil
	self.ModelWeld = nil
	setmetatable(self :: any, Food)
	return self
end

function Food.Cast(object: Interactable.Interactable?): Food?
	local item = Item.Cast(object)
	if item ~= nil and (item :: any).IsFood == true then
		return item :: any
	end
	return nil
end

local function findModel(content: string): BasePart?
	local template = platedFoods:FindFirstChild(`plated_{content}`)
	if template ~= nil and template:IsA("BasePart") then
		return template
	end
	return nil
end

-- Combines `name` (a food, or a pot's cooked content) into this food when they make a NoPlate recipe.
function Food.AddContent(self: Food, name: string): boolean
	local recipe = Recipes.Find({ self.Instance.Name, name })
	if recipe == nil or not Recipes.NoPlate[recipe] then
		return false
	end
	local template = findModel(recipe)
	if template == nil then
		return false
	end
	if self.ModelWeld ~= nil then
		self.ModelWeld:Destroy()
	end
	if self.Model ~= nil then
		self.Model:Destroy()
	end
	local model = template:Clone()
	model.CanCollide = false
	model.CanQuery = false
	model.CanTouch = false
	model.Massless = true
	model.Parent = self.Part
	self.Model = model
	-- Sits where the food sat: its bottom on the food's bottom.
	self.ModelWeld = Slot.WeldOnTop(model, self.Part, -self.Part.Size.Y)
	self.Part.Transparency = 1
	self.Instance.Name = recipe
	self.Instance:SetAttribute(Config.Interaction.CombinedAttribute, true)
	return true
end

-- Moves the other food's ingredient icons onto this one.
local function moveIcons(self: Food, other: Item.Item): ()
	local target = self.Part:FindFirstChild("FoodList")
	local source = other.Instance:FindFirstChild("FoodList")
	if target == nil or source == nil then
		return
	end
	for _, child in source:GetChildren() do
		if child:IsA("Frame") then
			child.Parent = target
		end
	end
end

function Food.Accept(self: Food, other: Interactable.Interactable, _player: Player?): boolean
	local food = Item.Cast(other)
	if food == nil or not Tags.IsClass(food.Instance, Tags.Food) or not self:AddContent(food.Instance.Name) then
		return false
	end
	moveIcons(self, food)
	if food.Holder ~= nil then
		CarryService.Release(food.Holder)
	end
	food.Instance:Destroy()
	EffectService.PlaySound("Interact")
	return true
end

return Food
