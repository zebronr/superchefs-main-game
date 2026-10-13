--!strict

-- Coins flying into the coin card: a spinning copy of the card's coin pops in, hops, then flies along an arc to
-- the card. Served plates launch one for everyone (OrdersController, paid on serve); cash the local player
-- collects launches one only on their screen (CashController). GameUIController holds the counter's roll-up until
-- the last local coin lands (Remaining).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Gif = require(script.Parent.Gif)
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

-- Times are seconds after StartedAt: the coin appears at AppearAt and leaves for the card at FlyAt.
type Flight = { Coin: ImageLabel, From: Vector2, Size: Vector2, StartedAt: number, AppearAt: number, FlyAt: number }

local CoinFly = {}
local gameInfo = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("GameInfo") :: ScreenGui
local coinSprite = gameInfo:WaitForChild("InfoFrame"):WaitForChild("CoinsFrame"):WaitForChild("CoinSprite") :: ImageLabel
local flights: { Flight } = {}
local landsAt = -math.huge
local connection: RBXScriptConnection? = nil

local function backOut(p: number, strength: number): number
	local q = p - 1
	return 1 + (strength + 1) * q ^ 3 + strength * q ^ 2
end

local function update(): ()
	local tuning = Config.UI.Coins
	local clock = os.clock()
	local to = coinSprite.AbsolutePosition + coinSprite.AbsoluteSize / 2 - gameInfo.AbsolutePosition
	for index = #flights, 1, -1 do
		local flight = flights[index]
		local coin = flight.Coin
		local t = clock - flight.StartedAt
		local p = (t - flight.FlyAt) / tuning.FlyTime
		if p >= 1 or coin.Parent == nil then
			coin:Destroy()
			table.remove(flights, index)
			continue
		end
		coin.Visible = t >= flight.AppearAt
		-- Pops in with an overshoot and hops up and back down.
		local pop = math.clamp((t - flight.AppearAt) / tuning.FlyPopTime, 0, 1)
		local grow = math.max(backOut(pop, tuning.FlyPopOvershoot), 0)
		local hop = math.clamp((t - flight.AppearAt) / math.max(flight.FlyAt - flight.AppearAt, 0.001), 0, 1)
		local position = flight.From - Vector2.new(0, tuning.FlyHop * 4 * hop * (1 - hop))
		if p > 0 then
			-- Quadratic curve bowing up between the start and the card.
			local mid = (flight.From + to) / 2 - Vector2.new(0, tuning.FlyArc)
			local q = 1 - p
			position = flight.From * (q * q) + mid * (2 * q * p) + to * (p * p)
		end
		coin.Size = UDim2.fromOffset(flight.Size.X * grow, flight.Size.Y * grow)
		coin.Position = UDim2.fromOffset(position.X, position.Y)
	end
	if #flights == 0 and connection ~= nil then
		connection:Disconnect()
		connection = nil
	end
end

-- Launches a coin from `from` (pixels in GameInfo); it appears after `appearAt` seconds and flies at `flyAt`.
function CoinFly.Launch(from: Vector2, appearAt: number, flyAt: number): ()
	local coin = coinSprite:Clone()
	coin.AnchorPoint = Vector2.new(0.5, 0.5)
	coin.Position = UDim2.fromOffset(from.X, from.Y)
	coin.Visible = false
	coin.ZIndex = 10
	coin.Parent = gameInfo
	Gif.Play(coin)
	local now = os.clock()
	table.insert(flights, {
		Coin = coin,
		From = from,
		Size = coinSprite.AbsoluteSize,
		StartedAt = now,
		AppearAt = appearAt,
		FlyAt = flyAt,
	})
	landsAt = math.max(landsAt, now + flyAt + Config.UI.Coins.FlyTime)
	if connection == nil then
		connection = RunService.RenderStepped:Connect(update)
	end
end

-- Launches a coin from a point in the world, where it is on screen right now.
function CoinFly.FromWorld(position: Vector3): ()
	local camera = workspace.CurrentCamera
	if camera == nil then
		return
	end
	-- WorldToScreenPoint is in the same space as AbsolutePosition (below the top bar inset).
	local point = camera:WorldToScreenPoint(position)
	CoinFly.Launch(Vector2.new(point.X, point.Y) - gameInfo.AbsolutePosition, 0, Config.UI.Coins.CashHopTime)
end

-- Seconds until the last coin in the air lands (0 when none is).
function CoinFly.Remaining(): number
	return math.max(landsAt - os.clock(), 0)
end

function CoinFly.Clear(): ()
	for _, flight in flights do
		flight.Coin:Destroy()
	end
	table.clear(flights)
	landsAt = -math.huge
end

return CoinFly
