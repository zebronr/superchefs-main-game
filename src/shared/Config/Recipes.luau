--!strict

local Recipes = {}

Recipes.Combinations = {
	["salad(tomato_lettuce)"] = { "chopped_tomato", "chopped_lettuce" },
	["salad(mango_cucumber)"] = { "chopped_cucumber", "chopped_mango" },
} :: { [string]: { string } }

local recipeNames: { string } = {}
for name in Recipes.Combinations do
	table.insert(recipeNames, name)
end
table.sort(recipeNames)

local function matches(expected: { string }, ingredients: { string }): boolean
	if #expected ~= #ingredients then
		return false
	end
	local counts: { [string]: number } = {}
	for _, ingredient in expected do
		counts[ingredient] = (counts[ingredient] or 0) + 1
	end
	for _, ingredient in ingredients do
		local count = counts[ingredient]
		if count == nil or count == 0 then
			return false
		end
		counts[ingredient] = count - 1
	end
	return true
end

function Recipes.Find(ingredients: { string }): string?
	for _, name in recipeNames do
		if matches(Recipes.Combinations[name], ingredients) then
			return name
		end
	end
	return nil
end

return Recipes
