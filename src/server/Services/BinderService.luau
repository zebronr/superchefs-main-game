--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Binder = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("Binder"))
local Tags = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Tags"))

local Interactable = require(script.Parent.Parent.Classes.Interactable)
local Item = require(script.Parent.Parent.Classes.Item)
local Plate = require(script.Parent.Parent.Classes.Plate)
local Counter = require(script.Parent.Parent.Classes.Stations.Counter)
local ChoppingBoard = require(script.Parent.Parent.Classes.Stations.ChoppingBoard)
local FoodContainer = require(script.Parent.Parent.Classes.Stations.FoodContainer)

type Bound = Interactable.Interactable & Binder.Destroyable

local BinderService = {}
local binders: { [string]: Binder.Binder<Bound> } = {}

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
	register(Tags.Countertop, Counter.new)
	register(Tags.ChoppingBoard, ChoppingBoard.new)
	register(Tags.FoodContainer, FoodContainer.new)
	register(Tags.Food, Item.new)
	register(Tags.Plate, Plate.new)
	register(Tags.DirtyPlate, Item.new)
end

function BinderService.Start(_self: typeof(BinderService)): ()
	for _, binder in binders do
		binder:Start()
	end
end

return BinderService
