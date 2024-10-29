local Countertop = {}

function Countertop.Use(player, objectCarried, visibleObject, heldState)
    print("Countertop", heldState)
end

function Countertop.Interact(player, objectCarried, visibleObject)
    print("COUNTERTOP INTERACT")
end

return Countertop