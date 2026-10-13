--!strict

local Recipes = {}

-- Result name = the two things combined on a plate (order doesn't matter). A result made more than one way repeats
-- under `name|2`, `name|3`...; Find returns the name without the suffix.
Recipes.Combinations = {
	["salad(tomato_lettuce)"] = { "chopped_tomato", "chopped_lettuce" },
	["salad(mango_cucumber)"] = { "chopped_cucumber", "chopped_mango" },
	-- Sandwiches: a bread slice plus spreads cooked in a pot and ladled onto the plate.
	jam_sandwich = { "chopped_bread", "strawberry_jam" },
	peanut_butter_sandwich = { "chopped_bread", "peanut_butter" },
	pbj_sandwich = { "jam_sandwich", "peanut_butter" },
	["pbj_sandwich|2"] = { "peanut_butter_sandwich", "strawberry_jam" },
	-- Burgers: a bun and a patty fried in a pan make the burger; a cheese slice on it (or a patty on a bun with cheese)
	-- makes the cheese burger.
	burger = { "bun", "patty" },
	bun_cheese = { "bun", "chopped_cheese" },
	cheese_burger = { "burger", "chopped_cheese" },
	["cheese_burger|2"] = { "bun_cheese", "patty" },
} :: { [string]: { string } }

-- Results that also combine without a plate: on a counter or in hand (a sandwich). Everything else needs a plate
-- (a salad can't be mixed in the air). Keyed by result name, without the `|2` suffix.
Recipes.NoPlate = {
	jam_sandwich = true,
	peanut_butter_sandwich = true,
	pbj_sandwich = true,
	burger = true,
	bun_cheese = true,
	cheese_burger = true,
} :: { [string]: boolean }

-- Contents that can't go on an empty plate: they only go onto a base already there (a spread needs bread first).
Recipes.NeedsBase = {
	strawberry_jam = true,
	peanut_butter = true,
	patty = true,
	chopped_cheese = true,
} :: { [string]: boolean }

Recipes.Pot = {
	strawberry_jam = { "chopped_strawberry" },
	peanut_butter = { "chopped_peanut" },
	strawberry_jam_salad = { "strawberry_jam", "chopped_lettuce" },
} :: { [string]: { string } }

-- Pan recipes: the pan shows PanFoods/<name>_raw while it cooks and PanFoods/<name> once done.
Recipes.Pan = {
	patty = { "chopped_raw_meat" },
} :: { [string]: { string } }

Recipes.SoupColors = {
	strawberry_jam = Color3.fromRGB(215, 47, 69),
	peanut_butter = Color3.fromRGB(224, 161, 87),
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
			return (string.split(name, "|"))[1]
		end
	end
	return nil
end

return Recipes
