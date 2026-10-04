--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Interactable = require(script.Parent.Interactable)
local Item = require(script.Parent.Item)
local Plate = require(script.Parent.Plate)
local Slot = require(script.Parent.Components.Slot)
local CarryService = require(script.Parent.Parent.Services.CarryService)
local FireService = require(script.Parent.Parent.Services.FireService)
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Interaction")).Cooking
local Recipes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Recipes"))
local Tags = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Tags"))

local soupTemplate = ServerStorage:WaitForChild("Assets"):WaitForChild("Foods"):WaitForChild("SoupModel")

local CookingTool = setmetatable({}, { __index = Item })
CookingTool.__index = CookingTool

export type CookingTool = Item.Item & {
	IsCookingTool: boolean,
	Content: string?,
	Progress: number,
	Enabled: boolean,
	CookLoop: thread?,
	BurnTimer: thread?,
	Soup: BasePart?,
	SoupWeld: WeldConstraint?,
	IsEnabled: (self: CookingTool) -> boolean,
	StartCooking: (self: CookingTool) -> (),
	StopCooking: (self: CookingTool) -> (),
	SetEnabled: (self: CookingTool, on: boolean) -> (),
}

function CookingTool.new(instance: Instance): CookingTool
	local self = Item.new(instance) :: CookingTool
	self.IsCookingTool = true
	self.Content = nil
	self.Progress = 0
	self.Enabled = false
	self.CookLoop = nil
	self.BurnTimer = nil
	self.Soup = nil
	self.SoupWeld = nil
	setmetatable(self :: any, CookingTool)
	instance:SetAttribute(Config.CookContentAttribute, nil)
	instance:SetAttribute(Config.CookProgressAttribute, 0)
	instance:SetAttribute(Config.CookStartedAtAttribute, nil)
	instance:SetAttribute(Config.CookedAtAttribute, nil)
	return self
end

function CookingTool.Cast(object: Interactable.Interactable?): CookingTool?
	local item = Item.Cast(object)
	if item ~= nil and (item :: any).IsCookingTool == true then
		return item :: any
	end
	return nil
end

function CookingTool.IsEnabled(self: CookingTool): boolean
	return self.Enabled or CollectionService:HasTag(self.Instance, "defaultEnabled")
end

local function cancelTimer(self: CookingTool): ()
	local timer = self.BurnTimer
	self.BurnTimer = nil
	if timer ~= nil and timer ~= coroutine.running() then
		task.cancel(timer)
	end
end

local function finish(self: CookingTool, finishedAt: number): ()
	self.CookLoop = nil
	self.Progress = 100
	self.Instance:SetAttribute(Config.CookProgressAttribute, 100)
	self.Instance:SetAttribute(Config.CookStartedAtAttribute, nil)
	self.Instance:SetAttribute(Config.CookedAtAttribute, finishedAt)
	cancelTimer(self)
	local burnAt = finishedAt + Config.CookSafeTime + Config.CookAlertDuration
	self.BurnTimer = task.delay(math.max(0, burnAt - workspace:GetServerTimeNow()), function(): ()
		self.BurnTimer = nil
		if self:IsEnabled() and self.Instance:IsDescendantOf(workspace) then
			FireService.Burn(self :: any)
		end
	end)
end

function CookingTool.StartCooking(self: CookingTool): ()
	if self.Content == nil or not self:IsEnabled() or self.CookLoop ~= nil then
		return
	end
	cancelTimer(self)
	if self.Progress >= 100 then
		finish(self, workspace:GetServerTimeNow())
		return
	end
	local startedAt = workspace:GetServerTimeNow()
	local startingProgress = self.Progress
	local duration = (100 - startingProgress) / Config.CookRate
	self.Instance:SetAttribute(Config.CookProgressAttribute, startingProgress)
	self.Instance:SetAttribute(Config.CookStartedAtAttribute, startedAt)
	self.CookLoop = task.delay(duration, function(): ()
		finish(self, startedAt + duration)
	end)
end

function CookingTool.StopCooking(self: CookingTool): ()
	local startedAt = self.Instance:GetAttribute(Config.CookStartedAtAttribute)
	if typeof(startedAt) == "number" then
		self.Progress = math.min(100, self.Progress + (workspace:GetServerTimeNow() - startedAt) * Config.CookRate)
	end
	local loop = self.CookLoop
	self.CookLoop = nil
	if loop ~= nil and loop ~= coroutine.running() then
		task.cancel(loop)
	end
	cancelTimer(self)
	self.Instance:SetAttribute(Config.CookProgressAttribute, self.Progress)
	self.Instance:SetAttribute(Config.CookStartedAtAttribute, nil)
	self.Instance:SetAttribute(Config.CookedAtAttribute, nil)
end

function CookingTool.SetEnabled(self: CookingTool, on: boolean): ()
	self.Enabled = on
	if on then
		self:StartCooking()
	else
		self:StopCooking()
	end
end

local function replaceSoup(self: CookingTool, color: Color3): ()
	if self.SoupWeld ~= nil then
		self.SoupWeld:Destroy()
		self.SoupWeld = nil
	end
	if self.Soup ~= nil then
		self.Soup:Destroy()
		self.Soup = nil
	end
	assert(soupTemplate:IsA("BasePart"), "SoupModel must be a BasePart")
	local soup = soupTemplate:Clone()
	soup.Color = color
	soup.CanCollide = false
	soup.Massless = true
	soup.Parent = self.Part
	self.Soup = soup
	self.SoupWeld = Slot.WeldOnTop(soup, self.Part, -self.Part.Size.Y / 2)
end

function CookingTool.Accept(self: CookingTool, other: Interactable.Interactable, _player: Player?): boolean
	local food = Item.Cast(other)
	if food ~= nil and CollectionService:HasTag(food.Instance, Tags.Food) then
		if self.Part:GetAttribute("cookingToolClass") ~= "Pot" then
			return false
		end
		local ingredients = if self.Content ~= nil then { self.Content, food.Instance.Name } else { food.Instance.Name }
		local nextContent = Recipes.Find(ingredients, Recipes.Pot)
		if nextContent == nil then
			return false
		end
		local color = Recipes.SoupColors[nextContent]
		self:StopCooking()
		replaceSoup(self, color)
		self.Content = nextContent
		self.Instance:SetAttribute(Config.CookContentAttribute, nextContent)
		if food.Holder ~= nil then
			CarryService.Release(food.Holder)
		end
		food.Instance:Destroy()
		if self.Progress > 0 then
			self.Progress = math.max(0, self.Progress - Config.CookProgressDeduction)
		end
		self.Instance:SetAttribute(Config.CookProgressAttribute, self.Progress)
		self:StartCooking()
		-- TODO(layer 9): Interact sound
		return true
	end
	if Plate.Cast(other) ~= nil then
		-- TODO(after parity): ladle pot dishes onto plates
		return false
	end
	return false
end

function CookingTool.Destroy(self: CookingTool): ()
	self:StopCooking()
	if self.SoupWeld ~= nil then
		self.SoupWeld:Destroy()
		self.SoupWeld = nil
	end
	if self.Soup ~= nil then
		self.Soup:Destroy()
		self.Soup = nil
	end
	Item.Destroy(self)
end

return CookingTool
