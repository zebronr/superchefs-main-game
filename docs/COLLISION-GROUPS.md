# Collision groups

The one source of truth for which parts collide with what. Every map, template and script follows it, so a level
built later behaves like the ones before it. Audited against Studio on 2026-10-07; `Bounds` and `GhostPhase` added 2026-10-13 for the Ghost, `Ragdoll` the same day for the Bear, `SeatedNPCs` the same day so a dashing Bear doesn't shove into seated customers.

## Rules

1. **Groups are registered in Studio only** (Model tab > Collision Groups, or through the MCP). Code never calls
   `PhysicsService:RegisterCollisionGroup` or `CollisionGroupSetCollidable`.
2. **Only the groups below exist.** A part never uses an unregistered name (Roblox silently treats it as `Default`,
   which hides mistakes). Adding, renaming or changing a group's collisions updates this file in the same change.
3. **Group names in code come from `Config`** (`Config.Character.CollisionGroup`, `.PhasedCollisionGroup`,
   `.GhostPhaseCollisionGroup`, `.RagdollCollisionGroup`, `Config.Customers.CollisionGroup` and `.SeatedCollisionGroup`, `Config.Skills.OrderRush.Visuals.CollisionGroup`); never a string literal in a script.
4. **Code sets a group only for things it creates or owns at runtime:** player characters (`CharacterService`, and the
   owning client's prediction in `Skills/Phase`; `SkillEffects.CollisionGroup` picks the group), the phased Alien,
   seated customers (`CustomerService` switches them between `NPCs` and `SeatedNPCs`), and client-only visuals. Everything else gets its group from its template or map part in Studio.
5. **Maps follow the checklist below.** A new map, or a map edit, is checked with the audit before it ships.

## Groups

| Group | What goes in it | Set by | Collides with |
|---|---|---|---|
| `Default` | Static world a phasing Ghost walks through: walls, counters, stations, solid decor. | Studio (map parts) | everything except `PlayerBarrier`, `Afterimage`, `GhostPhase` and `GhostBarrier` |
| `Bounds` | What nothing passes, not even a phasing Ghost: every floor a player stands on, and the map edge (`MapBarrier`). | Studio (map parts) | same as `Default`, plus `GhostPhase` |
| `Character` | Every part of a player character. | `CharacterService` on spawn | `Default`, `Bounds`, `Character`, `PlayerBarrier`, `NPCs` |
| `Phased` | A player character passing through others: Order Rush, and always for an incorporeal character (the Ghost, `Config.Character.Incorporeal`). | `CharacterService` from the `Phased` attribute and the character model | `Default`, `Bounds`, `PlayerBarrier`, `GhostBarrier` only |
| `GhostPhase` | The Ghost during Phase: through walls, counters and stations. | `CharacterService` from `PhaseUntil`; the owning client predicts it | `Bounds`, `PlayerBarrier` only |
| `NPCs` | Every part of customer and serving-window NPC templates (`ReplicatedStorage.NPCs`). The client-only ragdoll of a caught runner (`RagdollController`) keeps its template's `NPCs` parts. | Studio (templates) | `Default`, `Bounds`, `Character`, `PlayerBarrier`, `Pickupable` |
| `SeatedNPCs` | A customer while seated at a table (anchored). Players pass through, so a dash never shoves into an anchored body. | `CustomerService` when the customer sits; back to `NPCs` when it stands to leave or run | `Default`, `Bounds`, `Pickupable`, `GhostBarrier` |
| `Pickupable` | Every carryable item part: foods, plates, dirty plates, pots, extinguisher, soup. | Studio (templates and map items) | `Default`, `Bounds`, `NPCs` |
| `PlayerBarrier` | Invisible walls that keep players and NPCs out but let thrown items fly over (e.g. behind counters). They also stop a phasing Ghost. | Studio (map parts) | `Character`, `Phased`, `GhostPhase`, `NPCs` |
| `GhostBarrier` | Walls only a phasing Ghost passes (e.g. over the centre counters): they stop players (`Character`, and `Phased`, so a Ghost that isn't phasing and an Order Rush player are stopped too) and NPCs, while food passes: items don't collide (`Pickupable` = n) and throw casts skip it (they're `Default`, and `Default` = n). Only `GhostPhase` walks through; food the Ghost carries goes with it (held items are CanCollide off). Registered 2026-10-13, reworked the same day. | Studio (map parts) | `Character`, `Phased`, `NPCs`, `Ragdoll` |
| `Ragdoll` | The client-only floppy copy of a player thrown by the Bear (`Skills/BearToss` via `Util/RagdollCopy`): lands on floors and bounces off walls, never touches players, NPCs or items. | Client code | `Default`, `Bounds` only |
| `Afterimage` | Client-only visual copies (Order Rush copy, UFO, beam, the Ghost's echoes). | Client code | nothing |
| `StudioSelectable` | Roblox's built-in group for Studio selection. Never assign it. Studio's click-select only picks parts whose group collides with it, so map groups authored in Studio keep it on: `PlayerBarrier` was off (its walls couldn't be clicked) and was turned on 2026-10-13. Runtime-only groups (`Afterimage`, `GhostPhase`, `Ragdoll`, `SeatedNPCs`) stay off. | Roblox | (built-in) |

### Matrix (registered in Studio)

Y = collides. Keep this table identical to Studio.

| | Default | Pickupable | Character | PlayerBarrier | NPCs | Afterimage | Phased | Bounds | GhostPhase | Ragdoll | GhostBarrier | SeatedNPCs |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| **Default** | Y | Y | Y | n | Y | n | Y | Y | n | Y | n | Y |
| **Pickupable** | | n | n | n | Y | n | n | Y | n | n | n | Y |
| **Character** | | | Y | Y | Y | n | n | Y | n | n | Y | n |
| **PlayerBarrier** | | | | n | Y | n | Y | n | Y | n | n | n |
| **NPCs** | | | | | n | n | n | Y | n | n | Y | n |
| **Afterimage** | | | | | | n | n | n | n | n | n | n |
| **Phased** | | | | | | | n | Y | n | n | Y | n |
| **Bounds** | | | | | | | | Y | Y | Y | n | Y |
| **GhostPhase** | | | | | | | | | n | n | n | n |
| **Ragdoll** | | | | | | | | | | n | Y | n |
| **GhostBarrier** | | | | | | | | | | | n | Y |
| **SeatedNPCs** | | | | | | | | | | | | n |

Why: items never push or trip players (`Pickupable`/`Character` = n) and never stack-collide with each other; NPCs
walk through each other so a crowd never jams; players bump into each other and into NPCs (catching runners relies on
reaching them, not shoving them).

## Map checklist

Every map under `ServerStorage.Maps` uses these folders (missing ones are fine when the map doesn't need them):

| Folder / part | Group | Other settings |
|---|---|---|
| `Objects` (stations, counters, tables) | `Default` | Anchored, CanCollide on. Stations that catch throws are tagged `throwInteractable`. |
| Floor (every part a player stands on, wherever it sits, e.g. inside `Decorations`) | `Bounds` | Anchored. Without it a phasing Ghost falls through. |
| Walls, solid `Decorations` | `Default` | Anchored. A phasing Ghost walks through these. |
| `NonCollidableDecors` | `Default` | CanCollide, CanQuery and CanTouch off. |
| `MapBarrier` (map edge, blocks everything including thrown items and a phasing Ghost) | `Bounds` | Invisible, anchored, tagged `IGNORE`. (`Test/Basic` uses visible `Barriers` walls as its edge, also `Bounds`.) |
| `PlayerBarrier` (keeps players out, items fly over) | `PlayerBarrier` | Invisible, anchored, tagged `IGNORE`. |
| `GhostBarrier` (only a phasing Ghost passes; food and throws pass, players and NPCs don't) | `GhostBarrier` | Anchored. Needs no `IGNORE` tag: the group already lets throw casts and items through. Visible or invisible as the design wants. |
| `NPCBarriers` (guides window NPCs) | `Default` (see open items) | Invisible, anchored, tagged `IGNORE`. |
| `PreloadedPickupables` (plates on the map at start) | `Pickupable` | Same as the matching `ServerStorage.Assets` template. |
| `SpawnPoints`, `CustomerSpawn`, `NPCWaypoints` | `Default` | CanCollide, CanQuery and CanTouch off. |
| `Scenery` (everything outside the map edge, never reached: ground, streets, buildings, props) | `Default` | Anchored; CanCollide, CanQuery and CanTouch off. |

Templates: `ServerStorage.Assets.Foods` and `.Plates` items are `Pickupable` (plated food and soup visuals sitting on a
plate are CanCollide off and may stay `Default`). `ReplicatedStorage.NPCs` models are `NPCs` on every part, including
accessories. Client-only effect templates in `ReplicatedStorage.Assets` are CanCollide, CanQuery and CanTouch off, so
their group doesn't matter (leave `Default`).

## Audit

Claude runs this read-only check through the MCP (Edit datamodel) after any map or template change and fixes what it
reports (telling the user first, per CLAUDE.md). It lists unregistered groups, carryable items outside `Pickupable`,
NPC parts outside `NPCs`, barrier folders in the wrong group, and floors (CanCollide parts with their top at floor
height) outside `Bounds`.

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
	-- The map this part belongs to: the nearest ancestor with an `Objects` folder.
	local map: Instance? = d.Parent
	while map ~= nil and map:FindFirstChild("Objects") == nil do
		map = map.Parent
	end
	if d:IsA("BasePart") and map ~= nil then
		local folder = d:FindFirstAncestorOfClass("Folder")
		local name = if folder then folder.Name else ""
		local top = d.Position.Y + d.Size.Y / 2
		local isFloor = d.CanCollide and name ~= "PreloadedPickupables" and not d:IsDescendantOf((map :: any).Objects)
			and top > -1 and top < 2.6 and d.Size.Y < 3 and d.Size.X * d.Size.Z > 20
		local expected = if name == "PreloadedPickupables" then "Pickupable"
			elseif name == "PlayerBarrier" then "PlayerBarrier"
			elseif name == "GhostBarrier" then "GhostBarrier"
			elseif name == "MapBarrier" or isFloor then "Bounds"
			elseif name == "NPCBarriers" then "Default"
			else nil
		check(d, expected, if isFloor then "floor" else name)
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

4. (Closed 2026-10-11: the `CoOp/Test` maps were deleted.) They exist again (`Test/Basic`, `Test/Tables`); their six `PreloadedPickupables` plates were `Default` and moved to `Pickupable` on 2026-10-11 (audit clean).
5. `NPCBarriers` are `Default`, so they also block players and items. In Level1 they are in fact the collision boxes
   of the decor tables and chairs (whose meshes have CanCollide off), so that is intended there; a better name would
   be `FurnitureColliders`. Decide for `Chapter1/Level2` (being designed with new barriers): give furniture its own
   collision or keep collider boxes, and use an NPC-only group (new `NPCBarrier`, colliding with `NPCs` only) only
   for walls meant to guide NPCs.
7. `Maps.CoOp.Chapter1.Level2` (the demo map, built in Workspace and moved here 2026-10-13; the older draft is `Level2_Old`). Its barriers are colour-coded (`MapBarrier` red,
   `PlayerBarrier` blue, `NPCBarriers` green) and invisible again; set Transparency 0.6 to edit them.
   It has an empty `GhostBarrier` folder for ghost-only walls, and a `FireExtinguisher` in `PreloadedPickupables`
   (Pickupable, its `Emitter` CanCollide off) placed by a `DefObjectOnTop` on the countertop beside the stoves.
   `NPCBarriers` holds one `TableCollider` box per dining table (Default, IGNORE, the table's footprint, 10 tall), the
   furniture-collider pattern of item 5; the table meshes themselves are CanCollide off. Its `MapBarrier` now reaches down to y 1.4, past the floor top; Level1's still starts at 3.77, leaving a gap at the
   floor behind the counters. The `MapBarrier` spans the whole building, kitchen and dining room (x -423.38..-363.11,
   z -59.09..-2.46); the dining room's east wall parts sit in `NonCollidableDecors`, so this edge is what holds players
   in there. `PlayerBarrier` only lines the kitchen counters (west wall, and the north and south walls up to the
   kitchen wall at x -399.4); Level1's centre box and right wall were removed. The chairs are not collidable.
   Its `CustomerSpawn` sits at the map root on the east side (the user's former `SpawnPoints.NPCSpawn`), and the four
   `1_spawn` points form a rectangle centred on the kitchen's middle wall (x -409.39 / -391.39, z -15.35 / -46.35). Its
   `PreloadedPickupables` holds 10 plates (`Pickupable`), each linked by its own `DefObjectOnTop` on `PlateTable_1`. The two stoves (moved from loose Workspace into
   `Objects`) each hold a stand-in `Pan` from `PreloadedPickupables` through `DefObjectOnTop`, placed like Test/Basic's. The three food crates on the north wall were moved into `Objects` too; the sink is still in `Workspace.$GAME`.
   `Scenery` (outside the map edge) holds the ground slabs, roads with curb lines, sidewalks, 17 trees, a row of 11
   Blender buildings east of the street facing west, and 28 props (street lamps, benches). The building and prop
   templates are in `ServerStorage.Assets.Scenery`; their palettes are listed in `art/buildings/README.md`. The whole
   map was moved 224 studs west on 2026-10-13; the coordinates above are the new ones.
   `Scenery.Lots` holds the user's grass lots and concrete strips (moved in from loose Workspace, anchored, `Bounds` as floors;
   they were unanchored and fell into the void once the map sat past the Baseplate), and `Scenery.Props` the `Car_Sedan`.
6. The Edit-mode `Workspace` has loose test parts (`asd`, foods, countertops). They're not part of any map; delete or
   move them into a map.
