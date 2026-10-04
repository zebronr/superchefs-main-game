--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Item = require(script.Parent.Parent.Item)
local Station = require(script.Parent.Parent.Station)
local Counter = require(script.Parent.Counter)
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Interaction"))
local Tags = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Tags"))
local Trove = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Trove"))

local choppedFoods = ServerStorage:WaitForChild("Assets"):WaitForChild("Foods"):WaitForChild("ChoppedFoods")
local BIND_TIMEOUT = 5

type Session = {
	Player: Player,
	Character: Model,
	Item: Item.Item,
	Template: Instance,
	OnEnded: () -> (),
	Trove: typeof(Trove.new()),
	Loop: thread?,
	Timeout: thread?,
	Converting: boolean,
}

export type ChoppingBoard = Station.Station & {
	Session: Session?,
}

local ChoppingBoard = setmetatable({}, { __index = Station })
ChoppingBoard.__index = ChoppingBoard

function ChoppingBoard.new(instance: Instance): ChoppingBoard
	local self = Station.new(instance) :: ChoppingBoard
	self.Session = nil
	setmetatable(self :: any, ChoppingBoard)
	return self
end

function ChoppingBoard.Handle(self: ChoppingBoard, player: Player, held: Item.Item?): boolean
	return Counter.Handle(self, player, held)
end

local function endSession(self: ChoppingBoard, session: Session): ()
	if self.Session ~= session then
		return
	end
	self.Session = nil
	session.Trove:Destroy()
	local timeout = session.Timeout
	if timeout ~= nil and timeout ~= coroutine.running() then
		task.cancel(timeout)
	end
	local loop = session.Loop
	if loop ~= nil and loop ~= coroutine.running() and not session.Converting then
		task.cancel(loop)
	end
	CollectionService:RemoveTag(self.Instance, Tags.Locked)
	if session.Character:GetAttribute(Config.ActionAnimationAttribute) == "Chop" then
		session.Character:SetAttribute(Config.ActionAnimationAttribute, nil)
	end
	session.OnEnded()
end

local function complete(self: ChoppingBoard, session: Session): ()
	session.Converting = true
	local clone: Instance? = nil
	local success, message = pcall(function(): boolean
		local raw = self.Slot:Take()
		assert(raw ~= nil and raw == session.Item, "ChoppingBoard item changed during use")
		raw.Instance:Destroy()

		local newClone = session.Template:Clone()
		clone = newClone
		Tags.SetInteractionDisabled(newClone, true)
		local gameFolder = workspace:FindFirstChild("$GAME")
		assert(gameFolder ~= nil, "workspace.$GAME is missing")
		newClone.Parent = gameFolder
		local chopped = Item.Await(newClone, BIND_TIMEOUT)
		assert(self.Session == session and chopped ~= nil, "Chopped food could not bind")
		assert(self.Slot:Place(chopped), "Chopped food could not be placed")
		return true
	end)
	if not success then
		if clone ~= nil then
			clone:Destroy()
		end
		warn(`ChoppingBoard {self.Instance:GetFullName()} failed to finish: {message}`)
	end
	endSession(self, session)
end

function ChoppingBoard.StartUse(self: ChoppingBoard, player: Player, onEnded: () -> ()): boolean
	if self.Session ~= nil or self:IsLocked() then
		return false
	end
	local item = self.Slot:Get()
	if item == nil then
		return false
	end
	local template = choppedFoods:FindFirstChild(`chopped_{item.Instance.Name}`)
	if template == nil then
		return false
	end
	local character = player.Character
	if character == nil then
		return false
	end

	local session: Session = {
		Player = player,
		Character = character,
		Item = item,
		Template = template,
		OnEnded = onEnded,
		Trove = Trove.new(),
		Loop = nil,
		Timeout = nil,
		Converting = false,
	}
	self.Session = session
	CollectionService:AddTag(self.Instance, Tags.Locked)
	character:SetAttribute(Config.ActionAnimationAttribute, "Chop")
	session.Trove:Connect(item.Instance.Destroying, function(): ()
		if not session.Converting then
			endSession(self, session)
		end
	end)
	session.Trove:Connect(self.Instance.Destroying, function(): ()
		endSession(self, session)
	end)
	-- A release or timeout during conversion would destroy the raw food without placing the chopped one.
	session.Timeout = task.delay(100 / Config.ProgressPerChop * Config.ChopDelay + Config.UseTimeoutMargin, function(): ()
		if not session.Converting then
			endSession(self, session)
		end
	end)

	session.Loop = task.defer(function(): ()
		local stored = item.Instance:GetAttribute(Config.ChopProgressAttribute)
		local progress = if typeof(stored) == "number" then math.clamp(stored, 0, 100) else 0
		while self.Session == session do
			progress += Config.ProgressPerChop
			item.Instance:SetAttribute(Config.ChopProgressAttribute, math.min(progress, 100))
			if progress > 100 then
				complete(self, session)
				return
			end
			task.wait(Config.ChopDelay)
		end
	end)
	return true
end

function ChoppingBoard.StopUse(self: ChoppingBoard, player: Player): ()
	local session = self.Session
	if session ~= nil and session.Player == player and not session.Converting then
		endSession(self, session)
	end
end

function ChoppingBoard.Destroy(self: ChoppingBoard): ()
	local session = self.Session
	if session ~= nil then
		endSession(self, session)
	end
	Station.Destroy(self)
end

return ChoppingBoard
