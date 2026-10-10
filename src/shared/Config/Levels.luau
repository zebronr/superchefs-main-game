--!strict

export type RecipeStep = { ingredient_images: { string } }
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
export type LevelData = {
	EnableDirtyPlates: boolean,
	-- Table customers leave their coins as cash on the table to pick up; off = paid when served.
	EnableTableCash: boolean,
	LevelDuration: number,
	OrderDelay: number,
	Teams: number,
	Sequence: string,
	LoopSequence: string,
	CoinsPerOrder: number,
	Recipes: { Recipe },
	Customers: CustomerTuning?,
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
	-- Entry level: no sink, so served plates come back clean.
	EnableDirtyPlates = false,
	EnableTableCash = false,
	LevelDuration = 180,
	OrderDelay = 5,
	Teams = 1,
	Sequence = "1212-1233-1323-1323-3333-1231-",
	LoopSequence = "1323-3333-1231-",
	CoinsPerOrder = 10,
	Recipes = recipes,
}

-- Manual serve mode test level: customers sit at tables instead of using the serving window.
local tables: LevelData = {
	EnableDirtyPlates = true,
	EnableTableCash = true,
	LevelDuration = 180,
	OrderDelay = level1.OrderDelay,
	Teams = level1.Teams,
	Sequence = level1.Sequence,
	LoopSequence = level1.LoopSequence,
	CoinsPerOrder = level1.CoinsPerOrder,
	Recipes = recipes,
	Customers = {
		SpawnInterval = 8,
		MaxCustomers = 3,
		OrderPatience = 25,
		EatDuration = NumberRange.new(4, 9),
		DashChance = 0.25,
	},
}

local levels: { [string]: LevelData } = {
	["CoOp/Chapter1/Level1"] = level1,
	["CoOp/Test/Tables"] = tables,
	["CoOp/Test/Basic"] = tables,
}

local Levels = {}
local currentPath: string? = nil

-- Default level path per serve mode (Config/Round ServeMode).
Levels.DefaultFor = {
	Window = "CoOp/Chapter1/Level1",
	Manual = "CoOp/Test/Basic",
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

return Levels
