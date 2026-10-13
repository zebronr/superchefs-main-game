# Release TODO

Work that is deliberately left out of the refactor, but must be done before release.

## Re-answer the content maturity questionnaire

Before the public release (and again before any release that adds new content), re-answer Roblox's content maturity
questionnaire for the game on the Creator Dashboard, so the rating matches what the game has now. Added 2026-10-13 at
the user's request.

## Waiting-for-players screen before the round starts

Do this once the lobby place is connected to the main game, when players teleport in.

**Problem (found 2026-10-05):**
- `RoundService` starts the Intro as soon as the first player joins.
- A playtest measured the intro firing about 2.5 s before that player's client scripts started running.
- `ReadySetGo(startsAt)` gets queued and reaches `GameUIController` only after `startsAt + 3`. The client skips every frame, so Ready-Set-Go never shows.
- A player who joins during the Intro hits the same problem.
- Legacy never had this: its TESTING start button started the round only after everyone had loaded.

**Planned fix:**
1. Show a "waiting for players" screen while the game loads.
2. Each client reports that it is ready once its controllers are connected, for example with `ClientReady` on the `Round` remote.
3. The server starts the Intro only when all the expected players (the teleported party from the lobby) are ready, or after a timeout.
4. Move the join-time messages (the `Orders` snapshot, `RoundEnd`, `ReadySetGo`) from PlayerAdded to the ready handler. That way a late joiner gets them after its listeners exist.

**Done so far (2026-10-10):**
- Step 2: `src/client/init.client.luau` sends `Ready` on the `Round` remote once every controller's Start has returned (`Loader.Run` now waits for them).
- Step 4: `RoundService.markReady` sends the join-time messages, and round messages go only to ready players.
- For testing, `Config.Round.StartButton` (true) shows START on the loading screen while waiting, and the round starts when someone presses it. With it false, the round starts when the first client is ready.

**Done 2026-10-13:**
- Step 1: the loading screen (`ReplicatedFirst.LoadingGui`, `src/first/LoadingScreen.client.luau`) doubles as the waiting screen; the HUD and mobile controls stay hidden while `Waiting`. Each client sends `Loaded` once the map and assets are in (player attribute `Loaded`), and the screen lists who is ready.
- START is on the loading screen and only `Config.Round.StartHosts` can press it (server checked; anyone in Studio).

- Step 3 (in part): the server starts with no map; START loads it (`RoundState` `Loading`) and the intro begins once every active player has `Loaded`, or after `Config.Round.LoadTimeout`.

Still to do: wait for the whole teleported party (players still teleporting in aren't counted yet), then turn `StartButton` off for live servers.

**Demo-only boot screen (2026-10-13):** the gray Roblox-style `Boot` screen (logo, character picker, START, the
2-second logo spin) and the `/resetgame` command exist only for recording the demo. On release, a server reached from the
lobby skips it: the client goes straight to the loading screen, and the map loads without START. The loading screen must
then take into account players who have already loaded (a late joiner, or a party that loaded before this client), so
the chef list and the "every chef loaded" step start from the real state. Characters come from the lobby, not the
picker. Not built yet.

## Throw key

Throw is bound to E for Studio testing, because LeftAlt unfocuses the Studio window. Before release, set `Interaction.Controls.Throw` (`src/shared/Config/Interaction.luau`) back to `Enum.KeyCode.LeftAlt`, or pick a final key.

## Studio superskill cooldown switch

`Config.Skills.StudioNoCooldown` (false) turns cooldowns off in Studio. Live servers ignore it, but remove it and its code path before release. (The per-skill Studio test keys were removed on 2026-10-13; Q uses the chef's own superskill, and the boot screen's character picker chooses the chef.)

## Superskill HUD

Done 2026-10-11: the superskill card (`GameInfo.InfoFrame.Superskill`, and its copy in `MobileControls.Skill`) replaced `StarterGui.SkillHUD`. The icons in `art/superskill/` are first passes; redraw them if they don't read well in play.

## Stand-in superskill sounds

The Deep Freeze sounds in `SoundService.SoundEffects` are free Creator Store picks chosen without listening (2026-10-06): `FreezeStomp` 9113524447 (Body Impact 3), `FreezeWhoosh` 9125611419 (Ice Freeze crackles), `FreezeCrack` 140692325552736 (WX_Ice_Crack_02), `FreezeShatter` 9114856749 (Ice Block Shatter 9). Listen to them and replace any that don't fit the cartoon style before release.

## Movement check (anti-teleport)

Proposed 2026-10-13, **not built, waiting for the user's review**.

**Problem:** remotes are validated on the server (types, rate limits, interaction range, Gecko tongue range/height/line of sight/aim angle), but every range check uses the character's position, which the client owns. An exploiter can teleport next to a plate, interact and teleport back, or stand somewhere unreachable inside tongue range. Nothing on the server checks movement yet.

**Proposed design:**
- New `MovementGuardService` (server) samples each root at about 10 Hz and tracks only sideways movement. Up and down movement is ignored, so falls and jumps don't count.
- Each player has a **distance allowance that refills over time**: it refills at a generous max speed of about 30 studs/s (the fastest honest player is about 24: walk 16 × Hustle 1.3 × Penguin ice 1.15) and can bank up to about 1.5 s of movement, so a laggy client catching up is covered. Each sample spends the distance moved; moving more than the allowance holds is a strike.
- Honest moves that look like teleports:
  - Dash: `CharacterService.Dash` grants a one-time extra allowance.
  - Phase ending inside a wall: the client `PivotTo`s to open floor or back to its start spot. The server's Phase records the start spot and grants the larger of the pop-out distance and the distance back to the start, plus a margin.
  - Ragdoll / knockback: no checks while ragdolled, plus a short grace after.
  - Respawn, round start, any future server teleport: reset on `CharacterAdded`, plus a `Reset(player)` call.
  - Server lag spikes are covered because the allowance scales with real elapsed time.
- What happens on a strike:
  1. For about 1 s the server ignores that player's interactions, throws and superskill presses, and logs a warning.
  2. After 3 strikes within about 10 s, snap back to the last trusted position.
  3. Never kick.
  Strikes wear off over time.
- Rollout: a Config mode switch `"Off"` / `"Log"` / `"Enforce"`. Start in Log, so playtests only print what would have been flagged; switch to Enforce once there are no honest flags. Not a level setting (it's server security, not a mechanic).
- Build:
  - `src/server/Services/MovementGuardService.luau` with the API `Allow(player, studs)`, `Reset(player)`, `IsTrusted(player)`.
  - `src/shared/Config/MovementGuard.luau`, added to the Config index.
  - Hooks in `CharacterService.Dash`, the server's Phase, the ragdoll path, `InteractionService` and `SkillService`.
- New project rule in CLAUDE.md when built: any feature that moves a character must call `Allow` or `Reset`.

**Open questions for the user:**
- Should Enforce snap the character back after 3 strikes, or only block interactions?
- OK to start in Log mode?

Also worth adding later: a line-of-sight raycast in `InteractionService.isInRange`, so no one can interact through a wall even when standing close to it.
