--!strict

-- Studio only (Config.UI.EffectTester), toggled with /testerui: PlayerGui.EffectTester's buttons play the order, combo and coin effects
-- locally, without a round or the server, so they can be tuned by eye. Nothing here reaches the server.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local CoinFly = require(script.Parent.Parent.Util.CoinFly)
local ComboController = require(script.Parent.ComboController)
local GameUIController = require(script.Parent.GameUIController)
local OrdersController = require(script.Parent.OrdersController)
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Levels = Config.Levels
local Tags = require(Shared:WaitForChild("Tags"))

type Order = OrdersController.Order

local EffectTesterController = {}
-- Fake order numbers start high so they never meet the server's.
local nextOrder = 100000

local function addOrder(timeUsed: number): ()
	local recipes = Levels.GetCurrent().Recipes
	local index = math.random(1, #recipes)
	local duration = recipes[index].Time
	nextOrder += 1
	GameUIController.Preview()
	OrdersController.Simulate("AddOrder", {
		OrderNum = nextOrder,
		Recipe = recipes[index].Id,
		StartedAt = workspace:GetServerTimeNow() - duration * timeUsed,
		Duration = duration,
		Table = math.random(1, 6),
	})
end

local function oldest(): Order?
	return OrdersController.Orders()[1]
end

-- The level's combo window and fever, or stand-ins when the level has none.
local function comboWindow(): number
	local combo = Levels.GetCurrent().Combo
	return if combo ~= nil then combo.Window else 20
end

local function feverTuning(): { At: number, Time: number, Multiplier: number }
	local combo = Levels.GetCurrent().Combo
	local fever = if combo ~= nil then combo.Fever else nil
	return fever or { At = 6, Time = 10, Multiplier = 3 }
end

-- The simulated combo while it runs (0 once lapsed), and whether it is in a fever.
local function liveCombo(): (number, boolean)
	local state = ComboController.Simulated()
	local now = workspace:GetServerTimeNow()
	local endsAt = if state ~= nil then state.EndsAt else nil
	if state == nil or endsAt == nil or now > endsAt then
		return 0, false
	end
	local feverEndsAt = state.FeverEndsAt
	return state.Combo, feverEndsAt ~= nil and now < feverEndsAt
end

-- Starts a simulated fever at `combo`, then hands the badge back to the server's combo once it has burnt out.
local function startFever(combo: number): ()
	local endsAt = workspace:GetServerTimeNow() + feverTuning().Time
	ComboController.Simulate({ Combo = combo, EndsAt = endsAt, FeverEndsAt = endsAt })
	task.delay(feverTuning().Time + Config.UI.Combo.BreakTime + 0.1, function(): ()
		local state = ComboController.Simulated()
		if state ~= nil and state.FeverEndsAt == endsAt then
			ComboController.Simulate(nil)
		end
	end)
end

local function comboUp(): ()
	local combo, inFever = liveCombo()
	local state = ComboController.Simulated()
	if inFever and state ~= nil then
		ComboController.Simulate({ Combo = combo + 1, EndsAt = state.EndsAt, FeverEndsAt = state.FeverEndsAt })
		return
	end
	local level = Levels.GetCurrent()
	local fever = if level.Combo ~= nil then level.Combo.Fever else nil
	if fever ~= nil and combo + 1 >= fever.At then
		startFever(combo + 1)
		return
	end
	ComboController.Simulate({ Combo = combo + 1, EndsAt = workspace:GetServerTimeNow() + comboWindow() })
end

-- Breaks the simulated combo (`reason` as the server would name it), then hands the badge back to the server's
-- combo once the break has played.
local function breakCombo(reason: string): ()
	ComboController.Simulate({ Combo = 0, Reason = reason })
	task.delay(math.max(Config.UI.Combo.SmokeTime, Config.UI.Combo.BreakTime), function(): ()
		local state = ComboController.Simulated()
		if state ~= nil and state.Combo == 0 then
			ComboController.Simulate(nil)
		end
	end)
end

-- Coins for one serve at the simulated combo (Config.Levels Combo multipliers when the level has them).
local function serveAmount(): number
	local level = Levels.GetCurrent()
	local combo, fever = liveCombo()
	if fever then
		return math.round(level.CoinsPerOrder * feverTuning().Multiplier)
	end
	local multipliers = if level.Combo ~= nil then level.Combo.Multipliers else { 1 }
	return math.round(level.CoinsPerOrder * multipliers[math.clamp(combo, 1, #multipliers)])
end

local actions: { [string]: () -> () } = {
	AddOrder = function(): ()
		addOrder(0)
	end,
	AddUrgent = function(): ()
		-- Starts just inside the urgent part of its timer.
		addOrder(1 - Config.UI.Orders.Urgent * 0.9)
	end,
	Serve = function(): ()
		local order = oldest()
		if order ~= nil then
			OrdersController.Simulate("CompleteOrder", order.OrderNum)
			comboUp()
			GameUIController.PreviewGain(serveAmount())
		end
	end,
	Expire = function(): ()
		local order = oldest()
		if order ~= nil then
			OrdersController.Simulate("ExpireOrder", order.OrderNum)
			breakCombo("Expired")
		end
	end,
	Freeze = function(): ()
		local now = workspace:GetServerTimeNow()
		for _, order in OrdersController.Orders() do
			local pausedAt = order.PausedAt
			OrdersController.Simulate("UpdateOrder", {
				OrderNum = order.OrderNum,
				Recipe = order.Recipe,
				StartedAt = if pausedAt ~= nil then order.StartedAt + now - pausedAt else order.StartedAt,
				Duration = order.Duration,
				PausedAt = if pausedAt ~= nil then nil else now,
				Table = order.Table,
			})
		end
	end,
	ComboUp = function(): ()
		GameUIController.Preview()
		comboUp()
	end,
	ComboBreak = function(): ()
		breakCombo("Expired")
	end,
	-- A serve too late (or out of order) resets the combo without the card shaking.
	ComboLate = function(): ()
		breakCombo("Late")
	end,
	Fever = function(): ()
		GameUIController.Preview()
		startFever(math.max(liveCombo(), feverTuning().At))
	end,
	Coins = function(): ()
		GameUIController.Preview()
		GameUIController.PreviewGain(12)
	end,
	-- Table cash collected by this player: a coin flies from the nearest customer table (or in front of the
	-- camera) to the coin card.
	CollectCash = function(): ()
		local camera = workspace.CurrentCamera
		if camera == nil then
			return
		end
		local from = camera.CFrame.Position + camera.CFrame.LookVector * 20
		local best = math.huge
		for _, instance in CollectionService:GetTagged(Tags.ClassTag(Tags.CustomerTable)) do
			if instance:IsA("BasePart") then
				local distance = (instance.Position - camera.CFrame.Position).Magnitude
				if distance < best then
					best = distance
					from = instance.Position
				end
			end
		end
		GameUIController.Preview()
		CoinFly.FromWorld(from)
		GameUIController.PreviewGain(serveAmount())
	end,
}

function EffectTesterController.Start(_self: typeof(EffectTesterController)): ()
	local tuning = Config.UI.EffectTester
	local player = Players.LocalPlayer
	local allowed = RunService:IsStudio() and table.find(tuning.UserIds, player.UserId) ~= nil
	local command = TextChatService:WaitForChild(tuning.Command) :: TextChatCommand
	-- Off for everyone else, so for them "/testerui" is just a chat message.
	command.Enabled = allowed
	if not allowed then
		return
	end
	local gui = player:WaitForChild("PlayerGui"):WaitForChild("EffectTester") :: ScreenGui
	local panel = gui:WaitForChild("Panel")
	for name, action in actions do
		local button = panel:WaitForChild(name) :: GuiButton
		button.Activated:Connect(action)
	end
	gui.Enabled = false
	command.Triggered:Connect(function(source: TextSource): ()
		if source.UserId == player.UserId then
			gui.Enabled = not gui.Enabled
		end
	end)
end

return EffectTesterController
