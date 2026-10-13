--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Interactable = require(script.Parent.Interactable)
local Item = require(script.Parent.Item)
local Food = require(script.Parent.Food)
local Plate = require(script.Parent.Plate)
local CarryService = require(script.Parent.Parent.Services.CarryService)
local EffectService = require(script.Parent.Parent.Services.EffectService)
local FireService = require(script.Parent.Parent.Services.FireService)
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local CookingConfig = Config.Interaction.Cooking
local Recipes = Config.Recipes
local Tags = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Tags"))

local CookingTool = setmetatable({}, { __index = Item })
CookingTool.__index = CookingTool

-- Subclasses (one per tool type) override these.
CookingTool.Combinations = {} :: { [string]: { string } }

function CookingTool.Display(_self: CookingTool, _content: string): () end
function CookingTool.ClearDisplay(_self: CookingTool): () end
-- Runs when the content finishes cooking (a pan swaps the raw food for the cooked one).
function CookingTool.Cooked(_self: CookingTool): () end

export type CookingTool = Item.Item & {
	IsCookingTool: boolean,
	Content: string?,
	Progress: number,
	Enabled: boolean,
	CookLoop: thread?,
	BurnTimer: thread?,
	FrozenAt: number?,
	-- The content caught fire: it can't be plated any more, only emptied in the trash.
	Burned: boolean,
	Combinations: { [string]: { string } },
	Display: (self: CookingTool, content: string) -> (),
	ClearDisplay: (self: CookingTool) -> (),
	Cooked: (self: CookingTool) -> (),
	Empty: (self: CookingTool) -> (),
	IsServable: (self: CookingTool) -> boolean,
	IsEnabled: (self: CookingTool) -> boolean,
	StartCooking: (self: CookingTool) -> (),
	StopCooking: (self: CookingTool) -> (),
	Freeze: (self: CookingTool) -> (),
	Unfreeze: (self: CookingTool) -> (),
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
	self.FrozenAt = nil
	self.Burned = false
	setmetatable(self :: any, CookingTool)
	instance:SetAttribute(CookingConfig.CookContentAttribute, nil)
	instance:SetAttribute(CookingConfig.CookProgressAttribute, 0)
	instance:SetAttribute(CookingConfig.CookStartedAtAttribute, nil)
	instance:SetAttribute(CookingConfig.CookedAtAttribute, nil)
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
	self.Instance:SetAttribute(CookingConfig.CookProgressAttribute, 100)
	self.Instance:SetAttribute(CookingConfig.CookStartedAtAttribute, nil)
	self.Instance:SetAttribute(CookingConfig.CookedAtAttribute, finishedAt)
	self:Cooked()
	cancelTimer(self)
	local burnAt = finishedAt + CookingConfig.CookSafeTime + CookingConfig.CookAlertDuration
	self.BurnTimer = task.delay(math.max(0, burnAt - workspace:GetServerTimeNow()), function(): ()
		self.BurnTimer = nil
		if self:IsEnabled() and self.Instance:IsDescendantOf(workspace) then
			self.Burned = true
			FireService.Burn(self :: any)
		end
	end)
end

function CookingTool.StartCooking(self: CookingTool): ()
	-- A frozen tool starts again when it thaws (Unfreeze).
	if self.Content == nil or not self:IsEnabled() or self.CookLoop ~= nil or self.FrozenAt ~= nil then
		return
	end
	cancelTimer(self)
	if self.Progress >= 100 then
		finish(self, workspace:GetServerTimeNow())
		return
	end
	local startedAt = workspace:GetServerTimeNow()
	local startingProgress = self.Progress
	local duration = (100 - startingProgress) / CookingConfig.CookRate
	self.Instance:SetAttribute(CookingConfig.CookProgressAttribute, startingProgress)
	self.Instance:SetAttribute(CookingConfig.CookStartedAtAttribute, startedAt)
	self.CookLoop = task.delay(duration, function(): ()
		finish(self, startedAt + duration)
	end)
end

function CookingTool.StopCooking(self: CookingTool): ()
	local startedAt = self.Instance:GetAttribute(CookingConfig.CookStartedAtAttribute)
	if typeof(startedAt) == "number" then
		self.Progress = math.min(100, self.Progress + (workspace:GetServerTimeNow() - startedAt) * CookingConfig.CookRate)
	end
	local loop = self.CookLoop
	self.CookLoop = nil
	if loop ~= nil and loop ~= coroutine.running() then
		task.cancel(loop)
	end
	cancelTimer(self)
	self.Instance:SetAttribute(CookingConfig.CookProgressAttribute, self.Progress)
	self.Instance:SetAttribute(CookingConfig.CookStartedAtAttribute, nil)
	self.Instance:SetAttribute(CookingConfig.CookedAtAttribute, nil)
end

-- Deep Freeze: holds cooking progress and the burn countdown where they are.
function CookingTool.Freeze(self: CookingTool): ()
	if self.FrozenAt ~= nil then
		return
	end
	local now = workspace:GetServerTimeNow()
	if self.CookLoop ~= nil then
		-- Mid-cook: bank the progress so far, like StopCooking, but keep the content.
		local startedAt = self.Instance:GetAttribute(CookingConfig.CookStartedAtAttribute)
		if typeof(startedAt) == "number" then
			self.Progress = math.min(100, self.Progress + (now - startedAt) * CookingConfig.CookRate)
		end
		local loop = self.CookLoop
		self.CookLoop = nil
		if loop ~= nil and loop ~= coroutine.running() then
			task.cancel(loop)
		end
		self.Instance:SetAttribute(CookingConfig.CookProgressAttribute, self.Progress)
		self.Instance:SetAttribute(CookingConfig.CookStartedAtAttribute, nil)
	end
	-- Cooked: the burn countdown stops; CookedAt stays and clients hold the warning at FrozenAt.
	cancelTimer(self)
	self.FrozenAt = now
	self.Instance:SetAttribute(Config.Skills.Attribute.FrozenAt, now)
end

function CookingTool.Unfreeze(self: CookingTool): ()
	local frozenAt = self.FrozenAt
	if frozenAt == nil then
		return
	end
	self.FrozenAt = nil
	self.Instance:SetAttribute(Config.Skills.Attribute.FrozenAt, nil)
	if not self.Instance:IsDescendantOf(workspace) then
		return
	end
	local cookedAt = self.Instance:GetAttribute(CookingConfig.CookedAtAttribute)
	if typeof(cookedAt) == "number" and self:IsEnabled() then
		-- Shift the cooked time by the frozen time, which restarts the burn countdown where it stopped.
		finish(self, cookedAt + (workspace:GetServerTimeNow() - frozenAt))
	else
		self:StartCooking()
	end
end

function CookingTool.SetEnabled(self: CookingTool, on: boolean): ()
	self.Enabled = on
	if on then
		self:StartCooking()
	else
		self:StopCooking()
	end
end

-- Moves the ingredient icons (FoodList frames) from one item to another, so a pan's patty or a pot's spread keeps
-- its icon on the food or plate it's served onto.
local function moveIcons(from: Instance, to: Instance): ()
	local source = from:FindFirstChild("FoodList")
	local target = to:FindFirstChild("FoodList")
	if source == nil or target == nil then
		return
	end
	for _, child in source:GetChildren() do
		if child:IsA("Frame") then
			child.Parent = target
		end
	end
end

local function clearIcons(self: CookingTool): ()
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

function CookingTool.Accept(self: CookingTool, other: Interactable.Interactable, _player: Player?): boolean
	local food = Item.Cast(other)
	if food ~= nil and Tags.IsClass(food.Instance, Tags.Food) then
		local ingredients = if self.Content ~= nil then { self.Content, food.Instance.Name } else { food.Instance.Name }
		local nextContent = Recipes.Find(ingredients, self.Combinations)
		if nextContent == nil then
			-- Not a pot recipe: ladle the cooked content onto the food instead, when they combine without a plate.
			local target = Food.Cast(food)
			if target == nil or not self:IsServable() or not target:AddContent(self.Content :: string) then
				return false
			end
			moveIcons(self.Part, target.Part)
			self:Empty()
			EffectService.PlaySound("Interact")
			return true
		end
		self:StopCooking()
		self:Display(nextContent)
		self.Content = nextContent
		self.Instance:SetAttribute(CookingConfig.CookContentAttribute, nextContent)
		moveIcons(food.Instance, self.Part)
		if food.Holder ~= nil then
			CarryService.Release(food.Holder)
		end
		food.Instance:Destroy()
		if self.Progress > 0 then
			self.Progress = math.max(0, self.Progress - CookingConfig.CookProgressDeduction)
		end
		self.Instance:SetAttribute(CookingConfig.CookProgressAttribute, self.Progress)
		self:StartCooking()
		return true
	end
	local plate = Plate.Cast(other)
	if plate ~= nil then
		-- Ladle the cooked content onto the plate (either one may be the held item).
		local content = self.Content
		if content == nil or not self:IsServable() then
			return false
		end
		if not plate:AddContent(content) then
			return false
		end
		moveIcons(self.Part, plate.Part)
		self:Empty()
		EffectService.PlaySound("Interact")
		return true
	end
	return false
end

-- Done cooking, not burned and not on fire: ready to ladle out.
function CookingTool.IsServable(self: CookingTool): boolean
	return self.Content ~= nil and self.Progress >= 100 and not self.Burned and not FireService.IsBurning(self.Instance)
end

-- Throws the content away: back to an empty, cold tool.
function CookingTool.Empty(self: CookingTool): ()
	self:StopCooking()
	self:ClearDisplay()
	clearIcons(self)
	self.Content = nil
	self.Progress = 0
	self.Burned = false
	self.Instance:SetAttribute(CookingConfig.CookContentAttribute, nil)
	self.Instance:SetAttribute(CookingConfig.CookProgressAttribute, 0)
end

function CookingTool.Destroy(self: CookingTool): ()
	self:StopCooking()
	Item.Destroy(self)
end

return CookingTool
