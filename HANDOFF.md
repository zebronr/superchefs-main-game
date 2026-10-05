# Handoff: Superchefs refactor

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
