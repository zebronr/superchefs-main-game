--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AssetIds = require(Shared:WaitForChild("Util"):WaitForChild("AssetIds"))
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))

local PreloadService = {}
local cached: { string } = {}
local ready = false

function PreloadService.Init(_self: typeof(PreloadService)): ()
	Net.Function("Preload").OnServerInvoke = function(_player: Player): { string }
		while not ready do
			task.wait()
		end
		return cached
	end
end

function PreloadService.Start(_self: typeof(PreloadService)): ()
	local roots: { Instance } = {}
	for _, name in Config.Preload.ServerRoots do
		table.insert(roots, game:GetService(name))
	end
	AssetIds.Collect(roots, cached, {})
	ready = true
	print(`PreloadService: cached {#cached} asset ids`)
end

return PreloadService
