--!strict

local Character = require(script.Parent:WaitForChild("Character"))

-- How a step is cooked. Chopping is assumed for every ingredient, so it has no method of its own.
export type CookMethod = "Pot" | "Pan"
-- Method: nil = chopped or added as is (no badge on the order's step tray).
export type RecipeStep = { ingredient_images: { string }, Method: CookMethod? }
export type Recipe = {
	Id: number,
	Name: string,
	Time: number,
	Steps: { RecipeStep },
	FoodImage: string,
}
export type CustomerTuning = {
	SpawnInterval: number,
	MaxCustomers: number,
	OrderPatience: number,
	-- Seconds a customer eats, picked at random per customer.
	EatDuration: NumberRange,
	-- Probability a customer runs off after eating without paying (needs EnableTableCash; 0 = never).
	DashChance: number,
}
-- Fresh serves: how much of an order's time had run out when it was served, as a fraction (0 to 1).
export type ComboFreshTuning = {
	-- Served before this much of its time ran out: the combo goes up (the plate ring is green).
	FreshUntil: number,
	-- Served after this much: the combo resets (red). In between it holds without growing (yellow).
	LateAfter: number,
}
-- Fever: reaching At serves sets the team on fire for Time seconds. Every serve pays Multiplier and nothing
-- breaks the combo; when it ends the combo starts again from 0.
export type FeverTuning = { At: number, Time: number, Multiplier: number }
export type ComboTuning = {
	-- Seconds after a serve to make the next one and keep the combo going.
	Window: number,
	-- Coin multiplier by combo count (index 1 = the first serve of a streak); the last entry repeats.
	Multipliers: { number },
	-- nil = every serve builds the combo.
	Fresh: ComboFreshTuning?,
	-- Serving any order but the oldest resets the combo (still pays).
	OldestFirst: boolean?,
	-- nil = no fever.
	Fever: FeverTuning?,
}
-- The NEW TODAY sticker on the loading screen: the mechanic this level introduces.
export type NewMechanic = { Name: string, Hint: string }
export type LevelData = {
	-- Loading screen ticket: the level's name and its number ("TABLE 1-2").
	Title: string?,
	Number: string?,
	-- nil = the level adds nothing new (no sticker).
	NewMechanic: NewMechanic?,
	EnableDirtyPlates: boolean,
	-- Table customers leave their coins as cash on the table to pick up; off = paid when served.
	EnableTableCash: boolean,
	-- Serving orders back to back builds a team combo that multiplies coins; an expired order breaks it.
	EnableCombo: boolean,
	LevelDuration: number,
	OrderDelay: number,
	Teams: number,
	Sequence: string,
	LoopSequence: string,
	CoinsPerOrder: number,
	Recipes: { Recipe },
	Customers: CustomerTuning?,
	Combo: ComboTuning?,
	-- The gameplay camera's offset from the player for this map (which side it watches from); nil = Character.CameraOffset.
	CameraOffset: Vector3?,
}

local recipes: { Recipe } = {
	{
		Id = 1,
		Name = "chopped_cucumber",
		Time = 40,
		Steps = { { ingredient_images = { "rbxassetid://100503567650585" } } },
		FoodImage = "rbxassetid://113432140786725",
	},
	{
		Id = 2,
		Name = "chopped_mango",
		Time = 40,
		Steps = { { ingredient_images = { "rbxassetid://121871090737807" } } },
		FoodImage = "rbxassetid://122023330879408",
	},
	{
		Id = 3,
		Name = "salad(mango_cucumber)",
		Time = 60,
		Steps = {
			{ ingredient_images = { "rbxassetid://100503567650585" } },
			{ ingredient_images = { "rbxassetid://121871090737807" } },
		},
		FoodImage = "rbxassetid://128533613786186",
	},
}

local level1: LevelData = {
	Title = "FIRST SHIFT",
	Number = "1-1",
	-- Entry level: no sink, so served plates come back clean.
	EnableDirtyPlates = false,
	EnableTableCash = false,
	EnableCombo = false,
	LevelDuration = 180,
	OrderDelay = 5,
	Teams = 1,
	Sequence = "1212-1233-1323-1323-3333-1231-",
	LoopSequence = "1323-3333-1231-",
	CoinsPerOrder = 10,
	Recipes = recipes,
}

-- Chapter 1 Level 2 (manual serve mode, gameplay reveal demo): customers sit at tables instead of using the
-- serving window.
local level2: LevelData = {
	Title = "LUNCH RUSH",
	Number = "1-2",
	NewMechanic = { Name = "DIRTY PLATES", Hint = "wash them at the sink" },
	EnableDirtyPlates = true,
	EnableTableCash = true,
	EnableCombo = true,
	LevelDuration = 180,
	OrderDelay = level1.OrderDelay,
	Teams = level1.Teams,
	Sequence = level1.Sequence,
	LoopSequence = level1.LoopSequence,
	CoinsPerOrder = level1.CoinsPerOrder,
	Recipes = recipes,
	Customers = {
		SpawnInterval = 8,
		MaxCustomers = 10,
		OrderPatience = 25,
		EatDuration = NumberRange.new(4, 9),
		DashChance = 0.15,
	},
	Combo = {
		Window = 20,
		Multipliers = { 1, 1.2, 1.4, 1.6, 2 },
		Fresh = { FreshUntil = 0.5, LateAfter = 0.75 },
	},
}

-- Sandwiches: a bread slice from a chopped loaf, plus spreads cooked in a pot (chopped strawberry -> strawberry jam,
-- chopped peanut -> peanut butter) and ladled onto the plate.
local BREAD_ICON = "rbxassetid://76745084892041"
local STRAWBERRY_ICON = "rbxassetid://88480103207997"
local PEANUT_ICON = "rbxassetid://95741673925949"
local sandwichRecipes: { Recipe } = {
	{
		Id = 4,
		Name = "jam_sandwich",
		Time = 75,
		Steps = {
			{ ingredient_images = { BREAD_ICON } },
			{ ingredient_images = { STRAWBERRY_ICON }, Method = "Pot" },
		},
		FoodImage = "rbxassetid://89481326698230",
	},
	{
		Id = 5,
		Name = "peanut_butter_sandwich",
		Time = 75,
		Steps = {
			{ ingredient_images = { BREAD_ICON } },
			{ ingredient_images = { PEANUT_ICON }, Method = "Pot" },
		},
		FoodImage = "rbxassetid://113255624436887",
	},
	{
		Id = 6,
		Name = "pbj_sandwich",
		Time = 100,
		Steps = {
			{ ingredient_images = { BREAD_ICON } },
			{ ingredient_images = { STRAWBERRY_ICON }, Method = "Pot" },
			{ ingredient_images = { PEANUT_ICON }, Method = "Pot" },
		},
		FoodImage = "rbxassetid://128987833845031",
	},
}

-- Burger: a bun and chopped raw meat fried into a patty in a pan. The cheese burger adds a cheese slice chopped from
-- a wedge.
local BUN_ICON = "rbxassetid://90621736229104"
local MEAT_ICON = "rbxassetid://98317071199758"
local CHEESE_ICON = "rbxassetid://84478614105150"
local burgerRecipes: { Recipe } = {
	{
		Id = 7,
		Name = "cheese_burger",
		Time = 100,
		Steps = {
			{ ingredient_images = { BUN_ICON } },
			{ ingredient_images = { MEAT_ICON }, Method = "Pan" },
			{ ingredient_images = { CHEESE_ICON } },
		},
		FoodImage = "rbxassetid://84533964238750",
	},
	{
		Id = 8,
		Name = "burger",
		Time = 80,
		Steps = {
			{ ingredient_images = { BUN_ICON } },
			{ ingredient_images = { MEAT_ICON }, Method = "Pan" },
		},
		FoodImage = "rbxassetid://120434787255772",
	},
}

-- Test maps: Level 2 with every combo rule on (oldest first and fever come in later levels), plus the sandwiches to
-- test pot cooking and the burgers to test the pan.
-- The demo map is watched from the street side (the camera west of the player, looking east), and serves the burger
-- (its crates hold buns, meat and cheese) and the cheese burger.
level2.CameraOffset = Vector3.new(-20, 25, 0)
level2.Recipes = burgerRecipes

local levelTest: LevelData = table.clone(level2)
levelTest.CameraOffset = nil -- the test maps keep the default side
levelTest.Title = "TEST KITCHEN"
levelTest.Number = "T-1"
levelTest.Recipes = table.clone(recipes)
for _, recipe in sandwichRecipes do
	table.insert(levelTest.Recipes, recipe)
end
for _, recipe in burgerRecipes do
	table.insert(levelTest.Recipes, recipe)
end
levelTest.Combo = {
	Window = 20,
	Multipliers = { 1, 1.2, 1.4, 1.6, 2 },
	Fresh = { FreshUntil = 0.5, LateAfter = 0.75 },
	OldestFirst = true,
	Fever = { At = 6, Time = 10, Multiplier = 3 },
}

local levels: { [string]: LevelData } = {
	["CoOp/Chapter1/Level1"] = level1,
	["CoOp/Chapter1/Level2"] = level2,
	-- Test maps (manual mode) with Level 2's settings and every combo rule.
	["CoOp/Test/Tables"] = levelTest,
	["CoOp/Test/Basic"] = levelTest,
}

local Levels = {}
local currentPath: string? = nil

-- Default level path per serve mode (Config/Round ServeMode).
Levels.DefaultFor = {
	Window = "CoOp/Chapter1/Level1",
	Manual = "CoOp/Chapter1/Level2",
} :: { [string]: string }

function Levels.Get(path: string): LevelData
	return levels[path] or level1
end

function Levels.SetCurrent(path: string): ()
	currentPath = path
end

-- The server sets the path directly; clients read the LevelPath attribute LevelService puts on ReplicatedStorage.
function Levels.GetCurrentPath(): string?
	if currentPath ~= nil then
		return currentPath
	end
	local replicated = game:GetService("ReplicatedStorage"):GetAttribute("LevelPath")
	return if typeof(replicated) == "string" then replicated else nil
end

function Levels.GetCurrent(): LevelData
	return Levels.Get(Levels.GetCurrentPath() or "")
end

-- A recipe of the current level by its Id (orders and customers carry the Id, not the list position).
function Levels.GetRecipe(id: number): Recipe?
	for _, recipe in Levels.GetCurrent().Recipes do
		if recipe.Id == id then
			return recipe
		end
	end
	return nil
end

function Levels.GetCameraOffset(): Vector3
	return Levels.GetCurrent().CameraOffset or Character.CameraOffset
end

return Levels
