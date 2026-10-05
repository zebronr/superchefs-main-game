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

Until then, the round auto-starts on join, and the first countdown is missed in Studio playtests.
