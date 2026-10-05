--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local DirtyPlate = require(script.Parent.Parent.DirtyPlate)
local Item = require(script.Parent.Parent.Item)
local Plate = require(script.Parent.Parent.Plate)
local PlateStack = require(script.Parent.Parent.Components.PlateStack)
local Station = require(script.Parent.Parent.Station)
local CarryService = require(script.Parent.Parent.Parent.Services.CarryService)
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local InteractionConfig = Config.Interaction
local Tags = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Tags"))
local Trove = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Trove"))

local plateTemplate = ServerStorage:WaitForChild("Assets"):WaitForChild("Plates"):WaitForChild("Plate")
local BIND_TIMEOUT = 5

type Session = {
	Player: Player,
	Character: Model,
	OnEnded: () -> (),
	Trove: typeof(Trove.new()),
	Loop: thread?,
	Timeout: thread?,
	Converting: boolean,
	StopRequested: boolean,
}

export type Sink = Station.Station & {
	WashPartMarker: BasePart,
	DrainBoard: BasePart,
	PlateDisplays: Instance,
	DrainStack: PlateStack.PlateStack,
	DirtyCount: number,
	Session: Session?,
}

local Sink = setmetatable({}, { __index = Station })
Sink.__index = Sink

local function partChild(parent: Instance, name: string): BasePart
	local child = parent:WaitForChild(name)
	assert(child:IsA("BasePart"), `{name} must be a BasePart`)
	return child
end

function Sink.new(instance: Instance): Sink
	local self = Station.new(instance) :: Sink
	self.AutoUse = true
	self.WashPartMarker = partChild(instance, "WashPartMarker")
	self.DrainBoard = partChild(instance, "DrainBoard")
	self.PlateDisplays = instance:WaitForChild("PlateDisplays")
	self.DrainStack = self.Trove:Add(PlateStack.new(self.DrainBoard))
	self.DirtyCount = 0
	self.Session = nil
	setmetatable(self :: any, Sink)
	return self
end

local function washSide(self: Sink, player: Player): boolean?
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return nil
	end
	return (root.Position - self.WashPartMarker.Position).Magnitude < (root.Position - self.DrainBoard.Position).Magnitude
end

local function updateDisplays(self: Sink): ()
	for index = 1, InteractionConfig.MaxDisplayedDirtyPlates do
		local display = self.PlateDisplays:FindFirstChild(tostring(index))
		if display ~= nil and display:IsA("BasePart") then
			display.Transparency = if index <= self.DirtyCount then 0 else 1
		end
	end
end

function Sink.Handle(self: Sink, player: Player, held: Item.Item?): boolean
	-- Legacy useLock: nobody can interact with a sink while it is being washed at.
	if self.Session ~= nil then
		return false
	end
	local side = washSide(self, player)
	if side == nil then
		return false
	end
	if side then
		local dirty = DirtyPlate.Cast(held)
		if dirty == nil then
			return false
		end
		local dropped = CarryService.Drop(player, true)
		if dropped ~= dirty then
			return false
		end
		self.DirtyCount += dirty:Count()
		updateDisplays(self)
		for _, plate in dirty:TakeAll() do
			plate.Instance:Destroy()
		end
		dirty.Instance:Destroy()
		return true
	end
	if held ~= nil then
		-- Plate onto the top clean plate without taking it off the drain board.
		local top = self.DrainStack:Top()
		return top ~= nil and (top:Accept(held, player) or held:Accept(top, player))
	end
	local plate = self.DrainStack:PopTop()
	if plate == nil then
		return false
	end
	if not CarryService.Pickup(player, plate) then
		self.DrainStack:Push(plate)
		return false
	end
	return true
end

local function endSession(self: Sink, session: Session): ()
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
	if session.Character:GetAttribute(InteractionConfig.ActionAnimationAttribute) == "Wash" then
		session.Character:SetAttribute(InteractionConfig.ActionAnimationAttribute, nil)
	end
	session.OnEnded()
end

local function restartTimeout(self: Sink, session: Session): ()
	local timeout = session.Timeout
	if timeout ~= nil and timeout ~= coroutine.running() then
		task.cancel(timeout)
	end
	session.Timeout = task.delay(100 / InteractionConfig.WashRate + InteractionConfig.UseTimeoutMargin, function(): ()
		if not session.Converting then
			endSession(self, session)
		end
	end)
end

local function complete(self: Sink, session: Session): boolean
	session.Converting = true
	local clone: Instance? = nil
	local success, message = pcall(function(): boolean
		local newClone = plateTemplate:Clone()
		clone = newClone
		Tags.SetInteractionDisabled(newClone, true)
		local gameFolder = workspace:FindFirstChild("$GAME")
		assert(gameFolder ~= nil, "workspace.$GAME is missing")
		newClone.Parent = gameFolder
		local plate = Item.Await(newClone, BIND_TIMEOUT)
		assert(self.Session == session and plate ~= nil, "Clean plate could not bind")
		-- A plated plate stays on top so a finished wash doesn't bury it.
		local top = Plate.Cast(self.DrainStack:Top())
		local stacked = if top ~= nil and top.Content ~= nil then self.DrainStack:InsertBelowTop(plate) else self.DrainStack:Push(plate)
		assert(stacked, "Clean plate could not be stacked")
		self.DirtyCount -= 1
		updateDisplays(self)
		self.Instance:SetAttribute(InteractionConfig.WashProgressAttribute, nil)
		return true
	end)
	if not success then
		if clone ~= nil then
			clone:Destroy()
		end
		warn(`Sink {self.Instance:GetFullName()} failed to finish: {message}`)
	end
	session.Converting = false
	if not success or self.Session ~= session or session.StopRequested or self.DirtyCount <= 0 then
		endSession(self, session)
		return false
	end
	self.Instance:SetAttribute(InteractionConfig.WashProgressAttribute, 0)
	restartTimeout(self, session)
	return true
end

function Sink.StartUse(self: Sink, player: Player, onEnded: () -> ()): boolean
	if self.Session ~= nil or self:IsLocked() or self.DirtyCount <= 0 or washSide(self, player) ~= true then
		return false
	end
	local character = player.Character
	if character == nil then
		return false
	end
	local session: Session = {
		Player = player,
		Character = character,
		OnEnded = onEnded,
		Trove = Trove.new(),
		Loop = nil,
		Timeout = nil,
		Converting = false,
		StopRequested = false,
	}
	self.Session = session
	character:SetAttribute(InteractionConfig.ActionAnimationAttribute, "Wash")
	local stored = self.Instance:GetAttribute(InteractionConfig.WashProgressAttribute)
	local progress = if typeof(stored) == "number" then math.clamp(stored, 0, 100) else 0
	self.Instance:SetAttribute(InteractionConfig.WashProgressAttribute, progress)
	session.Trove:Connect(self.Instance.Destroying, function(): ()
		endSession(self, session)
	end)
	session.Trove:Connect(player.CharacterRemoving, function(): ()
		endSession(self, session)
	end)
	session.Trove:Connect(Players.PlayerRemoving, function(leaving: Player): ()
		if leaving == player then
			endSession(self, session)
		end
	end)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid ~= nil then
		session.Trove:Connect(humanoid.Died, function(): ()
			endSession(self, session)
		end)
	end
	restartTimeout(self, session)
	session.Loop = task.defer(function(): ()
		while self.Session == session do
			if progress >= 100 then
				if not complete(self, session) then
					return
				end
				progress = 0
			end
			local delta = RunService.Heartbeat:Wait()
			if self.Session ~= session then
				return
			end
			progress = math.min(progress + delta * InteractionConfig.WashRate, 100)
			self.Instance:SetAttribute(InteractionConfig.WashProgressAttribute, progress)
		end
	end)
	return true
end

function Sink.StopUse(self: Sink, player: Player): ()
	local session = self.Session
	if session ~= nil and session.Player == player then
		if session.Converting then
			session.StopRequested = true
		else
			endSession(self, session)
		end
	end
end

function Sink.Destroy(self: Sink): ()
	local session = self.Session
	if session ~= nil then
		endSession(self, session)
	end
	Station.Destroy(self)
end

return Sink
