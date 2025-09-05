local module = {}

module.PriorityLevel = {
    Countertop = 3,
    ChoppingBoard = 3,
    Plate = 2,
    CookingTool = 2.5,
    Food = 1,
    ServingCounter = 3,
    PlateTable = 3
}

module.AllowInteractionWithSelf = {
    DirtyPlate = true,
    Plate = true
}

return module