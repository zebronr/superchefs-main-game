local module = {}

local ServerStorage = game:GetService("ServerStorage")

module.map = ServerStorage:WaitForChild("Maps"):WaitForChild("CoOp"):WaitForChild("Chapter1"):WaitForChild("Level1")
module.levelDuration = 3*60
module.gameMode = "coOp"

module.sequence = "1212-1233-1323-1323-3333-1231"
module.loopSequence = "1323-3333-1231"
module.orderDelay = 5

module.teams = 1

module.recipes = {
    [1] = {
        food_name = "plated_chopped_cucumber",
        time = 45,
        steps = {
            [1] = {ingredient_images = {[1] = ""}}
        },
        foodImage = ""
    },
    [2] = {
        food_name = "plated_mango_cucumber",
        time = 45,
        steps = {
            [1] = {ingredient_images = {[1] = ""}}
        },
        foodImage = ""
    },
    [3] = {
        food_name = "plated_salad(mango_cucumber)",
        time = 70,
        steps = {
            [1] = {ingredient_images = {[1] = ""}},
            [2] = {ingredient_images = {[1] = ""}}
        },
        foodImage = ""
    }
}

return module