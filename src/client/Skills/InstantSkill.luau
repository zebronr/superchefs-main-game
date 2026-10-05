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
local switchedOff: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any

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
end

function InstantSkill.Root(character: Model): BasePart?
	local root = character:FindFirstChild("HumanoidRootPart")
	return if root ~= nil and root:IsA("BasePart") then root else nil
end

return InstantSkill
