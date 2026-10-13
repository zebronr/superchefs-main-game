--!strict

-- Draws every label tagged BitmapText in the Jersey 15 bitmap font (see Shared/Util/BitmapLabels).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BitmapLabels = require(Shared:WaitForChild("Util"):WaitForChild("BitmapLabels"))
local Tags = require(Shared:WaitForChild("Tags"))

local BitmapTextController = {}

function BitmapTextController.Start(_self: typeof(BitmapTextController)): ()
	if not BitmapLabels.IsReady() then
		return
	end
	CollectionService:GetInstanceAddedSignal(Tags.BitmapText):Connect(BitmapLabels.Bind)
	CollectionService:GetInstanceRemovedSignal(Tags.BitmapText):Connect(BitmapLabels.Unbind)
	for _, instance in CollectionService:GetTagged(Tags.BitmapText) do
		BitmapLabels.Bind(instance)
	end
end

return BitmapTextController
