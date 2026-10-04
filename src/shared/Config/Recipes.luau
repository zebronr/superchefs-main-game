--!strict

local Recipes = {}

Recipes.Combinations = {
	["salad(tomato_lettuce)"] = { "chopped_tomato", "chopped_lettuce" },
	["salad(mango_cucumber)"] = { "chopped_cucumber", "chopped_mango" },
} :: { [string]: { string } }

Recipes.Pot = {
	strawberry_jam = { "chopped_strawberry" },
	strawberry_jam_salad = { "strawberry_jam", "chopped_lettuce" },
} :: { [string]: { string } }

Recipes.SoupColors = {
	strawberry_jam = Color3.fromRGB(171, 51, 51),
	strawberry_jam_salad = Color3.fromRGB(8, 186, 141),
} :: { [string]: Color3 }

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

function Recipes.Find(ingredients: { string }, set: { [string]: { string } }?): string?
	local recipes = set or Recipes.Combinations
	local names: { string } = {}
	for name in recipes do
		table.insert(names, name)
	end
	table.sort(names)
	for _, name in names do
		if matches(recipes[name], ingredients) then
			return name
		end
	end
	return nil
end

return Recipes
