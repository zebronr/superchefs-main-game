--!strict

-- What the client has loaded, shared between the ReplicatedFirst loading screen and the client controllers
-- (every LocalScript on a client shares one require cache, so they all see this same table).

local LoadingState = {
	-- PreloadController's finished tiers (0 to 4).
	PreloadTier = 0,
	-- Every controller's Start has returned and the client sent Ready.
	ClientReady = false,
	-- os.clock() when this client pressed START (its own prediction), or nil.
	StartPressedAt = nil :: number?,
}

function LoadingState.PressStart(): ()
	LoadingState.StartPressedAt = os.clock()
end

return LoadingState
