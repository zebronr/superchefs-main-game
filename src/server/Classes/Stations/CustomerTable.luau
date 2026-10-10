--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DirtyPlate = require(script.Parent.Parent.DirtyPlate)
local Item = require(script.Parent.Parent.Item)
local Plate = require(script.Parent.Parent.Plate)
local Station = require(script.Parent.Parent.Station)
local CarryService = require(script.Parent.Parent.Parent.Services.CarryService)
local EffectService = require(script.Parent.Parent.Parent.Services.EffectService)
local OrderService = require(script.Parent.Parent.Parent.Services.OrderService)
local TeamService = require(script.Parent.Parent.Parent.Services.TeamService)
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local RoundConfig = Config.Round
local Net = require(Shared:WaitForChild("Net"))
local Tags = require(Shared:WaitForChild("Tags"))

export type CustomerState = "Walking" | "WaitingToOrder" | "WaitingForFood" | "Eating" | "Dashing" | "Caught" | "Leaving"

-- What CustomerService hands the table; kept as callbacks so this class never requires the service.
export type Customer = {
	GetState: () -> CustomerState,
	GetDish: () -> string?,
	TakeOrder: () -> (),
	Serve: () -> (),
}

local CustomerTable = setmetatable({}, { __index = Station })
CustomerTable.__index = CustomerTable

export type CustomerTable = Station.Station & {
	Customer: Customer?,
	Alive: boolean,
}

local tables: { [Instance]: CustomerTable } = {}

function CustomerTable.new(instance: Instance): CustomerTable
	local self = Station.new(instance) :: CustomerTable
	self.Customer = nil
	self.Alive = true
	setmetatable(self :: any, CustomerTable)
	tables[instance] = self
	self.Slot.OnChanged = function(): ()
		CustomerTable.RefreshInteraction(self)
	end
	CustomerTable.RefreshInteraction(self)
	return self
end

-- Every live table in the current map.
function CustomerTable.All(): { CustomerTable }
	local list: { CustomerTable } = {}
	for instance, customerTable in tables do
		if customerTable.Alive and instance:IsDescendantOf(workspace) then
			table.insert(list, customerTable :: any)
		end
	end
	table.sort(list, function(left: CustomerTable, right: CustomerTable): boolean
		return left.Instance.Name < right.Instance.Name
	end)
	return list
end

function CustomerTable.SetCustomer(self: CustomerTable, customer: Customer?): ()
	self.Customer = customer
	CustomerTable.RefreshInteraction(self)
end

function CustomerTable.GetCustomer(self: CustomerTable): Customer?
	return self.Customer
end

function CustomerTable.GetSeat(self: CustomerTable): BasePart?
	local seat = self.Instance:FindFirstChild("Seat")
	if seat ~= nil and seat:IsA("BasePart") then
		return seat
	end
	return nil
end

-- No customer reserved and no dirty plate left on the table.
function CustomerTable.IsFree(self: CustomerTable): boolean
	return self.Customer == nil and self.Slot:Get() == nil
end

function CustomerTable.AddCash(self: CustomerTable, amount: number): ()
	local current = self.Instance:GetAttribute("Cash")
	self.Instance:SetAttribute("Cash", (if typeof(current) == "number" then current else 0) + amount)
	self.Instance:SetAttribute("CashAt", workspace:GetServerTimeNow())
	CustomerTable.RefreshInteraction(self)
end

function CustomerTable.ClearCash(self: CustomerTable): ()
	self.Instance:SetAttribute("Cash", nil)
	self.Instance:SetAttribute("CashAt", nil)
	self.Instance:SetAttribute("CashCollectedBy", nil)
	self.Instance:SetAttribute("CashCollectedAt", nil)
	CustomerTable.RefreshInteraction(self)
end

local function serve(self: CustomerTable, customer: Customer, player: Player, plate: Plate.Plate): boolean
	local dish = customer.GetDish()
	if dish == nil or plate.Content ~= dish then
		Net.Event("Effect"):FireAllClients("ObjError", self.Instance)
		EffectService.Notify(player, self.Instance, "WRONG ORDER!")
		return false
	end
	local dropped = CarryService.Drop(player, true)
	if dropped ~= plate then
		return false
	end
	if not self.Slot:Place(plate) then
		CarryService.Pickup(player, plate)
		return false
	end
	customer.Serve()
	return true
end

-- Picks up the dirty plate a finished customer left behind, or stacks it onto carried dirty plates.
local function takeDirtyPlate(self: CustomerTable, player: Player, held: Item.Item?): boolean
	local onTop = self.Slot:Get()
	if onTop == nil or DirtyPlate.Cast(onTop) == nil then
		return false
	end
	if held ~= nil then
		local carried = DirtyPlate.Cast(held)
		return carried ~= nil and carried:Accept(onTop, player)
	end
	local taken = self.Slot:Take()
	if taken == nil then
		return false
	end
	if not CarryService.Pickup(player, taken) then
		self.Slot:Place(taken)
		return false
	end
	return true
end

function CustomerTable.RefreshInteraction(self: CustomerTable): ()
	local enabled = false
	if RoundConfig.ServeMode == "Manual" then
		local customer = self.Customer
		if customer ~= nil then
			local state = customer.GetState()
			enabled = state == "WaitingToOrder" or state == "WaitingForFood"
		end
		local cash = self.Instance:GetAttribute("Cash")
		enabled = enabled or (typeof(cash) == "number" and cash > 0) or DirtyPlate.Cast(self.Slot:Get()) ~= nil
	end
	Tags.SetInteractionDisabled(self.Instance, not enabled)
end

function CustomerTable.Handle(self: CustomerTable, player: Player, held: Item.Item?): boolean
	-- Window mode has no customers; the tables do nothing.
	if RoundConfig.ServeMode ~= "Manual" then
		return false
	end
	local customer = self.Customer
	if customer ~= nil then
		local state = customer.GetState()
		if state == "WaitingToOrder" then
			customer.TakeOrder()
			return true
		elseif state == "WaitingForFood" then
			local plate = Plate.Cast(held)
			if plate ~= nil then
				return serve(self, customer, player, plate)
			end
		end
	end
	-- One press clears the table: the cash is collected along with the dirty plate.
	local cash = self.Instance:GetAttribute("Cash")
	local amount = if typeof(cash) == "number" then cash else 0
	local collected = amount > 0
	if collected then
		OrderService.Pay(TeamService.GetTeam(player), amount, self.Instance)
		self.Instance:SetAttribute("CashCollectedBy", player.UserId)
		self.Instance:SetAttribute("CashCollectedAt", workspace:GetServerTimeNow())
		self.Instance:SetAttribute("Cash", nil)
		self.Instance:SetAttribute("CashAt", nil)
		CustomerTable.RefreshInteraction(self)
	end
	return takeDirtyPlate(self, player, held) or collected
end

function CustomerTable.Destroy(self: CustomerTable): ()
	self.Alive = false
	self.Customer = nil
	if tables[self.Instance] == self then
		tables[self.Instance] = nil
	end
	Station.Destroy(self)
end

return CustomerTable
