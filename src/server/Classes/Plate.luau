--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Interactable = require(script.Parent.Interactable)
local Item = require(script.Parent.Item)
local Slot = require(script.Parent.Components.Slot)
local CarryService = require(script.Parent.Parent.Services.CarryService)
local EffectService = require(script.Parent.Parent.Services.EffectService)
local Recipes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Recipes"))
local Tags = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Tags"))

local platedFoods = ServerStorage:WaitForChild("Assets"):WaitForChild("Foods"):WaitForChild("PlatedFoods")

local Plate = setmetatable({}, { __index = Item })
Plate.__index = Plate

export type Plate = Item.Item & {
	IsPlate: boolean,
	Content: string?,
	Model: BasePart?,
	ModelWeld: WeldConstraint?,
	Clear: (self: Plate) -> (),
}

function Plate.new(instance: Instance): Plate
	local self = Item.new(instance) :: Plate
	self.IsPlate = true
	self.Content = nil
	self.Model = nil
	self.ModelWeld = nil
	setmetatable(self :: any, Plate)
	return self
end

function Plate.Cast(object: Interactable.Interactable?): Plate?
	local item = Item.Cast(object)
	if item ~= nil and (item :: any).IsPlate == true then
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

local function clearModel(self: Plate): ()
	local weld = self.ModelWeld
	self.ModelWeld = nil
	if weld ~= nil then
		weld:Destroy()
	end
	local model = self.Model
	self.Model = nil
	if model ~= nil then
		model:Destroy()
	end
end

local function installModel(self: Plate, template: BasePart): ()
	clearModel(self)
	local model = template:Clone()
	model.CanCollide = false
	model.Massless = true
	model.Parent = self.Part
	self.Model = model
	self.ModelWeld = Slot.WeldOnTop(model, self.Part, model:GetAttribute("yOffset") :: number?)
end

local function plateFoodList(plate: Plate): Instance?
	local foodList = plate.Part:FindFirstChild("FoodList")
	if foodList == nil then
		warn(`Plate {plate.Instance:GetFullName()} has no FoodList`)
	end
	return foodList
end

local function moveFoodIcon(plate: Plate, food: Item.Item): ()
	local target = plateFoodList(plate)
	if target == nil then
		return
	end
	local foodList = food.Instance:FindFirstChild("FoodList")
	local icon = if foodList ~= nil then foodList:FindFirstChild("Frame") else nil
	if icon ~= nil and icon:IsA("Frame") then
		icon.Parent = target
	end
end

local function movePlateIcons(targetPlate: Plate, sourcePlate: Plate): ()
	local target = plateFoodList(targetPlate)
	if target == nil then
		return
	end
	local source = sourcePlate.Part:FindFirstChild("FoodList")
	if source == nil then
		warn(`Plate {sourcePlate.Instance:GetFullName()} has no FoodList`)
		return
	end
	for _, child in source:GetChildren() do
		if child:IsA("Frame") then
			child.Parent = target
		end
	end
end

function Plate.Accept(self: Plate, other: Interactable.Interactable, _player: Player?): boolean
	local food = Item.Cast(other)
	if food ~= nil and CollectionService:HasTag(food.Instance, Tags.Food) then
		local content = self.Content
		local nextContent = if content == nil then food.Instance.Name else Recipes.Find({ content, food.Instance.Name })
		if nextContent == nil then
			return false
		end
		local template = findModel(nextContent)
		if template == nil then
			return false
		end

		moveFoodIcon(self, food)
		installModel(self, template)
		self.Content = nextContent
		if food.Holder ~= nil then
			CarryService.Release(food.Holder)
		end
		food.Instance:Destroy()
		EffectService.PlaySound("Interact")
		return true
	end

	local sourcePlate = Plate.Cast(other)
	if sourcePlate == nil or self.Holder == nil or self.Content == nil or sourcePlate.Content == nil then
		return false
	end
	local recipe = Recipes.Find({ sourcePlate.Content, self.Content })
	if recipe == nil then
		return false
	end
	local template = findModel(recipe)
	if template == nil then
		return false
	end

	movePlateIcons(self, sourcePlate)
	installModel(self, template)
	self.Content = recipe
	sourcePlate:Clear()
	EffectService.PlaySound("Interact")
	return true
end

function Plate.CanSwapWith(self: Plate, other: Item.Item): boolean
	local otherPlate = Plate.Cast(other)
	return otherPlate ~= nil and (self.Content == nil) ~= (otherPlate.Content == nil)
end

function Plate.Clear(self: Plate): ()
	clearModel(self)
	self.Content = nil
	local foodList = self.Part:FindFirstChild("FoodList")
	if foodList == nil then
		return
	end
	for _, child in foodList:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
end

function Plate.Destroy(self: Plate): ()
	self:Clear()
	Item.Destroy(self)
end

return Plate
