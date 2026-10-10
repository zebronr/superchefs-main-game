--!strict

local AssetIds = {}

local function add(value: string, into: { string }, seen: { [string]: boolean }): ()
	if value == "" or string.sub(value, 1, 11) == "rbxasset://" or seen[value] then
		return
	end
	seen[value] = true
	table.insert(into, value)
end

local function read(instance: Instance, property: string, into: { string }, seen: { [string]: boolean }): ()
	local ok, value = pcall(function(): any
		return (instance :: any)[property]
	end)
	if ok and typeof(value) == "string" then
		add(value, into, seen)
	end
end

local function collectOne(instance: Instance, into: { string }, seen: { [string]: boolean }): ()
	if instance:IsA("MeshPart") then
		read(instance, "MeshId", into, seen)
		read(instance, "TextureID", into, seen)
	elseif instance:IsA("SpecialMesh") then
		read(instance, "MeshId", into, seen)
		read(instance, "TextureId", into, seen)
	elseif instance:IsA("Decal") or instance:IsA("Texture") or instance:IsA("ParticleEmitter") or instance:IsA("Beam") or instance:IsA("Trail") then
		read(instance, "Texture", into, seen)
	elseif instance:IsA("SurfaceAppearance") then
		read(instance, "ColorMap", into, seen)
		read(instance, "NormalMap", into, seen)
		read(instance, "RoughnessMap", into, seen)
		read(instance, "MetalnessMap", into, seen)
	elseif instance:IsA("Sound") then
		read(instance, "SoundId", into, seen)
	elseif instance:IsA("Animation") then
		read(instance, "AnimationId", into, seen)
	elseif instance:IsA("ImageLabel") or instance:IsA("ImageButton") then
		read(instance, "Image", into, seen)
	end
end

function AssetIds.Collect(roots: { Instance }, into: { string }, seen: { [string]: boolean }): ()
	for _, root in roots do
		collectOne(root, into, seen)
		for _, descendant in root:GetDescendants() do
			collectOne(descendant, into, seen)
		end
	end
end

return AssetIds
