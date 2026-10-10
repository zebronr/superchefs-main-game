# Collision groups

The one source of truth for which parts collide with what. Every map, template and script follows it, so a level
built later behaves like the ones before it. Audited against Studio on 2026-10-07.

## Rules

1. **Groups are registered in Studio only** (Model tab > Collision Groups, or through the MCP). Code never calls
   `PhysicsService:RegisterCollisionGroup` or `CollisionGroupSetCollidable`.
2. **Only the groups below exist.** A part never uses an unregistered name (Roblox silently treats it as `Default`,
   which hides mistakes). Adding, renaming or changing a group's collisions updates this file in the same change.
3. **Group names in code come from `Config`** (`Config.Character.CollisionGroup`, `.PhasedCollisionGroup`,
   `Config.Skills.OrderRush.Visuals.CollisionGroup`); never a string literal in a script.
4. **Code sets a group only for things it creates or owns at runtime:** player characters (`CharacterService`), the
   phased Alien, and client-only visuals. Everything else gets its group from its template or map part in Studio.
5. **Maps follow the checklist below.** A new map, or a map edit, is checked with the audit before it ships.

## Groups

| Group | What goes in it | Set by | Collides with |
|---|---|---|---|
| `Default` | Static world: floor, walls, counters, stations, solid decor, map edge (`MapBarrier`). | Studio (map parts) | everything except `PlayerBarrier` and `Afterimage` |
| `Character` | Every part of a player character. | `CharacterService` on spawn | `Default`, `Character`, `PlayerBarrier`, `NPCs` |
| `Phased` | A player character passing through others (Order Rush). | `CharacterService` from the `Phased` attribute | `Default`, `PlayerBarrier` only |
| `NPCs` | Every part of customer and serving-window NPC templates (`ReplicatedStorage.NPCs`). | Studio (templates) | `Default`, `Character`, `PlayerBarrier`, `Pickupable` |
| `Pickupable` | Every carryable item part: foods, plates, dirty plates, pots, extinguisher, soup. | Studio (templates and map items) | `Default`, `NPCs` |
| `PlayerBarrier` | Invisible walls that keep players and NPCs out but let thrown items fly over (e.g. behind counters). | Studio (map parts) | `Character`, `Phased`, `NPCs` |
| `Afterimage` | Client-only visual copies (Order Rush copy, UFO, beam). | Client code | nothing |
| `StudioSelectable` | Roblox's built-in group for Studio selection. Never assign it. | Roblox | (built-in) |

### Matrix (registered in Studio)

Y = collides. Keep this table identical to Studio.

| | Default | Pickupable | Character | PlayerBarrier | NPCs | Afterimage | Phased |
|---|---|---|---|---|---|---|---|
| **Default** | Y | Y | Y | n | Y | n | Y |
| **Pickupable** | | n | n | n | Y | n | n |
| **Character** | | | Y | Y | Y | n | n |
| **PlayerBarrier** | | | | n | Y | n | Y |
| **NPCs** | | | | | n | n | n |
| **Afterimage** | | | | | | n | n |
| **Phased** | | | | | | | n |

Why: items never push or trip players (`Pickupable`/`Character` = n) and never stack-collide with each other; NPCs
walk through each other so a crowd never jams; players bump into each other and into NPCs (catching runners relies on
reaching them, not shoving them).

## Map checklist

Every map under `ServerStorage.Maps` uses these folders (missing ones are fine when the map doesn't need them):

| Folder / part | Group | Other settings |
|---|---|---|
| `Objects` (stations, counters, tables) | `Default` | Anchored, CanCollide on. Stations that catch throws are tagged `throwInteractable`. |
| Floor, walls, solid `Decorations` | `Default` | Anchored. |
| `NonCollidableDecors` | `Default` | CanCollide, CanQuery and CanTouch off. |
| `MapBarrier` (map edge, blocks everything including thrown items) | `Default` | Invisible, anchored, tagged `IGNORE`. |
| `PlayerBarrier` (keeps players out, items fly over) | `PlayerBarrier` | Invisible, anchored, tagged `IGNORE`. |
| `NPCBarriers` (guides window NPCs) | `Default` (see open items) | Invisible, anchored, tagged `IGNORE`. |
| `PreloadedPickupables` (plates on the map at start) | `Pickupable` | Same as the matching `ServerStorage.Assets` template. |
| `SpawnPoints`, `CustomerSpawn`, `NPCWaypoints` | `Default` | CanCollide, CanQuery and CanTouch off. |

Templates: `ServerStorage.Assets.Foods` and `.Plates` items are `Pickupable` (plated food and soup visuals sitting on a
plate are CanCollide off and may stay `Default`). `ReplicatedStorage.NPCs` models are `NPCs` on every part, including
accessories. Client-only effect templates in `ReplicatedStorage.Assets` are CanCollide, CanQuery and CanTouch off, so
their group doesn't matter (leave `Default`).

## Audit

Claude runs this read-only check through the MCP (Edit datamodel) after any map or template change and fixes what it
reports (telling the user first, per CLAUDE.md). It lists unregistered groups, carryable items outside `Pickupable`,
NPC parts outside `NPCs`, and barrier folders in the wrong group.

```lua
local PS = game:GetService("PhysicsService")
local issues = {}
local function check(part: BasePart, expected: string?, label: string)
	if not PS:IsCollisionGroupRegistered(part.CollisionGroup) then
		table.insert(issues, `unregistered '{part.CollisionGroup}': {part:GetFullName()}`)
	elseif expected and part.CollisionGroup ~= expected then
		table.insert(issues, `{label} should be {expected}, is {part.CollisionGroup}: {part:GetFullName()}`)
	end
end
for _, d in game.ServerStorage.Maps:GetDescendants() do
	if d:IsA("BasePart") then
		local folder = d:FindFirstAncestorOfClass("Folder")
		local name = if folder then folder.Name else ""
		local expected = if name == "PreloadedPickupables" then "Pickupable"
			elseif name == "PlayerBarrier" then "PlayerBarrier"
			elseif name == "MapBarrier" or name == "NPCBarriers" then "Default"
			else nil
		check(d, expected, name)
	end
end
for _, root in { game.ServerStorage.Assets.Foods, game.ServerStorage.Assets.Plates } do
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then check(d, if d.CanCollide then "Pickupable" else nil, "item") end
	end
end
for _, d in game.ReplicatedStorage.NPCs:GetDescendants() do
	if d:IsA("BasePart") then check(d, "NPCs", "NPC") end
end
return if #issues == 0 then "clean" else table.concat(issues, "\n")
```

## Open items (audit 2026-10-07)

Not fixed yet; each needs a Studio change.

Fixed 2026-10-10 (audit clean): `SoupModel`, the fire extinguisher and its `Emitter` (now CanCollide off) moved
from the unregistered `PickupableObjects` to `Pickupable`; the `PreloadedPickupables` plates in all three maps moved to
`Pickupable`; the 12 NPC accessory handles moved to `NPCs`. Still open:

4. `CoOp/Test/Basic` has no `PlayerBarrier`; its invisible `Barriers.Wall` parts are `Default` and so block thrown
   items. Decide per wall: map edge → rename the folder `MapBarrier` and tag `IGNORE`; player-only → `PlayerBarrier`.
5. `NPCBarriers` are `Default`, so they also block players and items. If they only exist to guide NPCs, they need an
   NPC-only group (would be a new group: `NPCBarrier`, colliding with `NPCs` only). Decide before the next map.
6. The Edit-mode `Workspace` has loose test parts (`asd`, foods, countertops). They're not part of any map; delete or
   move them into a map.
