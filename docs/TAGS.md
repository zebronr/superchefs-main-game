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
| `CustomerTable` | customer tables (child `Seat` part; Manual mode maps). One per seat: a shared table is split into invisible parts, one per chair, over its top (Level2: a 4-chair table is 4 quarters, a 2-chair table 2 halves), each holding its `Seat` and its chair mesh, so the target highlight shows the chair (Roblox draws no highlight on an invisible part). | `Stations/CustomerTable` |
| `Runner` | customer model's `HumanoidRootPart` while dashing (set by code) | `Runner` |
| `Trash` | trash cans | `Stations/Trash` |
| `Stove` | stoves | `Stations/Stove` |
| `Sink` | sinks (children `WashPartMarker`, `DrainBoard`, `PlateDisplays`) | `Stations/Sink` |
| `Food` | food items, raw and chopped | `Item` |
| `Plate` | clean plates | `Plate` |
| `DirtyPlate` | dirty plates | `DirtyPlate` |
| `CookingTool` | pots/pans (`cookingToolClass` attribute picks the subclass) | `CookingTool` / `CookingTools/Pot`, `CookingTools/Pan` |
| `FireExtinguisher` | fire extinguisher | `FireExtinguisher` |

## Behavior tags (set in Studio)

| Tag | Put on | Effect |
|-----|--------|--------|
| `throwInteractable` | stations that catch thrown items: counters, chopping boards, stoves, food crates, customer tables | `ThrowService` lands a thrown item on it via `Receive`. Crates got it on 2026-10-05 (all maps). |
| `IGNORE` | invisible helper parts | Ignored by throw raycasts and the extinguisher spray. |
| `projectileInteractionIgnore` | parts thrown items should pass through | Ignored by throw raycasts. Not currently on anything. |
| `ProximityNode` | helper parts that redirect targeting to their station | Client targeting and server distance checks. Not currently on anything. |
| `defaultEnabled` | cooking tools that start enabled without a station | Read by `CookingTool`. Not currently on anything. |
| `BitmapText` | UI `TextLabel`s / `TextButton`s (HUD coins, timer, combo badge and COMBO LOST, superskill time and key, coin notification, round end title and coins, START button, `Assets.UI.ObjectNotification.TextLabel`, the progress bar's `Badge.Bang`) | `BitmapTextController` hides the label's own text and draws it in Jersey 15, following its `Text`, `TextColor3`, `TextTransparency` and `TextXAlignment`; a `UIStroke` (or `TextStrokeTransparency` < 1) becomes the shadow color. |

## Runtime tags (code adds and removes them; never set in Studio)

| Tag | Added by | Meaning |
|-----|----------|---------|
| `LOCKED` | `ChoppingBoard` while chopping | Station (or the item on it) can't be interacted with. |
| `FIRELOCKED` | `FireService` while on fire (stations and pots) | Can't be interacted with or picked up until the fire is out; a station with a burning item on top is locked too. |
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
| `weldingOffset` | Vector3 (degrees) | items | Rotation when placed on a surface. `RawFoods.raw_meat` uses `(90, 0, 0)` (with `holdingOffset` `(-90, 0, 0)`) so the upright mesh lies flat; the test map's Pan uses `(0, 45, 0)` to sit diagonally. |
| `directionOffset` | Vector3 (degrees) | stations | Rotation applied to items placed on it. |
| `surfaceOffset` | number (studs) | stations whose top is a separate part | Lifts items placed on it (`Slot.Place`) by this much. Every `FoodContainer` has its lid's height, `0.252`, so items sit on the lid instead of sinking into it. |
| `yOffset` | number | items | Height adjustment when placed. |

## Set by code at runtime (don't set in Studio)

| Attribute | On | Meaning |
|-----------|----|---------|
| `interactionDisabled` | items, CustomerTable stations | Not targetable (e.g. food while being handed out). `CustomerTable` sets it when there is nothing to do at the table. |
| `objectClass = "Runner"` | dashing customer HumanoidRootPart | Set and removed by `CustomerService` with the generated `Class_Runner` tag so the normal interaction binder can catch runners. |
| `ChopProgress`, `WashProgress` | chopping boards, sinks | Progress bars. |
| `Combined` | food | `true` on a food combined without a plate (`Recipes.NoPlate`, server `Food.AddContent`); the client won't predict a chop on it. |
| `ActionAnimation` | characters | Current chop/wash animation; also signals the owning client that auto-use is running, so movement or dash sends `StopUse`. Every client also puts that action's tool in the character's hand from it (`Config.Interaction.ActionTools`, `ActionToolController`); the owning client predicts it (`AnimationController.Predict`). |
| `CatchSwingAt` | player characters | Server time (lag-compensated) the player swung the bat at a dine-and-dasher. Every client shows the bat swing from it; the swinger predicts it. The catch lands only with the bonk (`Config.Interaction.CatchSwing`). |
| `CookContent`, `CookProgress`, `CookStartedAt`, `CookedAt`, `Fire`, `Spraying` | cooking tools, stations, extinguisher | Cooking, fire and spray state. |
| `ThrowStart`, `ThrowEnd`, `ThrowStartedAt`, `FallFrom`, `FallTo`, `FallStartedAt` | thrown items | Projectile animation. `ThrowStartedAt` is back-dated by the thrower's half-ping; the fall accelerates (`FallGravity`) from `FallFrom` to `FallTo`. |
| `DashedAt` | characters | Dash cooldown. |
| `CharacterModel` | characters | Name of the cloned character model (honours `Character.StudioOverride`). `Config.Skills.ByCharacter` maps it to a superskill. |
| `SkillState` | characters | nil, `"Aiming"` or `"Active"`. While set, Interact/Use/Throw/Dash are rejected (server) and skipped (client). |
| `SkillReadyAt`, `SkillCooldown` | characters | `GetServerTimeNow` when the superskill is ready again, and the cooldown's total length (HUD ring fraction). |
| `TongueState`, `TongueStartedAt`, `TongueTip` | characters | Gecko tongue: nil, `"Extending"` or `"Retracting"`, when that phase began, and where the tongue reaches. Extending `TongueStartedAt` is backdated by up to `MaxLagCompensation` for the actor's network delay; retracting is not. Every client draws from these after the actor's local prediction hands off. |
| `GrabFrom`, `GrabStartedAt`, `GrabByUserId` | items tagged `Grabbed` | Where the pulled item started, when the pull began, and whose tongue pulls it. |
| `CustomCharacter`, `PlayerColor`, `Team` | players / characters | Character model, outline color, team number. |
| `Loaded` | players | `true` once the player's client has streamed the map and preloaded its assets (`Loaded` on the `Round` remote); the round starts when every chef has it, and the loading screen's chef list shows READY. Cleared when the server empties and unloads the map. |
| `ChosenCharacter` | players | Demo: the chef picked on the boot screen (`PickCharacter` on the `Round` remote, only while `Waiting`); `CharacterService` spawns this model over every other rule. Kept through `/resetgame`. |
| `HeldForMap` | characters | `true` while `LevelService` keeps the character anchored because no map is loaded yet (before START). |
| `Cinematic` | players | `true` while `CinematicService` has removed an allowed developer from teams, spawns and round counts for filming. |
| `CustomerState`, `PatienceStartedAt`, `PatienceDuration`, `Recipe`, `Team` | customer models | Manual serve mode customer state for the bubble. A change from `WaitingToOrder` to `WaitingForFood` plays the take-order squash puff on every client (`OrderTakeController`). |
| `CustomerState` | CustomerTable parts | The seated customer's state (same values as on the customer model), nil with no customer. The mobile interact button reads it for ORDER and SERVE (`InputController`). |
| `Cash`, `CashAt`, `CashCollectedBy`, `CashCollectedAt` | CustomerTable parts | Uncollected coins, server time last placed, collector UserId and server time collected. Cleared at round reset. |
| `WillDash` | customer models | `true` (absent otherwise) when `CustomerService` rolled `DashChance` at spawn: the customer will run after eating. Clients show the sweat tell (`Assets.Effects.SweatDrops`) while they sit. |
| `CaughtAt`, `CaughtBy` | customer models | Server time and player UserId when a dashing customer is caught. `CustomerState` also gains `Dashing` and `Caught`. Every client hides a caught customer and ragdolls a local copy from these (`RagdollController`). |
| `CaughtByToss` | customer models | `true` when a Bear caught the dasher (Bear Toss); `RagdollController` flings it with `Skills.BearToss.RunnerFling`/`RunnerLift`. |
| `HustleUntil` | characters (Bill) | `GetServerTimeNow` when Hustle ends. Server chop/wash speed and every client's Hustle visuals read it (`SkillEffects`). |
| `FreezeCenter`, `FreezeStartedAt`, `FreezeUntil` | characters (Penguin) | The running frost circle: centre (Vector3) and its start and end. `FreezeService`, `FireService` and every client read the circles through `SkillEffects.FreezeZones`. Cleared when it ends. |
| `FrozenAt` | cooking tools, customer models | `GetServerTimeNow` when Deep Freeze froze it (nil when not frozen). Clients hold the progress/burn warning and patience bar at this time and tint the object. |
| `RushStartedAt`, `RushOrigin`, `RushStops` | characters (Alien) | Order Rush chain: lag-compensated start, where the Alien stood, and the stops (`"x,y,z,yaw;x,y,z,yaw"`, radians for facing, `SkillEffects.EncodeStops`). Clients draw the afterimages from these; they draw the origin at the hidden Alien's live position (RushOrigin is a fallback, since it lags when pressed while moving). Cleared when the chain ends. |
| `Phased` | characters (Alien) | True during Order Rush. `CharacterService` puts all current and newly added parts in the `Phased` collision group; cleared when the chain finishes or is canceled. (The Ghost is always in `Phased` without the attribute, from `Config.Character.Incorporeal`.) |
| `PhaseUntil` | characters (Ghost) | `GetServerTimeNow` when Phase ends. While it runs `CharacterService` puts the parts in `GhostPhase`, `InteractionService` refuses interacting and throwing and nobody catches throws with it; every client's Phase visuals read it (`SkillEffects.PhaseActive`). |
| `TossHeldBy` | characters (any player) | The Bear's UserId while it holds this player overhead (Bear Toss). The player's own client pins its (hidden) character above the Bear and every client draws a ragdoll copy held overhead; the server and client block its actions (`TossPath.Busy`). Cleared on the throw or put-down. |
| `TossStartedAt`, `TossFrom`, `TossTo` | characters (any player) | A Bear Toss flight: server start time and root positions (Vector3). The player's own client carries its hidden character along `TossPath.Position`; every client draws a tumbling ragdoll copy, the Bear's dip and the landing dust. The player is busy until `TossPath.EndsAt` (landing + `GetUpTime`); cleared a second after that. |
| `RoundState`, `RoundEndsAt`, `RoundPausedLeft`, `RoundDuration`, `Coins_<team>`, `ServeMode`, `LevelPath` | ReplicatedStorage | Round, coins and level info for clients. `RoundState`: `Waiting` (empty place, before START), `Loading` (map loaded, waiting for every chef), `Intro`, `Playing`, `Ended`. |
| `RoundPausedLeft` | ReplicatedStorage | Seconds left on the round clock while the cinematic camera has it paused (`RoundService.SetTimerPaused`); nil when running. The HUD timer shows it. |
| `Combo_<team>`, `ComboEndsAt_<team>` | ReplicatedStorage | Team combo (level `EnableCombo`): serves made back to back, and the server time the streak lapses (nil when broken). Set by `OrderService`; `ComboController` draws the badge and fire from them. |
| `ComboReason_<team>` | ReplicatedStorage | Why the team's combo last reset: `Expired`, `Failed`, `Late`, `OutOfOrder` or `FeverOver`; nil while it runs or after it lapsed. Set by `OrderService`; `ComboController` picks the break text from it. |
| `FeverEndsAt_<team>` | ReplicatedStorage | Server time the team's fever ends (level `Combo.Fever`); nil outside a round. Set by `OrderService`; `ComboController` draws the fever while it is in the future. |
