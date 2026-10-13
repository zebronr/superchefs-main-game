--!strict

-- Order row (PlayerGui.OrderList.list, top-right): a plate per order ringed by its timer, with a tray per recipe
-- step under it. Orders come from the server's Round events; everything drawn here is client cosmetic.
local GuiService = game:GetService("GuiService")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CoinFly = require(script.Parent.Parent.Util.CoinFly)
local TicketFly = require(script.Parent.Parent.Util.TicketFly)
local RadialRing = require(script.Parent.Parent.Util.RadialRing)
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Levels = Config.Levels
local Net = require(Shared:WaitForChild("Net"))
local Tags = require(Shared:WaitForChild("Tags"))

-- PausedAt: server time Deep Freeze paused the order (nil while it runs). Table: the customer's table number.
export type Order = {
	OrderNum: number,
	Recipe: number,
	StartedAt: number,
	Duration: number,
	PausedAt: number?,
	Table: number?,
}
type Tray = { Frame: GuiObject, Pop: UIScale }
-- A child effect piece and where it sits at rest.
type Piece = { Object: GuiObject, Position: UDim2, Size: UDim2 }
type Card = {
	Root: GuiObject,
	Body: GuiObject,
	Scale: UIScale,
	Plate: GuiObject,
	Glow: ImageLabel,
	Face: GuiObject,
	Dish: ImageLabel,
	-- The table tag and its centre's offset from the plate centre at PlateSize, so it can rock with the dish.
	Tag: GuiObject,
	TagOffset: Vector2,
	Served: GuiObject,
	ServedPop: UIScale,
	Trail: GuiObject,
	TrailLines: { GuiObject },
	Sparkles: GuiObject,
	SparklePieces: { Piece },
	Sweat: GuiObject,
	Drops: { Piece },
	Ring: RadialRing.Ring?,
	Trays: { Tray },
	Order: Order,
	-- Local clock time it arrived (nil = was already there, no arrival animation).
	AddedAt: number?,
	Ticket: TicketFly.Flight?,
	FromTicket: boolean,
	-- Local clock time it was served or expired (nil while active).
	RemovedAt: number?,
	Success: boolean,
	Size: number,
	UrgePhase: number,
}
-- The coin a served plate turns into: grows in place while the plate shrinks, then arcs to the coin card.

local OrdersController = {}
local gui = Players.LocalPlayer:WaitForChild("PlayerGui")
local templates = ReplicatedStorage:WaitForChild("UIs"):WaitForChild("OrdersUIs")
local plateTemplate = templates:WaitForChild("PlateOrder") :: GuiObject
local trayTemplate = templates:WaitForChild("StepTray") :: GuiObject
local slotTemplate = templates:WaitForChild("StepSlot") :: GuiObject
local orderList = gui:WaitForChild("OrderList") :: ScreenGui
local list = orderList:WaitForChild("list") :: GuiObject
local listScale = list:WaitForChild("UIScale") :: UIScale
local listLayout = list:WaitForChild("UIListLayout") :: UIListLayout
-- The queue strip for orders that don't fit: one dish icon per recipe with how many are waiting, so players can
-- still prep ahead. Always the leftmost item in the row.
local queue = list:WaitForChild("Queue") :: GuiObject
local queueLayout = queue:WaitForChild("UIListLayout") :: UIListLayout
local entryTemplate = queue:WaitForChild("Entry") :: GuiObject
type QueueEntry = { Root: GuiObject, Pop: UIScale, Count: GuiObject, CountLabel: TextLabel, Shown: number, ChangedAt: number }
local queued: { [number]: QueueEntry } = {}
entryTemplate.Visible = false
-- Order cards use LayoutOrder = -OrderNum, so this keeps the strip left of every one.
queue.LayoutOrder = -2 ^ 30
queue.Visible = false
local gameInfo = gui:WaitForChild("GameInfo") :: ScreenGui
local cards: { [number]: Card } = {}
local leaving: { Card } = {}

-- Walks a dotted child path of a template clone; the template contract is in docs/PLACEHOLDER-UI.md.
local function find(parent: Instance, path: string): any
	local current = parent
	for name in string.gmatch(path, "[^%.]+") do
		local child = current:FindFirstChild(name)
		if child == nil then
			error(`{parent.Name} is missing {path}`)
		end
		current = child
	end
	return current
end

local function backOut(p: number, strength: number): number
	local q = p - 1
	return 1 + (strength + 1) * q ^ 3 + strength * q ^ 2
end

local function trayWidth(slots: number): number
	local tuning = Config.UI.Orders
	return 2 * tuning.TrayPadding + slots * tuning.SlotSize + math.max(slots - 1, 0) * tuning.SlotGap
end

local function timeLeft(order: Order): number
	local now = order.PausedAt or workspace:GetServerTimeNow()
	return math.clamp((order.StartedAt + order.Duration - now) / math.max(order.Duration, 0.001), 0, 1)
end

local function ringColor(order: Order, fraction: number): Color3
	local tuning = Config.UI.Orders
	if order.PausedAt ~= nil then
		return Config.UI.Patience.Frozen
	end
	local progress = 1 - fraction
	local level = Levels.GetCurrent()
	local fresh = if level.EnableCombo and level.Combo ~= nil then level.Combo.Fresh else nil
	if fresh ~= nil then
		-- Fresh serves: flat bands that switch where the combo rule does (green builds, yellow holds, red resets).
		local function band(edge: number): number
			return math.clamp((progress - edge) / tuning.RingBlend + 0.5, 0, 1)
		end
		return tuning.RingGreen:Lerp(tuning.RingYellow, band(fresh.FreshUntil)):Lerp(tuning.RingRed, band(fresh.LateAfter))
	end
	return if progress <= 0.5
		then tuning.RingGreen:Lerp(tuning.RingYellow, progress * 2)
		else tuning.RingYellow:Lerp(tuning.RingRed, (progress - 0.5) * 2)
end

-- Plate size multiplier and drop offset (pixels) at `t` seconds after arrival: falls, squashes, stretches, settles.
local function arrival(t: number): (Vector2, number)
	local tuning = Config.UI.Orders
	if t < tuning.DropTime then
		local p = t / tuning.DropTime
		return Vector2.one, -tuning.DropHeight * (1 - p * p)
	end
	t -= tuning.DropTime
	if t < tuning.SquashTime then
		return Vector2.one:Lerp(tuning.Squash, t / tuning.SquashTime), 0
	end
	t -= tuning.SquashTime
	if t < tuning.StretchTime then
		return tuning.Squash:Lerp(tuning.Stretch, t / tuning.StretchTime), 0
	end
	t -= tuning.StretchTime
	if t < tuning.SettleTime then
		local p = t / tuning.SettleTime
		return Vector2.one + (tuning.Stretch - Vector2.one) * (math.cos(p * math.pi * 3) * (1 - p) ^ 2), 0
	end
	return Vector2.one, 0
end

local function pieces(parent: Instance): { Piece }
	local list: { Piece } = {}
	for _, child in parent:GetChildren() do
		if child:IsA("GuiObject") then
			table.insert(list, { Object = child, Position = child.Position, Size = child.Size })
		end
	end
	table.sort(list, function(left: Piece, right: Piece): boolean
		return left.Object.Name < right.Object.Name
	end)
	return list
end

-- Centre of `object` relative to its parent's centre, in pixels, with the parent drawn at `parentSize`.
local function centreOffset(object: GuiObject, parentSize: number): Vector2
	local position = object.Position
	local size = Vector2.new(object.Size.X.Offset, object.Size.Y.Offset)
	local topLeft = Vector2.new(position.X.Scale, position.Y.Scale) * parentSize
		+ Vector2.new(position.X.Offset, position.Y.Offset) - object.AnchorPoint * size
	return topLeft + size / 2 - Vector2.one * parentSize / 2
end

local function destroyCard(card: Card): ()
	card.Root:Destroy()
end

local function clearCards(): ()
	for number, card in cards do
		destroyCard(card)
		cards[number] = nil
	end
	for _, card in leaving do
		destroyCard(card)
	end
	table.clear(leaving)
	CoinFly.Clear()
	TicketFly.Clear()
end

-- Table numbers come from the same numeric name suffix that CustomerService uses.
local function tablePart(number: number): BasePart?
	for _, instance in CollectionService:GetTagged(Tags.ClassTag(Tags.CustomerTable)) do
		if instance:IsA("BasePart") and instance:IsDescendantOf(workspace)
			and tonumber(string.match(instance.Name, "(%d+)$")) == number then
			return instance
		end
	end
	return nil
end

local function buildTray(step: { ingredient_images: { string }, Method: string? }, index: number, animate: boolean): Tray
	local tuning = Config.UI.Orders
	local tray = trayTemplate:Clone()
	tray.Size = UDim2.fromOffset(trayWidth(#step.ingredient_images), tuning.TrayHeight)
	tray.LayoutOrder = index
	tray.Visible = true
	local slots = find(tray, "Slots") :: Instance
	for slotIndex, image in step.ingredient_images do
		local slot = slotTemplate:Clone()
		slot.Size = UDim2.fromOffset(tuning.SlotSize, tuning.SlotSize)
		slot.LayoutOrder = slotIndex
		slot.Visible = true
		;(find(slot, "Ingredient") :: ImageLabel).Image = image
		slot.Parent = slots
	end
	local method = find(tray, "Method") :: GuiObject
	local cookMethod = step.Method
	method.Visible = cookMethod ~= nil
	if cookMethod ~= nil then
		method.BackgroundColor3 = tuning.MethodColors[cookMethod] or method.BackgroundColor3
		;(find(method, "Icon") :: ImageLabel).Image = tuning.MethodIcons[cookMethod] or ""
	end
	local pop = find(tray, "Pop") :: UIScale
	pop.Scale = if animate then 0 else 1
	return { Frame = tray, Pop = pop }
end

-- Draws one card for this frame (defined below); addOrder calls it so a new card never shows a frame at rest.
local updateCard: (card: Card, dt: number, clock: number, oldest: number?) -> boolean

local function addOrder(order: Order, animate: boolean): ()
	local recipe = Levels.GetRecipe(order.Recipe)
	if recipe == nil or cards[order.OrderNum] ~= nil then
		return
	end
	local tuning = Config.UI.Orders
	local root = plateTemplate:Clone()
	local plate = find(root, "Body.Plate") :: GuiObject
	local steps = find(root, "Body.Steps") :: GuiObject
	local trays: { Tray } = {}
	local stepsWidth = 0
	for index, step in recipe.Steps do
		local tray = buildTray(step, index, animate)
		tray.Frame.Parent = steps
		table.insert(trays, tray)
		stepsWidth += trayWidth(#step.ingredient_images) + (if index > 1 then tuning.TrayGap else 0)
	end
	(find(steps, "UIListLayout") :: UIListLayout).Padding = UDim.new(0, tuning.TrayGap)
	steps.Size = UDim2.fromOffset(stepsWidth, tuning.TrayHeight)
	steps.Position = UDim2.new(0.5, 0, 0, tuning.PlateSize + tuning.StepsGap)
	steps.Visible = #trays > 0
	local height = tuning.PlateSize + (if #trays > 0 then tuning.StepsGap + tuning.TrayHeight else 0)
	root.Size = UDim2.fromOffset(math.max(tuning.PlateSize, stepsWidth), height)
	root.Name = tostring(order.OrderNum)
	root.LayoutOrder = -order.OrderNum
	root.Visible = true
	local dish = find(plate, "Face.Dish") :: ImageLabel
	dish.Image = recipe.FoodImage
	local tag = find(plate, "Table") :: GuiObject
	local tagOffset = centreOffset(tag, tuning.PlateSize)
	tag.AnchorPoint = Vector2.new(0.5, 0.5)
	local tableNumber = order.Table
	tag.Visible = tableNumber ~= nil
	if tableNumber ~= nil then
		(find(tag, "Label") :: TextLabel).Text = string.format(tuning.TableLabel, tableNumber)
	end
	local served = find(plate, "Served") :: GuiObject
	served.Visible = false
	local glow = find(plate, "Glow") :: ImageLabel
	glow.Visible = false
	local trail = find(plate, "Trail") :: GuiObject
	trail.Visible = false
	local trailLines: { GuiObject } = {}
	for _, piece in pieces(trail) do
		table.insert(trailLines, piece.Object)
	end
	local sparkles = find(plate, "Sparkles") :: GuiObject
	sparkles.Visible = false
	local sweat = find(plate, "Sweat") :: GuiObject
	sweat.Visible = false
	local card: Card = {
		Root = root,
		Body = find(root, "Body") :: GuiObject,
		Scale = find(root, "Scale") :: UIScale,
		Plate = plate,
		Glow = glow,
		Face = find(plate, "Face") :: GuiObject,
		Dish = dish,
		Tag = tag,
		TagOffset = tagOffset,
		Served = served,
		ServedPop = find(served, "Pop") :: UIScale,
		Trail = trail,
		TrailLines = trailLines,
		Sparkles = sparkles,
		SparklePieces = pieces(sparkles),
		Sweat = sweat,
		Drops = pieces(sweat),
		Ring = RadialRing.Find(plate),
		Trays = trays,
		Order = order,
		AddedAt = if animate then os.clock() else nil,
		Ticket = nil,
		FromTicket = false,
		RemovedAt = nil,
		Success = false,
		Size = 1,
		UrgePhase = 0,
	}
	cards[order.OrderNum] = card
	updateCard(card, 0, os.clock(), nil)
	root.Parent = list
	if animate and tableNumber ~= nil then
		local part = tablePart(tableNumber)
		local camera = workspace.CurrentCamera
		if part ~= nil and camera ~= nil then
			local point = camera:WorldToScreenPoint(part.Position + Vector3.new(0, part.Size.Y / 2 + Config.UI.TakeOrder.TicketHeight, 0))
			if point.Z > 0 then
				card.FromTicket = true
				card.AddedAt = os.clock() + TicketFly.Duration()
				card.Body.Visible = false
				local from = Vector2.new(point.X, point.Y) - orderList.AbsolutePosition
				card.Ticket = TicketFly.Launch(from, listScale.Scale, function(): Vector2?
					if cards[order.OrderNum] ~= card then
						return nil
					end
					local destination: GuiObject = card.Plate
					if not card.Root.Visible then
						local entry = queued[card.Order.Recipe]
						if entry ~= nil and entry.Root.Visible then
							destination = entry.Root
						elseif queue.Visible then
							destination = queue
						end
					end
					return destination.AbsolutePosition + destination.AbsoluteSize / 2 - orderList.AbsolutePosition
				end, function(): ()
					card.Ticket = nil
					local entry = queued[card.Order.Recipe]
					if not card.Root.Visible and entry ~= nil then
						entry.ChangedAt = os.clock()
					end
				end)
			end
		end
	end
end

-- A served plate that pays at once turns into a spinning coin that hops out of it and flies to the coin counter.
-- Everyone sees it: every client gets CompleteOrder.
local function spawnCoin(card: Card): ()
	local tuning = Config.UI.Orders
	local from = card.Plate.AbsolutePosition + card.Plate.AbsoluteSize / 2 - gameInfo.AbsolutePosition
	CoinFly.Launch(from, tuning.ShrinkDelay, tuning.CoinDelay)
end

local function removeOrder(number: number, success: boolean): ()
	local card = cards[number]
	if card == nil then
		return
	end
	cards[number] = nil
	if card.Ticket ~= nil then
		TicketFly.Cancel(card.Ticket)
		destroyCard(card)
		return
	end
	-- Waiting in the queue strip: nothing to animate; a paid serve's coin flies from its dish there.
	if not card.Root.Visible then
		if success and not Levels.GetCurrent().EnableTableCash then
			local tuning = Config.UI.Orders
			local entry = queued[card.Order.Recipe]
			local from: GuiObject = if entry ~= nil then entry.Root else queue
			CoinFly.Launch(from.AbsolutePosition + from.AbsoluteSize / 2 - gameInfo.AbsolutePosition, tuning.ShrinkDelay, tuning.CoinDelay)
		end
		destroyCard(card)
		return
	end
	card.RemovedAt = os.clock()
	card.Success = success
	card.Glow.Visible = false
	card.Sweat.Visible = false
	if success then
		card.Dish.Visible = false
		card.Served.Visible = true
		card.ServedPop.Scale = Config.UI.Orders.StampScale
		card.Sparkles.Visible = true
		-- With table cash the coins come later, when someone collects the cash (CashController).
		if not Levels.GetCurrent().EnableTableCash then
			spawnCoin(card)
		end
	else
		card.Dish.ImageColor3 = Config.UI.Orders.Fail
	end
	table.insert(leaving, card)
end

-- Draws one card for this frame; false once it has finished leaving.
function updateCard(card: Card, dt: number, clock: number, oldest: number?): boolean
	local tuning = Config.UI.Orders
	local addedAt = card.AddedAt
	local t = if addedAt ~= nil then clock - addedAt else math.huge
	-- The ticket and row use separate RenderStepped connections, so wait for the actual landing callback.
	card.Body.Visible = not card.FromTicket or (t >= 0 and card.Ticket == nil)
	local arrivalTime = if card.FromTicket then t + tuning.DropTime else t
	local size: Vector2
	local drop: number
	if card.FromTicket and t < 0 then
		size, drop = Vector2.one, 0
	else
		size, drop = arrival(arrivalTime)
	end
	local fraction = timeLeft(card.Order)
	local shown = if card.FromTicket and t < 0 then 0 else fraction
	if arrivalTime < tuning.DropTime + tuning.RingSweepTime then
		local p = math.clamp((arrivalTime - tuning.DropTime) / tuning.RingSweepTime, 0, 1)
		shown = math.min(fraction, 1 - (1 - p) ^ 3)
	end
	for index, tray in card.Trays do
		local p = math.clamp((arrivalTime - tuning.DropTime - tuning.TrayDelay - (index - 1) * tuning.TrayStagger) / tuning.TrayPopTime, 0, 1)
		tray.Pop.Scale = math.max(backOut(p, tuning.TrayPopOvershoot), 0)
	end
	local trailFade = (arrivalTime - tuning.DropTime) / tuning.TrailFadeTime
	card.Trail.Visible = not card.FromTicket and trailFade < 1
	if trailFade < 1 then
		for _, line in card.TrailLines do
			line.BackgroundTransparency = 0.25 + 0.75 * math.clamp(trailFade, 0, 1)
		end
	end
	local color = ringColor(card.Order, fraction)
	local sway = 0
	local tilt = 0
	local shrink = 1
	local removedAt = card.RemovedAt
	local target = if removedAt == nil and card.Order.OrderNum == oldest then tuning.OldestScale else 1
	card.Size += (target - card.Size) * math.min(1, dt * tuning.ScaleSpeed)
	if removedAt ~= nil then
		local r = clock - removedAt
		local shrinkAt: number
		if card.Success then
			shown = 1
			color = tuning.RingGreen
			local p = math.clamp(r / tuning.StampTime, 0, 1)
			card.ServedPop.Scale = tuning.StampScale + (1 - tuning.StampScale) * p * p
			-- Sparkles burst out from the check and wink out.
			local sparkle = r / tuning.SparkleTime
			card.Sparkles.Visible = sparkle < 1
			local q = math.clamp(sparkle, 0, 1)
			local grow = math.sin(q * math.pi)
			for _, piece in card.SparklePieces do
				local out = Vector2.new(piece.Position.X.Scale - 0.5, piece.Position.Y.Scale - 0.5) * 2 * tuning.SparkleSpread * q
				piece.Object.Position = piece.Position + UDim2.fromScale(out.X, out.Y)
				piece.Object.Size = UDim2.fromOffset(piece.Size.X.Offset * grow, piece.Size.Y.Offset * grow)
				piece.Object.Rotation = 90 * q
			end
			shrinkAt = tuning.ShrinkDelay
		else
			color = tuning.RingRed
			if r < tuning.ShakeTime then
				sway = math.sin(r * tuning.ShakeSpeed) * tuning.ShakeOffset * (1 - r / tuning.ShakeTime)
			end
			shrinkAt = tuning.ShakeTime
		end
		local p = math.clamp((r - shrinkAt) / tuning.ShrinkTime, 0, 1)
		if p >= 1 then
			destroyCard(card)
			return false
		end
		shrink = 1 - p * p
	elseif fraction < tuning.Urgent and card.Order.PausedAt == nil then
		local urgency = 1 - fraction / tuning.Urgent
		card.UrgePhase += dt * (tuning.UrgeSpeedMin + (tuning.UrgeSpeedMax - tuning.UrgeSpeedMin) * urgency)
		local wave = math.sin(card.UrgePhase)
		tilt = wave * tuning.UrgeTilt
		size *= 1 + math.abs(wave) * tuning.UrgePulse
		card.Glow.Visible = true
		card.Glow.ImageTransparency = 0.2 + 0.6 * (1 - math.abs(wave))
		card.Sweat.Visible = true
		for index, sweatDrop in card.Drops do
			-- Each drop flies out sideways and falls, fading, one after another.
			local q = (clock / tuning.SweatTime + (index - 1) / #card.Drops) % 1
			local side = if sweatDrop.Position.X.Scale < 0.5 then -1 else 1
			local distance = tuning.SweatDistance
			sweatDrop.Object.Position = sweatDrop.Position + UDim2.fromOffset(side * distance * q, distance * (q * q - 0.6 * q))
			sweatDrop.Object.Rotation = side * 40 * q
			local image = sweatDrop.Object :: ImageLabel
			image.ImageTransparency = q * q
		end
	else
		card.Glow.Visible = false
		card.Sweat.Visible = false
	end
	local ring = card.Ring
	if ring ~= nil then
		RadialRing.Set(ring, shown, color)
	end
	local plateSize = tuning.PlateSize
	if card.FromTicket and t >= 0 then
		size *= math.max(backOut(math.clamp(t / Config.UI.TakeOrder.CardPopTime, 0, 1), Config.UI.TakeOrder.CardPopOvershoot), 0.001)
	end
	-- Scaled about the plate's bottom so the squash lands on the trays.
	card.Plate.Size = UDim2.fromOffset(plateSize * size.X, plateSize * size.Y)
	card.Plate.Position = UDim2.new(0.5, sway, 0, plateSize * (1 - size.Y) + drop)
	-- The dish and table tag rock together about the plate centre.
	card.Face.Rotation = tilt
	card.Tag.Rotation = tilt
	local angle = math.rad(tilt)
	local offset = card.TagOffset
	local rocked = Vector2.new(
		offset.X * math.cos(angle) - offset.Y * math.sin(angle),
		offset.X * math.sin(angle) + offset.Y * math.cos(angle)
	)
	card.Tag.Position = UDim2.new(0.5, rocked.X * size.X, 0.5, rocked.Y * size.Y)
	card.Scale.Scale = card.Size * shrink
	return true
end

-- Design-pixel width of the queue strip with `count` dishes in it.
local function queueWidth(count: number): number
	local tuning = Config.UI.Orders
	return if count > 0 then count * tuning.QueueEntrySize + (count - 1) * tuning.QueueGap else 0
end

-- Draws the queue strip: one entry per recipe among `hidden` (order numbers, oldest first), the oldest dish nearest
-- the plates. An entry pops when it appears or its count changes.
local function drawQueue(hidden: { number }, clock: number): ()
	local tuning = Config.UI.Orders
	local counts: { [number]: number } = {}
	local firsts: { [number]: number } = {}
	local kinds = 0
	for _, number in hidden do
		local recipe = cards[number].Order.Recipe
		if counts[recipe] == nil then
			kinds += 1
			firsts[recipe] = number
		end
		counts[recipe] = (counts[recipe] or 0) + 1
	end
	for recipe, entry in queued do
		if counts[recipe] == nil then
			entry.Root:Destroy()
			queued[recipe] = nil
		end
	end
	for recipe, count in counts do
		local entry = queued[recipe]
		if entry == nil then
			local root = entryTemplate:Clone()
			root.Size = UDim2.fromOffset(tuning.QueueEntrySize, tuning.QueueEntrySize)
			-- Shown from the next frame, once the layouts have placed it (else it flashes where the strip last was).
			root.Visible = false
			local info = Levels.GetRecipe(recipe)
			;(find(root, "Badge.Icon") :: ImageLabel).Image = if info ~= nil then info.FoodImage else ""
			local countFrame = find(root, "Count") :: GuiObject
			local created: QueueEntry = {
				Root = root,
				Pop = find(root, "Pop") :: UIScale,
				Count = countFrame,
				CountLabel = find(countFrame, "Label") :: TextLabel,
				Shown = 0,
				ChangedAt = clock,
			}
			root.Parent = queue
			queued[recipe] = created
			entry = created
		elseif not entry.Root.Visible then
			entry.Root.Visible = true
			entry.ChangedAt = clock
		end
		local current = entry :: QueueEntry
		if current.Shown ~= count then
			if current.Shown ~= 0 then
				current.ChangedAt = clock
			end
			current.Shown = count
			current.Count.Visible = count > 1
			current.CountLabel.Text = string.format(tuning.QueueCountLabel, count)
		end
		current.Root.LayoutOrder = -firsts[recipe]
		local p = math.clamp((clock - current.ChangedAt) / tuning.QueuePopTime, 0, 1)
		current.Pop.Scale = 1 + tuning.QueuePop * math.sin(p * math.pi)
	end
	queueLayout.Padding = UDim.new(0, tuning.QueueGap)
	queue.Size = UDim2.fromOffset(queueWidth(kinds), tuning.PlateSize)
	queue.Visible = kinds > 0
end

-- Hides the newest orders that don't fit between the row's right end and its left limit; they show in the queue
-- strip instead. Widths use each card's target size (not its animated one), so the cut doesn't flicker.
local function fitRow(oldest: number?, clock: number): ()
	local tuning = Config.UI.Orders
	local scale = listScale.Scale
	local gap = listLayout.Padding.Offset * scale
	local padding = list:FindFirstChildOfClass("UIPadding")
	local right = list.AbsolutePosition.X + list.AbsoluteSize.X
		- (if padding ~= nil then padding.PaddingRight.Offset * scale + padding.PaddingRight.Scale * list.AbsoluteSize.X else 0)
	local inset = GuiService.TopbarInset
	local left = if list.AbsolutePosition.Y < inset.Max.Y then inset.Min.X else 0
	local room = right - left - tuning.EdgeMargin
	for _, card in leaving do
		if card.Root.Visible then
			room -= card.Root.AbsoluteSize.X + gap
		end
	end
	local numbers: { number } = {}
	for number in cards do
		table.insert(numbers, number)
	end
	table.sort(numbers)
	local widths: { number } = {}
	local total = 0
	for index, number in numbers do
		local card = cards[number]
		widths[index] = card.Root.Size.X.Offset * scale * (if number == oldest then tuning.OldestScale else 1) + gap
		total += widths[index]
	end
	-- The most plates that fit beside the strip of what's left (fewer plates can mean more dishes in the strip).
	local shown = #numbers
	while shown > 0 do
		local kinds: { [number]: boolean } = {}
		local kindCount = 0
		for index = shown + 1, #numbers do
			local recipe = cards[numbers[index]].Order.Recipe
			if not kinds[recipe] then
				kinds[recipe] = true
				kindCount += 1
			end
		end
		local strip = if kindCount > 0 then queueWidth(kindCount) * scale + gap else 0
		if total + strip <= room then
			break
		end
		total -= widths[shown]
		shown -= 1
	end
	local hidden: { number } = {}
	for index, number in numbers do
		cards[number].Root.Visible = index <= shown
		if index > shown then
			table.insert(hidden, number)
		end
	end
	drawQueue(hidden, clock)
end

local function step(dt: number): ()
	local tuning = Config.UI.Orders
	-- Same rule as MobileControls (InputController): a touch screen gets the touch layout, keyboard or not.
	local touch = UserInputService.TouchEnabled
	local camera = workspace.CurrentCamera
	if camera ~= nil then
		listScale.Scale = camera.ViewportSize.Y / tuning.DesignHeight * (if touch then tuning.TouchScale else tuning.DesktopScale)
	end
	local clock = os.clock()
	local oldest: number? = nil
	for number in cards do
		if oldest == nil or number < oldest then
			oldest = number
		end
	end
	for _, card in cards do
		updateCard(card, dt, clock, oldest)
	end
	for index = #leaving, 1, -1 do
		if not updateCard(leaving[index], dt, clock, oldest) then
			table.remove(leaving, index)
		end
	end
	fitRow(oldest, clock)
end

local function isOrder(value: unknown): boolean
	if typeof(value) ~= "table" then
		return false
	end
	local data = value :: { [string]: any }
	return typeof(data.OrderNum) == "number" and typeof(data.Recipe) == "number"
		and typeof(data.StartedAt) == "number" and typeof(data.Duration) == "number"
end

local function handle(message: unknown, value: unknown): ()
	if message == "Orders" and typeof(value) == "table" then
		clearCards()
		for _, entry in value :: { unknown } do
			if isOrder(entry) then
				addOrder(entry :: Order, false)
			end
		end
	elseif message == "AddOrder" and isOrder(value) then
		addOrder(value :: Order, true)
	elseif message == "UpdateOrder" and isOrder(value) then
		-- A paused or resumed order: new timing, same card.
		local order = value :: Order
		local card = cards[order.OrderNum]
		if card ~= nil then
			card.Order = order
		end
	elseif message == "CompleteOrder" and typeof(value) == "number" then
		removeOrder(value, true)
	elseif message == "ExpireOrder" and typeof(value) == "number" then
		removeOrder(value, false)
	elseif message == "RoundEnd" then
		clearCards()
	end
end

-- Effect tester: plays a Round message locally as if the server had sent it.
function OrdersController.Simulate(message: string, value: unknown): ()
	handle(message, value)
end

-- The orders on screen, oldest first.
function OrdersController.Orders(): { Order }
	local orders: { Order } = {}
	for _, card in cards do
		table.insert(orders, card.Order)
	end
	table.sort(orders, function(left: Order, right: Order): boolean
		return left.OrderNum < right.OrderNum
	end)
	return orders
end

function OrdersController.Start(_self: typeof(OrdersController)): ()
	Net.Event("Round").OnClientEvent:Connect(handle)
	RunService.RenderStepped:Connect(step)
end

return OrdersController
