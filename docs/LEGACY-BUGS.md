# Legacy bugs

Bugs found in `legacy/` while porting, and what the rewrite does instead. Grouped by port layer, updated as each layer lands. Open suspicions for later layers stay in `docs/PARITY.md` under "Suspected bugs".

## Layer 1: pickup/drop + Counter

### Fixed

| # | Bug | Where | Rewrite |
|---|---|---|---|
| 1 | Remote args weren't type-checked. A client could send a non-Instance as the target, and the request errored inside the handler's pcall. | `InteractionHandler.server.lua` `verifyRequest` | `InteractionService.onRequest` checks the type of every argument before using it. |
| 2 | `interactLock[obj]` was cleared only on the happy path. If an object's `Interact` errored, that object could never be interacted with again (the "error 2" print). | `InteractionHandler.server.lua` | The lock is released after a `pcall`, so it's cleared even when the interaction errors. |
| 3 | `PickupObject` didn't check whether the player was already carrying something. | `ObjectAction.lua` | `CarryService.Pickup` refuses if the player is already holding an item. |
| 4 | A carried item stayed in `PlayerValues` after death, respawn or leaving, leaving stale state. | `ObjectAction.lua`, `PlayerValues` | `CarryService` drops and clears the held item on death, respawn, leave, and when the item is destroyed. |
| 5 | `Cache` tables never released entries, and `Cache.ClearCache` rebinds a loop variable, so it does nothing. Every object ever touched stayed in memory. | `shared/Cache.lua` | The Binder makes one object per tagged instance and destroys it when the instance leaves workspace. Per-object state lives on the object or its instance. |
| 6 | Collision groups were set once at character load, so parts added later (accessories) were missed. | `CharacterInitialization.server.lua` | `CharacterService` also handles `DescendantAdded`. |
| 7 | `VisibleObjectNode` was updated only when a ProximityNode won. When a normal part won afterwards, the stale node stayed. | `HighlightHandler.client.lua` | `TargetController` resets the node every time the target changes. |
| 8 | `DropObject` set the network owner even on anchored or welded results, which errors. | `ObjectAction.lua` | Partly fixed: the call is wrapped in `pcall`, and the delayed reset is cancelled on re-pickup. A drop placed straight onto a surface still briefly gets the player as network owner. |
| 9 | `verifyRequest` returned `nil` instead of `false` on the rate limit or `playerLock`. | `InteractionHandler.server.lua` | Typed return values (`--!strict`). |

### Dead code, not ported

- `requestInteraction` never returned the module's result, so `InteractionRequestFunction:Invoke` always returned nil and `Projectile.lua`'s `interactionFailed` check never ran.
- Countertop's final `else return true` branch was unreachable.
- `ToggleInteraction.lua` existed twice, once in server and once in shared, with identical contents.
- `Tool.lua` was empty, but `"Tool"` was still listed in `useableClasses`.
- Leftover debug prints: `"interacting?"`, `"error 1/2"`, `"COUNTERTOP INTERACT"`.
- `CookingTool.lua` registered two caches under the same id `CookingTool_FoodContent`. It worked only because each module kept its own local reference. (This one is layer 5; noted here because it's a `Cache` bug.)

### Still open (later layers)

- `projectileInteractionIgnore` was tagged only in Countertop paths. Items placed any other way (chopping result, `DefObjectOnTop`, the swap) never got the tag. → layer 7 (throw).
- A server-originated swap (thrown Food landing on a counter that holds Food) did nothing and left the thrown item disabled. → layer 7.

## Layer 2: ChoppingBoard + Use

### Fixed

| # | Bug | Where | Rewrite |
|---|---|---|---|
| 10 | Holding Use on a non-choppable item set `Debounce[item]` and `LOCKED` but never cleared `Debounce`. That item could never start a chop loop again, and the board stayed locked until release. | `ChoppingBoard.lua` | `StartUse` refuses non-choppable items up front and never locks the board. |
| 11 | Releasing and re-pressing within 0.3 s chopped nothing: the second press hit `Debounce` and returned, while the first loop saw `isBeingChopped = nil` and exited. | `ChoppingBoard.lua` | Each chop session owns its own loop thread, cancelled on stop. No shared flags. |
| 12 | A release went to whatever the client was targeting at release time. Walk away while chopping and release, and `playerLock` stayed set, blocking all your interactions until a later release near something. | `InteractionHandler.server.lua` `functions.Use` | The server remembers what each player is using (`activeUse`) and ignores the release's target. |
| 13 | The UseTimeout and ProximityWatch paths called `main.Use(..., false)` directly and never cleared `playerLock` or `useLock`. | `InteractionHandler.server.lua` | Each session reports its end through `onEnded`, and that clears `activeUse` no matter how it ended. |
| 14 | `ToggleUseLock:Fire(board, nil)` on completion bypassed the handler's bookkeeping, so the player's `playerLock` stayed until they released. | `ChoppingBoard.lua` | Completion ends the session, which unlocks the player right away. |
| 15 | `Debounce`, `ChoppingProgress` and `isBeingChopped` leaked for destroyed items. | `ChoppingBoard.lua` | Progress is the `ChopProgress` attribute on the food itself, so it's gone when the food is. |
| 16 | Client progress was simulated separately (`Progress[object]`), was never reset by the server on early release, and was never cleared when the food was destroyed, so it could desync and leak. | `ProgressBarHandler.client.lua` | The client draws the bar from the replicated `ChopProgress` attribute. Nothing is simulated and there's no cache. |
| 17 | No cleanup if the player died or left mid-chop: the board stayed `LOCKED` and the animation state was left behind. | `ChoppingBoard.lua`, `InteractionHandler.server.lua` | The use is stopped on death, respawn and leave, and when the board or the food is destroyed. |

## Layer 3: Plate + recipes

### Fixed

| # | Bug | Where | Rewrite |
|---|---|---|---|
| 18 | A failed attempt to plate food created an empty, truthy `PlateContent` entry. Later plate interactions treated the plate as full. | `Plate.lua` `plateFood` | `Plate.Accept` changes `Content` only after finding a plated model. |
| 19 | Mixing two plates left the carried plate's old model and weld in place, then added a second model and weld. | `Plate.lua` `mixFood` | `Plate.Accept` destroys the old model and weld before installing the recipe model. |
| 20 | Plating could call `GetAttribute` on a nil carried object when the player had empty hands. | `Plate.lua` `plateFood` | `Plate.Accept` uses the food's own `Holder` and releases it only when held. |
| 21 | Clearing a plate with content but no plated model called `Destroy` on nil. | `Plate.lua` `clearPlate` | `Plate.Clear` checks the model and weld independently and is safe on an empty plate. |
| 22 | Destroyed plates remained in the `PlateContent` cache. | `Plate.lua` | Content lives on the Plate object, which the binder destroys with its instance. |
| 23 | A missing plate `FoodList` made plating wait forever. | `Plate.lua` `plateFood`, `mixFood` | Plating warns and skips icon moves when the destination has no `FoodList`. |
| 24 | Recipe matches depended on `pairs` order if recipes overlapped. | `FoodTree.lua` `CheckCombination` | `Recipes.Find` checks recipe names in sorted order. |
| 25 | A plated model could add mass to its plate and change carry physics. | `Plate.lua` `plateFood`, `mixFood` | Cloned plated models are Massless. |

## Not bugs (checked)

- Dirty plates and the Sink do work. The levels in the repo come from a showcase that turned `enableDirtyPlates` off per level.
- No jumping (`JumpPower = 0`) is intentional: Space is the interact key.
