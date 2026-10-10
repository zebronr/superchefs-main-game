--!strict

local Character = {}

Character.CharacterModels = {
	St4rqqs = "Bill",
	Player1 = "Bill",
	Player2 = "Bill",
	idgiveup4ever2touchu = "Bill",
	zebronr = "Gecko",
} :: { [string]: string }
Character.DefaultCharacterModel = "Bill"
Character.CollisionGroup = "Character"
-- Registered in Studio; avoids characters, customers, pickups and afterimages during Order Rush.
Character.PhasedCollisionGroup = "Phased"
-- In Studio every player gets this character model, whatever the name mapping says. Set nil to use the mapping. Ignored on live servers.
Character.StudioOverride = "Gecko" :: string?
Character.Colors = {
	{ Color3.fromRGB(14, 0, 115), Color3.fromRGB(115, 0, 2), Color3.fromRGB(0, 115, 0), Color3.fromRGB(115, 107, 0) },
	{ Color3.fromRGB(165, 63, 164), Color3.fromRGB(0, 113, 115), Color3.fromRGB(115, 67, 0), Color3.fromRGB(111, 167, 28) },
}

Character.DashLength = 0.33
Character.DashStrength = 70
Character.DashFollowupFactor = 0.6
Character.DashCooldown = 0.43
Character.DashMaxForce = 30000
Character.DashEffectCooldown = 0.3
Character.DashTrailCount = 7
Character.DashTrailMinSize = Vector3.new(1.94, 0.9, 1.675)
Character.DashTrailMaxSize = Vector3.new(9.054, 4.201, 7.815)
Character.DashTrailInterval = 0.05
Character.DashTrailGrowTime = 0.2
Character.DashTrailShrinkTime = 0.8

Character.RunAnimationId = "rbxassetid://115102747595810"
Character.PickupAnimationId = "rbxassetid://77035704035780"
Character.DashAnimationId = "rbxassetid://95922700952770"

Character.CameraOffset = Vector3.new(20, 25, 0)
Character.CameraSpeed = 5
Character.CameraFov = 50
-- "Fixed": legacy FollowUp, a fixed angle that slides after the player.
-- "Track": re-aims at the player every frame, so the angle sways while the position catches up.
Character.CameraMode = "Fixed" :: "Fixed" | "Track"

return Character
