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
	-- Server time Deep Freeze paused the ticket (nil while it runs). Clients stop the bar here.
	PausedAt: number?,
	-- Table number of a manual order's customer (shown on the plate); nil for window orders.
	Table: number?,
}

-- Timer is nil while the ticket is paused; OnExpire restarts it on Resume (only manual orders have one).
type Entry = { Data: Order, Timer: thread?, OnExpire: (() -> ())? }

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

-- Team combo (level EnableCombo): Combo_{team} counts serves made back to back, each within the level's
-- Combo.Window of the last; ComboEndsAt_{team} is the server time the streak lapses. ComboReason_{team} says why
-- it last reset ("Expired", "Failed", "Late", "OutOfOrder", "FeverOver"; nil while it runs or after a lapse).
-- FeverEndsAt_{team} is the server time the team's fever ends. Clients draw all of it.
local function setCombo(team: number, combo: number, endsAt: number?, reason: string?): ()
	ReplicatedStorage:SetAttribute(`ComboReason_{team}`, reason)
	ReplicatedStorage:SetAttribute(`Combo_{team}`, combo)
	ReplicatedStorage:SetAttribute(`ComboEndsAt_{team}`, endsAt)
end

local function inFever(team: number, now: number): boolean
	local endsAt = ReplicatedStorage:GetAttribute(`FeverEndsAt_{team}`)
	return typeof(endsAt) == "number" and now < endsAt
end

-- Nothing breaks the combo during a fever.
local function breakCombo(team: number, reason: string): ()
	if Levels.GetCurrent().EnableCombo and not inFever(team, workspace:GetServerTimeNow()) then
		setCombo(team, 0, nil, reason)
	end
end

local function startFever(team: number, fever: { Time: number }, now: number): number
	local endsAt = now + fever.Time
	local generation = activeGeneration
	ReplicatedStorage:SetAttribute(`FeverEndsAt_{team}`, endsAt)
	task.delay(fever.Time, function(): ()
		if activeGeneration == generation and ReplicatedStorage:GetAttribute(`FeverEndsAt_{team}`) == endsAt then
			setCombo(team, 0, nil, "FeverOver")
		end
	end)
	return endsAt
end

-- Coins for serving `order` (`oldest` = it was the team's oldest open order): CoinsPerOrder, times the combo
-- multiplier when combos are on, and moves the combo by the level's rules (fresh serves, oldest first, fever).
local function serveAmount(team: number, order: Order, oldest: boolean): number
	local level = Levels.GetCurrent()
	local tuning = level.Combo
	if not level.EnableCombo or tuning == nil then
		return level.CoinsPerOrder
	end
	local now = workspace:GetServerTimeNow()
	local current = ReplicatedStorage:GetAttribute(`Combo_{team}`)
	local endsAt = ReplicatedStorage:GetAttribute(`ComboEndsAt_{team}`)
	local count = if typeof(current) == "number" and typeof(endsAt) == "number" and now <= endsAt then current else 0
	local fever = tuning.Fever
	local multipliers = tuning.Multipliers
	local function multiplierAt(combo: number): number
		return if #multipliers > 0 then multipliers[math.clamp(combo, 1, #multipliers)] else 1
	end
	if fever ~= nil and inFever(team, now) then
		-- Every serve counts and pays the fever rate; the streak runs until the fever ends.
		setCombo(team, count + 1, ReplicatedStorage:GetAttribute(`FeverEndsAt_{team}`) :: number?, nil)
		return math.round(level.CoinsPerOrder * fever.Multiplier)
	end
	local resetBy: string? = nil
	local grows = true
	if tuning.OldestFirst and not oldest then
		resetBy = "OutOfOrder"
	else
		local fresh = tuning.Fresh
		if fresh ~= nil then
			local used = ((order.PausedAt or now) - order.StartedAt) / math.max(order.Duration, 0.001)
			if used >= fresh.LateAfter then
				resetBy = "Late"
			elseif used >= fresh.FreshUntil then
				grows = false
			end
		end
	end
	if resetBy ~= nil then
		-- Still paid, at the base rate; a streak of 0 has nothing to lose.
		if count > 0 then
			setCombo(team, 0, nil, resetBy)
		end
		return math.round(level.CoinsPerOrder * multiplierAt(1))
	end
	if not grows then
		-- Holds: no gain, but the window starts over.
		if count > 0 then
			setCombo(team, count, now + tuning.Window, nil)
		end
		return math.round(level.CoinsPerOrder * multiplierAt(count))
	end
	count += 1
	if fever ~= nil and count >= fever.At then
		setCombo(team, count, startFever(team, fever, now), nil)
		return math.round(level.CoinsPerOrder * fever.Multiplier)
	end
	setCombo(team, count, now + tuning.Window, nil)
	return math.round(level.CoinsPerOrder * multiplierAt(count))
end

local function oldestNumber(teamOrders: { [number]: Entry }): number?
	local oldest: number? = nil
	for number in teamOrders do
		if oldest == nil or number < oldest then
			oldest = number
		end
	end
	return oldest
end

local function clearCombo(team: number): ()
	setCombo(team, 0, nil, nil)
	ReplicatedStorage:SetAttribute(`FeverEndsAt_{team}`, nil)
end

function OrderService.SendSnapshot(player: Player): ()
	Net.Event("Round"):FireClient(player, "Orders", snapshot(TeamService.GetTeam(player)))
end

function OrderService.Stop(): ()
	activeGeneration = nil
	for team, teamOrders in orders do
		clearCombo(team)
		for _, entry in teamOrders do
			local timer = entry.Timer
			if timer ~= nil then
				task.cancel(timer)
			end
		end
	end
	orders = {}
	nextNumbers = {}
end

local function addOrder(team: number, recipeId: number, generation: number): ()
	local recipe = Levels.GetRecipe(recipeId)
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
		breakCombo(team, "Expired")
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

-- Credits a team when payment is actually collected.
function OrderService.Pay(team: number, amount: number, _at: Instance): ()
	local attribute = `Coins_{team}`
	local coins = ReplicatedStorage:GetAttribute(attribute)
	ReplicatedStorage:SetAttribute(attribute, (if typeof(coins) == "number" then coins else 0) + amount)
	for _, member in TeamService.GetPlayers(team) do
		Net.Event("Effect"):FireClient(member, "CoinNotif", amount)
	end
end

local function payOrder(team: number, counter: Instance, amount: number): ()
	Net.Event("Effect"):FireAllClients("OrderFinish", counter)
	OrderService.Pay(team, amount, counter)
end

function OrderService.StartRound(teamCount: number, generation: number): ()
	OrderService.Stop()
	activeGeneration = generation
	local level = Levels.GetCurrent()
	for team = 1, teamCount do
		orders[team] = {}
		nextNumbers[team] = 1
		clearCombo(team)
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
function OrderService.Open(team: number, recipeId: number, onExpire: () -> (), tableNumber: number?): number?
	local generation = activeGeneration
	local teamOrders = orders[team]
	local recipe = Levels.GetRecipe(recipeId)
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
		Table = tableNumber,
	}
	local function expire(): ()
		if activeGeneration ~= generation or teamOrders[number] == nil then
			return
		end
		teamOrders[number] = nil
		sendTeam(team, "ExpireOrder", number)
		breakCombo(team, "Expired")
		onExpire()
	end
	teamOrders[number] = { Data = order, Timer = task.delay(recipe.Time, expire), OnExpire = expire }
	sendTeam(team, "AddOrder", order)
	return number
end

-- Deep Freeze: stops a manual order's timer.
function OrderService.Pause(team: number, number: number): ()
	local teamOrders = orders[team]
	local entry = if teamOrders ~= nil then teamOrders[number] else nil
	if entry == nil or entry.OnExpire == nil or entry.Data.PausedAt ~= nil then
		return
	end
	local timer = entry.Timer
	entry.Timer = nil
	if timer ~= nil then
		task.cancel(timer)
	end
	entry.Data.PausedAt = workspace:GetServerTimeNow()
	sendTeam(team, "UpdateOrder", entry.Data)
end

-- Restarts a paused order with the time it had left; its StartedAt moves by the paused time.
function OrderService.Resume(team: number, number: number): ()
	local teamOrders = orders[team]
	local entry = if teamOrders ~= nil then teamOrders[number] else nil
	local pausedAt = if entry ~= nil then entry.Data.PausedAt else nil
	if entry == nil or pausedAt == nil then
		return
	end
	local now = workspace:GetServerTimeNow()
	local data = entry.Data
	data.StartedAt += now - pausedAt
	data.PausedAt = nil
	local expire = entry.OnExpire
	if expire ~= nil then
		entry.Timer = task.delay(math.max(0, data.StartedAt + data.Duration - now), expire)
	end
	sendTeam(team, "UpdateOrder", data)
end

-- Returns the coins the serve earned (combo included), whether or not they are paid now; 0 for a failure.
function OrderService.Close(team: number, number: number, success: boolean, counter: Instance, pay: boolean?): number
	local teamOrders = orders[team]
	local entry = if teamOrders ~= nil then teamOrders[number] else nil
	if teamOrders == nil or entry == nil then
		return 0
	end
	local oldest = oldestNumber(teamOrders) == number
	local timer = entry.Timer
	if timer ~= nil then
		task.cancel(timer)
	end
	teamOrders[number] = nil
	if not success then
		sendTeam(team, "ExpireOrder", number)
		breakCombo(team, "Failed")
		return 0
	end
	sendTeam(team, "CompleteOrder", number)
	local amount = serveAmount(team, entry.Data, oldest)
	if pay == false then
		Net.Event("Effect"):FireAllClients("OrderFinish", counter)
	else
		payOrder(team, counter, amount)
	end
	return amount
end

function OrderService.Serve(player: Player, dish: string, counter: Instance): boolean
	local team = TeamService.GetTeam(player)
	if ReplicatedStorage:GetAttribute("RoundState") == "Playing" then
		local teamOrders = orders[team]
		if teamOrders ~= nil then
			local oldest = oldestNumber(teamOrders)
			for _, order in snapshot(team) do
				local recipe = Levels.GetRecipe(order.Recipe)
				if recipe ~= nil and recipe.Name == dish then
					local entry = teamOrders[order.OrderNum]
					if entry ~= nil then
						local timer = entry.Timer
						if timer ~= nil then
							task.cancel(timer)
						end
						teamOrders[order.OrderNum] = nil
						sendTeam(team, "CompleteOrder", order.OrderNum)
						payOrder(team, counter, serveAmount(team, order, order.OrderNum == oldest))
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
