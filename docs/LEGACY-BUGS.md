# Legacy bugs

> The refactor is complete, and `legacy/` was removed from the tree. To read the `legacy/...` paths below, check out the tag `legacy-snapshot`, for example `git show legacy-snapshot:legacy/server/MainGame.server.lua`.

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

- ~~`projectileInteractionIgnore` was tagged only in Countertop paths.~~ Resolved in layer 7 (#41).
- ~~A server-originated swap (thrown Food landing on a counter that holds Food) did nothing and left the thrown item disabled.~~ Resolved in layer 7: a failed landing leaves the food where it fell with interaction enabled (see the layer 7 Notes).

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
- Level1 keeps dirty plates off, as in the showcase: it is the entry level and has no sink.

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
| 42 | Collision used three forward 100-stud rays from the current point and counted a hit within 3 studs. A thin obstacle could be missed or tunneled through between frames, and a wall up to 3 studs ahead triggered the fall before the item reached it. | `Projectile.lua` `checkCollision` | The server sweeps a sphere from the previous step's position to the new one each Heartbeat, so nothing between two frames is skipped, and the item falls from the sphere's contact point at the obstacle. |
| 43 | The exclude list was rebuilt every frame, with tag lookups, in `checkCollision`. | `Projectile.lua` `checkCollision` | The exclude list and `RaycastParams` are built once per throw. |
| 44 | A throw whose arc ended exactly on a catching counter never reached it: only a mid-flight collision looked for a counter. | `Projectile.lua` | The end of the arc is treated like an impact, and a `throwInteractable` station under the endpoint receives the item. |

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

## Layer 9: Character, movement, camera, sounds

### Fixed

| # | Bug | Where | Rewrite |
|---|---|---|---|
| 42 | The nominal dash effect cooldown was never activated because `onCooldown[player]` was never set. | `EffectsReplicator.server.lua` | `CharacterService.Dash` records each accepted request and enforces 0.3 s before setting `DashedAt`. |
| 43 | Loading a character for an unmapped username attempted to clone nil. | `CharacterLoader.lua` | The name map falls back to Bill. |
| 44 | Character loading waited one second before telling the client to load animations. | `CharacterLoader.lua` | Animation tracks load when the local character and Animator are ready, with no fixed delay. |
| 45 | The color lookup returned nil for a player number beyond four. | `CharacterLoader.lua`, `CharacterColors.lua` | Join order fills the lowest free slot from 1 to 4; extra players wrap through those colors. |
| 46 | Dash physics kept the first character and root part after respawn. | `PlayerMobility.client.lua` | Each dash reads the current local character. |
| 47 | Starting FollowUp again leaked its previous camera part and simulation connection. | `CustomCamera.client.lua` `followUp` | One render connection follows the current character, keeping legacy's fixed camera angle. |
| 48 | `playAnimation` waited for `Stopped` even for looping run and pickup tracks. | `Animate.client.lua` | Track playback never waits for a stop event. |
| 49 | The character script recreated Animation instances on every respawn. | `Animate.client.lua` | Animation objects are shared for the client session; each character gets one set of tracks. |
| 50 | Mobile controls waited forever when `MobileControls` was absent. | `MobileControlHandler.client.lua` | The GUI wait times out after ten seconds and warns. |
| 51 | The sound client set `Looped` after `Play()`, so the first play could use the previous loop setting. | `SoundEffectsHandler.client.lua` | The only server requested sound, Interact, is played directly without changing loop state. |
| 52 | The dash trail effect yielded its caller until every part finished. | `EffectsHandler.client.lua` `effects.dash` | Trail creation runs in its own task; tween completion destroys each clone. |

### Dead code, not ported

- `CustomCamera.client.lua`'s `coOp` and `coOpLoad` modes were unused by the start flow.
- `Animate.client.lua`'s `LockCharacter` and `preloaded_choppingAnimation` were unused.
- The walk and idle animation IDs were loaded but never played by `Animate.client.lua`.
- The TimeSync remote and `timeOffset` sampling loop were replaced by `workspace:GetServerTimeNow()` and server timestamps. Its client timing bug is #38.
- `MobileControlHandler.client.lua`'s touch enabled debug print was omitted.

### Notes

- Team assignment remains in the game loop layer. Until then, character colors use team 1.
- Dash is allowed while carrying or using, as in legacy. The server routes Dash separately from `consumeRequest` so its own 0.3 s effect cooldown is enforced without the interaction request limit.
- Countertop played Interact after its lock checks but before all action branches, including branches that did nothing. The rewrite retains that sound timing.
- Food played Interact on entry. Plate played it on pickup, drop, a content swap, and successful plating or mixing. No legacy `PlayRE:FireAllClients("Interact")` call appeared in CookingTool or Sink; neither has an Interact or wash sound here.
- Chop plays locally when a board's `ChopProgress` increases, matching the legacy progress bar's sound per progress step.
- FollowUp starts on character spawn because there is no round start in this layer. RenderStepped updates the camera after simulation for the frame being drawn. There is no camera disable path; legacy `DisableFollowUp` also did not restore the previous FOV.
- StarterCharacterScripts is empty in this project. Its legacy manual clone is replaced by the new client controllers.

### Notes (after the game loop)

- Characters are not frozen during ReadySetGo; legacy did not freeze them either. The missed first countdown on join is tracked in `docs/RELEASE-TODO.md`.

## Game loop (server)

### Fixed

| # | Bug | Where | Rewrite |
|---|---|---|---|
| 53 | `-` always set `orderLock` and waited for a later completion or expiry. If the list was already empty, the generator waited forever. | `MainGame.server.lua` `orderSequence` | `OrderService` checks the team's current orders before waiting, so an empty list advances immediately. |
| 54 | `*` and `/` changed `loadedLevelData.orderDelay` on the shared required level table, carrying the change into later generators or starts. | `MainGame.server.lua` `orderSequence` | Each team's generator keeps its own delay, initialized from config for each round. |
| 55 | `StartGame` had no server re-entry guard, so another request could start a second order loop for the same team. | `MainGame.server.lua` `StartGame`, `startOrders` | `RoundService` starts only from Waiting and invalidates every prior round task with a generation token. `OrderService` also stops its previous generators and timers on each start. |

### Dead code, not ported

- `ClearOrders` and `EndTimer` were declared but never fired. Round reset uses `Orders` with an empty list; the timer follows `RoundEndsAt`.
- `teamPoints` and `comboMultiplier` were registered but never used.
- `CacheOrders` is replaced by shared recipe config.
- The TESTING start button and remote are replaced by automatic start on the first join.

### Notes

- Wrong dishes still destroy the plate and food, return a plate, and show the error effect and notification. Expired orders still have no penalty.
- The server now sends `ExpireOrder` when it removes an order; legacy left card expiry to each client's timer.
- Legacy's `teams = {} or teamOverwrite` ignored an overwrite. The rewrite has no overwrite path, so this is not listed as a fixed bug.
- The beyond-four-player color bug was already fixed as #45; colors now use the player's team and wrap within that team's palette.
- Legacy had no round end. The new timer stops generators and NPCs, shows team coins, and restarts after ten seconds.
- Reset snapshots the children of `$GAME` before the first map clone. It destroys all current children, then clones those hand-placed snapshots and a fresh map. Destroying the old objects lets the Binder clean their state; `FireService` untracks destroyed burning instances.

## Game loop (client)

### Fixed

| # | Bug | Where | Rewrite |
|---|---|---|---|
| 56 | `AddOrder` edited the cached recipe's order number and subtracted latency from its `time`, so repeated orders of the same recipe started with progressively shorter timers. | `OrdersUIHandler.client.lua` `AddOrder` | Cards read immutable shared recipe data and use each order's own server timestamp and duration. |
| 57 | `completeOrder` cancelled an order UI thread that might already have finished, which could error. | `OrdersUIHandler.client.lua` `completeOrder` | Cards cancel only their active tweens and use a generation to stop pending entrance work. |
| 58 | A second `StartTimer` event started another countdown loop because both loops shared only `countingDown`. | `TimerHandler.client.lua` `StartTimer` | One timer view reads replicated round attributes and server time. |
| 59 | `calculatePath` accepted paths with failed status; later movement could iterate nil path entries and error. | `NPCHandler.client.lua` `calculatePath`, `spawnNpc` | Only successful paths are stored and spawned. |
| 60 | The NPC clear remote was declared but never handled or fired, leaving NPCs active across a reset. | `NPCHandler.client.lua`, `MainGame.server.lua` | `ClearNPCs` stops active movement and destroys models; paths are reloaded for the replacement map. |
| 61 | `orderFinish` passed fractional bounds to `math.random`, truncating its intended smoke spread and size multipliers. | `EffectsHandler.client.lua` `orderFinish` | `Random:NextNumber` samples the full fractional ranges. |

### Dead code, not ported

- `GIFModule` multiplied `ImageRectSize` just before replacing it with a fixed size on every frame. Its deprecated `wait` was replaced with frame updates driven by `RenderStepped`.

### Notes

- The server now decides order expiry; the client animates card failure only after `ExpireOrder`.
- `Instructions` remains hidden. The legacy start flow disabled it and never enabled it.
- The order and round timers use `workspace:GetServerTimeNow()`; the `timeOffset` read before initialization was already recorded in #38.
