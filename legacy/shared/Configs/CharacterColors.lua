local module = {}

local team1 = {
    [1] = Color3.fromRGB(14, 0, 115),
    [2] = Color3.fromRGB(115, 0, 2),
    [3] = Color3.fromRGB(0, 115, 0),
    [4] = Color3.fromRGB(115, 107, 0)
}

local team2 = {
    [1] = Color3.fromRGB(165, 63, 164),
    [2] = Color3.fromRGB(0, 113, 115),
    [3] = Color3.fromRGB(115, 67, 0),
    [4] = Color3.fromRGB(111, 167, 28)
}

module.Color = {
    [1] = team1,
    [2] = team2
}

return module