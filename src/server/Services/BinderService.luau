--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Binder = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("Binder"))
local Tags = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Tags"))

local Interactable = require(script.Parent.Parent.Classes.Interactable)
local Item = require(script.Parent.Parent.Classes.Item)
local Plate = require(script.Parent.Parent.Classes.Plate)
local DirtyPlate = require(script.Parent.Parent.Classes.DirtyPlate)
local CookingTool = require(script.Parent.Parent.Classes.CookingTool)
local Pot = require(script.Parent.Parent.Classes.CookingTools.Pot)
local FireExtinguisher = require(script.Parent.Parent.Classes.FireExtinguisher)
local Counter = require(script.Parent.Parent.Classes.Stations.Counter)
local ChoppingBoard = require(script.Parent.Parent.Classes.Stations.ChoppingBoard)
local FoodContainer = require(script.Parent.Parent.Classes.Stations.FoodContainer)
local PlateTable = require(script.Parent.Parent.Classes.Stations.PlateTable)
local ServingCounter = require(script.Parent.Parent.Classes.Stations.ServingCounter)
local Stove = require(script.Parent.Parent.Classes.Stations.Stove)
local Sink = require(script.Parent.Parent.Classes.Stations.Sink)
local Trash = require(script.Parent.Parent.Classes.Stations.Trash)
local FireService = require(script.Parent.FireService)

type Bound = Interactable.Interactable & Binder.Destroyable

local BinderService = {}
local binders: { [string]: Binder.Binder<Bound> } = {}

-- Cooking tool subclasses by the part's cookingToolClass attribute; new tool types register here.
local cookingTools: { [string]: (Instance) -> CookingTool.CookingTool } = {
	Pot = Pot.new,
}

local function newCookingTool(instance: Instance): CookingTool.CookingTool
	local class = instance:GetAttribute("cookingToolClass")
	local constructor = if typeof(class) == "string" then cookingTools[class] else nil
	if constructor == nil then
		return CookingTool.new(instance)
	end
	return constructor(instance)
end

local function register(tag: string, constructor: (Instance) -> Interactable.Interactable): ()
	binders[tag] = Binder.new(tag, constructor :: (Instance) -> Bound)
end

function BinderService.Get(tag: string): Binder.Binder<Bound>?
	return binders[tag]
end

-- Looks the instance up across every binder.
function BinderService.GetObject(instance: Instance): Interactable.Interactable?
	for _, binder in binders do
		local object = binder:Get(instance)
		if object ~= nil then
			return object
		end
	end
	return nil
end

function BinderService.Init(_self: typeof(BinderService)): ()
	FireService.SetObjectProvider(function(tag: string): { any }
		local binder = binders[tag]
		return if binder ~= nil then binder:GetAll() else {}
	end)
	register(Tags.Countertop, Counter.new)
	register(Tags.ChoppingBoard, ChoppingBoard.new)
	register(Tags.FoodContainer, FoodContainer.new)
	register(Tags.PlateTable, PlateTable.new)
	register(Tags.ServingCounter, ServingCounter.new)
	register(Tags.Stove, Stove.new)
	register(Tags.Sink, Sink.new)
	register(Tags.Trash, Trash.new)
	register(Tags.Food, Item.new)
	register(Tags.Plate, Plate.new)
	register(Tags.DirtyPlate, DirtyPlate.new)
	register(Tags.CookingTool, newCookingTool)
	register(Tags.FireExtinguisher, FireExtinguisher.new)
end

function BinderService.Start(_self: typeof(BinderService)): ()
	for _, binder in binders do
		binder:Start()
	end
end

return BinderService
