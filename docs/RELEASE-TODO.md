# Release TODO

Work that is deliberately left out of the refactor, but must be done before release.

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
- For testing, `Config.Round.StartButton` (true) shows `StarterGui.StartRound` while waiting, and the round starts when someone presses it. With it false, the round starts when the first client is ready.

Still to do: steps 1 and 3 (the waiting screen, and waiting for the whole teleported party), then turn `StartButton` off for live servers.

## Throw key

Throw is bound to E for Studio testing, because LeftAlt unfocuses the Studio window. Before release, set `Interaction.Controls.Throw` (`src/shared/Config/Interaction.luau`) back to `Enum.KeyCode.LeftAlt`, or pick a final key.

## Studio superskill test keys

`Config.Skills.StudioTestKeys` (R Tongue Grab, T Hustle, Y Deep Freeze, U Order Rush) lets any character use any superskill in Studio with no cooldowns. Live servers ignore it, but set it to nil and remove the code path before release.

## Superskill HUD

The desktop superskill button is hidden (`Config.UI.ShowSkillHud = false`, 2026-10-05). Before release, remake `StarterGui.SkillHUD` (see `docs/PLACEHOLDER-UI.md`) and set the flag back to true, or decide on a different superskill indicator.

## Stand-in superskill sounds

The Deep Freeze sounds in `SoundService.SoundEffects` are free Creator Store picks chosen without listening (2026-10-06): `FreezeStomp` 9113524447 (Body Impact 3), `FreezeWhoosh` 9125611419 (Ice Freeze crackles), `FreezeCrack` 140692325552736 (WX_Ice_Crack_02), `FreezeShatter` 9114856749 (Ice Block Shatter 9). Listen to them and replace any that don't fit the cartoon style before release.
