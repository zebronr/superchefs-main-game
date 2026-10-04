# CLAUDE.md

Superchefs Game place (Roblox, Luau, Rojo). See `HANDOFF.md` for current state and next steps.

## Project rules

- Code changes go through the repo and Rojo. Rojo overwrites scripts in Studio.
- Rojo stays disconnected until the Studio vs repo diff is resolved (see `HANDOFF.md`).
- **Scripts** live in the repo and sync through Rojo. Never edit scripts through the Studio MCP.
- **Remotes, bindables, and other non-script instances** (folders, assets, values) are created in Studio through the MCP, so they're visible in the Explorer. Never create them in code: scripts reference them with `WaitForChild`. Tell the user exactly what will be created or changed before each MCP write.
- Prefer token-cheap routes: to read Studio state in bulk, parse a saved place file locally (`Game.rbxl` with the extractor script) instead of reading script by script through the MCP.
- Commit only when asked.

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
4. **Fallback.** If Codex fails because of quota or rate limits (or is otherwise unavailable), use a Sonnet subagent (`Agent` tool with `model: "sonnet"`) with the same spec, and tell the user Codex ran out.
