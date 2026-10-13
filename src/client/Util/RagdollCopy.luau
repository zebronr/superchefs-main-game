--!strict

local CollectionService = game:GetService("CollectionService")

-- A client-only floppy copy of a character: the joints become ball sockets, the root part is gone, and the copy
-- carries no attributes or tags (so no game code mistakes it for the real one). Caught dine-and-dashers
-- (RagdollController) and players thrown by the Bear (Skills/BearToss) use it; the real model is hidden meanwhile.
local RagdollCopy = {}

export type Copy = {
	Model: Model,
	-- The main body part (Torso or UpperTorso): the part to pin or push.
	Body: BasePart?,
	Parts: { BasePart },
	-- Each part's and decal's own Transparency, to fade from.
	Faded: { [Instance]: number },
}

local function strip(instance: Instance): ()
	for name in instance:GetAttributes() do
		instance:SetAttribute(name, nil)
	end
	for _, tag in CollectionService:GetTags(instance) do
		CollectionService:RemoveTag(instance, tag)
	end
end

-- Makes the copy and parents it to Workspace. `group` puts every part in that collision group (nil keeps the
-- template's groups).
function RagdollCopy.Make(model: Model, group: string?): Copy?
	if model:FindFirstChild("HumanoidRootPart") == nil then
		return nil
	end
	local wasArchivable = model.Archivable
	model.Archivable = true
	local copy = model:Clone()
	model.Archivable = wasArchivable
	strip(copy)
	copy.Name = `{model.Name}Ragdoll`
	local copyRoot = copy:FindFirstChild("HumanoidRootPart")
	if copyRoot ~= nil then
		copyRoot:Destroy()
	end
	local faded: { [Instance]: number } = {}
	local parts: { BasePart } = {}
	for _, descendant in copy:GetDescendants() do
		strip(descendant)
		if
			descendant:IsA("BillboardGui")
			or descendant:IsA("Highlight")
			or descendant:IsA("ParticleEmitter")
			or descendant:IsA("BaseScript")
			or descendant:IsA("Sound")
		then
			descendant:Destroy()
		elseif descendant:IsA("Motor6D") then
			local part0, part1 = descendant.Part0, descendant.Part1
			if part0 ~= nil and part1 ~= nil then
				local attachment0 = Instance.new("Attachment")
				attachment0.CFrame = descendant.C0
				attachment0.Parent = part0
				local attachment1 = Instance.new("Attachment")
				attachment1.CFrame = descendant.C1
				attachment1.Parent = part1
				local socket = Instance.new("BallSocketConstraint")
				socket.Attachment0 = attachment0
				socket.Attachment1 = attachment1
				socket.LimitsEnabled = true
				socket.TwistLimitsEnabled = true
				socket.Parent = part1
			end
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = true
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.LocalTransparencyModifier = 0
			if group ~= nil then
				descendant.CollisionGroup = group
			end
			faded[descendant] = descendant.Transparency
			table.insert(parts, descendant)
		elseif descendant:IsA("Decal") then
			descendant.LocalTransparencyModifier = 0
			faded[descendant] = descendant.Transparency
		end
	end
	local humanoid = copy:FindFirstChildOfClass("Humanoid")
	if humanoid ~= nil then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		humanoid.BreakJointsOnDeath = false
		humanoid.RequiresNeck = false
		humanoid.PlatformStand = true
		humanoid.EvaluateStateMachine = false
	end
	local body = copy:FindFirstChild("Torso") or copy:FindFirstChild("UpperTorso")
	copy.Parent = workspace
	return {
		Model = copy,
		Body = if body ~= nil and body:IsA("BasePart") then body else nil,
		Parts = parts,
		Faded = faded,
	}
end

-- Fades the copy: 0 = its own transparency, 1 = gone.
function RagdollCopy.Fade(copy: Copy, amount: number): ()
	for instance, transparency in copy.Faded do
		local value = transparency + (1 - transparency) * amount
		if instance:IsA("BasePart") then
			instance.Transparency = value
		elseif instance:IsA("Decal") then
			instance.Transparency = value
		end
	end
end

return RagdollCopy
