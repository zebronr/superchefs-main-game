# Handoff: Superchefs refactor

## Config (2026-10-05)

One entry point: `local Config = require(Shared:WaitForChild("Config"))` (`src/shared/Config/init.luau`). Never require the child files directly, and children must never require the index.

- `Config.Character`: movement, dash, camera.
- `Config.Interaction`: stations, cooking, carry, throw (`.Cooking`, `.Throw`).
- `Config.Levels`: level data, per-level customer tuning, `GetCurrent()`.
- `Config.Recipes`: pot and plate combinations, soup colors.
- `Config.Round`: serve mode and round timings.
- `Config.Customers`: customer team, walking, animation, arrival.
- `Config.UI`: patience, ticket and coin colors.

Types are re-exported on the index (`Config.ServeMode`, `Config.Recipe`, `Config.CustomerTuning`, `Config.LevelData`). New tunables go in these files, never hardcoded in scripts.

## Assets layout (2026-10-05)

`ReplicatedStorage.Assets` (client templates):
- `UI`: BurningWarning, CookingFinished, ObjectNotification, ProgressBar (BillboardGuis).
- `Highlights`: CharacterHighlight, ErrorHighlight, VisibilityHighlight.
- `Effects`: DashTrail, FireEmitter, PlayerIndicator, ProjectileTrail.
- `Skills.<SkillName>`: one folder per skill, e.g. `Skills.TongueGrab` (TongueBody, TongueTip, TongueGuide, TongueHighlight, `VFX`).

`ServerStorage.Assets` keeps `Foods` and `Plates`. New templates go in the matching folder.

## Interactions

Chopping boards and sinks auto-use from one tap. Releasing Use does not stop them; moving, dashing, Interact, server distance checks, or completion does. A sink washes its entire dirty stack in one session, resetting progress and the safety timeout after each plate. The extinguisher remains hold-to-spray.

## Serve modes (Window / Manual)

- `src/shared/Config/Round.luau` `ServeMode` picks the mode once at server start: `"Manual"` (default) or `"Window"` (legacy serving window). `Levels.DefaultFor` maps the mode to the level path, and `LevelService` loads `ServerStorage.Maps` by that path. It also sets the `ServeMode` and `LevelPath` attributes on ReplicatedStorage; the client's `Levels.GetCurrent()` reads `LevelPath`.
- Window: unchanged (order sequence, ServingCounter, ambient NPCs) on `CoOp/Chapter1/Level1`.
- Manual: clean test map `CoOp/Test/Basic` (`Maps.CoOp.Test.Basic`: floor, invisible walls, the stations, no decor; the older `Test/Tables` is a Level1 clone and still loads if you point `DefaultFor.Manual` at it) with `CustomerTable_1..3` (each with a `Seat`) and a `CustomerSpawn`. `CustomerService` spawns NPC models from `ReplicatedStorage.NPCs` every `Customers.SpawnInterval`; they walk to a free table, wait to order, you interact to take the order (`OrderService.Open` makes the ticket), cook, then deliver the plate to their table (`CustomerTable` station). They eat, leave a dirty plate (or a clean plate returns to the PlateTable when `EnableDirtyPlates` is false), and walk back. `CustomerController` shows the `UIs.CustomerBubble` (alert or recipe icon, patience bar).
- Barebones on purpose: block tables, no sitting animation, random recipes, single team (team 1), only the dirty plate can be picked up from a table.

---

## Session 3 update (2026-10-04)

- Rename done. `origin` is now `zebronr/superchefs-main-game`, and the old repo is the remote `legacy`. Both branches are pushed.
- Scaffold done and committed on `refactor`: `default.project.json` remap, `.luaurc`, Loader, Net, Binder, BinderService, Interactable, and the client/server entry points. `StarterPlayerScripts.Client` is a child, not the folder itself. The Workspace and Lighting overrides were removed from the project file.
- `luau-lsp` was added to Rokit. The typecheck command is in `CLAUDE.md`, and `src/` reports zero errors.
- Open: the legacy client scripts in Studio's StarterPlayerScripts will still run next to `Client` after a sync. Ask the user whether to delete them via MCP. `ReplicatedStorage.Remotes` doesn't exist yet; create it via MCP when the first remote is needed.
- Later in session 3: `default.project.json` sets `$ignoreUnknownInstances: false` on ServerScriptService, StarterPlayerScripts and StarterCharacterScripts. Rojo is synced into `Game.rbxl`, so Studio now has only the new scripts; the legacy Server Folder and client/character scripts are removed. This change is **uncommitted**. Note that `ReplicatedStorage.Remotes` already exists with the legacy remotes.
- Tags are added via MCP, and the user approved that. Parity rule: fix clear legacy bugs and list each one in the checklist.
- The parity checklist is written: `docs/PARITY.md` has 172 items across the 9 layers, each with data, remotes, Studio dependencies and suspected bugs. Codex hit its usage limit, so Sonnet wrote it. Claude spot-checked the claims against `legacy/`. It is uncommitted.
- Studio (via MCP, user-approved):
  - 60 instances under ServerStorage.Maps/Assets are tagged with their `objectClass` name.
  - `ReplicatedStorage.Remotes.Interact` RemoteEvent was created.
  - Stove/Sink/CookingTool/FireExtinguisher have no ServerStorage templates; they exist only as loose test objects in Workspace.
- Layer 1 is ported but **uncommitted**. Sonnet wrote it because Codex was out of quota; Claude reviewed it. Code is in `src/`: Item, Station, Slot, Counter, FoodContainer, CarryService, InteractionService, LevelService (temporary bootstrap), CharacterService, TargetController, InputController.
- MCP playtest passed for crate pickup, place on counter, take back, floor drop and floor pickup. The 4 `DefObjectOnTop` items load onto their counters.
- Not yet tested in a playtest: same-class swap, floor Food swap, highlight visuals, LOCKED, death drop, rate limit.
- User playtest found nothing worked: players spawned at `Workspace.SpawnLocation`, about 90 studs from the level. Fixes:
  - LevelService now moves each character to `SpawnPoints["1_spawn{i}"]` on spawn, like legacy `teleportPlayers`.
  - CharacterService sets `JumpPower = 0`, like legacy CharacterLoader, so Space doesn't jump.
  - Re-verified by MCP: highlight, crate pickup, floor drop.
- Layers 1–2 committed (`0bec958`). Layer 3 (Plate, `Config/Recipes`, `Item:CanSwapWith`, `Slot.WeldOnTop`) is written by Codex, reviewed, and passed an MCP playtest: chopped mango → plate on a counter, then + cucumber → `salad(mango_cucumber)`, then picked up the full plate. Uncommitted.
  - Not yet playtested: plate-to-plate merge and swap, plating from the floor, plating from a chopping board.
- Legacy bug log: `docs/LEGACY-BUGS.md` (now a CLAUDE.md rule).
- Layer 3 committed (`f997198`). Layer 4 was reduced to interactions only (ServingCounter + PlateTable + `Components/PlateStack`) and the user playtested it. Orders, coins, timer, round start/end, teams and NPCs moved to a later "game loop" layer (user choices: auto-start on join, wrong dish keeps legacy behavior, NPCs in layer 9).
- Layer 4 committed (`3cdd3f6`). Layer 5 (CookingTool, Stove, FireService, FireExtinguisher, EffectsController, cook bar in ProgressController) written by Codex, reviewed, MCP-playtested: strawberry → pot → stove → cooked in 5 s → warning → fire at 10 s → extinguished. Uncommitted. Test objects tagged via MCP (user-approved): `$GAME.Stove`, `$GAME.Pot`, `Workspace.FireExtinguisher`; 6 stale FireEmitter parts removed. Level1 has no stove. Pot → plate stays a stub (user choice).
- Layer 9 (characters, dash, camera with `CameraMode` Fixed/Track, sounds, mobile) and the game loop (RoundService/OrderService/TeamService, map reset, order cards, timer, coins, ReadySetGo, round end + auto-restart, NPCs, effects) are written, reviewed and typechecked, but uncommitted. CookingTool was split back into a base class + `Classes/CookingTools/Pot.luau` subclass, chosen by `cookingToolClass` in BinderService (legacy structure).
- Final parity audit done (2026-10-05): all 172 `docs/PARITY.md` items ticked (142 done, 26 deliberate changes, 2 N/A); the 2 gaps it found were fixed (stray CookingTool targeting priority, Sink interact during a wash). Deferred release work lives in `docs/RELEASE-TODO.md` (missed first ReadySetGo → waiting-for-players screen).
- Studio: the user is working in a backup place; Remotes `Interact`/`Effect`/`Round`, `StarterGui.RoundEnd` and the class tags (60 ServerStorage + `$GAME` Stove/Pot/Sink/Part + Workspace.FireExtinguisher) were recreated there via MCP. Loose legacy test objects in Workspace are intentionally untagged.
- **Next:** commit, then cleanup (delete legacy Studio leftovers: legacy remote folders, `ReplicatedStorage.Modules`, `Bindables`, TESTING; remove `legacy/`; merge `refactor` into `main`), then start building the main game.
- (old) Next: port layer 1 (pickup/drop + Counter). See "After the scaffold" below. Everything below this section is from session 2.

---

Date: 2026-10-04. Read `CLAUDE.md` first: it covers the workflow (Claude plans, Codex writes, Claude verifies) and the Studio/Rojo rules.

## First thing in session 3: finish the rename

The user is renaming the local folder from `superchefs-main-game-legacy` to `superchefs-main-game` between sessions.

1. **Memory:** the old memory lives at `~/.claude/projects/C--Users-Zebron-Documents-Coding-Projects-superchefs-main-game-legacy/memory/`. Session 2 already copied it to the new project key `...-superchefs-main-game/memory/`. Check that it's there. If it isn't, copy it.
2. **New GitHub repo:** the user wants a **new** repo and wants to keep the old one, `zebronr/superchefs-main-game-legacy`, untouched. `gh` isn't installed, so the user creates an empty repo `zebronr/superchefs-main-game` on github.com (no README or license). Then:
   ```bash
   git remote rename origin legacy
   git remote add origin https://github.com/zebronr/superchefs-main-game.git
   git push -u origin main refactor
   ```
   Confirm with the user before pushing.

## State

- **`main`**: commit `a446161` "Sync legacy scripts from Studio". The Studio diff is done and Studio won: all 60 scripts were extracted from `Downloads/Game.rbxl`. `main` matches the live game.
- **`refactor`** (current branch, **uncommitted, staged or in progress**):
  - `src/` was moved to `legacy/` with `git mv`. It's reference only and Rojo doesn't sync it.
  - `aftman.toml` and `sourcemap.json` were deleted. The toolchain is now **Rokit** (`rokit.toml`: rojo 7.4.4, wally 0.3.2, wally-package-types 1.7.0, installed in `~/.rokit/bin`).
  - `wally.toml`: `Signal = alexanderlindholt/signalplus@3.7.2` and `Trove = sleitnick/trove@1.8.0`. `wally install` works, and `Packages/` is gitignored.
  - `servePlaceIds` was removed from `default.project.json`, so Rojo can sync into the local `Downloads/Game.rbxl`. That file is the test place for the refactor. The rest of `default.project.json` still has the **old** mapping and needs rewriting (see below).
  - Commit this when the user agrees. The user approves commits.
- Tooling the user chose: Wally, Rokit, `--!strict` everywhere. They chose **not** to use StyLua or Selene.

## Rules added this session (also in CLAUDE.md and memory)

- **Codex writes code.** Run it with `codex exec -s workspace-write ...`, then verify the diff. If Codex hits its quota, fall back to a Sonnet subagent.
- **Save tokens.** Bulk-read Studio by parsing a saved place file locally. The extractor script was in the session-2 scratchpad, which is gone, so have Codex rewrite it if needed. It's a pure-Python rbxl parser that needs `zstandard`; chunks are zstd-compressed.
- **Remotes, bindables and other non-script instances are created in Studio through the MCP, never in code.** The user wants to see them in the Explorer. Scripts get them with `WaitForChild`. Tell the user what you'll create before each MCP write.

## Next: scaffold (delegate to Codex)

Spec to hand over:
- `default.project.json`:
  - `src/shared` → `ReplicatedStorage.Shared`
  - `Packages` → `ReplicatedStorage.Packages`
  - `src/server` → `ServerScriptService.Server`. Same name as legacy, so Rojo replaces the legacy server scripts.
  - `src/client` → `StarterPlayer.StarterPlayerScripts`
  - `src/character` → `StarterPlayer.StarterCharacterScripts`
  - Legacy `ReplicatedStorage.Modules` stays in Studio as dead modules; delete it later via the MCP with the user's permission.
- `.luaurc`: `languageMode: strict`. Use `.luau` files.
- `src/shared/Util/Loader.luau`: requires every ModuleScript in a folder, calls `Init` on all of them in order, then `Start` on each in its own `task.spawn`. Typed.
- `src/server/init.server.luau`: loads `Services/`. `src/client/init.client.luau`: loads `Controllers/`.
- `src/shared/Net`: a typed lookup of Studio-made remotes under `ReplicatedStorage.Remotes` using `WaitForChild`. It never creates instances.
- `src/server/Classes/Interactable.luau`: base class that owns a Trove, with `Interact(player, heldItem)` and `Destroy`.
- A tag→class binder: CollectionService tag → class, Instance → object, destroyed when the Instance is removed. This fixes the legacy `Cache` leak.
- Typecheck after `wally install` and `rojo sourcemap` + `wally-package-types`.

## After the scaffold

1. Write a parity checklist of legacy behaviors, now including Trash, mobile controls, sounds, CharacterLoader and the TESTING start flow.
2. Port in layers:
   1. pickup/drop + Counter
   2. ChoppingBoard
   3. Plate + recipes
   4. ServingCounter + orders/round
   5. Stove/Pot/fire
   6. Sink/dirty plates
   7. throw
   8. trash
   9. UI/effects/sounds
3. After parity, move on to game design. The user wants it to grow beyond an Overcooked copy.

Legacy architecture notes (state in module-level caches, hidden inheritance, priority numbers, recipes in 3 places) are in `main`'s history of this file (commit `a446161`).

---

## Throwing (revamped 2026-10-05)

- Server (`ThrowService`): the start time is back-dated by half the thrower's ping (capped by `MaxLagCompensation`). Each Heartbeat it sweeps a sphere (`CastRadius`) along the arc with an exclude list built once per throw. A hit, or the end of the arc, is an impact: the item falls straight down with `FallGravity`, and a `throwInteractable` station under the impact point receives it.
- Catch: before the sweep, a player with empty hands, not mid-Use, within `CatchRadius` of the path and facing the item (`CatchFacingDot`) picks it up through `CarryService.Pickup`. If the pickup fails, the item falls instead.
- Client: `InputController.throwHeld` calls `ProjectileController.Predict` for Food. The thrower runs the flight locally, rolls back after `PredictionTimeout` without confirmation, and blends into the server timeline over `ReconcileTime` once the `Projectile` tag and `ThrowStartedAt` arrive. Other clients render from the replicated attributes.
- Tunables: `Interaction.Throw` in `src/shared/Config/Interaction.luau`.

## Super skills (2026-10-05)

- Server: `Services/SkillService` owns the `Skill` remote, per-player state and cooldown attributes. A skill is a module in `src/server/Skills/` returning `Types.Skill` (`Aim`, `Release`, `Interrupt`, `Cancel`, `HoldTimeout`, optional `FindIntercept`/`TakeThrown`); `Skills/TongueGrab` is the Gecko. It talks to the rest through `ThrowService.SetInterceptor` / `SetCharacterHitHandler` and `InteractionService.TakeFor` / `StationOf` / `IsUsing`.
- Client: `Controllers/SkillController` (key, mobile button, HUD, aim flow, rooting) and one module per skill in `src/client/Skills/` (`BeginAim`/`StepAim`/`ReleaseAim`/`EndAim`/`GetDirection`/`GetTarget`/`Setup`). `ReleaseAim` receives whether the player released (rather than timed out). `InputController` skips other actions while `SkillController.IsBusy()`.
- Gecko auto-aims to a nearby reachable item on press. Movement spins a virtual aim yaw; the Gecko turns quickly toward the reachable item closest to it, with a 10-degree switch margin. The guide and highlight follow the lock. Release sends that lock as a hint, which the server validates before targeting; invalid hints fall back to the aim line. Holding until timeout cancels without firing and applies a 0.5-second cooldown. The fired tongue and flying item use shared extend/retract easing.
- The releasing client draws its tongue immediately and hands off when a fresh `TongueStartedAt` arrives. The server backdates extending by capped half-ping and publishes state, timestamps and tip only; every client renders the effect.
- Add a skill: write the server module and the client module, register each in `SkillService` and `SkillController`, map the character in `Config.Skills.ByCharacter`, add its tuning to `Config/Skills.luau`, and add Studio UI/assets (see `docs/PLACEHOLDER-UI.md`).
- Studio instances needed: `Remotes.Skill`, `Assets.Skills.TongueGrab.TongueBody` (Beam), `TongueTip` (MeshPart), `VFX` (Thwip/Splat/Dust/Pop emitters, ItemTrail), `TongueGuide` / `TongueHighlight`, `StarterGui.SkillHUD`, `MobileControls.Skill`. Art sources live in `art/tongue/`: `tongue_tip.py` is a headless Blender script and `textures.py` uses Pillow; outputs are in `art/tongue/out/`. Optional sounds in `SoundService.SoundEffects`: `TongueThwip`, `TonguePop`, `TongueWhiff`.
- `Config.Character.StudioOverride` (default `"Gecko"`): in Studio every player gets that model; set nil to use the name mapping. Live servers ignore it.
- Design: `docs/design/characters/gecko-tongue-grab.md`.

### Instant skills: Hustle, Deep Freeze, Order Rush (2026-10-05, written by Claude, smoke-tested in Studio)
- Press-once skills sit beside the hold-to-aim ones. Server: `Types.InstantSkill` (`RequiresEmptyHands`, `AllowedWhileUsing`, `Use(ctx, startedAt)`, `Cancel`), registered in `SkillService.instantSkills`, used through the `"Use"` action (lag-compensated `startedAt`; any refusal fires `"Interrupted"`). Client: `Skills/InstantSkill` (type + helpers), registered in `SkillController.instantSkills`; press predicts (`Predict`), the server confirms by changing `SkillReadyAt` or `SkillState`, and `"Interrupted"` or `Skills.InstantConfirmTimeout` rolls back (`Rollback`).
- Shared rules in `src/shared/Util/SkillEffects.luau` (Hustle multipliers, frost circles, Order Rush targets/stops/timeline), read by the server and every client.
- `Controllers/SpeedController` now owns the local WalkSpeed/AutoRotate: named multipliers (Hustle, Ice) and named roots (Aim, OrderRush). The aim rooting in `SkillController` uses it.
- Hustle: `HustleUntil` on Bill; `ChoppingBoard`/`Sink` scale by `SkillEffects.WorkMultiplier`.
- Deep Freeze: `Services/FreezeService` scans the circles every `ScanInterval` and calls `CookingTool:Freeze/Unfreeze` and `CustomerService.SetFrozen` (which pauses the order with `OrderService.Pause/Resume`, sending `"UpdateOrder"` with `PausedAt`). `FireService` holds spread from and into circles. Client: frost circle, frozen highlight, ice slide (render step after the default controls, `humanoid:Move`), Penguin speed on own ice.
- Order Rush: server picks targets, stores the chain on the Alien and calls `CustomerService.TakeOrderFor` at each stop's halfway time; the Alien never moves. Clients hide the Alien and draw a UFO (2026-10-05 rework): it drops in and beams the Alien up, flies to each customer and beams a see-through copy of the Alien down and back up, returns, beams the Alien down and zips away. The UFO path is one pure function (`ufoPathAt`); the copy is drawn per part with squash and deterministic glitch. Purely visual from the same attributes; timings in `Config.Skills.OrderRush` (Vanish/Step/Return = 1.1/1.5/1.2 s; per stop the UFO flies 32%, the copy descends 18% so it lands when the order is taken, stands still, then rises during the last 22%), look in `.Visuals`. The local player is rooted for the chain and its camera follows its own UFO (`CameraController.SetFocus`), easing back to the Alien as the UFO leaves.
- "Alien" is a working name: rename the `ByCharacter` key with the model.
- **Temporary test mode:** `Config.Skills.StudioTestKeys` (R Tongue Grab, T Hustle, Y Deep Freeze, U Order Rush) lets any character use any skill in Studio, with no cooldowns (`SkillService` honours the skill name the client sends, and `finish` zeroes the cooldown). Q still uses the character's own skill. Live servers ignore it; set it to nil to turn it off, and remove it before release.
- Smoke test (Studio, solo, character switched via the `CharacterModel` attribute): Hustle gives 20.8 walk speed plus the trail and ends on time; Deep Freeze freezes the Pot (highlight, FrozenAt), draws the circle, gives the Penguin 18.4 on its ice, and everything clears after 6 s; Order Rush hides and roots the Alien, draws afterimages, takes both waiting orders and restores the Alien. No console errors. Not yet tested: the ice slide for another player (needs 2 players), freezing a customer or fire, rollback on refusal.
- **Stand-ins made in Studio (MCP):** `ServerStorage.Characters.Penguin` (dark blue) and `ServerStorage.Characters.Alien` (green) are recoloured clones of Bill with the attribute `StandIn = true`; replace them with the real models. No player is mapped to them in `Config.Character.CharacterModels` yet.
- **Placeholder templates made in Studio (MCP)**, to be restyled to the art style; the code needs these names and classes (each is optional and warned once if missing):
  - `Assets.Skills.Hustle`: `SpeedTrail` (Trail), `Aura` (ParticleEmitter, looping), `Steam` and `Exhale` (ParticleEmitters, Enabled false).
  - `Assets.Skills.DeepFreeze`: `FrostCircle` (BasePart, flat, top face +Y, X/Z footprint scaled to the circle; optional child Decals named `Cracks`, faded in near the end), `FrozenHighlight` (Highlight), `Snow` and `Shatter` (ParticleEmitters).
  - `Assets.Skills.OrderRush`: `Ufo` (a MeshPart or a Model, pivot upright at its centre), `TractorBeam` (BasePart: a cone 1 tall, wide end down, scaled to length by the code), `AfterimageHighlight` (Highlight), `Sparkle` (ParticleEmitter). `Ufo` is `art/ufo/out/Ufo.fbx`, one mesh with the dome baked into `Ufo.png` (TextureID rbxassetid://132208650132118, ~8 studs wide, anchored, no collide/query/touch). `TractorBeam` is `TractorBeam.fbx` (TextureID rbxassetid://122107337116832, SmoothPlastic, Transparency 0.15, size 6×1×6). Re-exporting `Ufo.fbx` changes its UVs, so re-upload `Ufo.png` with it. FBX imports come in 100× too big (the UFO at 200 wide): set `Size = MeshSize * (8 / MeshSize.X)`. After importing, set the mesh's PivotOffset to identity (the UFO came in with a 12-stud offset and drew off screen). Sources: `art/ufo/textures.py` (Pillow) then `art/ufo/ufo.py` (headless Blender). The copy, UFO and beam use the `Afterimage` collision group (registered in Studio, collides with nothing) because the copy's Humanoid forces collisions back on.
- Untested edge cases to watch in playtest: ice feel with the top-down camera (input mapping falls back to `MoveDirection` without the PlayerModule controls), afterimage clones of the character (they copy accessories and anything parented to it), and Order Rush stop heights (afterimages stand at the Alien's height).
