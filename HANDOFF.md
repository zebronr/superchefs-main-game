# Handoff: Superchefs refactor (session 1 → 2)

Date: 2026-10-04

## Where we are

The user came back after about a year away. They want to refactor the **Game place** (this repo) into a clean OOP structure first, then work on game design. The Lobby place is separate and teleports players here.

**Update (session 2): the Studio vs repo diff is done. Studio won.** All 60 Studio scripts were extracted from `Downloads/Game.rbxl` and copied into `src/`. That added Trash, mobile controls, sounds, CharacterLoader/Colors and a TESTING start flow, and moved OrdersUIHandler to `UI/`. The changes are staged on `main` but not committed yet. Once they're committed, `src/` matches Studio, so connecting Rojo is safe.

## Rules (from the user)

- Code changes go through the repo and Rojo. Rojo always overwrites the scripts in Studio.
- The Roblox Studio MCP is **read-only**. Ask the user before using it. Never write through it without explicit permission for that specific change.
- Commit only when asked.

## MCP status

- The Studio MCP is registered for this folder in `.mcp.json` (`Roblox_Studio` → `%LOCALAPPDATA%\Roblox\mcp.bat` → `StudioMCP.exe`). A new session should load it after the user approves the server.
- Session 1 could not see the tools, because `.mcp.json` was added mid-session. It drove `StudioMCP.exe` directly over stdio instead. The server responded and listed its tools, but `list_roblox_studios` returned `{"studios":[]}`. **Studio was not connected to the server.**
  - Likely fix: enable or toggle Studio's MCP setting with the place open.
- Read tools to use: `list_roblox_studios` → `get_studio_state` → `search_game_tree` (`datamodel_type: "Edit"`, `instance_type: "BaseScript"`, `max_depth: 10`) → `script_read`. Every call needs a `studio_id`.
- **Fallback (more reliable):** the user saves the place as `superchefs.rbxlx` in the repo root (it's gitignored). Parse the XML, extract every Script, LocalScript and ModuleScript, and diff them against `src/`.

## Diff deliverable

Map Studio paths to repo paths using `default.project.json`:

| Studio | Repo |
|---|---|
| ReplicatedStorage.Modules | src/shared |
| ServerScriptService.Server | src/server |
| ServerStorage.Modules | src/modules (folder doesn't exist) |
| StarterPlayer.StarterPlayerScripts | src/starterPlayerScripts |
| StarterPlayer.StarterCharacterScripts | src/starterCharacterScripts |

Report:
1. Scripts that differ, with a summary of each change.
2. Scripts that exist only in Studio, including ones outside the mapped folders.
3. Scripts that exist only in the repo.

Then the user decides what to bring into git before the refactor branch is created.

## Agreed refactor decisions

- New branch, rebuilt from scratch. Legacy code is reference only.
- **Parity first:** the new code must behave the same as legacy before any design changes.
- Custom lightweight Service/Controller loader with an Init/Start lifecycle. Not Knit.
- Signal+ for in-process signals. Plain RemoteEvents/Functions, **created in Studio through the MCP** (the user wants to see them in the Explorer), never in code. A typed shared `Net` module may wrap them via `WaitForChild`. No networking library for now.
- The user knows Trove, Signal and `--!strict`, but hasn't used Wally.
- Recommended, not yet confirmed by the user:
  - Wally, plus `wally-package-types` for strict types
  - `--!strict`
  - StyLua
  - moving from Aftman to Rokit

## Legacy code analysis (summary)

The code is about 4,200 lines and fairly clean. The main structural problems:

- **State isn't owned by objects.** It lives in module-level tables keyed by Instance (`Cache.RegisterCache`), e.g. `FoodContent[pot]` and `PlateContent[plate]`. Nothing cleans those tables up, so they leak.
- **Inheritance is hidden.** Stove and ChoppingBoard call `Countertop.Interact` first. Pickup/drop boilerplate is duplicated across Food, Plate, DirtyPlate, CookingTool and FireExtinguisher.
- **Priority numbers stand in for polymorphism.** `InteractionConfigs.PriorityLevel` plus `if A and B elseif B and A` chains decide who handles an interaction.
- **Recipes live in three places:** `FoodTree`, `Pot.Combinations` and `LevelData.recipes`. Code also depends on asset naming conventions (`chopped_`, `plated_`).
- **Remotes and bindables are created in Studio,** so the repo can't see them.
- **No boot order.** Scripts rely on `WaitForChild` timing plus `task.wait(5)`. `MainGame` hardcodes the test level, never ends the round, and ignores teleport data.
- `tick()` plus the custom TimeSync can be replaced with `workspace:GetServerTimeNow()`.
- Latent bugs (moot after the rewrite):
  - `teams = {} or teamOverwrite`
  - `Cache.ClearCache` is a no-op
  - Sink disables interaction on the plate *template* instead of the clone
  - CookingTool registers two caches under the same id

## Proposed target layout

```
src/
  shared/      Data/ (Items, Recipes, Stations), Net/, Util/
  server/      init.server.lua, Services/ (Round, Orders, Teams, Interaction, Fire, Teleport data),
               Classes/ Interactable → Items/ (Food, Plate, CookingTool→Pot/Pan, Extinguisher)
                                     → Stations/ (Counter→ChoppingBoard/Stove/Sink/ServingCounter/PlateTable, Dispenser)
  client/      init.client.lua, Controllers/ (Input, Targeting/Highlight, Camera, OrdersUI, Effects, ProgressBars, NPCs)
```

A CollectionService tag maps each tagged Instance to its class object. Interaction works as `station:Interact(player, heldItem)`, which falls through to `heldItem:CombineWith(slotItem)`.

## Next steps

1. **Studio vs repo diff** (above), and resolve the differences with the user.
2. Scaffold the `refactor` branch: tooling, Rojo mapping, loaders, `Net`, `Interactable` base.
3. Write a parity checklist of legacy behaviors.
4. Port in layers:
   1. pickup/drop and Counter
   2. ChoppingBoard
   3. Plate and recipes
   4. ServingCounter and orders/round
   5. Stove, Pot and fire
   6. Sink and dirty plates
   7. throw
   8. UI and effects
5. After parity, move on to game design. The user wants it to grow beyond an Overcooked copy.
