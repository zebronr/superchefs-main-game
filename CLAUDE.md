# CLAUDE.md

Superchefs Game place (Roblox, Luau, Rojo). See `HANDOFF.md` for current state and next steps.

## Project rules

- Code changes go through the repo and Rojo. Rojo overwrites scripts in Studio.
- Rojo stays connected while working: `rojo serve` runs in the background and Studio picks up every saved file. Don't stop it or ask the user to reconnect unless the server actually died.
- **Scripts** live in the repo and sync through Rojo. Never edit scripts through the Studio MCP.
- **Remotes, bindables, and other non-script instances** (folders, assets, values) are created in Studio through the MCP, so they're visible in the Explorer. Never create them in code: scripts reference them with `WaitForChild`. Tell the user exactly what will be created or changed before each MCP write.
- Prefer token-cheap routes: to read Studio state in bulk, parse a saved place file locally (`Game.rbxl` with the extractor script) instead of reading script by script through the MCP.
- **List every placeholder UI in `docs/PLACEHOLDER-UI.md`.** Whenever Claude (or a subagent) makes a stand-in UI in Studio for the user to remake later, add a row: the instance path, what it's for, the child names and types the code relies on (so a remake keeps working), and the script that uses it. Remove the row once the user has replaced it.
- **Keep `docs/TAGS.md` current.** It lists CollectionService tags and attributes separately. Whenever a tag or attribute is added, removed, renamed, or put on a new kind of instance (in code or through the MCP), update the right part of that file in the same change.
- **All tunables live in `src/shared/Config`**, reached through the `Config` index module; never hardcode gameplay values in scripts.
- **Hard rule, every skill and every effect, no exceptions: the server simulates data, clients render.** The server owns state as data only (states, timestamps, positions, as attributes) and never animates: no tweens, VFX or per-frame visual CFrame moves on the server. Every client renders the effect from that data for all players, and the acting player predicts their own action locally, then hands off to the server timeline (lag-compensated start, blend on confirm, roll back on timeout). The client never waits on the server for its own prediction (movement, visuals, timers run on local time); instead it is corrected when the server's data disagrees (a refusal or interrupt rolls back, a different result replaces the predicted one). Throwing and the Gecko tongue are the reference implementations.
- Commit only when asked.
- **Versioning follows `docs/VERSIONING.md`.** Every player-visible change adds a line under `Unreleased` in `CHANGELOG.md` in the same change. Claude never creates, moves or pushes a version tag without being asked. When asked to cut a release, Claude proposes the version number (minor = milestone, patch = fixes or tuning) and waits for an OK.
- **The legacy port is finished** (2026-10-05). `legacy/` was removed; read it from the tag `legacy-snapshot` when needed. The rule below applies whenever legacy behavior is ported or compared later.
- **Log every legacy bug in `docs/LEGACY-BUGS.md`.** Whenever a port fixes, finds, or deliberately keeps a bug from `legacy/`, add it to that layer's section in the same table format (bug, legacy file, what the rewrite does), continuing the numbering. Dead code goes under "Dead code, not ported"; bugs left for a later layer go under "Still open". Every port spec must tell Codex to do this, and Claude checks the entries against the code during verify: a fix is listed only if the rewrite really fixes it.

## Workflow: Claude plans, Codex writes, Claude verifies

Claude is the main agent. It does not write implementation code itself unless the change is trivial (a few lines).

1. **Plan.** Claude reads the relevant code, decides the design, and writes a precise task spec: files to touch, behavior expected, constraints (`--!strict`, style, parity with legacy), and what "done" means.
2. **Delegate the writing to Codex.** Codex CLI is on PATH (`codex`). Run it non-interactively from the repo root:

   ```bash
   codex exec -s workspace-write -c model_reasoning_effort="medium" -o "<scratchpad>/codex-last.md" "<task spec>"
   ```

   - Pick the reasoning effort per task: `low` for mechanical edits and renames, `medium` for normal features, `high` for tricky logic, cross-file refactors, or bugs that need investigation.
   - Pass long specs through stdin (`codex exec ... - < spec.md`) rather than one huge argument.
   - Split big jobs into focused tasks. Independent tasks can run in parallel; tasks touching the same files run one after another.
   - Codex must not commit, touch Studio, or use the Roblox MCP.
3. **Verify.** Claude reviews the diff (`git diff`) against the spec: correctness, parity with legacy behavior, types, and code style matching the surrounding code. Fix small issues directly; send larger problems back to Codex with specific feedback.
   Typecheck every change (must report zero errors). Use the full `~/.rokit/bin` path, because Aftman shadows `rojo` on PATH. `globalTypes.d.luau` is gitignored; re-download it from `https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau` if it's missing.

   ```bash
   ~/.rokit/bin/rojo sourcemap default.project.json -o sourcemap.json && ~/.rokit/bin/wally-package-types --sourcemap sourcemap.json Packages/ && ~/.rokit/bin/luau-lsp analyze --definitions=@roblox=globalTypes.d.luau --sourcemap=sourcemap.json --ignore="Packages/**" src
   ```
4. **Fallback.** If Codex fails because of quota or rate limits (or is otherwise unavailable), use a Sonnet subagent (`Agent` tool with `model: "sonnet"`) with the same spec, and tell the user Codex ran out.
