--!strict

export type RecipeStep = { ingredient_images: { string } }
export type Recipe = {
	Id: number,
	Name: string,
	Time: number,
	Steps: { RecipeStep },
	FoodImage: string,
}
export type LevelData = {
	EnableDirtyPlates: boolean,
	LevelDuration: number,
	OrderDelay: number,
	Teams: number,
	Sequence: string,
	LoopSequence: string,
	CoinsPerOrder: number,
	Recipes: { Recipe },
}

local level1: LevelData = {
	-- Entry level: no sink, so served plates come back clean.
	EnableDirtyPlates = false,
	LevelDuration = 180,
	OrderDelay = 5,
	Teams = 1,
	Sequence = "1212-1233-1323-1323-3333-1231-",
	LoopSequence = "1323-3333-1231-",
	CoinsPerOrder = 10,
	Recipes = {
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
	},
}

local levels: { [string]: LevelData } = {
	["CoOp/Chapter1/Level1"] = level1,
}

local Levels = {}
local currentPath: string? = nil

function Levels.Get(path: string): LevelData
	return levels[path] or level1
end

function Levels.SetCurrent(path: string): ()
	currentPath = path
end

function Levels.GetCurrent(): LevelData
	return Levels.Get(currentPath or "")
end

return Levels
