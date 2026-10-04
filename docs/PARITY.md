# Legacy parity checklist

Source of truth: everything under `legacy/` (read in full). Each item is a behavior the rewrite must match (or consciously change). "unclear:" marks things the code does not settle (usually because they depend on Studio instances not in the repo). Path prefixes used below:

- `SI` = `legacy/server/Interactions/` , `SO` = `legacy/server/Interactions/Objects/` , `SC` = `legacy/server/CoreFunctions/`
- `CI` = `legacy/starterPlayerScripts/Interaction/` , `CV` = `legacy/starterPlayerScripts/Visuals/` , `CU` = `legacy/starterPlayerScripts/UI/`
- `CC` = `legacy/starterCharacterScripts/`

(Items still spell out the full file name so they stay greppable.)

## How the legacy interaction system works

1. **Targeting (client, every Heartbeat)** — `CC/Interaction/HighlightHandler.client.lua` runs `GetPartBoundsInRadius(HRP, 8)` filtered (Include) to parts tagged `VISIBLE` or `ProximityNode`. A part is a candidate only if it has attribute `objectClass` and not `interactionDisabled`, and is closer than 6 studs (`VisibilityConfigs.DefaultMinimumDistance`; per-class override table is empty). Score = `priority*100 - distance`, where priority comes from `VisibilityConfigs.PriorityLevel` (Food 1.15, ServingCounter 1.3, default 1). Best score wins. If the winner is a `ProximityNode` part, the target is `part.Parent.Parent` and the node part is stored as `VisibleObjectNode`. The target gets a cloned `VisibilityHighlight` (on the object and each BasePart descendant) and is written to the local `PlayerValues.VisibleObject` ObjectValue. The tag lists are refreshed whenever the server fires `UpdateVisibilityParameters` (it does so after spawning any new object).
2. **Request (client -> server)** — `CI/InteractionHandler.client.lua`: Space = `Interact`, LeftCtrl press/release = `Use(true/false)`. It fires `Remotes.Interactions.InteractionRequest(request, {vO = VisibleObject, vON = VisibleObjectNode, hS = heldState})`. Mobile buttons go through `ReplicatedStorage.Bindables.Controls.*` bindables into the same functions.
3. **Validation (server)** — `SI/InteractionHandler.server.lua` `verifyRequest`: max 10 requests per player per 0.5 s window; ignored while `playerLock[player]` (set during a Use hold, bypassed for Use-release); reject if target has `interactionDisabled`; target must be within `6 + 10` studs of HRP (measured to the node part or the object itself); or, with no target, the player must be carrying something.
4. **Choosing the object (server)** — carried object = `PlayerValues.ObjectCarried` (server-side ObjectValue). `Interact`: `objectToInteractWith = visibleObject or objectCarried`, but if both exist and `InteractionConfigs.PriorityLevel[carried class] (default 1) > PriorityLevel[visible class] (default 1)` the carried object's module handles it. Priorities: Countertop 3, ChoppingBoard 3, ServingCounter 3, PlateTable 3, Trash 3, CookingTool 2.5, Plate 2, Food 1 (everything else defaults to 1; ties go to the visible object). `Use`: `objectToUse = objectCarried or visibleObject` (carried wins).
5. **Dispatch** — `objectClass` attribute -> must be in `interactableClasses` (Interact) / `useableClasses` (Use) -> `require(Objects/<Class>/<Class>)` and call `main.Interact(player, objectCarried, visibleObject)` / `main.Use(player, objectCarried, visibleObject, heldState)`. A per-object `interactLock` (Interact) and `useLock` (Use, owner = player) serialize work. Modules chain to each other (ChoppingBoard and Stove call `Countertop.Interact`; Countertop re-dispatches to the higher-priority of carried/on-top object; PlateTable calls `Plate.Interact`).
6. **Server-originated interactions** — `ReplicatedStorage.Remotes.Interactions.InteractionRequestFunction` is a BindableFunction. `Projectile.lua` invokes it with `player = nil` and `{oC = projectile, vO = counter}` to land a thrown food onto a counter (skips `verifyRequest`, uses `oC` instead of `ObjectCarried`).
7. **Carry model** — a carried object is welded to the HRP by a `WeldConstraint` named `ObjectHolder`; an object resting on a surface is welded by a `WeldConstraint` named `objectTopWelder` parented to the surface (`Part0 = surface`, `Part1 = object`). `Welds.isObjectOnTop(surface)` = that weld's `Part1`.

---

## Layer 1 — Pickup/drop + Counter

Checklist

- [ ] Space triggers `Interact` with current `VisibleObject`/`VisibleObjectNode`; LeftCtrl press sends `Use(true)`, release sends `Use(false)`; input ignored when `gameProcessed` — `legacy/starterPlayerScripts/Interaction/InteractionHandler.client.lua`
- [ ] Highlight target is chosen every Heartbeat from parts tagged `VISIBLE`/`ProximityNode` within radius 8, accepted only if distance < 6, with attribute `objectClass` and without `interactionDisabled` — `legacy/starterCharacterScripts/Interaction/HighlightHandler.client.lua`
- [ ] Target score = `priority*100 - distance`; Food priority 1.15, ServingCounter 1.3, others 1 (so a Food 15 studs "worth" closer, ServingCounter 30) — `legacy/starterCharacterScripts/Interaction/HighlightHandler.client.lua`, `legacy/shared/Configs/VisibilityConfigs.lua`
- [ ] A `ProximityNode` part resolves to `part.Parent.Parent` as the target and is remembered as `VisibleObjectNode`; node distance is what the server checks — `legacy/starterCharacterScripts/Interaction/HighlightHandler.client.lua`, `legacy/server/Interactions/InteractionHandler.server.lua`
- [ ] Only one object is highlighted at a time; highlight clone `VisibilityHighlight` is placed on the object and on every BasePart descendant, removed when the target changes or none is left — `legacy/starterCharacterScripts/Interaction/HighlightHandler.client.lua`
- [ ] Server rejects Interact/Use if target `interactionDisabled`, or farther than 16 studs (6 default min distance + 10 margin) from HRP (node or object position) — `legacy/server/Interactions/InteractionHandler.server.lua`
- [ ] With no target, a request is only valid if the player is carrying something — `legacy/server/Interactions/InteractionHandler.server.lua`
- [ ] Rate limit: at most 10 requests per player in any rolling 0.5 s; excess dropped with a warn — `legacy/server/Interactions/InteractionHandler.server.lua`
- [ ] While the player holds Use (`playerLock`), all other requests from that player are ignored; Use-release bypasses it — `legacy/server/Interactions/InteractionHandler.server.lua`
- [ ] Carried-vs-visible dispatch by `PriorityLevel` (Countertop/ChoppingBoard/ServingCounter/PlateTable/Trash 3, CookingTool 2.5, Plate 2, Food 1, default 1; strictly greater carried priority wins, ties -> visible) — `legacy/server/Interactions/InteractionHandler.server.lua`, `legacy/shared/Configs/InteractionConfigs.lua`
- [ ] Interactable classes: Countertop, CookingTool, Food, Plate, ChoppingBoard, Stove, FireExtinguisher, DirtyPlate, Sink, FoodContainer, ServingCounter, PlateTable, Trash — `legacy/server/Interactions/InteractionHandler.server.lua`
- [ ] Per-object `interactLock` blocks a second Interact on the same object while one is running; an object with a `useLock` (being chopped/washed) cannot be Interacted — `legacy/server/Interactions/InteractionHandler.server.lua`
- [ ] Pickup: object becomes Massless, unanchored, network-owned by the player, `interactionDisabled = true`, welded to HRP (`ObjectHolder`) at `HRP.CFrame * (0,0,-2) * rotation(holdingOffset degrees)`, CanCollide false, `ObjectCarried` set — `legacy/server/CoreFunctions/Actions/ObjectAction.lua`
- [ ] Drop: weld removed, `ObjectCarried` cleared, Massless false, CanCollide true; unless `dontEnable`, `interactionDisabled` cleared after 0.5 s — `legacy/server/CoreFunctions/Actions/ObjectAction.lua`
- [ ] After a drop, 0.5 s later the network owner is reset to server (only if still owned by that player) and linear velocity zeroed; cancelled if the object is picked up again within 0.5 s — `legacy/server/CoreFunctions/Actions/ObjectAction.lua`
- [ ] Empty hands + a Food visible -> pick it up; carrying Food + nothing visible -> drop on the floor in front (2 studs ahead, falls physically); carrying Food + visible Food -> drop carried, pick up visible (swap); Interact sound `Play("Interact")` is broadcast to all clients on every Food interact — `legacy/server/Interactions/Objects/Food/Food.lua`
- [ ] Same empty/drop behavior (without sound) for CookingTool, FireExtinguisher, DirtyPlate; Plate drop/pickup plays Interact sound — `legacy/server/Interactions/Objects/CookingTool/CookingTool.lua`, `legacy/server/Interactions/Objects/FireExtinguisher/FireExtinguisher.lua`, `legacy/server/Interactions/Objects/DirtyPlate/DirtyPlate.lua`, `legacy/server/Interactions/Objects/Plate/Plate.lua`
- [ ] FoodContainer with empty hands: clones the container's `Food` ObjectValue target, parents it to `workspace.$GAME`, disables its interaction, fires `UpdateVisibilityParameters`, and picks it up; does nothing if the player is carrying — `legacy/server/Interactions/Objects/FoodContainer/FoodContainer.lua`
- [ ] Countertop ignores the interaction if the countertop has tag `LOCKED` or `FIRELOCKED`, or the object on top has `LOCKED` — `legacy/server/Interactions/Objects/Countertop/Countertop.lua`
- [ ] Countertop + carrying + counter empty: carried object is dropped (no re-enable) and welded on top of the counter, tagged `projectileInteractionIgnore`; on a server-originated call (`player == nil`) it is disabled and placed instead — `legacy/server/Interactions/Objects/Countertop/Countertop.lua`
- [ ] Placement CFrame: `surface.CFrame * (0, surface.Y/2 + objectRotatedHeight/2 + increment, 0) * rotation(-weldingOffset + surface.directionOffset)` — `legacy/server/CoreFunctions/Welds.lua`
- [ ] Countertop + empty hands + object on top: unweld, pick it up, remove tag `projectileInteractionIgnore` — `legacy/server/Interactions/Objects/Countertop/Countertop.lua`
- [ ] Countertop + carrying + same class on top (and class not in `AllowInteractionWithSelf`): swap (player puts carried on counter, takes the on-top object) — `legacy/server/Interactions/Objects/Countertop/Countertop.lua`
- [ ] Countertop + carrying + different (or self-interacting Plate/DirtyPlate) class on top: the higher-priority object's module runs as `Interact(player, otherObject, thatObject)` (ties: the on-top object); e.g. carrying a Food over a Plate on the counter plates it, carrying a Plate over a Food on the counter plates it — `legacy/server/Interactions/Objects/Countertop/Countertop.lua`
- [ ] `AllowInteractionWithSelf = {DirtyPlate, Plate}`; all other same-class pairs swap — `legacy/shared/Configs/InteractionConfigs.lua`
- [ ] Countertop fires the Interact sound to all clients on every non-blocked interaction — `legacy/server/Interactions/Objects/Countertop/Countertop.lua`
- [ ] Map load: every child of `loadedMap.Objects` with a `DefObjectOnTop` ObjectValue gets that object disabled and welded on top, then the value is destroyed — `legacy/server/MainGame.server.lua`
- [ ] Server `PlayerValues` folder per player: `VisibleObject`, `ObjectCarried`, `VisibleObjectNode` ObjectValues (client writes Visible* locally only) — `legacy/server/Initialize/PlayerValues.server.lua`, `legacy/shared/PlayerValues.lua`
- [ ] Any exception inside a request is caught and logged with request name/params (no crash) — `legacy/server/Interactions/InteractionHandler.server.lua`

#### Data
- `pickupZSpace = 2` (carry distance in front of HRP), drop re-enable delay 0.5 s, network-owner reset delay 0.5 s — `legacy/server/CoreFunctions/Actions/ObjectAction.lua`
- `maxRequest = 10` per 0.5 s, `positionMarginOfError = 10`, `timeoutMOE = 0.2` — `legacy/server/Interactions/InteractionHandler.server.lua`
- `DefaultMinimumDistance = 6`, `MinimumDistance = {}`, `PriorityLevel {Food 1.15, ServingCounter 1.3}` — `legacy/shared/Configs/VisibilityConfigs.lua`
- Highlight `ProximityRadius = 8`, `PriorityWeight = 100` — `legacy/starterCharacterScripts/Interaction/HighlightHandler.client.lua`
- Controls: Interact = Space, Use = LeftControl, Dash = LeftShift, Throw = LeftAlt — `legacy/shared/Configs/Controls.lua`
- Interaction `PriorityLevel` and `AllowInteractionWithSelf` — `legacy/shared/Configs/InteractionConfigs.lua`

#### Remotes / bindables
- `ReplicatedStorage.Remotes.Interactions.InteractionRequest` (RemoteEvent, client -> server: `"Interact"`/`"Use"`) — fired by `CI/InteractionHandler.client.lua`
- `ReplicatedStorage.Remotes.Interactions.InteractionRequestFunction` (BindableFunction; server-only) — invoked by `Projectile.lua`
- `ReplicatedStorage.Remotes.Interactions.UpdateVisibilityParameters` (RemoteEvent, server -> all clients) — fired by MainGame (after map load), FoodContainer, Sink, PlateTable, ChoppingBoard
- `ServerStorage.Bindables.ToggleUseLock` (BindableEvent `(object, state)`) — fired by ChoppingBoard, handled in InteractionHandler.server
- `ReplicatedStorage.Remotes.Sounds.Play` (RemoteEvent `"Interact"`) — fired by Countertop, Food, Plate
- `ReplicatedStorage.Bindables.Controls.Interact` / `.Use` (client-only bindables) — fired by MobileControlHandler, consumed by InteractionHandler.client

#### Studio dependencies
- Object parts need attributes: `objectClass`, `interactionDisabled` (runtime), optional `holdingOffset` (Vector3 degrees, held rotation), `weldingOffset` (Vector3 degrees, resting rotation), surface `directionOffset` (Vector3 degrees)
- Tags: `VISIBLE`, `ProximityNode` (node part nested exactly 2 levels under the target), `LOCKED`, `FIRELOCKED`, `projectileInteractionIgnore`
- `ReplicatedStorage.Assets.VisibilityHighlight`
- `workspace.$GAME` (parent for spawned objects), map `Objects` folder with optional `DefObjectOnTop` ObjectValue children
- `PlayerGui` is not needed for this layer (mobile buttons are layer 9)
- Collision group `Character` (parts of the character are put in it) — `legacy/server/Initialize/CharacterInitialization.server.lua`

#### Suspected bugs
- `legacy/server/Interactions/InteractionHandler.server.lua`: `requestInteraction` never returns the module result, so `InteractionRequestFunction:Invoke(...)` always returns nil; `Projectile.lua`'s `interactionFailed` logic is dead.
- `legacy/server/Interactions/InteractionHandler.server.lua`: `interactLock[obj] = true` is cleared only on the happy path; an error thrown by a module's `Interact` leaves that object permanently un-interactable ("error 2" print).
- `legacy/server/Interactions/InteractionHandler.server.lua`: `playerLock` is cleared only inside the Use handler for a target found at release time. If the player holds Use, walks away (VisibleObject becomes nil, `verifyRequest` returns false) and releases, `playerLock[player]` stays true and blocks all their Interact requests until a later successful Use-release near something. The UseTimeout/ProximityWatch paths call `main.Use(..., false)` directly and do not clear `playerLock`/`useLock` either.
- `legacy/server/Interactions/InteractionHandler.server.lua`: `verifyRequest` returns nil (not false) on rate limit/playerLock; `vO`/`vON` are client-supplied and not type-checked (non-Instance would error inside pcall).
- `legacy/server/Interactions/InteractionHandler.server.lua`: leftover debug `print("interacting?")`, `print("error 1/2")`; `legacy/server/Interactions/Objects/Countertop/Countertop.lua` leftover `print("COUNTERTOP INTERACT")`.
- `legacy/server/Interactions/Objects/Countertop/Countertop.lua`: `projectileInteractionIgnore` is added/removed only in Countertop paths; objects placed by other code (ChoppingBoard result, `DefObjectOnTop`, plated/sink plates, swap path) never get the tag, and the swap path (`objectCarried` class == on-top class) places the carried object without tagging.
- `legacy/server/Interactions/Objects/Countertop/Countertop.lua`: the final `else return true` branch is unreachable (`elseif objectOnTop` is the complement of `if not objectOnTop`).
- `legacy/server/Interactions/Objects/Countertop/Countertop.lua`: server-originated swap (`player == nil`, same class, thrown Food landing on a counter that holds Food) returns without doing anything and leaves the thrown object disabled/unmoved except what `stopProjectile` did.
- `legacy/shared/Cache.lua`: `ClearCache` rebinds a loop variable and does nothing (caches never cleared between rounds). `Cache.Retrieve("CookingTool_ToolEnabled")` is used by FireHandler through string ids; `CookingTool.lua` registers `FoodContent` and `CookingProgress` under the same id `CookingTool_FoodContent` (works only because each module keeps its own local reference).
- `legacy/server/CoreFunctions/Actions/ObjectAction.lua`: `PickupObject` does not check that the player is not already carrying something and `module.GetValue(...)` errors when the value object is missing; `DropObject` sets `SetNetworkOwner(player)` even for anchored/welded results.
- `legacy/server/CoreFunctions/ToggleInteraction.lua` and `legacy/shared/ToggleInteraction.lua` are identical duplicates (only the shared one is required).
- `legacy/server/Interactions/Objects/Tool/Tool.lua` is an empty file; `"Tool"` is in `useableClasses` (dead).
- `legacy/starterCharacterScripts/Interaction/HighlightHandler.client.lua`: `VisibleObjectNode` is only updated when a node part wins; it stays stale if a non-node part wins afterwards (server tolerates it only because it falls back to object position).

---

## Layer 2 — ChoppingBoard

Checklist

- [ ] ChoppingBoard Interact behaves exactly like Countertop (place/take/swap) — `legacy/server/Interactions/Objects/ChoppingBoard/ChoppingBoard.lua`
- [ ] Chopping requires empty hands, a visible ChoppingBoard and a food on it; Use dispatch picks the carried object first, so holding anything prevents chopping — `legacy/server/Interactions/InteractionHandler.server.lua`
- [ ] Holding Use starts chopping if `ServerStorage.Assets.Foods.ChoppedFoods` contains `chopped_<foodName>`; otherwise nothing is chopped — `legacy/server/Interactions/Objects/ChoppingBoard/ChoppingBoard.lua`
- [ ] While chopping the board gets tag `LOCKED` (blocks Countertop interaction, i.e. nobody can take the food) — `legacy/server/Interactions/Objects/ChoppingBoard/ChoppingBoard.lua`
- [ ] Progress: +20 every 0.3 s, so the 6th increment (>100) at ~1.5 s completes the chop; the loop waits 0.3 s after each of the first five increments (5 x 0.3 = 1.5 s total hold) — `legacy/server/Interactions/Objects/ChoppingBoard/ChoppingBoard.lua`
- [ ] Progress persists per food item if the player releases Use early; re-holding resumes from the stored value — `legacy/server/Interactions/Objects/ChoppingBoard/ChoppingBoard.lua`
- [ ] Releasing Use stops the loop, plays `StopAnimation("Chop")`, removes `LOCKED`, hides the progress bar for everyone — `legacy/server/Interactions/Objects/ChoppingBoard/ChoppingBoard.lua`
- [ ] On completion: raw food is unwelded and destroyed, the `chopped_*` clone (interaction disabled) is parented to `$GAME`, `UpdateVisibilityParameters` fired, chopped food welded onto the board, `LOCKED` removed, `ToggleUseLock(board, nil)`, progress bar destroyed — `legacy/server/Interactions/Objects/ChoppingBoard/ChoppingBoard.lua`
- [ ] An already-chopped food cannot be chopped again (no `chopped_chopped_*` asset expected) — `legacy/server/Interactions/Objects/ChoppingBoard/ChoppingBoard.lua`
- [ ] `UseTimeout = 1.5 s` (+0.2 s margin): the server force-calls `Use(false)` 1.7 s after the hold started if the player never released — `legacy/server/Interactions/InteractionHandler.server.lua`, `legacy/server/Interactions/Objects/ChoppingBoard/ChoppingBoard.lua`
- [ ] Chop animation `PlayAnimation("Chop", looped=true)` fired to the chopping player only; stopped on release/complete — `legacy/server/Interactions/Objects/ChoppingBoard/ChoppingBoard.lua`, `legacy/starterCharacterScripts/Visuals/ActionAnimationsHandler.client.lua`
- [ ] Clients show a progress bar on the food: +20 per 0.3 s locally, `Chop` sound at each step, latency-compensated first step (`chopDelay - travelTime`); bar destroyed when `d` flag is sent — `legacy/starterPlayerScripts/Visuals/ProgressBarHandler.client.lua`
- [ ] ChoppingBoard can burn (FireHandler burnable class) — `legacy/server/CoreFunctions/Utilities/FireHandler.lua`
- [ ] ChoppingBoard priority 3 (same as Countertop) — `legacy/shared/Configs/InteractionConfigs.lua`

#### Data
- `ProgressAmount = 20`, `ChopDelay = 0.3`, `UseTimeout = (100/20)*0.3 = 1.5` — `legacy/server/Interactions/Objects/ChoppingBoard/ChoppingBoard.lua`
- Chop animation id `74695809221721` — `legacy/starterCharacterScripts/Visuals/ActionAnimationsHandler.client.lua` (separate unused `chop` id `89917089939246` in `legacy/shared/Animations.lua`)
- Chop-able / result foods: not listed in code; determined by the folder `ServerStorage.Assets.Foods.ChoppedFoods` (names used by recipes: `chopped_cucumber`, `chopped_mango`, `chopped_tomato`, `chopped_lettuce`, `chopped_strawberry` — unclear: exact folder contents)

#### Remotes / bindables
- `Remotes.Effects.ProgressBar` (server -> all, `"ChoppingProgress"` `{s, cD, pPC, o, sT}` / `{s=false, o, d}`)
- `Remotes.Character.PlayAnimation(name, looped)` / `StopAnimation(name)` (server -> that player)
- `Remotes.Interactions.UpdateVisibilityParameters`
- `ServerStorage.Bindables.ToggleUseLock`

#### Studio dependencies
- `ServerStorage.Assets.Foods.ChoppedFoods.chopped_*` (BaseParts/Models with `objectClass = "Food"`, `FoodList` child — see layer 3)
- ChoppingBoard part with `objectClass = "ChoppingBoard"`, `ProgressBar` template at `ReplicatedStorage.Assets.ProgressBar` (child path `BG/Clip/Bar`), SoundService `SoundEffects.Chop`

#### Suspected bugs
- `legacy/server/Interactions/Objects/ChoppingBoard/ChoppingBoard.lua`: for a non-choppable item the loop sets `Debounce[item] = true` and `LOCKED` but never clears `Debounce` (only the choppable branch does); `LOCKED` is only removed by the later release. Also `Debounce`, `ChoppingProgress`, `isBeingChopped` leak for destroyed items.
- `legacy/server/Interactions/Objects/ChoppingBoard/ChoppingBoard.lua`: if the player releases and re-presses within 0.3 s the second hold hits `Debounce` and returns while the first loop sees `isBeingChopped = nil` and exits, so the hold chops nothing.
- `legacy/server/Interactions/Objects/ChoppingBoard/ChoppingBoard.lua`: Use is dispatched by a visible object that may differ at release time (client re-targets); see layer 1 stuck `playerLock`.
- `legacy/server/Interactions/Objects/ChoppingBoard/ChoppingBoard.lua`: client progress is simulated independently (`Progress[object]` cache in `ProgressBarHandler.client.lua`), keyed by the food instance and never reset on early release by the server, so client and server progress can desync.
- `legacy/starterPlayerScripts/Visuals/ProgressBarHandler.client.lua`: `ChoppingProgress` with `s = false` (no `d`) leaves the bar visible by design (progress kept), but the stored `Progress[object]` is never cleared when the food is destroyed (leak).
- `legacy/server/Interactions/Objects/ChoppingBoard/ChoppingBoard.lua`: `ToggleUseLock:Fire(choppingBoard, nil)` bypasses the handler's `playerLock`/`useLock` bookkeeping (the player's `playerLock` stays until release).

---

## Layer 3 — Plate + recipes

Checklist

- [ ] Carrying Food + visible Plate (or carrying Plate + visible Food): food is put on the plate; empty plate requires a model `ServerStorage.Assets.Foods.PlatedFoods["plated_<foodName>"]`, otherwise nothing happens — `legacy/server/Interactions/Objects/Plate/Plate.lua`
- [ ] Plate with content + another food: the combined list is looked up in `FoodTree` (order independent, multiset equality); on match the plate shows `plated_<combinationName>`; on no match nothing happens (food stays in hand) — `legacy/server/Interactions/Objects/Plate/Plate.lua`, `legacy/server/Interactions/Objects/Plate/FoodTree.lua`
- [ ] Combination `salad(tomato_lettuce)` = {chopped_tomato, chopped_lettuce}; `salad(mango_cucumber)` = {chopped_cucumber, chopped_mango} — `legacy/server/Interactions/Objects/Plate/FoodTree.lua`
- [ ] Plating clones the plated model into the plate (CanCollide false), moves the food's `FoodList.Frame` icon into the plate's `FoodList`, drops the carried food if it was the player's carried Food, strips welds of the food, destroys the old plated model (if any), welds the new one on top using attribute `yOffset` as increment, and destroys the food — `legacy/server/Interactions/Objects/Plate/Plate.lua`
- [ ] Plate content is stored as a single-element list: `{foodName}` after the first food, `{combinationName}` after a combination — `legacy/server/Interactions/Objects/Plate/Plate.lua`
- [ ] Plating plays the Interact sound to everyone — `legacy/server/Interactions/Objects/Plate/Plate.lua`
- [ ] Plate-on-plate with exactly one plate having content: the two plates are swapped (visible plate is unwelded; the carried plate is put on that spot if the visible plate was on a surface, otherwise dropped; then the visible plate is picked up) — `legacy/server/Interactions/Objects/Plate/Plate.lua`
- [ ] Plate-on-plate where both have content: `mixFood(visible, carried)` merges the visible plate's content into the carried plate if the combined list is a recipe; icons are moved, the source plate is cleared (food destroyed, icons destroyed); no match -> nothing happens — `legacy/server/Interactions/Objects/Plate/Plate.lua`
- [ ] Both plates empty: nothing happens — `legacy/server/Interactions/Objects/Plate/Plate.lua`
- [ ] `Plate.clearPlate` removes the plated model, empties content and deletes all `Frame` children from the plate's `FoodList` — `legacy/server/Interactions/Objects/Plate/Plate.lua`
- [ ] Plate carried/visible with empty hands/nothing: plain pickup/drop with Interact sound — `legacy/server/Interactions/Objects/Plate/Plate.lua`
- [ ] Plate on a counter + carrying food (or reverse): handled via Countertop re-dispatch (layer 1) — `legacy/server/Interactions/Objects/Countertop/Countertop.lua`
- [ ] Interact sound plays when plating succeeds, mixing succeeds, and on plate pickup/drop — `legacy/server/Interactions/Objects/Plate/Plate.lua`
- [ ] CookingTool Interact with carried Plate or visible Plate over a CookingTool is a stub that only prints (cannot ladle soup onto a plate) — `legacy/server/Interactions/Objects/CookingTool/CookingTool.lua`
- [ ] Plate priority 2 (beats Food 1 when carried; loses to Countertop/ChoppingBoard/ServingCounter/PlateTable/Trash 3; loses to CookingTool 2.5) — `legacy/shared/Configs/InteractionConfigs.lua`
- [ ] Food list icons: each food model carries `FoodList/Frame`, which moves to the plate's `FoodList` when plated — `legacy/server/Interactions/Objects/Plate/Plate.lua`

#### Data
- Recipes (FoodTree) — `legacy/server/Interactions/Objects/Plate/FoodTree.lua`:
  - `salad(tomato_lettuce)` = `chopped_tomato` + `chopped_lettuce`
  - `salad(mango_cucumber)` = `chopped_cucumber` + `chopped_mango`
- Level recipe table (orders; see layer 4): ids 1 `chopped_cucumber`, 2 `chopped_mango`, 3 `salad(mango_cucumber)` — `legacy/server/LevelsData/CoOp/Chapter1/LevelData.lua`
- Plated model naming: `plated_<foodName>` / `plated_<recipeName>` under `ServerStorage.Assets.Foods.PlatedFoods`

#### Remotes / bindables
- `Remotes.Sounds.Play` (`"Interact"`)

#### Studio dependencies
- `ServerStorage.Assets.Foods.PlatedFoods` (`plated_*` models with optional attribute `yOffset`)
- Food templates need `FoodList` (child `Frame`); Plate needs `FoodList` (container of Frames, probably a BillboardGui/SurfaceGui) — unclear: exact class of `FoodList`
- `ServerStorage.Assets.Plates.Plate` and `.DirtyPlate`
- Which `plated_*` models exist is unclear (not in repo); only recipes above are known

#### Suspected bugs
- `legacy/server/Interactions/Objects/Plate/Plate.lua`: `plateFood` creates `PlateContent[plate] = {}` before knowing whether plating succeeds; a failed attempt leaves an empty (truthy) table, so the plate-on-plate branch treats it as "has content" (`oCPlateContent and not vOPlateContent`) and `mixFood` can be reached with empty lists.
- `legacy/server/Interactions/Objects/Plate/Plate.lua`: `mixFood` never removes the previous plated model/`objectTopWelder` on the target plate before welding the new one (unlike `plateFood`), leaving the old food model and a second weld on the plate.
- `legacy/server/Interactions/Objects/Plate/Plate.lua`: `ObjectAction.GetValue(player,"ObjectCarried"):GetAttribute(...)` errors if the player carries nothing (e.g. server-originated or counter-driven plating after the player's hands are empty).
- `legacy/server/Interactions/Objects/Plate/Plate.lua`: `clearPlate` calls `food:Destroy()` without checking `isObjectOnTop` returned a part.
- `legacy/server/Interactions/Objects/Plate/Plate.lua`: `module.PlateContent` cache key is not cleaned when a plate is destroyed (served/destroyed plates leak).
- `legacy/server/Interactions/Objects/Plate/Plate.lua`: `food.Parent = nil` is done before `Welds.unweldFromSurface`-like cleanup in some paths; in `plateFood` the manual loop over `food:GetConnectedParts()` runs before reparenting, fine, but `mixFood` swaps order of source clear vs. destination placement (source icons are moved before `clearPlate` deletes frames from the source - ok), unclear if icon duplication occurs.
- `legacy/server/Interactions/Objects/Plate/FoodTree.lua`: recipe `salad(tomato_lettuce)` has no entry in the level's recipe list (orders can never ask for it); `pairs` iteration order makes overlapping recipes ambiguous (none exist today).

---

## Layer 4 — ServingCounter + orders/round

Checklist

- [ ] ServingCounter accepts only a carried Plate that has content; the Plate's first content entry is the dish name passed to order completion; the carried plate is dropped (no re-enable) and destroyed regardless of whether an order matched — `legacy/server/Interactions/Objects/ServingCounter/ServingCounter.lua`
- [ ] Empty plate at a ServingCounter: nothing happens, plate stays in hand — `legacy/server/Interactions/Objects/ServingCounter/ServingCounter.lua`
- [ ] Carrying a loose `chopped_*` Food at a ServingCounter shows "NEEDS PLATE!" above the counter (only that player) — `legacy/server/Interactions/Objects/ServingCounter/ServingCounter.lua`, `legacy/starterPlayerScripts/Visuals/EffectsHandler.client.lua`
- [ ] Any other carried object / empty hands at a ServingCounter: nothing — `legacy/server/Interactions/Objects/ServingCounter/ServingCounter.lua`
- [ ] ServingCounter has priority 3 for interaction and 1.3 for highlight targeting — `legacy/shared/Configs/InteractionConfigs.lua`, `legacy/shared/Configs/VisibilityConfigs.lua`
- [ ] Serving always schedules a new (clean) plate to appear on the team's `PlateTable_<team>` after 1.5 s (dirty if the level sets `enableDirtyPlates`; it's a per-level flag, off in the Chapter1 showcase level that's in the repo), even when no order matched — `legacy/server/MainGame.server.lua`, `legacy/server/Interactions/Objects/PlateTable/PlateTable.lua`
- [ ] Order matching: orders of the player's team are sorted by `orderNum`; the earliest order whose recipe `food_name` equals the plate's dish completes — `legacy/server/MainGame.server.lua`
- [ ] On success: `orderFinish` smoke effect at the counter (all clients), the order timer thread is cancelled, `CompleteOrder(orderNum)` sent to each team member (UI slides the card out), coins +10 for the team — `legacy/server/MainGame.server.lua`
- [ ] On no match: `objError` red highlight flashes on the counter for all clients (6 toggles x 0.05 s) and the server player gets "NO ORDER YET!" above the counter — `legacy/server/MainGame.server.lua`, `legacy/starterPlayerScripts/Visuals/EffectsHandler.client.lua`
- [ ] Coin grant: per-team total updated, each team player gets `UpdateCoin(total)` and a green "+10" popup (`coinNotif` type 1, 1.5 s rise to y 0.624, fade 0.7 s after 0.8 s) — `legacy/server/MainGame.server.lua`, `legacy/starterPlayerScripts/Visuals/EffectsHandler.client.lua`
- [ ] Coin label updates, coin sprite spins (GIF 40 frames, 6 rows x 7 columns, 24 fps), label pops (scale 1.3, green `14,255,14`, 1 s) — `legacy/starterPlayerScripts/UI/CoinDisplayHandler.client.lua`, `legacy/starterPlayerScripts/Visuals/EffectsHandler.client.lua`, `legacy/starterPlayerScripts/EffectsModules/GIFModule.lua`
- [ ] Order sequence strings: digit = spawn that recipe id; `-` = block until the team's active order list is empty (via `orderLock`); `*` doubles `orderDelay`; `/` halves it; after each digit the generator waits `orderDelay` (5 s default) — `legacy/server/MainGame.server.lua`
- [ ] Intro sequence `1212-1233-1323-1323-3333-1231-` plays once, then `loopSequence` `1323-3333-1231-` repeats forever — `legacy/server/LevelsData/CoOp/Chapter1/LevelData.lua`, `legacy/server/MainGame.server.lua`
- [ ] Each order has a server timer = recipe `time` (40 s for ids 1 and 2, 60 s for id 3); on expiry the order is removed with no penalty, no coin change, no server notification to clients (client UI expires itself) — `legacy/server/MainGame.server.lua`
- [ ] When the team's order list becomes empty (completion or expiry) `orderLock` is released so a `-` can proceed — `legacy/server/MainGame.server.lua`
- [ ] AddOrder sends `(recipeId, {orderNum}, serverTick)` to every team member; clients clone the recipe data from the cached recipes (sent once by `CacheOrders`) — `legacy/server/MainGame.server.lua`, `legacy/starterPlayerScripts/UI/OrdersUIHandler.client.lua`
- [ ] Order card UI: small card if total ingredient images <= 2 else big card; cards stack with `LayoutOrder = -orderNum` (newest first); card slides in (0.4 s Back), each step slides in (0.25 s), timer fill tweens to full + yellow `(184,180,46)` over half the remaining time then to empty + red `(163,37,46)` over the other half; remaining time is reduced by the network latency (`timeOffset`) — `legacy/starterPlayerScripts/UI/OrdersUIHandler.client.lua`
- [ ] Failure animation: card shakes 5 times (0.03 scale, 0.05 s tween each way), image tints alternate `(255,124,124)`/white, slides up out in 0.4 s then is destroyed — `legacy/starterPlayerScripts/UI/OrdersUIHandler.client.lua`
- [ ] Success animation: card images tinted `(150,210,166)`, slides up out (0.5 s Back) and is destroyed; UI thread cancelled — `legacy/starterPlayerScripts/UI/OrdersUIHandler.client.lua`
- [ ] Order UI layout positions per slot type (`noprocess1slot`, `process1slot`, `process2slot`, `process3slot`, big/small positions table) — `legacy/starterPlayerScripts/UI/OrdersUIHandler.client.lua`
- [ ] Round setup flow (TESTING start): see layer 9 for the button; server: `loadMap` -> `setTeams` -> load characters -> teleport -> NPC loop -> UI reset/show -> camera -> wait 1 s -> `startGame` (cache recipes, ReadySetGo, wait 3 s, StartTimer(180 s), start order loops per team) — `legacy/server/MainGame.server.lua`
- [ ] ReadySetGo: each of Ready/Set/Go frames visible for 1 s in sequence (client), then the timer starts 3 s after the event — `legacy/starterPlayerScripts/UI/ReadySetGo.client.lua`, `legacy/server/MainGame.server.lua`
- [ ] Round timer: 3:00 (`levelDuration = 180`), label formatted `m:ss`, counts down on the client from `seconds - (travel time)` with initial remainder wait; reset sets the label to the duration — `legacy/starterPlayerScripts/UI/TimerHandler.client.lua`
- [ ] Teams: `teams = 1` in the level; with one team all players are in team 1; with more teams players are shuffled round-robin; team index + position decide spawn `"{team}_spawn{i}"` and color — `legacy/server/MainGame.server.lua`, `legacy/server/LevelsData/CoOp/Chapter1/LevelData.lua`
- [ ] NPC customers: server spawns one every 2 s from a random `Starters` child; see layer 9 for client behavior — `legacy/server/MainGame.server.lua`
- [ ] PlateTable: after an order is served a plate is added to `PlateTable_<team>` after 1.5 s: if the table is empty the plate is welded on; if stack count < 2 the new plate is placed first and the old one stacked above it; if stack >= 2 the top plate is lifted off, the new plate is stacked, then the lifted plate is put back on top (new plate is inserted *under* the top plate) — `legacy/server/Interactions/Objects/PlateTable/PlateTable.lua`
- [ ] PlateTable Interact: top object clean Plate + carrying -> `Plate.Interact` with the highest plate in the stack as target; empty hands -> take the highest plate (unwelded) — `legacy/server/Interactions/Objects/PlateTable/PlateTable.lua`
- [ ] PlateTable Interact with a DirtyPlate on top: empty hands picks it up; carrying a DirtyPlate stacks the carried onto the table's — `legacy/server/Interactions/Objects/PlateTable/PlateTable.lua`

#### Data
- `levelDuration = 180`, `orderDelay = 5`, `teams = 1`, `gameMode = "coOp"`, `sequence`, `loopSequence` — `legacy/server/LevelsData/CoOp/Chapter1/LevelData.lua`
- Recipes (id, name, time s, images): 1 `chopped_cucumber` 40 s (ingredient `rbxassetid://100503567650585`, food `rbxassetid://113432140786725`); 2 `chopped_mango` 40 s (ingredient `rbxassetid://121871090737807`, food `rbxassetid://122023330879408`); 3 `salad(mango_cucumber)` 60 s (two steps: cucumber image then mango image; food `rbxassetid://128533613786186`) — `legacy/server/LevelsData/CoOp/Chapter1/LevelData.lua`
- Coins per completed order = 10; no tips; no failure penalty — `legacy/server/MainGame.server.lua`
- Serve-to-plate-return delay 1.5 s — `legacy/server/MainGame.server.lua`
- Shake: 5 times, magnitude 0.03, 0.05 s — `legacy/starterPlayerScripts/UI/OrdersUIHandler.client.lua`
- ReadySetGo 1 s per frame; timer start 3 s after the event — `legacy/starterPlayerScripts/UI/ReadySetGo.client.lua`, `legacy/server/MainGame.server.lua`
- Smoke effect: 8 directions, spread 2.2-2.7, size multiplier 1.7-2.5 — `legacy/starterPlayerScripts/Visuals/EffectsHandler.client.lua`

#### Remotes / bindables
- `ServerStorage.Bindables.CompleteOrder` (BindableEvent `(player, dish, {servingCounter})`) — fired by ServingCounter, handled in MainGame
- `Remotes.OrderRemotes.CacheOrders` (server -> all), `.AddOrder(id, {orderNum}, serverTick)` (server -> team), `.CompleteOrder(orderNum)` (server -> team), `.ClearOrders` (declared in MainGame, never fired)
- `Remotes.Effects.Effects` (`"orderFinish"`, `"objError"`, `"objectNotif"`, `"coinNotif"`), `Remotes.Effects.ReadySetGo`
- `Remotes.GameInfo.UpdateCoin(total)`, `.Reset(duration)`, `.StartTimer({s, sT})`, `.EndTimer` (client listens; server never fires it)
- `Remotes.Game.SetGameUI(state)`, `Remotes.Camera.SetCamera`
- `Remotes.NPCs.LoadPaths`, `.SpawnNPC`, `.Clear` (declared, never fired)
- `Remotes.Network.TimeSync` (RemoteFunction), `Remotes.TESTING.StartGame`

#### Studio dependencies
- Map `ServerStorage.Maps.CoOp.Chapter1.Level1` containing: `Objects` (incl. `PlateTable_<team>`, ServingCounters), `SpawnPoints` (`1_spawn1`, ...), `NPCWaypoints` (`Starters`, `Fillers`)
- `workspace.$GAME`, `workspace.$Temp`, `workspace.asd3` (camera reference part)
- Client UI: `PlayerGui.OrderList.list`, `ReplicatedStorage.UIs.OrdersUIs.{bigFrame, smallFrame, noprocess1slot, process1slot, process2slot, process3slot}` with `Frame/foodDisplay`, `Frame/stepsDisplay`, `Frame/timer/fill`
- `ReplicatedStorage.Assets.{ObjectNotification, ErrorHighlight, DashTrail(used as smoke)}`

#### Suspected bugs
- `legacy/server/MainGame.server.lua`: `orderSequence` `-` deadlock: it sets `orderLock = true` and waits for something to set it false, but `orderLock` is only set false when an order completes/expires and the list becomes empty. If the team already cleared every order before the generator reaches `-`, nothing will ever release it and no further orders spawn.
- `legacy/server/MainGame.server.lua`: `*` and `/` mutate `loadedLevelData.orderDelay` on the shared required module table; it is never restored (affects later rounds/respawns of the module).
- **Missing in repo; build new** (user doesn't remember whether the full game had it): `legacy/server/MainGame.server.lua` has no round end: `EndTimer` and `ClearOrders` are never fired, the timer just hits 0:00 on clients, orders/NPC loops continue forever, `teamPoints`/`comboMultiplier` caches are unused, and the TESTING start can be fired again (no guard) which would start a second order loop on the same team.
- `legacy/server/MainGame.server.lua`: `setTeams` has `teams = {} or teamOverwrite` (always `{}`), so `teamOverwrite` is ignored and any non-nil overwrite returns with empty teams.
- `legacy/server/MainGame.server.lua`: new plate is queued even when the served plate matched no order (free plate; the wrong dish is destroyed).
- `legacy/server/MainGame.server.lua`: a served dish that matches no order is lost (plate and food destroyed) instead of rejected.
- `legacy/server/MainGame.server.lua`: `CompleteOrderBE` handler uses `findPlayerTeam(player)` returning two values into one variable (ok) but `PlateTable_{team_i}` must exist; `plateContent` is compared against `food_name` verbatim.
- `legacy/starterPlayerScripts/UI/OrdersUIHandler.client.lua`: `AddOrder` mutates the cached recipe table (`data.orderNum`, `data.time -= latency`); `time` shrinks cumulatively by the latency each time the same recipe is ordered; also errors if `ReplicatedStorage:GetAttribute("timeOffset")` is not yet set.
- `legacy/starterPlayerScripts/UI/OrdersUIHandler.client.lua`: the server cancels expired orders silently while the client removes cards by its own timer; they can disagree (client timer starts after the 0.4+0.25*steps animation delay, which is subtracted, so approximately in sync).
- `legacy/starterPlayerScripts/UI/OrdersUIHandler.client.lua`: `completeOrder` calls `task.cancel(orderUIThread[orderNum])` on a thread that may already be dead/finished.
- `legacy/starterPlayerScripts/UI/TimerHandler.client.lua`: `countingDown` is a single shared flag, so a second `StartTimer` spawns a second loop; timer also waits `remainder` before first tick.
- `legacy/server/Interactions/Objects/PlateTable/PlateTable.lua`: `takeHighestPlate(origin, true)` re-parents the *origin* (stack base) to `$GAME` which is meaningless for a stack welded to a table; `DirtyPlate.stackPlates` re-stack order puts the new plate under the previous top.
- `legacy/server/Interactions/Objects/PlateTable/PlateTable.lua`: no cap on stack height.
- `legacy/server/Interactions/Objects/ServingCounter/ServingCounter.lua`: the "NEEDS PLATE!" check is `string.find(name, "chopped_")` only (soup/jam in pots cannot be served at all).

---

## Layer 5 — Stove / Pot / fire

Checklist

- [ ] Stove Interact = Countertop Interact, plus: when a CookingTool with `cookingToolClass` in `{Pot, Pan}` ends up on the stove it is enabled (`ToolEnabled`) and `startCooking` is called; when it is removed, `stopCooking` runs, a `"cancel"` effect fires for all clients, and `ToolEnabled` is cleared — `legacy/server/Interactions/Objects/Stove/Stove.lua`
- [ ] Cooking starts only if the tool has food content, is not already cooking, and is enabled (on a stove or tagged `defaultEnabled`) — `legacy/server/Interactions/Objects/CookingTool/CookingTool.lua`
- [ ] Cooking progress rises 20 per second (100 in 5 s) on the server and is simulated on clients from `{pR, sT, pA}` with latency compensation — `legacy/server/Interactions/Objects/CookingTool/CookingTool.lua`, `legacy/starterPlayerScripts/Visuals/ProgressBarHandler.client.lua`
- [ ] Adding a valid food to a tool (carrying the tool + visible Food, carrying Food + visible tool, or via counter re-dispatch): food is added to the tool's content list; `Pot.Combinations` decides validity — `legacy/server/Interactions/Objects/CookingTool/CookingTool.lua`
- [ ] Pot combinations: `strawberry_jam` = {chopped_strawberry}; `strawberry_jam_salad` = {strawberry_jam, chopped_lettuce}; content becomes `{combination}` — `legacy/server/Interactions/Objects/CookingTool/Classes/Pot.lua`
- [ ] Putting valid food in the pot consumes the food (dropped from hand if it was the carried Food, destroyed) and replaces the pot's visible soup (`SoupModel` clone welded inside at offset `-pot.Size.Y/2`, colored `strawberry_jam` `(171,51,51)`, `strawberry_jam_salad` `(8,186,141)`) — `legacy/server/Interactions/Objects/CookingTool/CookingTool.lua`, `legacy/server/Interactions/Objects/CookingTool/Classes/Pot.lua`
- [ ] Each valid food added deducts 50 progress (min 0) and sends a `changeProgress` to clients, then `startCooking` is attempted again — `legacy/server/Interactions/Objects/CookingTool/CookingTool.lua`
- [ ] Invalid food is not consumed — `legacy/server/Interactions/Objects/CookingTool/CookingTool.lua`
- [ ] At 100 progress the tool is "cooked"; clients show a "cooking finished" popup (TextLabel `Image` fades in 0.3 s after 0.1 s delay, stays 2.5 s, fades out 0.3 s) — `legacy/starterPlayerScripts/Visuals/EffectsHandler.client.lua`
- [ ] Burning warning icon blinks (starts 0.5 s interval, x0.8 each toggle, min 0.05 s) for `AlertDuration = 5 s`, beginning at `0.1 + 2.5 + SafeTime - 2.9 = 4.7 s` after completion on the client — `legacy/starterPlayerScripts/Visuals/EffectsHandler.client.lua`
- [ ] Server burns the tool `SafeTime + AlertDuration = 10 s` after completion (`FireHandler.BurnObject`); the burn timer is cancelled if cooking is stopped (tool lifted off the stove) — `legacy/server/Interactions/Objects/CookingTool/CookingTool.lua`
- [ ] BurnObject only applies to `objectClass` in `{Countertop, ChoppingBoard, CookingTool, Stove}`; a CookingTool burns only if enabled (on a stove) or `defaultEnabled`; an object already holding a `fireValue` is skipped — `legacy/server/CoreFunctions/Utilities/FireHandler.lua`
- [ ] A burning object gets `NumberValue fireValue = 100` and tag `FIRELOCKED`, and a `"fire"` effect is sent to all clients (particles emit at `Emitter.Rate * fireValue/100`, removed when the value is gone) — `legacy/server/CoreFunctions/Utilities/FireHandler.lua`, `legacy/starterPlayerScripts/Visuals/EffectsHandler.client.lua`
- [ ] Fire spread: every 8 s each burning object ignites other `$GAME` children of burnable classes within 5 studs (by `.Position`), unless they already burn, are an un-enabled CookingTool, or have an object on top that is the burning object or any burnable-class object — `legacy/server/CoreFunctions/Utilities/FireHandler.lua`
- [ ] Countertop-like interaction (place/take) is blocked on a countertop tagged `FIRELOCKED` — `legacy/server/Interactions/Objects/Countertop/Countertop.lua`
- [ ] FireExtinguisher: Interact = pick up / drop; Use only works while carrying it — `legacy/server/Interactions/Objects/FireExtinguisher/FireExtinguisher.lua`
- [ ] Extinguisher Use (hold LeftCtrl): foam particle effect on all clients; every 1 s a 3x3 raycast fan (x = -5, 0, 5; y = -3, -4, -5; forward 13.5 studs from the `Emitter` part) hits parts; any hit part within 13.5 studs having a `fireValue` loses 10; at <= 0 the value is destroyed and `FIRELOCKED` removed — `legacy/server/Interactions/Objects/FireExtinguisher/FireExtinguisher.lua`
- [ ] Extinguisher is proximity sensitive: if the player stops holding that object the server stops the Use automatically — `legacy/server/Interactions/InteractionHandler.server.lua`
- [ ] Releasing Use stops the loop and the foam — `legacy/server/Interactions/Objects/FireExtinguisher/FireExtinguisher.lua`
- [ ] Stopping cooking sends `CookingProgress{s=false, d = (progress>=100)}` so a finished bar is removed — `legacy/server/Interactions/Objects/CookingTool/CookingTool.lua`
- [ ] CookingTool priority 2.5, Stove not in priority table (default 1) but its Interact uses Countertop logic — `legacy/shared/Configs/InteractionConfigs.lua`

#### Data
- `ProgressRate = 20`/s, `SafeTime = 5`, `AlertDuration = 5`, `progressDeduction = 50` — `legacy/server/Interactions/Objects/CookingTool/CookingTool.lua`
- `cookingToolClassesAllowed = {"Pot","Pan"}` — `legacy/server/Interactions/Objects/Stove/Stove.lua`; only a `Pot` class module exists (`Pan` has none -> `PutFoodInTool` does nothing for a Pan)
- Fire: `spreadRate = 8 s`, `spreadDistance = 5 studs`, initial `fireValue = 100`, burnables `{Countertop, ChoppingBoard, CookingTool, Stove}` — `legacy/server/CoreFunctions/Utilities/FireHandler.lua`
- Extinguisher: `maxDistance = 13.5`, `deductFire = 10`, tick 1 s — `legacy/server/Interactions/Objects/FireExtinguisher/FireExtinguisher.lua`
- Pot soup colors — `legacy/server/Interactions/Objects/CookingTool/Classes/Pot.lua` (a third color `chopped_lettuce_soup (99,2,235)` is unused)

#### Remotes / bindables
- `Remotes.Effects.ProgressBar` (`"CookingProgress"`, `"changeProgress"`), `Remotes.Effects.Effects` (`"fire"`, `"FEFoam"`, `"cancel"`; client-local `"cookingFinished"`, `"burningWarning"` via `ReplicatedStorage.Bindables.Effects`)
- `ProgressBarHandler.client.lua` fires `Bindables.Effects("cookingFinished", {...})` itself when its local simulation reaches 100

#### Studio dependencies
- Pot/Pan parts: `objectClass = "CookingTool"`, `cookingToolClass`, optional tag `defaultEnabled`
- `ServerStorage.Assets.Foods.SoupModel`; `ReplicatedStorage.Assets.{ProgressBar, CookingFinished, BurningWarning, FireEmitter}` (`FireEmitter` has `ParticleEmitter`)
- FireExtinguisher with child `Emitter` (Part) containing a `ParticleEmitter`; Stove `objectClass = "Stove"`
- Tags `IGNORE`, `FIRELOCKED`, `defaultEnabled`

#### Suspected bugs
- `legacy/server/Interactions/Objects/CookingTool/CookingTool.lua`: `startCooking` returns early when `CookingState` is still true, but the cooking loop leaves `CookingState = true` after reaching 100. Adding food after the pot finished deducts 50 progress but never restarts the loop, so the pot stays at the reduced value and never recooks or re-warns (the already scheduled burn thread still fires).
- `legacy/server/Interactions/Objects/CookingTool/CookingTool.lua`: in `PutFoodInTool` the food is reparented to nil before `Welds.unweldFromSurface(food)`, so for food that was on a counter the weld may remain with a nil `Part1`; unclear: `isObjectOnTop` may then keep returning nil while a stale `objectTopWelder` exists on the counter.
- **Missing in repo; build new** (user doesn't remember whether the full game had it): `legacy/server/Interactions/Objects/CookingTool/CookingTool.lua`: `PlateFood` is a stub (prints only); nothing can be taken out of a pot, so pot dishes (`strawberry_jam*`) can never be served.
- `legacy/server/Interactions/Objects/CookingTool/CookingTool.lua`: `CookingProgress`/`CookedState` are not reset when the tool is lifted off the stove and put back; progress and "cooked" persist. `CookedState` is never read.
- `legacy/server/Interactions/Objects/CookingTool/CookingTool.lua`: the content/progress/state caches are not cleaned up when the pot is destroyed; debug `warn`/`print` calls everywhere.
- `legacy/server/CoreFunctions/Utilities/FireHandler.lua`: `FIRELOCKED` is only checked by Countertop; a burning Pot (which receives the tag) is not blocked from interaction, and fire on a Stove/Countertop only blocks placing/taking on that surface. The dead (commented) first spread loop is left in the file.
- `legacy/server/CoreFunctions/Utilities/FireHandler.lua`: fire never burns/destroys food, never damages players, and a burning object is never reset after extinguishing (cooking state stays "cooked"; may reignite only via the cooking path again).
- `legacy/server/CoreFunctions/Utilities/FireHandler.lua`: `workspace:WaitForChild("$GAME"):GetChildren()` is scanned for objects whose `.Position` is read; Models (no `.Position`) would error - unclear which instances are parented directly under `$GAME`.
- `legacy/server/Interactions/Objects/FireExtinguisher/FireExtinguisher.lua`: `RaycastParams.FilterDescendantsInstances = {GetTagged("IGNORE"), extinguisher:GetDescendants()}` nests arrays; Roblox expects a flat array of Instances (the nested tables are likely ignored or error) - unclear.
- `legacy/server/Interactions/Objects/FireExtinguisher/FireExtinguisher.lua`: the ray only counts the first hit part and `ray.Instance` must be the exact part holding `fireValue`; the `while toolState[...]` loop is not cancelled if the extinguisher is destroyed; `toolState` leaks.
- `legacy/starterPlayerScripts/Visuals/EffectsHandler.client.lua`: `cancel` cancels *all* `effectThreads` (any object), not just that object's; `effectThreads` keyed by object are never cleared; `burningWarning` auto-destroys its UI after 5 s even if the object is not actually burning on the server.
- `legacy/starterPlayerScripts/Visuals/ProgressBarHandler.client.lua`: `Progress[object]` is initialized from `progressAmount` each start and a stale `pA` plus latency pre-advance can show >100; `CookingProgress` bar destroyed locally at 100 independent of the server.
- `legacy/server/Interactions/Objects/Stove/Stove.lua`: the `"cancel"` effect is only sent when the pot leaves via Stove Interact; the pot burning (no stove involvement) path is not covered.

---

## Layer 6 — Sink / dirty plates

Checklist

- [ ] Sink has two interaction sides; the side is decided by which of `WashPartMarker`/`DrainBoard` is closer to the player's HRP — `legacy/server/Interactions/Objects/Sink/Sink.lua`
- [ ] Wash side + carrying a DirtyPlate (stack): the whole stack count is added to the sink's dirty count (max 3 shown), the carried stack is dropped and destroyed, `PlateDisplays/1..3` become visible (Transparency 0) up to the count (hidden = 1) — `legacy/server/Interactions/Objects/Sink/Sink.lua`
- [ ] Drain side + empty hands: picks up the highest clean plate from the drain board (unwelded from the stack); carrying anything blocks it — `legacy/server/Interactions/Objects/Sink/Sink.lua`
- [ ] Washing (hold Use at the wash side with dirty plates > 0): progress +75/s (100 in ~1.33 s), progress persists across early releases, progress bar over `WashPartMarker` — `legacy/server/Interactions/Objects/Sink/Sink.lua`, `legacy/starterPlayerScripts/Visuals/ProgressBarHandler.client.lua`
- [ ] `UseTimeout = 100/75 = 1.33 s` (+0.2 margin): server stops the hold automatically — `legacy/server/Interactions/Objects/Sink/Sink.lua`, `legacy/server/Interactions/InteractionHandler.server.lua`
- [ ] When washing completes: dirty count -1, display plates updated, bar destroyed, a clean `Plate` clone is welded onto the drain board, or stacked on top of the existing drain-board stack — `legacy/server/Interactions/Objects/Sink/Sink.lua`
- [ ] Wash animation: unclear: `Animations.wash` id exists (`rbxassetid://77309393012974`) but no code plays it — `legacy/shared/Animations.lua`
- [ ] Stacking dirty plates: carrying a DirtyPlate and Interacting with a visible DirtyPlate unwelds the visible one and puts it on top of the carried stack — `legacy/server/Interactions/Objects/DirtyPlate/DirtyPlate.lua`
- [ ] Stack helpers: `findHighestStack` walks `objectTopWelder` chain while the object above is Plate/DirtyPlate; `countStack` counts plates in the chain; `takeHighestPlate` unwelds the top plate; `stackPlates` places a plate on top and disables its interaction — `legacy/server/Interactions/Objects/DirtyPlate/DirtyPlate.lua`
- [ ] PlateTable returns dirty plates instead of clean ones when the level sets `enableDirtyPlates` (per-level flag; the Sink/DirtyPlate cycle worked in levels that enable it, per the user) — `legacy/server/Interactions/Objects/PlateTable/PlateTable.lua`, `legacy/server/MainGame.server.lua`
- [ ] A carried Plate dropped on a DirtyPlate/Plate stack on the PlateTable: handled by PlateTable/Plate (layer 4) — `legacy/server/Interactions/Objects/PlateTable/PlateTable.lua`
- [ ] Sink has no highlight priority override (default 1, min distance 6) — `legacy/shared/Configs/VisibilityConfigs.lua`

#### Data
- `progressRate = 75`/s, `UseTimeout = 100/75`, max 3 display plates — `legacy/server/Interactions/Objects/Sink/Sink.lua`

#### Remotes / bindables
- `Remotes.Effects.ProgressBar` (`"washingProgress"`), `Remotes.Interactions.UpdateVisibilityParameters`

#### Studio dependencies
- Sink with children `WashPartMarker`, `DrainBoard`, `PlateDisplays/{1,2,3}`; `objectClass = "Sink"`, `useableClasses` includes Sink
- `ServerStorage.Assets.Plates.{Plate, DirtyPlate}`

#### Suspected bugs
- `legacy/server/Interactions/Objects/Sink/Sink.lua`: `Use` indexes `dirtyPlatesCount[sink] <= 0` and `renderDisplayPlates` indexes it too; `dirtyPlatesCount[sink]` is nil until the first plate is deposited, so holding Use on a sink before any dirty plate was ever put in throws (caught by pcall, but `useLock`/`playerLock` stay set until release).
- `legacy/server/Interactions/Objects/Sink/Sink.lua`: `ToggleInteraction.Set(Plate, false)` disables the *template* in ServerStorage instead of the clone; the first clean plate on an empty drain board is enabled but all later clones inherit `interactionDisabled = true`.
- `legacy/server/Interactions/Objects/Sink/Sink.lua`: if the wash side is empty-handed the Interact does nothing; a Plate/Food at the wash side is ignored; `washingProgress` is not cleared when the dirty count drops to 0 mid-wash (only on completion).
- `legacy/server/Interactions/Objects/Sink/Sink.lua`: displays capped at 3 but the count itself is unbounded; plates beyond 3 are counted but not shown.
- `legacy/server/Interactions/Objects/DirtyPlate/DirtyPlate.lua`: `takeHighestPlate(origin, true)` re-parents `origin` to `$GAME` (odd, only matters if origin was nested), and with `unweld` it uses `Welds.unweldFromSurface(highest)` which walks all connected parts.
- `legacy/server/Interactions/Objects/DirtyPlate/DirtyPlate.lua`: `findHighestStack`/`countStack` stop at the first non-plate object above (e.g. a plated food welded on a clean plate), so a plate holding food is treated as the stack top.
- `legacy/server/Interactions/Objects/DirtyPlate/DirtyPlate.lua`: carrying a DirtyPlate near a Plate (not Dirty) does nothing; mixed stacks are only prevented by class checks in `findHighestStack` (both classes continue the chain).

---

## Layer 7 — Throw

Checklist

- [ ] LeftAlt (or the mobile Throw button) while carrying throws: client sends `ActionRequest("throw", {localCFrame = carried.CFrame})` — `legacy/starterCharacterScripts/Actions/ActionsHandler.client.lua`
- [ ] Only objects with `objectClass == "Food"` can be thrown; the server also requires the client-reported position within 10 studs of the server position of the carried object — `legacy/server/CoreFunctions/Actions/ThrowAction.lua`
- [ ] Throw drops the object without re-enabling interaction (stays un-targetable while in flight) — `legacy/server/CoreFunctions/Actions/ThrowAction.lua`
- [ ] Target point: 30 studs forward from the starting CFrame (holding offset undone), then a 100-stud downward raycast to the floor (no filter); landing CFrame is floor hit + half the object's vertical extent; if no floor is found the 30-stud point itself is used — `legacy/server/CoreFunctions/Actions/Projectile.lua`
- [ ] Flight path: quadratic Bezier start -> midpoint (lerp 0.5 raised by `height = 7`) -> end at `speed = 45` studs/s over total (two-segment length)/45 seconds; the projectile is anchored during flight — `legacy/server/CoreFunctions/Actions/Projectile.lua`
- [ ] Clients animate the projectile locally from `{sCF, eP, s, h, p, sT}`, latency-compensated by `timeOffset`; server fires `"simulate"`, `"fall"`, `"stop"` — `legacy/starterPlayerScripts/Visuals/ProjectileHandler.client.lua`
- [ ] A projectile trail (`ProjectileTrail` with two attachments at x = +-1) is shown during flight and removed 0.5 s after stop — `legacy/starterPlayerScripts/Visuals/EffectsHandler.client.lua`
- [ ] Collision test each server Heartbeat: three raycasts of length 100 from (position + 0.25 up) toward local `(0, y, -100)` with y in {-45, 0, 45}; excludes the thrower's character, the projectile, tags `projectileInteractionIgnore` and `IGNORE`; a hit within 3 studs of the projectile means collision — `legacy/server/CoreFunctions/Actions/Projectile.lua`
- [ ] On collision the projectile falls straight down at `gravity = 20` (studs/s, linear) to the surface below (unfiltered raycast, + half vertical extent) and clients mirror the fall — `legacy/server/CoreFunctions/Actions/Projectile.lua`
- [ ] On completion (`t >= 1` or fall complete) the projectile gets its final CFrame, zero velocity, unanchored, interaction re-enabled, trail removed — `legacy/server/CoreFunctions/Actions/Projectile.lua`
- [ ] If the projectile collided, a downward 100-stud raycast limited to parts tagged `throwInteractable` that have `objectClass` selects a counter; after the fall the server invokes `InteractionRequestFunction("Interact", {oC = projectile, vO = counter})` (player nil) so the thrown food lands on the counter — `legacy/server/CoreFunctions/Actions/Projectile.lua`
- [ ] Without a collision (flight reaches its end) no counter interaction is attempted — `legacy/server/CoreFunctions/Actions/Projectile.lua`
- [ ] Catching: unclear: there is no catch mechanic in the legacy code; a landed Food is just an ordinary pickup-able object
- [ ] Throw works for any carried Food regardless of hands/target; Plates, Pots, Extinguishers, DirtyPlates cannot be thrown — `legacy/server/CoreFunctions/Actions/ThrowAction.lua`
- [ ] `ActionRequest` only handles action `"throw"` — `legacy/server/CoreFunctions/Actions/ActionHandler.server.lua`

#### Data
- `distance = 30`, `height = 7`, `speed = 45`, `gravity = 20`, collision ray length 100, collision radius 3, ray angles y = -45/0/45, `marginOfError = 10` — `legacy/server/CoreFunctions/Actions/Projectile.lua`, `legacy/server/CoreFunctions/Actions/ThrowAction.lua`
- Controls: Throw = LeftAlt — `legacy/shared/Configs/Controls.lua`

#### Remotes / bindables
- `Remotes.Actions.ActionRequest` (client -> server `"throw"`)
- `Remotes.Projectile.SimulateProjectile` (server -> all: `"simulate"`, `"fall"`, `"stop"`)
- `Remotes.Effects.Effects` (`"ProjectileTrail"`)
- `Remotes.Interactions.InteractionRequestFunction` (BindableFunction, server-only)
- `ReplicatedStorage.Bindables.Controls.Throw` (mobile)

#### Studio dependencies
- Tags `throwInteractable` (counters that catch thrown food), `projectileInteractionIgnore`, `IGNORE`
- `ReplicatedStorage.Assets.ProjectileTrail`; Food needs attribute `holdingOffset` (the code reads `holdingOffset.X` without a nil check)

#### Suspected bugs
- `legacy/server/CoreFunctions/Actions/Projectile.lua`: the server never moves the part during flight (it only computes positions and anchors it); only clients move it locally, so other server-side queries see the object at the start position until `stopProjectile`.
- `legacy/server/CoreFunctions/Actions/Projectile.lua`: `CalculateEndpoint` indexes `holdingOffset.X` without `or Vector3.zero` (other helpers default it) -> errors for Food without the attribute.
- `legacy/server/CoreFunctions/Actions/Projectile.lua`: `checkFloor` is entirely commented out and always returns nil; `_testPart` and `print(interactionObject)` are debug leftovers; `interactionFailed` is never non-nil (see layer 1).
- `legacy/server/CoreFunctions/Actions/Projectile.lua`: after the fall completes with a counter present the `InteractionRequestFunction` result is ignored; a thrown food landing on an occupied Food counter will swap-fail silently (layer 1 bug).
- `legacy/server/CoreFunctions/Actions/Projectile.lua`: the Heartbeat simulation has no timeout/cleanup if the projectile is destroyed mid-flight (Trash/Serving cannot reach it, but a server reset could).
- `legacy/server/CoreFunctions/Actions/ThrowAction.lua`: no cooldown/rate limit besides the generic request limiter (the throw remote goes through `ActionHandler`, not `verifyRequest`); `params.localCFrame` is read without checking `params` is a table.
- `legacy/starterCharacterScripts/Actions/ActionsHandler.client.lua`: throw is sent for any carried object (server filters); `Controls.Throw` input and mobile bindable both fire a request each.
- `legacy/starterPlayerScripts/Visuals/ProjectileHandler.client.lua`: `simulation[Projectile]` connections are overwritten (not disconnected) when `fall` starts after `simulate`; `stop` is relied upon to disconnect; `t` starts at `travelTime` (seconds) but is incremented as a 0..1 fraction (unit mismatch).

---

## Layer 8 — Trash

Checklist

- [ ] Trash priority 3, so it handles the interaction even when the carried object has lower priority (Food 1, Plate 2) — `legacy/shared/Configs/InteractionConfigs.lua`
- [ ] Carrying Food + Interact on Trash: carried Food is dropped (no re-enable) and destroyed — `legacy/server/Interactions/Objects/Trash/Trash.lua`
- [ ] Carrying a Plate + Interact on Trash: the plate's contents are cleared (plated food + icons destroyed, content reset) but the plate stays in the player's hands — `legacy/server/Interactions/Objects/Trash/Trash.lua`, `legacy/server/Interactions/Objects/Plate/Plate.lua`
- [ ] Carrying anything else (DirtyPlate, CookingTool, FireExtinguisher) or nothing: nothing happens — `legacy/server/Interactions/Objects/Trash/Trash.lua`
- [ ] No sound/effect is played for Trash — `legacy/server/Interactions/Objects/Trash/Trash.lua`

#### Data
- none beyond priority 3 — `legacy/shared/Configs/InteractionConfigs.lua`

#### Remotes / bindables
- none

#### Studio dependencies
- Trash part with `objectClass = "Trash"` (+ `VISIBLE` tag)

#### Suspected bugs
- `legacy/server/Interactions/Objects/Trash/Trash.lua`: `Plate.clearPlate` is a no-op for an empty plate; a plate that only has an empty `{}` content table (from a failed plate attempt) still passes the `PlateContent[plate]` check and then `food:Destroy()` errors on nil (layer 3 bug).
- `legacy/server/Interactions/Objects/Trash/Trash.lua`: trashing a pot's content is not possible (CookingTool is ignored), so a wrongly filled pot can never be emptied.

---

## Layer 9 — UI / effects / sounds / camera / animations / mobile / character / testing / time sync

Checklist

Character and controls
- [ ] Character is the cloned model from `ServerStorage.Characters` chosen by player name (hardcoded: `St4rqqs`, `Player1`, `Player2`, `idgiveup4ever2touchu` -> `Bill`, `zebronr` -> `Gecko`), parented to workspace and assigned as `player.Character`; `JumpPower = 0` — `legacy/server/CoreFunctions/CharacterLoader.lua`
- [ ] All `StarterCharacterScripts` children are cloned into the character manually — `legacy/server/CoreFunctions/CharacterLoader.lua`
- [ ] Each character BasePart is put in collision group `Character` on `CharacterAdded` — `legacy/server/Initialize/CharacterInitialization.server.lua`
- [ ] Player colors by team/slot (team 1: `(14,0,115)`, `(115,0,2)`, `(0,115,0)`, `(115,107,0)`; team 2: `(165,63,164)`, `(0,113,115)`, `(115,67,0)`, `(111,167,28)`): `plrIndicator` (a ring/decal part welded under HRP, tinted, only for that player) and `charHighlight` (outline color on a `CharacterHighlight` clone, for everyone) — `legacy/shared/Configs/CharacterColors.lua`, `legacy/server/CoreFunctions/CharacterLoader.lua`, `legacy/starterPlayerScripts/Visuals/EffectsHandler.client.lua`
- [ ] 1 s after character load the server fires `LoadAnimations` to the player; the client loads the `Chop` animation track then — `legacy/server/CoreFunctions/CharacterLoader.lua`, `legacy/starterCharacterScripts/Visuals/ActionAnimationsHandler.client.lua`
- [ ] Dash (LeftShift or mobile button): LinearVelocity with `MaxForce = 30000` along the flat look vector at 70 studs/s on the first frame then 42 (`dashStrength*0.6`) each Heartbeat for 0.33 s; local cooldown 0.43 s; plays the dash animation, spawns the local dash trail effect and asks the server to replicate the effect to other players — `legacy/starterCharacterScripts/Actions/PlayerMobility.client.lua`, `legacy/starterCharacterScripts/Actions/ActionsHandler.client.lua`
- [ ] Dash effect for other players: 7 `DashTrail` parts at HRP-3 studs, random Y rotation, sizes lerped from `(9.054,4.201,7.815)` to `(1.94,0.9,1.675)`, grow in 0.2 s then shrink 0.8 s (Exponential), one every 0.05 s, then destroyed — `legacy/starterPlayerScripts/Visuals/EffectsHandler.client.lua`
- [ ] Server replicates only `"dash"` to everyone but the sender, with a nominal 0.30 s per-player cooldown — `legacy/server/EffectsReplicator.server.lua`
- [ ] Animations on the character: run (`115102747595810`) played looped while `Humanoid.Running` speed > 0 and stopped at 0; `pickup` (`77035704035780`) plays looped while `ObjectCarried` is set and stops when cleared; `dash` once; `walk`/`idle`/`chop` loaded but not played here — `legacy/starterCharacterScripts/Animate.client.lua`, `legacy/shared/Animations.lua`
- [ ] Default `WalkSpeed` 16 (no code lowers it; a `LockCharacter` helper exists but is never called) — `legacy/starterCharacterScripts/Animate.client.lua`
- [ ] Mobile: `PlayerGui.MobileControls` is enabled only when `UserInputService.TouchEnabled`; Interact button click -> Interact, Use button down/up -> Use(true/false), Dash and Throw buttons click — `legacy/starterPlayerScripts/Interaction/MobileControlHandler.client.lua`

Game UI
- [ ] On start the UIs `GameInfo`, `Instructions`, `OrderList`, `ReadySetGo` are all disabled; `SetGameUI(true)` enables `GameInfo` and `OrderList` — `legacy/starterPlayerScripts/UI/Initialize.client.lua`
- [ ] `GameInfo.Reset` sets the coin label to "0" and the timer label to the level duration (`m:ss`, fallback 180) — `legacy/starterPlayerScripts/UI/Initialize.client.lua`, `legacy/starterPlayerScripts/UI/TimerHandler.client.lua`
- [ ] Timer counts down each second to 0:00 and then stops; `EndTimer` would stop it (never fired) — `legacy/starterPlayerScripts/UI/TimerHandler.client.lua`
- [ ] ReadySetGo overlay (1 s each, Ready -> Set -> Go) — `legacy/starterPlayerScripts/UI/ReadySetGo.client.lua`
- [ ] Order list UI, coin display, coin popups: see layer 4 — `legacy/starterPlayerScripts/UI/OrdersUIHandler.client.lua`, `legacy/starterPlayerScripts/UI/CoinDisplayHandler.client.lua`
- [ ] `popUpText` effect: label scales up by `sc` and tints to color over `s/2`, then returns; ignored while a previous pop on the same label is running — `legacy/starterPlayerScripts/Visuals/EffectsHandler.client.lua`
- [ ] `objectNotif`: a BillboardGui above the object with a text label that rises for 1.3 s (linear), starts fading at 0.8 s over 0.5 s, then is destroyed — `legacy/starterPlayerScripts/Visuals/EffectsHandler.client.lua`
- [ ] `objError`: `ErrorHighlight` toggled 6 times at 0.05 s intervals then destroyed — `legacy/starterPlayerScripts/Visuals/EffectsHandler.client.lua`
- [ ] `orderFinish`: 8 smoke puffs (`DashTrail` clones, Neon, "Fossil" color) spread outward and fade — `legacy/starterPlayerScripts/Visuals/EffectsHandler.client.lua`
- [ ] Progress bar visuals: `ReplicatedStorage.Assets.ProgressBar` clone parented to the object; bar width = `progress/100 * 2` scale (inside a clip frame) — `legacy/starterPlayerScripts/Visuals/ProgressBarHandler.client.lua`
- [ ] Fire effect: particle emission rate scales with `fireValue/100`; the emitter is removed when the NumberValue disappears — `legacy/starterPlayerScripts/Visuals/EffectsHandler.client.lua`
- [ ] FireExtinguisher foam effect: emits `Emitter.Rate` particles per second while active — `legacy/starterPlayerScripts/Visuals/EffectsHandler.client.lua`

Sounds
- [ ] `Sounds.Play(name, looped)` plays `SoundService.SoundEffects[name]` and sets its `Looped`; `Sounds.Stop(name)` stops it. Server only ever plays `"Interact"` (broadcast); `"Chop"` is played by the client progress bar per chop step — `legacy/starterPlayerScripts/Sounds/SoundEffectsHandler.client.lua`, `legacy/starterPlayerScripts/Visuals/ProgressBarHandler.client.lua`

Camera
- [ ] `FollowUp` camera: scriptable, FOV 50, camera part offset `(20, 25, 0)` from HRP, position lerp `dt*5` on `PostSimulation`, looks at the player; `disable` restores `Follow` type; extra `coOp` (random 1-stud drift tweens, 2 s each) and `coOpLoad` modes exist (unused by the start flow) — `legacy/starterPlayerScripts/Visuals/CustomCamera.client.lua`

NPC customers
- [ ] Server fires `SpawnNPC(starterPart)` every 2 s to all clients; each client clones a random model from `ReplicatedStorage.NPCs` into `workspace.$Temp`, plays walk animation `74792532038099` looped, moves it to the starter then along precomputed `PathfindingService` paths (AgentRadius 2, AgentHeight 6, no jumping): `_direct` starters go straight to the `EndPoint`, others go starter -> random filler -> end point; destroyed 1 s after finishing — `legacy/server/MainGame.server.lua`, `legacy/starterPlayerScripts/Visuals/NPCHandler.client.lua`
- [ ] Paths are computed once at round start on every client from `LoadPaths(NPCWaypoints)` — `legacy/starterPlayerScripts/Visuals/NPCHandler.client.lua`

TESTING start flow
- [ ] Start button `PlayerGui.TESTING.ScreenGui.Start` is visible only for the player named `zebronr`; click fires `Remotes.TESTING.StartGame` and hides the button — `legacy/starterPlayerScripts/TESTING/start.client.lua`
- [ ] Server flow on `StartGame`: load map Chapter1, wait 3 s, `UpdateVisibilityParameters`, set teams, spawn characters, `MoveTo` spawn points, load NPC paths + start NPC spawner, reset game-info UI, show game UI, set FollowUp camera, wait 1 s, `startGame` (see layer 4) — `legacy/server/MainGame.server.lua`

Time sync
- [ ] Client sync: 5 samples (0.1 s apart) per round taking the minimum `offset = serverTick - (receiveTime - rtt/2)`; first 5 rounds spaced 3 s, afterwards 5 samples every 60 s; stored as `ReplicatedStorage` attribute `timeOffset` — `legacy/starterPlayerScripts/Network/TimeSyncHandler.client.lua`
- [ ] Server `Remotes.Network.TimeSync.OnServerInvoke` returns `tick()` — `legacy/server/TimeSyncHandler.server.lua`
- [ ] All timed visuals use `tick() + timeOffset - serverSentTick` for latency compensation (orders, timer, projectile, progress bars) — `legacy/starterPlayerScripts/**`

#### Data
- Colors (above), dash numbers: `dashLength = 0.33`, `dashStrength = 70` (x0.6 after first frame), `dashCooldown = 0.43`, effect cooldown 0.30 — `legacy/starterCharacterScripts/Actions/PlayerMobility.client.lua`, `legacy/server/EffectsReplicator.server.lua`
- Camera: offset `(20,25,0)`, speed 5, FOV 50, `coopCameraLoadDistance = 15` — `legacy/starterPlayerScripts/Visuals/CustomCamera.client.lua`
- Animation ids — `legacy/shared/Animations.lua`; Chop id `74695809221721` in `legacy/starterCharacterScripts/Visuals/ActionAnimationsHandler.client.lua`; NPC walk `74792532038099`
- Coin sprite GIF: 40 frames, 6 rows x 7 columns, 24 fps, 1024x1024 sheet — `legacy/starterPlayerScripts/Visuals/EffectsHandler.client.lua`, `legacy/starterPlayerScripts/EffectsModules/GIFModule.lua`
- Notification colors: coin `(47,255,10)`, tip `(255,207,15)` (tip is never sent)
- Controls table — `legacy/shared/Configs/Controls.lua`

#### Remotes / bindables
- `Remotes.Effects.{Effects, RequestEffectToServer, ProgressBar, ReadySetGo}`; `Remotes.Character.{LoadAnimations, PlayAnimation, StopAnimation}`; `Remotes.Sounds.{Play, Stop}`; `Remotes.Camera.SetCamera(type, cframe, params)`; `Remotes.Game.SetGameUI`; `Remotes.GameInfo.{UpdateCoin, Reset, StartTimer, EndTimer}`; `Remotes.NPCs.{LoadPaths, SpawnNPC, Clear}`; `Remotes.Network.TimeSync`; `Remotes.TESTING.StartGame`; `Remotes.Actions.ActionRequest`
- Client bindables: `ReplicatedStorage.Bindables.PlayerMobility`, `.Effects`, `.Controls.{Interact, Use, Dash, Throw}`

#### Studio dependencies
- `StarterPlayer.StarterCharacterScripts` contents; `ServerStorage.Characters.{Bill, Gecko}`; `ReplicatedStorage.NPCs`
- `PlayerGui`: `GameInfo` (`InfoFrame/{CoinsFrame/{TextLabel, CoinSprite}, TimerFrame/TextLabel}`, `CoinNotification`), `Instructions`, `OrderList/list`, `ReadySetGo/{Ready, Set, Go}`, `MobileControls/{Interact, Use, Dash, Throw}`, `TESTING/ScreenGui/Start`
- `ReplicatedStorage.Assets.{ProjectileTrail, CookingFinished, BurningWarning, FireEmitter, DashTrail, ObjectNotification, ErrorHighlight, PlayerIndicator, CharacterHighlight, VisibilityHighlight, ProgressBar}`
- `SoundService.SoundEffects.{Interact, Chop}`
- Collision group `Character` registered in the place; workspace `$GAME`, `$Temp`, `asd3`

#### Suspected bugs
- `legacy/server/EffectsReplicator.server.lua`: `onCooldown[player]` is never set to true (only cleared by the delay), so the 0.30 s dash cooldown does nothing; any client can flood dash effects to all others.
- `legacy/server/CoreFunctions/CharacterLoader.lua`: `plrchar[player.Name]` is a hardcoded name map; any other player makes `character:Clone()` error; `task.wait(1)` blocks per player (sequential, N seconds); `CharacterColors.Color[team][slot]` is nil beyond 4 players per team.
- `legacy/starterCharacterScripts/Animate.client.lua`: `playAnimation` yields on `track.Stopped:Wait()` (blocks the caller); `animationLock` never set; `preloaded_choppingAnimation` is unused; each respawn re-creates `Animation` children under the script; the duplicate chop id differs from `ActionAnimationsHandler`.
- `legacy/starterCharacterScripts/Actions/PlayerMobility.client.lua`: dash is not blocked while carrying/chopping/washing and ignores Use-lock; `Character`/`HumanoidRootPart` are captured once at script start.
- `legacy/starterPlayerScripts/Visuals/CustomCamera.client.lua`: `CoopCamera` creates a tween when `params.tween` but never plays it; `DisableFollowUp` does not restore camera FOV; `followUp` is not re-entrant (second call leaks the first connection/part); camera cframe argument (`asd3.CFrame`) is ignored for `FollowUp`.
- `legacy/starterPlayerScripts/Visuals/NPCHandler.client.lua`: `calculatePath` ignores path status (errors only if `ComputeAsync` throws), so failed paths yield empty/nil entries and `for _, waypoint in pairs(p)` can error; `MoveToFinished:Wait()` can stall up to its timeout; NPCs spawn forever and `NPCsRemotes.Clear` is never fired.
- `legacy/starterPlayerScripts/Network/TimeSyncHandler.client.lua`: uses the minimum offset sample, not the minimum-RTT sample; consumers read `timeOffset` immediately and error if it is not yet set; `tick()` is used for cross-machine time.
- `legacy/starterPlayerScripts/Interaction/MobileControlHandler.client.lua`: `print(UserInputService.TouchEnabled)` debug; waits for `PlayerGui.MobileControls` forever if absent.
- `legacy/starterPlayerScripts/Visuals/EffectsHandler.client.lua`: `ProjectileTrail` stop path yields 0.5 s and errors if `debris[...]` is nil; `FEFoam` `WaitForChild("Emitter")` can hang; `effects.dash` yields for the whole animation; `orderFinish` uses `math.random(float, float)` (truncated) for spread/size.
- `legacy/starterPlayerScripts/EffectsModules/GIFModule.lua`: `loadFrame`/`playGIF` shrink `ImageRectSize` each frame then overwrite it (dead lines); uses deprecated `wait`.
- `legacy/starterPlayerScripts/TESTING/start.client.lua`, `legacy/server/MainGame.server.lua`: the start flow is gated only on a hardcoded username (client) and has no server-side authorization or re-entry guard — anyone can fire `Remotes.TESTING.StartGame`.
- `legacy/starterPlayerScripts/Sounds/SoundEffectsHandler.client.lua`: `Looped` is set after `Play()`; `Sounds.Stop` is never used by the server.
- `legacy/server/MainGame.server.lua`: `NPCLoop(false)` is never called; `SetCameraRE:FireAllClients("FollowUp", ...)` is sent before `startGame`'s 3 s countdown but characters are not frozen during Ready/Set/Go.
