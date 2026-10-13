--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- The shape SkillController expects from a press-once skill, plus small helpers the skills share.
local InstantSkill = {}

export type InstantSkill = {
	-- Mirrors the server rule; the HUD greys out and the key does nothing while carrying.
	RequiresEmptyHands: boolean,
	Setup: () -> (),
	-- Extra local gate (Order Rush needs a waiting customer). The server checks again.
	CanUse: (character: Model) -> boolean,
	-- Starts the effect locally the moment the key is pressed.
	Predict: (character: Model) -> (),
	-- The server refused or never answered: undo everything Predict started.
	Rollback: () -> (),
	-- True while the local character cannot act (the skill holds it).
	IsBusy: () -> boolean,
	-- Optional: true while the local character may move and dash but not interact or throw.
	-- Checked for every instant skill, so a Studio test key counts too.
	BlocksInteract: (() -> boolean)?,
	-- Optional: true while the local character may not throw (the Ghost phasing).
	BlocksThrow: (() -> boolean)?,
	-- Optional: true while the local character's run animation stays off (the Ghost floats while phasing).
	StopsRunAnimation: (() -> boolean)?,
}

local warned: { [string]: boolean } = {}
local burstAttachments: { [ParticleEmitter]: Attachment } = {}

function InstantSkill.WarnOnce(message: string): ()
	if not warned[message] then
		warned[message] = true
		warn(message)
	end
end

-- `ReplicatedStorage.Assets.Skills.<name>`, the folder holding a skill's templates.
function InstantSkill.Folder(name: string): Instance?
	local assets = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Skills")
	local folder = assets:FindFirstChild(name)
	if folder == nil then
		InstantSkill.WarnOnce(`ReplicatedStorage.Assets.Skills.{name} is missing; its visuals are skipped`)
	end
	return folder
end

-- A template of the given class from a skill folder, or nil (with one warning).
function InstantSkill.Template(folder: Instance?, name: string, className: string): Instance?
	if folder == nil then
		return nil
	end
	local template = folder:FindFirstChild(name)
	if template == nil or not template:IsA(className) then
		InstantSkill.WarnOnce(`{folder:GetFullName()}.{name} ({className}) is missing; that effect is skipped`)
		return nil
	end
	return template
end

-- Fires `count` particles of an emitter template at a world CFrame (EmissionDirection Front = its LookVector).
function InstantSkill.Burst(template: ParticleEmitter?, cframe: CFrame, count: number): ()
	if template == nil or count <= 0 then
		return
	end
	local attachment: Attachment? = burstAttachments[template]
	if attachment == nil or attachment.Parent == nil then
		local newAttachment = Instance.new("Attachment")
		newAttachment.Name = `{template.Name}Burst`
		newAttachment.Parent = workspace.Terrain
		local emitter = template:Clone()
		emitter.Enabled = false
		emitter.Parent = newAttachment
		burstAttachments[template] = newAttachment
		attachment = newAttachment
	end
	local placed = attachment :: Attachment
	placed.WorldCFrame = cframe
	local emitter = placed:FindFirstChildOfClass("ParticleEmitter")
	if emitter ~= nil then
		emitter:Emit(count)
	end
end

-- Highlights and surface GUIs (the outline, the "you" ring) that SetHidden turned off, to turn back on.
-- A strong table: Roblox can collect Instance keys out of weak tables while the Instance still exists.
local switchedOff: { [Instance]: boolean } = {}

-- Hides or shows a character for this client (LocalTransparencyModifier leaves the real values alone).
function InstantSkill.SetHidden(character: Model, hidden: boolean): ()
	local value = if hidden then 1 else 0
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.LocalTransparencyModifier = value
		elseif descendant:IsA("Decal") then
			descendant.LocalTransparencyModifier = value
		elseif descendant:IsA("Highlight") or descendant:IsA("SurfaceGui") then
			local toggle = descendant :: any
			if hidden and toggle.Enabled then
				toggle.Enabled = false
				switchedOff[descendant] = true
			elseif not hidden and switchedOff[descendant] then
				toggle.Enabled = true
				switchedOff[descendant] = nil
			end
		end
	end
	-- Drop entries for instances destroyed while hidden.
	if not hidden then
		for instance in switchedOff do
			if instance.Parent == nil then
				switchedOff[instance] = nil
			end
		end
	end
end

function InstantSkill.Root(character: Model): BasePart?
	local root = character:FindFirstChild("HumanoidRootPart")
	return if root ~= nil and root:IsA("BasePart") then root else nil
end

-- The joint that holds the body on the root part (R6 RootJoint or R15 Root): moving its C0 squashes or lifts the
-- whole body without moving the character. Offset it in the root's space (`offset * Original`): R6's C0 is rotated,
-- so `Original * offset` would move the body along the wrong axis.
function InstantSkill.RootJoint(character: Model): Motor6D?
	local root = InstantSkill.Root(character)
	local r6 = if root then root:FindFirstChild("RootJoint") else nil
	if r6 ~= nil and r6:IsA("Motor6D") then
		return r6
	end
	local torso = character:FindFirstChild("LowerTorso")
	local r15 = if torso then torso:FindFirstChild("Root") else nil
	return if r15 ~= nil and r15:IsA("Motor6D") then r15 else nil
end

-- CharacterEffectsController's player-color outline (a clone of Assets.Highlights.CharacterHighlight). Roblox draws
-- only one Highlight per character, so effects borrow this one (and put it back) instead of adding their own.
function InstantSkill.CharacterHighlight(character: Model): Highlight?
	local highlight = character:FindFirstChild("CharacterHighlight")
	return if highlight ~= nil and highlight:IsA("Highlight") then highlight else nil
end

function InstantSkill.ExpoOut(t: number): number
	return if t >= 1 then 1 else 1 - 2 ^ (-10 * t)
end

-- 0 to 1 with an overshoot that wobbles out (`wobble` is the overshoot's size).
function InstantSkill.Elastic(t: number, wobble: number): number
	if t <= 0 then
		return 0
	elseif t >= 1 then
		return 1
	end
	return InstantSkill.ExpoOut(t) + wobble * math.sin(t * math.pi * 5) * (1 - t) ^ 2
end

return InstantSkill
