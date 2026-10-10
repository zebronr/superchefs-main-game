--!strict

export type PreloadTuning = {
	BatchSize: number,
	BatchDelay: number,
	CharacterWait: number,
	WarmUp: boolean,
	WarmUpDistance: number,
	ServerRoots: { string },
}

local Preload = {
	BatchSize = 20, -- Content ids requested per batch.
	BatchDelay = 0.05, -- Seconds between batches.
	CharacterWait = 5, -- Maximum seconds to wait for the local character model attribute.
	WarmUp = true, -- Draw superskill mesh templates briefly after download.
	WarmUpDistance = 6, -- Studs in front of the camera for warm-up draws.
	ServerRoots = { "ServerStorage" }, -- Services scanned once on the server.
} :: PreloadTuning

return Preload
