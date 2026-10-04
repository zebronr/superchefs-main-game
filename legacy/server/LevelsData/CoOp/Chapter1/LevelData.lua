local module = {}

local ServerStorage = game:GetService("ServerStorage")

module.map = ServerStorage:WaitForChild("Maps"):WaitForChild("CoOp"):WaitForChild("Chapter1"):WaitForChild("Level1")
module.levelDuration = 3*60
module.gameMode = "coOp"

module.sequence = "1212-1233-1323-1323-3333-1231-"
module.loopSequence = "1323-3333-1231-"
module.orderDelay = 5

module.teams = 1

module.recipes = {
    [1] = {
        food_name = "chopped_cucumber",
        time = 40,
        steps = {
            [1] = {ingredient_images = {[1] = "rbxassetid://100503567650585"}}
        },
        foodImage = "rbxassetid://113432140786725"
    },
    [2] = {
        food_name = "chopped_mango",
        time = 40,
        steps = {
            [1] = {ingredient_images = {[1] = "rbxassetid://121871090737807"}}
        },
        foodImage = "rbxassetid://122023330879408"
    },
    [3] = {
        food_name = "salad(mango_cucumber)",
        time = 60,
        steps = {
            [1] = {ingredient_images = {[1] = "rbxassetid://100503567650585"}},
            [2] = {ingredient_images = {[1] = "rbxassetid://121871090737807"}}
        },
        foodImage = "rbxassetid://128533613786186"
    }
}

return module