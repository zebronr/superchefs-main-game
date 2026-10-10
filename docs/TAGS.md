# Tags and attributes

Two different things, both set in Studio's Properties panel:
- **Tags** (Part 1): CollectionService tags, the "Tags" section of Properties. Code finds them with `CollectionService:HasTag` / `GetTagged`, through `src/shared/Tags.luau` (add new tags there, not as string literals).
- **Attributes** (Part 2): named values in the "Attributes" section. Code reads them with `instance:GetAttribute(name)`. They can't be looked up with CollectionService.

What an object *is* (its class) is authored as the `objectClass` attribute only. The `Class_<name>` tags are generated from it at server start.

Names are case-sensitive. Keep this file in sync whenever either changes.

Last Studio scan: 2026-10-05 (after the legacy cleanup).

# Part 1: CollectionService tags

## Class tags (generated, never set by hand)

Authoring a class is the `objectClass` attribute (Part 2). At server start, `BinderService.Init` adds `Class_<objectClass>` (see `Tags.ClassTag`) to every instance under these roots that has a known `objectClass`: `ServerStorage.Maps`, `ServerStorage.Assets` and `workspace["$GAME"]` (its initial children are what `LevelService` snapshots and re-clones). Other loose Workspace objects are not tagged, so they stay inert. An unknown `objectClass` value logs a warning with the full name.

Clones inherit the tags, so map clones and items spawned from `ServerStorage.Assets` bind automatically, and clients see the tags because they replicate with the instances. Code finds objects by tag (`GetTagged`, `GetInstanceAddedSignal`, `Binder`) and tests class membership with `Tags.IsClass` / `Tags.ClassOf`, which read the attribute. Do not add raw class tags like `Countertop` by hand: nothing reads them.

Each `objectClass` value (listed in `Tags.Classes`; the generated tag is `Class_` plus the value) and the class it binds. An instance should carry exactly one.

| `objectClass` | Put on | Class |
|-----|--------|-------|
| `Countertop` | counter parts | `Stations/Counter` |
| `ChoppingBoard` | chopping boards | `Stations/ChoppingBoard` |
| `FoodContainer` | food crates (child `Food` ObjectValue → raw food template) | `Stations/FoodContainer` |
| `PlateTable` | `PlateTable_<team>` | `Stations/PlateTable` |
| `ServingCounter` | serving window (Window mode maps) | `Stations/ServingCounter` |
| `CustomerTable` | customer tables (child `Seat` part; Manual mode maps) | `Stations/CustomerTable` |
| `Runner` | customer model's `HumanoidRootPart` while dashing (set by code) | `Runner` |
| `Trash` | trash cans | `Stations/Trash` |
| `Stove` | stoves | `Stations/Stove` |
| `Sink` | sinks (children `WashPartMarker`, `DrainBoard`, `PlateDisplays`) | `Stations/Sink` |
| `Food` | food items, raw and chopped | `Item` |
| `Plate` | clean plates | `Plate` |
| `DirtyPlate` | dirty plates | `DirtyPlate` |
| `CookingTool` | pots/pans (`cookingToolClass` attribute picks the subclass) | `CookingTool` / `CookingTools/Pot` |
| `FireExtinguisher` | fire extinguisher | `FireExtinguisher` |

## Behavior tags (set in Studio)

| Tag | Put on | Effect |
|-----|--------|--------|
| `throwInteractable` | stations that catch thrown items: counters, chopping boards, stoves, food crates, customer tables | `ThrowService` lands a thrown item on it via `Receive`. Crates got it on 2026-10-05 (all maps). |
| `IGNORE` | invisible helper parts | Ignored by throw raycasts and the extinguisher spray. |
| `projectileInteractionIgnore` | parts thrown items should pass through | Ignored by throw raycasts. Not currently on anything. |
| `ProximityNode` | helper parts that redirect targeting to their station | Client targeting and server distance checks. Not currently on anything. |
| `defaultEnabled` | cooking tools that start enabled without a station | Read by `CookingTool`. Not currently on anything. |

## Runtime tags (code adds and removes them; never set in Studio)

| Tag | Added by | Meaning |
|-----|----------|---------|
| `LOCKED` | `ChoppingBoard` while chopping | Station (or the item on it) can't be interacted with. |
| `FIRELOCKED` | `FireService` while on fire | Station can't be interacted with until the fire is out. |
| `Grabbed` | `TongueGrab` (server superskill) on an item the Gecko's tongue is pulling back | Clients move the anchored item from `GrabFrom` to the grabber's mouth (`GrabByUserId`); the sphere sweeps and LOS rays ignore it, and it can't be grabbed again. |
| `Projectile` | `ThrowService` on a flying item | Client `ProjectileController` animates it. The thrower's client predicts the flight before this tag arrives. Other in-flight items are excluded from the sweep. |

## Other tags in the place

Legacy cleanup on 2026-10-05 removed every raw class tag (131), `VISIBLE` (132), `Useable`, `Flamable`, `Pickupable`, and renamed the typo `Throw_Interactable` to `throwInteractable`. What remains besides the tags above:

| Tag | Where | Note |
|-----|-------|------|
| numeric tags (e.g. `1757225430`) | 3 animation `KeyframeSequence`s | Added by the Studio animation editor; ignore. |

# Part 2: Attributes (`GetAttribute`, not CollectionService)

## Set in Studio on map objects

| Attribute | Type | Put on | Effect |
|-----------|------|--------|--------|
| `objectClass` | string | every station and item | **The one authoring attribute for what an object is.** One of the class names in Part 1 (`Tags.Classes`). Read by `Tags.ClassOf`; the generated `Class_<name>` tag is derived from it at server start. |
| `cookingToolClass` | string | cooking tools (`"Pot"`, `"Pan"`) | Picks the CookingTool subclass; stoves only heat classes in `Cooking.StoveToolClasses`. |
| `holdingOffset` | Vector3 (degrees) | items | Rotation while carried and thrown. |
| `weldingOffset` | Vector3 (degrees) | items | Rotation when placed on a surface. |
| `directionOffset` | Vector3 (degrees) | stations | Rotation applied to items placed on it. |
| `yOffset` | number | items | Height adjustment when placed. |

## Set by code at runtime (don't set in Studio)

| Attribute | On | Meaning |
|-----------|----|---------|
| `interactionDisabled` | items, CustomerTable stations | Not targetable (e.g. food while being handed out). `CustomerTable` sets it when there is nothing to do at the table. |
| `objectClass = "Runner"` | dashing customer HumanoidRootPart | Set and removed by `CustomerService` with the generated `Class_Runner` tag so the normal interaction binder can catch runners. |
| `ChopProgress`, `WashProgress` | chopping boards, sinks | Progress bars. |
| `ActionAnimation` | characters | Current chop/wash animation; also signals the owning client that auto-use is running, so movement or dash sends `StopUse`. |
| `CookContent`, `CookProgress`, `CookStartedAt`, `CookedAt`, `Fire`, `Spraying` | cooking tools, stations, extinguisher | Cooking, fire and spray state. |
| `ThrowStart`, `ThrowEnd`, `ThrowStartedAt`, `FallFrom`, `FallTo`, `FallStartedAt` | thrown items | Projectile animation. `ThrowStartedAt` is back-dated by the thrower's half-ping; the fall accelerates (`FallGravity`) from `FallFrom` to `FallTo`. |
| `DashedAt` | characters | Dash cooldown. |
| `CharacterModel` | characters | Name of the cloned character model (honours `Character.StudioOverride`). `Config.Skills.ByCharacter` maps it to a superskill. |
| `SkillState` | characters | nil, `"Aiming"` or `"Active"`. While set, Interact/Use/Throw/Dash are rejected (server) and skipped (client). |
| `SkillReadyAt`, `SkillCooldown` | characters | `GetServerTimeNow` when the superskill is ready again, and the cooldown's total length (HUD ring fraction). |
| `TongueState`, `TongueStartedAt`, `TongueTip` | characters | Gecko tongue: nil, `"Extending"` or `"Retracting"`, when that phase began, and where the tongue reaches. Extending `TongueStartedAt` is backdated by up to `MaxLagCompensation` for the actor's network delay; retracting is not. Every client draws from these after the actor's local prediction hands off. |
| `GrabFrom`, `GrabStartedAt`, `GrabByUserId` | items tagged `Grabbed` | Where the pulled item started, when the pull began, and whose tongue pulls it. |
| `CustomCharacter`, `PlayerColor`, `Team` | players / characters | Character model, outline color, team number. |
| `CustomerState`, `PatienceStartedAt`, `PatienceDuration`, `Recipe`, `Team` | customer models | Manual serve mode customer state for the bubble. |
| `Cash`, `CashAt`, `CashCollectedBy`, `CashCollectedAt` | CustomerTable parts | Uncollected coins, server time last placed, collector UserId and server time collected. Cleared at round reset. |
| `CaughtAt`, `CaughtBy` | customer models | Server time and player UserId when a dashing customer is caught. `CustomerState` also gains `Dashing` and `Caught`. |
| `HustleUntil` | characters (Bill) | `GetServerTimeNow` when Hustle ends. Server chop/wash speed and every client's Hustle visuals read it (`SkillEffects`). |
| `FreezeCenter`, `FreezeStartedAt`, `FreezeUntil` | characters (Penguin) | The running frost circle: centre (Vector3) and its start and end. `FreezeService`, `FireService` and every client read the circles through `SkillEffects.FreezeZones`. Cleared when it ends. |
| `FrozenAt` | cooking tools, customer models | `GetServerTimeNow` when Deep Freeze froze it (nil when not frozen). Clients hold the progress/burn warning and patience bar at this time and tint the object. |
| `RushStartedAt`, `RushOrigin`, `RushStops` | characters (Alien) | Order Rush chain: lag-compensated start, where the Alien stood, and the stops (`"x,y,z,yaw;x,y,z,yaw"`, radians for facing, `SkillEffects.EncodeStops`). Clients draw the afterimages from these; they draw the origin at the hidden Alien's live position (RushOrigin is a fallback, since it lags when pressed while moving). Cleared when the chain ends. |
| `Phased` | characters (Alien) | True during Order Rush. `CharacterService` puts all current and newly added parts in the `Phased` collision group; cleared when the chain finishes or is canceled. |
| `RoundState`, `RoundEndsAt`, `RoundDuration`, `Coins_<team>`, `ServeMode`, `LevelPath` | ReplicatedStorage | Round, coins and level info for clients. |
