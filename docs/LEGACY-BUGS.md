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

## Layer 4: ServingCounter + PlateTable

### Fixed

| # | Bug | Where | Rewrite |
|---|---|---|---|
| 26 | `AddPlate` ran 1.5 s after a serve without checking that its table still existed. If the map was unloaded in between (round end), the new plate was cloned into `$GAME` and welded to a dead table. | `PlateTable.lua` `AddPlate` | The delayed callback looks up a live bound table, and `AddPlate` checks again after binding the clone. A plate that can't be placed is destroyed. |

### Notes

- Latent, not reachable in legacy flows: the stack walk used the first `objectTopWelder` child, and a plated model's weld has the same name. Only the top plate can ever hold food, so the walk never misread a stack. `PlateStack` keeps an explicit list anyway.
- `takeHighestPlate(origin, true)` re-parents the bottom plate to `$GAME`, but it's always already there, so it's harmless. It isn't ported.
- The stack has no height cap, matching legacy. Serving consumes one plate and returns one.
- Returned plates go to `PlateTable_1` until the game loop adds teams. The showcase level has dirty plates disabled.
- The showcase PlateTable starts empty, so the only plates in play are the 4 preloaded ones on counters.

## Layer 5: Stove, Pot, fire

### Fixed

| # | Bug | Where | Rewrite |
|---|---|---|---|
| 27 | Adding food after a pot reached 100 deducted progress, but `CookingState` stayed true, so `startCooking` returned without restarting and the old burn timer still fired. | `CookingTool.lua` `startCooking`, `PutFoodInTool` | `CookingTool.Accept` stops the prior run and burn timer, deducts progress, then starts a new run. |
| 28 | Swapping two pots on a stove changed its occupant without enabling the new pot or stopping the old one. The legacy code only compared occupied versus empty. | `Stove.lua` `Interact` | `Stove.Handle` compares the actual slot item before and after the counter interaction. |
| 29 | Cancelling effects for one pot cancelled every object's warning thread, while the thread cache retained entries. | `EffectsHandler.client.lua` `cancel` | Each pot's effects follow its own `CookedAt` attribute and are cleaned up with that instance. |
| 30 | The extinguisher built `RaycastParams.FilterDescendantsInstances` with nested arrays, then called `workspace:Raycast` without passing the params. Its own part or an `IGNORE` part could block the spray. | `FireExtinguisher.lua` `Use` | The raycast receives a flat exclusion list containing `IGNORE` parts, the extinguisher and its descendants, and the user's character. |
| 31 | Cooking content, progress, cooking state, burn delay, enabled state, and extinguisher use state stayed in caches or live loops after an object was destroyed. | `CookingTool.lua`, `FireExtinguisher.lua`, `EffectsHandler.client.lua` | Bound objects own their state and cancel their threads when destroyed; client effects clean up their connections and clones. |
| 32 | Fire spread read `.Position` from every direct child of `$GAME`, which errors if a child is a Model. | `FireHandler.lua` `BurnObject` | `FireService` considers bound burnable BaseParts inside workspace. |
| 33 | The client's cooking bar could grow past 100 after latency compensation or `changeProgress`, and could finish before the server. | `ProgressBarHandler.client.lua` `CookingProgress`, `changeProgress` | The bar derives clamped progress from server attributes and disappears at 100. |

### Notes

- `CookingTool.lua` registered `FoodContent` and `CookingProgress` with the same cache ID. `RegisterCache` replaced the registry entry, but each local retained its own table. No legacy code retrieved that ID, so this had no observed gameplay effect. The rewrite stores content and progress separately on the object.
- The warning still follows the specified legacy timing: it ends at 9.7 s, 0.3 s before a scheduled burn at 10 s. Clearing `CookedAt` cancels it if cooking stops; it does not promise that fire will actually start.
- Fire does not destroy food or hurt players. An extinguished pot stays cooked, and a burning pot can be picked up.
- Taking food out of a pot remains the legacy `PlateFood` stub.

## Layer 6: Sink + dirty plates

### Fixed

| # | Bug | Where | Rewrite |
|---|---|---|---|
| 34 | Using a sink before its first dirty plate deposit compared `nil <= 0` and threw. | `Sink.lua` `Use` | `Sink.DirtyCount` starts at 0; `StartUse` returns without locking when it is empty. |
| 35 | Washing changed `interactionDisabled` on the ServerStorage `Plate` template instead of the new plate. The first clone could remain enabled on the drain board, and later clones inherited the modified template. | `Sink.lua` `Use` | The new clone is disabled before binding and stacking; the template is untouched. |
| 36 | Sink counts, wash state and progress remained in `Cache` after a sink was destroyed; the client also retained washing progress by marker. | `Sink.lua`, `ProgressBarHandler.client.lua` | The bound sink owns its count and session; progress is an attribute on that sink. The client removes its tracked bar and connections when the sink leaves workspace. |

### Dead code, not ported

- `Animations.lua` defined `wash`, but no legacy code played it. The rewrite connects that ID to the wash session through `ActionAnimation`.

### Notes

- The dirty count is unbounded while `PlateDisplays` shows at most three, matching legacy.
- Interacting on the wash side while carrying anything other than a DirtyPlate does nothing, matching legacy.
- The suspected stale `washingProgress` when the count reaches zero mid-wash is not reachable through the legacy paths: only completion decrements the count, and completion first clears progress. It is not listed as a fixed bug.
- The stack walk could stop at a plated food weld, but legacy only plates the top clean plate. It was not a reachable dirty-plate stack bug; `PlateStack` tracks entries explicitly.
- The showcase disabled dirty plates. Level1 enables them in the rewrite so the sink cycle can be tested.

## Not bugs (checked)

- Dirty plates and the Sink do work. The levels in the repo come from a showcase that turned `enableDirtyPlates` off per level.
- No jumping (`JumpPower = 0`) is intentional: Space is the interact key.

## Layer 7: Throwing

### Fixed

| # | Bug | Where | Rewrite |
|---|---|---|---|
| 37 | `CalculateEndpoint` indexed `holdingOffset.X` without a default, so throwing Food without that attribute errored after dropping it. | `Projectile.lua` `CalculateEndpoint` | Shared projectile math reads the offset through `Tags.GetVector3`, which defaults to zero. |
| 38 | The client used `tick() + timeOffset - sentTime` for flight and fall. `timeOffset` came from a separate, approximate sync loop and could still be unset when a throw arrived, causing arithmetic on nil or skewed elapsed time. | `ProjectileHandler.client.lua`, `TimeSyncHandler.client.lua` | Both sides use `workspace:GetServerTimeNow()` and replicated start timestamps. |
| 39 | The client initialized `t` and `f` with elapsed seconds, then added a fraction (`deltaTime / totalTime`) each frame. A late packet started at the wrong point on the path. | `ProjectileHandler.client.lua` `simulate`, `fall` | Elapsed server time is divided by duration before clamping and interpolation. |
| 40 | The throw action read `params.localCFrame` without checking that `params` was a table. A malformed throw request errored in the remote handler. | `ActionHandler.server.lua` | `InteractionService` checks that the Throw argument is a CFrame before routing it. |
| 41 | Countertop added `projectileInteractionIgnore` only on some placement paths. Resting items placed by default setup, chopping, or other Slots could block collision rays. | `Countertop.lua`, `Projectile.lua` `checkCollision` | The collision filter includes every bound Item whose `Surface` is set by `Slot.Place`. |

### Dead code, not ported

- `checkFloor` was entirely commented out and always returned nil.
- `_testPart` was a debug helper, and its only call was commented out.
- The projectile's debug prints were omitted.

### Notes

- The server still computes the flight path without moving the anchored part until completion. Clients animate it locally.
- The landing `Receive` result is ignored, as the legacy bindable result was. A failed occupied-counter interaction leaves the food where it fell, with interaction enabled.
- There is no throw cooldown beyond the shared request limiter.
- Floor and surface rays exclude the projectile itself. The legacy unfiltered rays could intersect its own collider; other floor geometry remains eligible.
- Legacy stored both `simulate` and `fall` connections in `simulation[Projectile]`, but sent `stop` before `fall` in its normal path. The first connection was disconnected before the slot was overwritten, so a live-connection leak was not confirmed. The rewrite uses one render loop per controller.
- Legacy had no `Destroying` cleanup for a projectile, but no ordinary gameplay path could destroy one during flight. Map teardown or external scripts could; the rewrite disconnects immediately if that happens.

## Layer 8: Trash

### Notes

- No new fixes. The trash crash on a plate with content but no plated model is #21 (layer 3); `Plate.Clear` is safe there.
- A pot's content can't be trashed, as in legacy (Trash ignores CookingTools), so a wrongly filled pot can't be emptied. Kept for parity; revisit when balancing gameplay.
- An empty plate, a dirty plate, an extinguisher or empty hands do nothing at the trash, as in legacy.
