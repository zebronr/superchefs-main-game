--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Item = require(script.Parent.Item)
local FireService = require(script.Parent.Parent.Services.FireService)
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Interaction")).Cooking

type Session = {
	Player: Player,
	OnEnded: () -> (),
	Loop: thread?,
	HolderWatch: RBXScriptConnection?,
}

local FireExtinguisher = setmetatable({}, { __index = Item })
FireExtinguisher.__index = FireExtinguisher

export type FireExtinguisher = Item.Item & {
	Session: Session?,
}

function FireExtinguisher.new(instance: Instance): FireExtinguisher
	local self = Item.new(instance) :: FireExtinguisher
	self.Session = nil
	setmetatable(self :: any, FireExtinguisher)
	instance:SetAttribute(Config.SprayingAttribute, nil)
	return self
end

local function endSession(self: FireExtinguisher, session: Session): ()
	if self.Session ~= session then
		return
	end
	self.Session = nil
	local loop = session.Loop
	if loop ~= nil and loop ~= coroutine.running() then
		task.cancel(loop)
	end
	if session.HolderWatch ~= nil then
		session.HolderWatch:Disconnect()
	end
	self.Instance:SetAttribute(Config.SprayingAttribute, nil)
	session.OnEnded()
end

local function findFire(part: Instance): Instance?
	local current: Instance? = part
	while current ~= nil and current ~= workspace do
		if FireService.IsBurning(current) then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function spray(self: FireExtinguisher, player: Player): ()
	local emitter = self.Part:FindFirstChild("Emitter")
	if emitter == nil or not emitter:IsA("BasePart") then
		return
	end
	local excluded: { Instance } = { self.Instance }
	for _, ignored in CollectionService:GetTagged("IGNORE") do
		table.insert(excluded, ignored)
	end
	for _, descendant in self.Instance:GetDescendants() do
		table.insert(excluded, descendant)
	end
	if player.Character ~= nil then
		table.insert(excluded, player.Character)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = excluded
	for y = -3, -5, -1 do
		for x = -5, 5, 5 do
			local origin = emitter.CFrame
			local endpoint = origin * CFrame.new(x, y, -Config.ExtinguisherRange)
			local hit = workspace:Raycast(origin.Position, endpoint.Position - origin.Position, params)
			if hit ~= nil and (hit.Position - origin.Position).Magnitude <= Config.ExtinguisherRange then
				local burning = findFire(hit.Instance)
				if burning ~= nil then
					FireService.Extinguish(burning, Config.ExtinguisherDeduction)
				end
			end
		end
	end
end

function FireExtinguisher.StartUse(self: FireExtinguisher, player: Player, onEnded: () -> ()): boolean
	if self.Holder ~= player or self.Session ~= nil then
		return false
	end
	local emitter = self.Part:FindFirstChild("Emitter")
	if emitter == nil or not emitter:IsA("BasePart") then
		return false
	end
	local session: Session = {
		Player = player,
		OnEnded = onEnded,
		Loop = nil,
		HolderWatch = nil,
	}
	self.Session = session
	self.Instance:SetAttribute(Config.SprayingAttribute, true)
	session.HolderWatch = game:GetService("RunService").Heartbeat:Connect(function(): ()
		if self.Holder ~= player then
			endSession(self, session)
		end
	end)
	session.Loop = task.defer(function(): ()
		while self.Session == session and self.Holder == player do
			spray(self, player)
			task.wait(Config.ExtinguisherTick)
		end
		endSession(self, session)
	end)
	return true
end

function FireExtinguisher.StopUse(self: FireExtinguisher, player: Player): ()
	local session = self.Session
	if session ~= nil and session.Player == player then
		endSession(self, session)
	end
end

function FireExtinguisher.Destroy(self: FireExtinguisher): ()
	local session = self.Session
	if session ~= nil then
		endSession(self, session)
	end
	Item.Destroy(self)
end

return FireExtinguisher
