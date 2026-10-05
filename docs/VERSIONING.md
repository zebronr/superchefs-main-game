# Versioning

## Format

`MAJOR.MINOR.PATCH`, tagged in git as `vMAJOR.MINOR.PATCH` (annotated tags, e.g. `git tag -a v0.7.0 -m "..."`).

- **0.x (now, before the first public release):**
  - **Minor** (`0.6.0` → `0.7.0`): a milestone. That means a new mode, mechanic or system, a new level set, a big rework, or anything that changes how the game plays.
  - **Patch** (`0.7.0` → `0.7.1`): fixes, tuning changes in `Config`, and small polish. Nothing a player would call "new".
- **1.0.0:** the first public release on Roblox.
- **After 1.0:** a major bump is a big update, such as a season or a reworked core loop. Minor and patch keep the meanings above.

Pre-release builds for playtests can add a suffix: `0.7.0-test.1`, `0.7.0-test.2`, and so on.

## When to bump

- A version is cut when work is committed and merged to `main`. The tag goes on that `main` commit, never on a feature branch.
- Not every commit needs a version. Commits pile up under "Unreleased" until you decide it's a release.
- Committing a feature you're not happy with yet is normal and never gets a tag. Its CHANGELOG line can say "(WIP)" until the feature is done; drop that before cutting the release, or leave the feature out of the release notes if it ships hidden.
- If you're unsure whether it's a minor or a patch, ask: "would I announce this to players?" Yes means minor.

## CHANGELOG

- `CHANGELOG.md` keeps an `Unreleased` section at the top. Every change a player could notice gets a line there in the same change, written for a player or designer rather than about the code. That covers gameplay, UI, levels, controls and tuning.
- Internal refactors, docs and tooling get a line only if they matter later (for example "one `Config` module for all tunables").
- Cutting a release:
  1. Rename `Unreleased` to `## X.Y.Z: <short name> (YYYY-MM-DD)` and start a new empty `Unreleased`.
  2. Commit.
  3. Tag the commit and push it with `git push origin vX.Y.Z`.

## History

| Version | Commit | What |
|---------|--------|------|
| `v0.5.0` | `a446161` | Legacy OOP prototype, final Studio sync before the rewrite. |
| `legacy-snapshot` | `c3cce3f` | Not a version: the last commit with `legacy/` in the tree, kept for reading legacy code. |
