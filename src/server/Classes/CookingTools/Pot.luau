--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local CookingTool = require(script.Parent.Parent.CookingTool)
local Slot = require(script.Parent.Parent.Components.Slot)
local Recipes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Recipes"))

local soupTemplate = ServerStorage:WaitForChild("Assets"):WaitForChild("Foods"):WaitForChild("SoupModel")

local Pot = setmetatable({}, { __index = CookingTool })
Pot.__index = Pot

export type Pot = CookingTool.CookingTool & {
	Soup: BasePart?,
	SoupWeld: WeldConstraint?,
}

Pot.Combinations = Recipes.Pot

function Pot.new(instance: Instance): Pot
	local self = CookingTool.new(instance) :: Pot
	self.Soup = nil
	self.SoupWeld = nil
	setmetatable(self :: any, Pot)
	return self
end

local function clearSoup(self: Pot): ()
	if self.SoupWeld ~= nil then
		self.SoupWeld:Destroy()
		self.SoupWeld = nil
	end
	if self.Soup ~= nil then
		self.Soup:Destroy()
		self.Soup = nil
	end
end

function Pot.Display(self: Pot, content: string): ()
	clearSoup(self)
	assert(soupTemplate:IsA("BasePart"), "SoupModel must be a BasePart")
	local soup = soupTemplate:Clone()
	soup.Color = Recipes.SoupColors[content]
	soup.CanCollide = false
	soup.Massless = true
	soup.Parent = self.Part
	self.Soup = soup
	self.SoupWeld = Slot.WeldOnTop(soup, self.Part, -self.Part.Size.Y / 2)
end

function Pot.Destroy(self: Pot): ()
	clearSoup(self)
	CookingTool.Destroy(self)
end

return Pot
