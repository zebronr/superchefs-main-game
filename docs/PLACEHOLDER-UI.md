# Placeholder UI

Stand-in UIs made by Claude that need a proper remake. When you remake one, keep the names and types in "Code relies on" (or tell Claude to update the script), then delete its row.

| UI | Purpose | Code relies on | Used by | Added |
|----|---------|----------------|---------|-------|
| `ReplicatedStorage.UIs.CustomerBubble` | Bubble over a seated customer: "!" while waiting to order, dish icon while waiting for food, patience bar in both. | `BillboardGui` root; descendants found by name: `Icon` (ImageLabel), `Alert` (GuiObject), `Bar` (GuiObject) with child `Fill` (Frame, width scaled 0–1 and recolored green→yellow→red). | `src/client/Controllers/CustomerController.luau` | 2026-10-05 |
| `StarterGui.SkillHUD` | Super-skill button on the HUD: key letter, cooldown fill, greyed when unavailable. Only shown for characters with a skill, and hidden for now while `Config.UI.ShowSkillHud` is false. | `ScreenGui` root; `Button` (Frame) with children `Key` (TextLabel, code sets its text to the key name) and `Cooldown` (Frame, anchored at the bottom: code sets only the Y scale of `Size` to the remaining cooldown fraction). | `src/client/Controllers/SkillController.luau` | 2026-10-05 |
| `StarterGui.MobileControls.Skill` | Touch button for the super skill: hold to aim, release to fire. | `TextButton` named `Skill` directly under `MobileControls`; child `Cooldown` (Frame, same behavior as above). | `src/client/Controllers/SkillController.luau` | 2026-10-05 |
| `ReplicatedStorage.Assets.Skills.TongueGrab.TongueGuide` | Striped aim guide. | A single `BasePart` stretched along its Z axis by code. Its top-face `SurfaceGui` named `Guide` and its contents are free to remake as long as the stretched part looks right. | `src/client/Skills/TongueGrab.luau` | 2026-10-05 |
| `ReplicatedStorage.Assets.Skills.TongueGrab.TongueHighlight` | Outline on the item the tongue would grab while aiming. | `Highlight`. Code clones it, sets `Adornee` and `Enabled`. | `src/client/Skills/TongueGrab.luau` | 2026-10-05 |
