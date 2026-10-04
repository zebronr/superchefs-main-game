local module = {}

local foodCombinations = {
    ["salad(tomato_lettuce)"] = {"chopped_tomato", "chopped_lettuce"},
    ["salad(mango_cucumber)"] = {"chopped_cucumber", "chopped_mango"}
}

local function areTablesEqual(t1, t2)
    if #t1 ~= #t2 then return false end
    
    local count = {}
    for _, v in ipairs(t1) do
        count[v] = (count[v] or 0) + 1
    end
    for _, v in ipairs(t2) do
        if not count[v] or count[v] == 0 then
            return false
        end
        count[v] = count[v] - 1
    end
    return true
end

function module.CheckCombination(passedCombination, overwriteCombinations)
    local combinations = overwriteCombinations or foodCombinations
    for recipeName, ingredients in pairs(combinations) do
        if areTablesEqual(ingredients, passedCombination) then
            return recipeName
        end
    end
    return nil
end

return module