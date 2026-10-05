--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EffectService = require(script.Parent.EffectService)
local TeamService = require(script.Parent.TeamService)
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Levels = Config.Levels
local RoundConfig = Config.Round
local Net = require(Shared:WaitForChild("Net"))

export type Order = {
	OrderNum: number,
	Recipe: number,
	StartedAt: number,
	Duration: number,
}

type Entry = { Data: Order, Timer: thread }

local OrderService = {}
local activeGeneration: number? = nil
local orders: { [number]: { [number]: Entry } } = {}
local nextNumbers: { [number]: number } = {}

local function sendTeam(team: number, message: string, value: any): ()
	for _, player in TeamService.GetPlayers(team) do
		Net.Event("Round"):FireClient(player, message, value)
	end
end

local function snapshot(team: number): { Order }
	local list: { Order } = {}
	local teamOrders = orders[team]
	if teamOrders == nil then
		return list
	end
	for _, entry in teamOrders do
		table.insert(list, entry.Data)
	end
	table.sort(list, function(left: Order, right: Order): boolean
		return left.OrderNum < right.OrderNum
	end)
	return list
end

function OrderService.SendSnapshot(player: Player): ()
	Net.Event("Round"):FireClient(player, "Orders", snapshot(TeamService.GetTeam(player)))
end

function OrderService.Stop(): ()
	activeGeneration = nil
	for _, teamOrders in orders do
		for _, entry in teamOrders do
			task.cancel(entry.Timer)
		end
	end
	orders = {}
	nextNumbers = {}
end

local function addOrder(team: number, recipeId: number, generation: number): ()
	local recipe = Levels.GetCurrent().Recipes[recipeId]
	if recipe == nil then
		warn(`Order sequence names missing recipe {recipeId}`)
		return
	end
	local number = nextNumbers[team] or 1
	nextNumbers[team] = number + 1
	local order: Order = {
		OrderNum = number,
		Recipe = recipeId,
		StartedAt = workspace:GetServerTimeNow(),
		Duration = recipe.Time,
	}
	local timer = task.delay(recipe.Time, function(): ()
		if activeGeneration ~= generation then
			return
		end
		local teamOrders = orders[team]
		if teamOrders == nil or teamOrders[number] == nil then
			return
		end
		teamOrders[number] = nil
		sendTeam(team, "ExpireOrder", number)
	end)
	orders[team][number] = { Data = order, Timer = timer }
	sendTeam(team, "AddOrder", order)
end

local function runSequence(team: number, sequence: string, delaySeconds: number, generation: number): number
	for index = 1, #sequence do
		if activeGeneration ~= generation then
			break
		end
		local symbol = string.sub(sequence, index, index)
		if symbol == "-" then
			while activeGeneration == generation and next(orders[team]) ~= nil do
				task.wait(0.1)
			end
		elseif symbol == "*" then
			delaySeconds *= 2
		elseif symbol == "/" then
			delaySeconds /= 2
		else
			local recipeId = tonumber(symbol)
			if recipeId ~= nil then
				addOrder(team, recipeId, generation)
				task.wait(delaySeconds)
			else
				warn(`Unknown order sequence symbol {symbol}`)
			end
		end
	end
	return delaySeconds
end

-- Effects and coins for a delivered order, shared by the serving window and manual tables.
local function payOrder(team: number, counter: Instance): ()
	Net.Event("Effect"):FireAllClients("OrderFinish", counter)
	local amount = Levels.GetCurrent().CoinsPerOrder
	local attribute = `Coins_{team}`
	local coins = ReplicatedStorage:GetAttribute(attribute)
	ReplicatedStorage:SetAttribute(attribute, (if typeof(coins) == "number" then coins else 0) + amount)
	for _, member in TeamService.GetPlayers(team) do
		Net.Event("Effect"):FireClient(member, "CoinNotif", amount)
	end
end

function OrderService.StartRound(teamCount: number, generation: number): ()
	OrderService.Stop()
	activeGeneration = generation
	local level = Levels.GetCurrent()
	for team = 1, teamCount do
		orders[team] = {}
		nextNumbers[team] = 1
		if RoundConfig.ServeMode == "Manual" then
			continue
		end
		task.spawn(function(): ()
			local delaySeconds = runSequence(team, level.Sequence, level.OrderDelay, generation)
			while activeGeneration == generation do
				if #level.LoopSequence == 0 then
					return
				end
				delaySeconds = runSequence(team, level.LoopSequence, delaySeconds, generation)
			end
		end)
	end
end

-- Manual serve mode: a customer's order. Expiry fires ExpireOrder and then onExpire.
function OrderService.Open(team: number, recipeId: number, onExpire: () -> ()): number?
	local generation = activeGeneration
	local teamOrders = orders[team]
	local recipe = Levels.GetCurrent().Recipes[recipeId]
	if generation == nil or teamOrders == nil or recipe == nil then
		return nil
	end
	local number = nextNumbers[team] or 1
	nextNumbers[team] = number + 1
	local order: Order = {
		OrderNum = number,
		Recipe = recipeId,
		StartedAt = workspace:GetServerTimeNow(),
		Duration = recipe.Time,
	}
	local timer = task.delay(recipe.Time, function(): ()
		if activeGeneration ~= generation or teamOrders[number] == nil then
			return
		end
		teamOrders[number] = nil
		sendTeam(team, "ExpireOrder", number)
		onExpire()
	end)
	teamOrders[number] = { Data = order, Timer = timer }
	sendTeam(team, "AddOrder", order)
	return number
end

function OrderService.Close(team: number, number: number, success: boolean, counter: Instance): ()
	local teamOrders = orders[team]
	local entry = if teamOrders ~= nil then teamOrders[number] else nil
	if teamOrders == nil or entry == nil then
		return
	end
	task.cancel(entry.Timer)
	teamOrders[number] = nil
	if success then
		sendTeam(team, "CompleteOrder", number)
		payOrder(team, counter)
	else
		sendTeam(team, "ExpireOrder", number)
	end
end

function OrderService.Serve(player: Player, dish: string, counter: Instance): boolean
	local team = TeamService.GetTeam(player)
	if ReplicatedStorage:GetAttribute("RoundState") == "Playing" then
		local teamOrders = orders[team]
		if teamOrders ~= nil then
			for _, order in snapshot(team) do
				local recipe = Levels.GetCurrent().Recipes[order.Recipe]
				if recipe ~= nil and recipe.Name == dish then
					local entry = teamOrders[order.OrderNum]
					if entry ~= nil then
						task.cancel(entry.Timer)
						teamOrders[order.OrderNum] = nil
						sendTeam(team, "CompleteOrder", order.OrderNum)
						payOrder(team, counter)
						return true
					end
				end
			end
		end
	end
	Net.Event("Effect"):FireAllClients("ObjError", counter)
	EffectService.Notify(player, counter, "NO ORDER YET!")
	return false
end

return OrderService
