local module = {}

local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CoreFunctions = ServerScriptService:WaitForChild("Server"):WaitForChild("CoreFunctions")
local Welds = require(CoreFunctions:WaitForChild("Welds"))

local Assets = ServerStorage:WaitForChild("Assets")
local SoupModel = Assets:WaitForChild("Foods"):WaitForChild("SoupModel")

module.Combinations = {
    ["strawberry_jam"] = {"chopped_strawberry"},
    ["strawberry_jam_salad"] = {"strawberry_jam", "chopped_lettuce"}
}

local colors = {
    ["strawberry_jam"] = Color3.fromRGB(171, 51, 51),
    ["strawberry_jam_salad"] = Color3.fromRGB(8, 186, 141),
    ["chopped_lettuce_soup"] = Color3.fromRGB(99, 2, 235)
}

function module.Display(pot, FoodContent)
    local displaySoup = Welds.isObjectOnTop(pot) 
    if displaySoup then
        Welds.unweldObjectOnTop(pot)
        displaySoup:Destroy()
    end
    warn(FoodContent)
    displaySoup = SoupModel:Clone()
    displaySoup.Parent = pot
    Welds.PlaceObjectOnTop(displaySoup, pot, -pot.Size.Y/2)
    displaySoup.Color = colors[FoodContent[1]]
end

return module