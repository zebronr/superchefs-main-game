--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = {}
local remotes: Folder? = nil
local events: { [string]: RemoteEvent } = {}
local functions: { [string]: RemoteFunction } = {}
local unreliableEvents: { [string]: UnreliableRemoteEvent } = {}

local function getRemotes(name: string): Folder
	if remotes ~= nil then
		return remotes
	end

	local folder = ReplicatedStorage:WaitForChild("Remotes", 10)
	if folder == nil then
		warn(`ReplicatedStorage.Remotes is missing while looking for remote {name}; waiting for it`)
		folder = ReplicatedStorage:WaitForChild("Remotes")
	end
	assert(folder:IsA("Folder"), "ReplicatedStorage.Remotes must be a Folder")
	remotes = folder
	return folder
end

local function findRemote(name: string): Instance
	local folder = getRemotes(name)
	local remote = folder:WaitForChild(name, 10)
	if remote == nil then
		warn(`Remote {name} is missing after 10 seconds; waiting for it`)
		remote = folder:WaitForChild(name)
	end
	return remote
end

function Net.Event(name: string): RemoteEvent
	local cached = events[name]
	if cached ~= nil then
		return cached
	end

	local remote = findRemote(name)
	assert(remote:IsA("RemoteEvent"), `Remote {name} must be a RemoteEvent, got {remote.ClassName}`)
	events[name] = remote
	return remote
end

function Net.Function(name: string): RemoteFunction
	local cached = functions[name]
	if cached ~= nil then
		return cached
	end

	local remote = findRemote(name)
	assert(remote:IsA("RemoteFunction"), `Remote {name} must be a RemoteFunction, got {remote.ClassName}`)
	functions[name] = remote
	return remote
end

function Net.UnreliableEvent(name: string): UnreliableRemoteEvent
	local cached = unreliableEvents[name]
	if cached ~= nil then
		return cached
	end

	local remote = findRemote(name)
	assert(remote:IsA("UnreliableRemoteEvent"), `Remote {name} must be an UnreliableRemoteEvent, got {remote.ClassName}`)
	unreliableEvents[name] = remote
	return remote
end

return Net
