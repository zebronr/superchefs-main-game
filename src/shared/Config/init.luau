--!strict

-- The one entry point to every tunable: local Config = require(Shared:WaitForChild("Config")).
-- Children must never require this module.

local Character = require(script:WaitForChild("Character"))
local CinematicCamera = require(script:WaitForChild("CinematicCamera"))
local Customers = require(script:WaitForChild("Customers"))
local Interaction = require(script:WaitForChild("Interaction"))
local Levels = require(script:WaitForChild("Levels"))
local Loading = require(script:WaitForChild("Loading"))
local Preload = require(script:WaitForChild("Preload"))
local Recipes = require(script:WaitForChild("Recipes"))
local Round = require(script:WaitForChild("Round"))
local Skills = require(script:WaitForChild("Skills"))
local UI = require(script:WaitForChild("UI"))

export type ServeMode = Round.ServeMode
export type RecipeStep = Levels.RecipeStep
export type Recipe = Levels.Recipe
export type PreloadTuning = Preload.PreloadTuning
export type CustomerTuning = Levels.CustomerTuning
export type LevelData = Levels.LevelData
export type TongueGrabTuning = Skills.TongueGrabTuning
export type HustleTuning = Skills.HustleTuning
export type DeepFreezeTuning = Skills.DeepFreezeTuning
export type OrderRushTuning = Skills.OrderRushTuning
export type BearTossTuning = Skills.BearTossTuning

local Config = {
	Character = Character,
	CinematicCamera = CinematicCamera,
	Customers = Customers,
	Interaction = Interaction,
	Levels = Levels,
	Loading = Loading,
	Preload = Preload,
	Recipes = Recipes,
	Round = Round,
	Skills = Skills,
	UI = UI,
}

return Config
