# Changelog

Versions are git tags (`vMAJOR.MINOR.PATCH`). The rules are in `docs/VERSIONING.md`.

## Unreleased

- The Gecko's tongue is now textured and wobbling with a sticky tip, effects for firing, sticking, missing a wall and catching, and a trail on the grabbed item.
- Tap once to chop food or wash a whole stack of plates; move or dash to stop early.
- Gecko's Tongue Grab now snaps toward nearby items, spins to lock onto reachable items, shows a striped aim guide, and fires a smoother tongue immediately on release; holding until the limit cancels without firing, and every lock switch restarts that limit.
- Super skills: a skill framework (`SkillService`, `Skills/` on the server and client, a Skill HUD button, key `Q`) and the Gecko's Tongue Grab. Hold Q to aim and spin, release to shoot the tongue over counters and pull an item into your hands; thrown items can be caught by the tongue. In Studio every player is the Gecko (`Character.StudioOverride`).
- Manual serve mode: customers walk in, sit at tables, order, eat, and leave a dirty plate. `Round.ServeMode` toggles it against the legacy serving window.
- Carrying dirty plates, you can stack another one straight from a customer table.
- Clean test map `CoOp/Test/Basic`.
- Crates accept items on their lid, and the item on top is taken first.
- Class identity comes from the `objectClass` attribute, which generates `Class_<name>` tags at server start. Legacy tags were cleaned up.
- Throwing revamp:
  - sphere-sweep collision and a gravity fall;
  - lag compensation and instant local throws;
  - teammates can catch thrown items.
- One `Config` index module for all tunables.
- Food (or a pot) can be plated straight onto the top clean plate on the sink's drain board. A finished wash slides its new plate under a plated one instead of burying it.

## 0.5.0: Legacy (tag `v0.5.0`, commit `a446161`)

The original OOP prototype, as synced from Studio before the rewrite. It has pickup and drop, counters, chopping, plates and recipes, the serving window, the stove, pot cooking, fire and the extinguisher, the sink and dirty plates, throwing, trash, dash, and the round loop. Known bugs are logged in `docs/LEGACY-BUGS.md`.
