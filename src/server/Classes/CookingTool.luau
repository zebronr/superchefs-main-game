--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Interactable = require(script.Parent.Interactable)
local Item = require(script.Parent.Item)
local Plate = require(script.Parent.Plate)
local CarryService = require(script.Parent.Parent.Services.CarryService)
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

export type CookingTool = Item.Item & {
	IsCookingTool: boolean,
	Content: string?,
	Progress: number,
	Enabled: boolean,
	CookLoop: thread?,
	BurnTimer: thread?,
	FrozenAt: number?,
	Combinations: { [string]: { string } },
	Display: (self: CookingTool, content: string) -> (),
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
	cancelTimer(self)
	local burnAt = finishedAt + CookingConfig.CookSafeTime + CookingConfig.CookAlertDuration
	self.BurnTimer = task.delay(math.max(0, burnAt - workspace:GetServerTimeNow()), function(): ()
		self.BurnTimer = nil
		if self:IsEnabled() and self.Instance:IsDescendantOf(workspace) then
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

function CookingTool.Accept(self: CookingTool, other: Interactable.Interactable, _player: Player?): boolean
	local food = Item.Cast(other)
	if food ~= nil and Tags.IsClass(food.Instance, Tags.Food) then
		local ingredients = if self.Content ~= nil then { self.Content, food.Instance.Name } else { food.Instance.Name }
		local nextContent = Recipes.Find(ingredients, self.Combinations)
		if nextContent == nil then
			return false
		end
		self:StopCooking()
		self:Display(nextContent)
		self.Content = nextContent
		self.Instance:SetAttribute(CookingConfig.CookContentAttribute, nextContent)
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
	if Plate.Cast(other) ~= nil then
		-- TODO(after parity): ladle pot dishes onto plates
		return false
	end
	return false
end

function CookingTool.Destroy(self: CookingTool): ()
	self:StopCooking()
	Item.Destroy(self)
end

return CookingTool
