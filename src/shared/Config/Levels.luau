--!strict

export type LevelData = {
	EnableDirtyPlates: boolean,
}

local defaults: LevelData = {
	EnableDirtyPlates = false,
}

local levels: { [string]: LevelData } = {
	-- The legacy showcase had this off; enable it here so the sink cycle can be tested.
	["CoOp/Chapter1/Level1"] = { EnableDirtyPlates = true },
}

local Levels = {}
local currentPath: string? = nil

function Levels.Get(path: string): LevelData
	return levels[path] or defaults
end

function Levels.SetCurrent(path: string): ()
	currentPath = path
end

function Levels.GetCurrent(): LevelData
	return Levels.Get(currentPath or "")
end

return Levels
