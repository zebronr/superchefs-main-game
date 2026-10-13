--!strict

-- Paper tickets fly from a table to an order card; their puffs are short-lived UI clones.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local tuning = Config.UI.TakeOrder

export type Flight = {
	Ticket: GuiObject,
	From: Vector2,
	To: Vector2,
	Position: Vector2,
	Size: Vector2,
	Scale: number,
	StartedAt: number,
	NextPuffAt: number,
	Target: () -> Vector2?,
	OnLand: () -> (),
}
type Puff = { Image: ImageLabel, From: Vector2, Offset: Vector2, Size: Vector2, StartedAt: number, Life: number }

local TicketFly = {}
local orderList = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("OrderList") :: ScreenGui
local ticketTemplate = orderList:WaitForChild("Ticket") :: GuiObject
local puffTemplate = orderList:WaitForChild("TicketPuff") :: ImageLabel
local flights: { Flight } = {}
local puffs: { Puff } = {}
local connection: RBXScriptConnection? = nil

local function backOut(p: number, strength: number): number
	local q = p - 1
	return 1 + (strength + 1) * q ^ 3 + strength * q ^ 2
end

local function spawnPuff(position: Vector2, offset: Vector2, scale: number, life: number): ()
	local image = puffTemplate:Clone()
	image.Size = UDim2.fromOffset(puffTemplate.Size.X.Offset * scale, puffTemplate.Size.Y.Offset * scale)
	image.Position = UDim2.fromOffset(position.X, position.Y)
	image.ImageTransparency = 0.2
	image.Visible = true
	image.Parent = orderList
	table.insert(puffs, {
		Image = image,
		From = position,
		Offset = offset,
		Size = Vector2.new(image.Size.X.Offset, image.Size.Y.Offset),
		StartedAt = os.clock(),
		Life = life,
	})
end

local function land(index: number, flight: Flight, position: Vector2): ()
	flight.Ticket:Destroy()
	table.remove(flights, index)
	flight.OnLand()
	local offset = math.random() * math.pi * 2
	for i = 1, tuning.LandPuffs do
		local angle = (i - 1) / tuning.LandPuffs * math.pi * 2 + offset
		spawnPuff(position, Vector2.new(math.cos(angle), math.sin(angle)) * tuning.LandSpread * flight.Scale, flight.Scale, tuning.LandLife)
	end
end

local function update(): ()
	local clock = os.clock()
	for index = #flights, 1, -1 do
		local flight = flights[index]
		local ticket = flight.Ticket
		local t = clock - flight.StartedAt
		local p = math.clamp((t - tuning.TicketDelay) / tuning.TicketFlyTime, 0, 1)
		local to = flight.Target()
		if to == nil then
			land(index, flight, flight.Position)
			continue
		end
		flight.To = to
		local eased = p * p * (3 - 2 * p)
		local mid = (flight.From + flight.To) / 2 - Vector2.new(0, tuning.TicketArc * flight.Scale)
		local q = 1 - eased
		local position = flight.From * (q * q) + mid * (2 * q * eased) + flight.To * (eased * eased)
		flight.Position = position
		if p >= 1 then
			land(index, flight, position)
			continue
		end
		ticket.Visible = t >= tuning.TicketDelay
		local pop = math.clamp((t - tuning.TicketDelay) / tuning.TicketPopTime, 0, 1)
		local grow = math.max(backOut(pop, tuning.TicketPopOvershoot), 0.001)
		local shrink = 1 + (tuning.TicketLandScale - 1) * eased
		ticket.Size = UDim2.fromOffset(flight.Size.X * grow * shrink, flight.Size.Y * grow * shrink)
		ticket.Position = UDim2.fromOffset(position.X, position.Y)
		ticket.Rotation = math.sin(p * math.pi * 2) * tuning.TicketSpin
		if t >= tuning.TicketDelay then
			while flight.NextPuffAt <= clock do
				spawnPuff(position, Vector2.zero, flight.Scale, tuning.TrailLife)
				flight.NextPuffAt += tuning.TrailInterval
			end
		end
	end
	for index = #puffs, 1, -1 do
		local puff = puffs[index]
		local p = math.clamp((clock - puff.StartedAt) / puff.Life, 0, 1)
		if p >= 1 then
			puff.Image:Destroy()
			table.remove(puffs, index)
		else
			local ease = 1 - (1 - p) ^ 2
			local position = puff.From + puff.Offset * ease
			local grow = 1 + (tuning.TrailGrow - 1) * ease
			puff.Image.Position = UDim2.fromOffset(position.X, position.Y)
			puff.Image.Size = UDim2.fromOffset(puff.Size.X * grow, puff.Size.Y * grow)
			puff.Image.ImageTransparency = 0.2 + 0.8 * p
		end
	end
	if #flights == 0 and #puffs == 0 and connection ~= nil then
		connection:Disconnect()
		connection = nil
	end
end

function TicketFly.Duration(): number
	return tuning.TicketDelay + tuning.TicketFlyTime
end

function TicketFly.Launch(from: Vector2, scale: number, target: () -> Vector2?, onLand: () -> ()): Flight
	local ticket = ticketTemplate:Clone()
	local size = Vector2.new(ticketTemplate.Size.X.Offset, ticketTemplate.Size.Y.Offset) * scale
	ticket.Size = UDim2.fromOffset(size.X, size.Y)
	ticket.Position = UDim2.fromOffset(from.X, from.Y)
	ticket.Visible = false
	ticket.Parent = orderList
	local clock = os.clock()
	local flight: Flight = {
		Ticket = ticket,
		From = from,
		To = target() or from,
		Position = from,
		Size = size,
		Scale = scale,
		StartedAt = clock,
		NextPuffAt = clock + tuning.TicketDelay,
		Target = target,
		OnLand = onLand,
	}
	table.insert(flights, flight)
	if connection == nil then
		connection = RunService.RenderStepped:Connect(update)
	end
	return flight
end

function TicketFly.Cancel(flight: Flight): ()
	for index, current in flights do
		if current == flight then
			current.Ticket:Destroy()
			table.remove(flights, index)
			break
		end
	end
end

function TicketFly.Clear(): ()
	for _, flight in flights do
		flight.Ticket:Destroy()
	end
	table.clear(flights)
	for _, puff in puffs do
		puff.Image:Destroy()
	end
	table.clear(puffs)
	if connection ~= nil then
		connection:Disconnect()
		connection = nil
	end
end

return TicketFly
