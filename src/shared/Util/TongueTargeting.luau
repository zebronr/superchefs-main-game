--!strict

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local TongueConfig = Config.Skills.TongueGrab
local Tags = require(Shared:WaitForChild("Tags"))

-- The Gecko's targeting rules, shared so the server decision and the client preview agree.
local TongueTargeting = {}

function TongueTargeting.ExtendAlpha(elapsed: number): number
	return TweenService:GetValue(math.clamp(elapsed / TongueConfig.ExtendTime, 0, 1), TongueConfig.ExtendEasingStyle, TongueConfig.ExtendEasingDirection)
end

function TongueTargeting.RetractAlpha(elapsed: number): number
	return TweenService:GetValue(math.clamp(elapsed / TongueConfig.RetractTime, 0, 1), TongueConfig.RetractEasingStyle, TongueConfig.RetractEasingDirection)
end

-- The vector on the ground plane, normalized; zero when there is no horizontal part.
function TongueTargeting.Flat(vector: Vector3): Vector3
	local result = Vector3.new(vector.X, 0, vector.Z)
	return if result.Magnitude > 1e-4 then result.Unit else Vector3.zero
end

-- Where the tongue leaves: the face attachment, else the head, else the root.
function TongueTargeting.Mouth(character: Model): Vector3
	local head = character:FindFirstChild("Head")
	if head ~= nil and head:IsA("BasePart") then
		local attachment = head:FindFirstChild("FaceFrontAttachment")
		if attachment ~= nil and attachment:IsA("Attachment") then
			return attachment.WorldPosition
		end
		return head.Position
	end
	return character:GetPivot().Position
end

-- Where targeting measures from: the root's centre at mouth height. Unlike the mouth it doesn't move
-- as the Gecko turns, so range and the dead zone don't flicker while spinning between items.
function TongueTargeting.AimOrigin(character: Model): Vector3
	local mouth = TongueTargeting.Mouth(character)
	local root = character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return mouth
	end
	return Vector3.new(root.Position.X, mouth.Y, root.Position.Z)
end

-- Line of sight: only walls and other non-class geometry block. Characters, stations, items and
-- helper parts are excluded, so the tongue passes over counters.
function TongueTargeting.LosParams(extraExcluded: { Instance }): RaycastParams
	local excluded: { Instance } = table.clone(extraExcluded)
	for _, player in Players:GetPlayers() do
		if player.Character ~= nil then
			table.insert(excluded, player.Character)
		end
	end
	local tags: { string } = { Tags.Ignore, Tags.ProjectileIgnore, Tags.Projectile, Tags.Grabbed }
	for _, className in Tags.Classes do
		table.insert(tags, Tags.ClassTag(className))
	end
	for _, tag in tags do
		for _, instance in CollectionService:GetTagged(tag) do
			table.insert(excluded, instance)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = excluded
	return params
end

-- Shared range, height and line-of-sight checks for a candidate.
local function reachable(origin: Vector3, part: BasePart, params: RaycastParams): (boolean, Vector3, number)
	local offset = part.Position - origin
	local flatOffset = Vector3.new(offset.X, 0, offset.Z)
	local distance = flatOffset.Magnitude
	if distance < TongueConfig.DeadZone or distance > TongueConfig.Range or math.abs(offset.Y) > TongueConfig.MaxHeightDifference then
		return false, flatOffset, distance
	end
	local hit = workspace:Raycast(origin, offset, params)
	return hit == nil or hit.Instance == part, flatOffset, distance
end

-- Range, height and line of sight, without requiring the item to sit near an aim line.
function TongueTargeting.Reachable(origin: Vector3, part: BasePart, params: RaycastParams): boolean
	local canReach = reachable(origin, part, params)
	return canReach
end

-- The candidate closest along the flat aim line that is in range, near the line, at a reachable
-- height and in line of sight.
function TongueTargeting.Find(origin: Vector3, direction: Vector3, candidates: { BasePart }, params: RaycastParams): BasePart?
	local aim = TongueTargeting.Flat(direction)
	if aim == Vector3.zero then
		return nil
	end
	local best: BasePart? = nil
	local bestAlong = math.huge
	for _, part in candidates do
		local reachablePart, flatOffset = reachable(origin, part, params)
		if not reachablePart then
			continue
		end
		local along = flatOffset:Dot(aim)
		if along < TongueConfig.DeadZone or along > TongueConfig.Range or along >= bestAlong then
			continue
		end
		if (flatOffset - aim * along).Magnitude > TongueConfig.LineRadius then
			continue
		end
		best = part
		bestAlong = along
	end
	return best
end

-- Lowest distance plus turning cost among reachable items, regardless of current aim line.
function TongueTargeting.Best(origin: Vector3, facing: Vector3, candidates: { BasePart }, params: RaycastParams): BasePart?
	local aim = TongueTargeting.Flat(facing)
	if aim == Vector3.zero then
		return nil
	end
	local best: BasePart? = nil
	local bestScore = math.huge
	for _, part in candidates do
		local reachablePart, flatOffset, distance = reachable(origin, part, params)
		if not reachablePart then
			continue
		end
		local angle = math.acos(math.clamp(aim:Dot(flatOffset / distance), -1, 1))
		local score = distance + TongueConfig.AutoAimTurnPenalty * angle
		if score < bestScore then
			best = part
			bestScore = score
		end
	end
	return best
end

-- Where the tongue ends when it whiffs: full range, clipped at the first blocking hit.
function TongueTargeting.WhiffTip(origin: Vector3, direction: Vector3, params: RaycastParams): Vector3
	local reach = direction * TongueConfig.Range
	local hit = workspace:Raycast(origin, reach, params)
	return if hit ~= nil then hit.Position else origin + reach
end

return TongueTargeting
