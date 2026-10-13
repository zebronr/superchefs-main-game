# Handoff: Superchefs refactor

## Current state

Developer filming mode (`/cinecam`): see [docs/CINEMATIC-CAMERA.md](docs/CINEMATIC-CAMERA.md) for access, camera keys, and round behavior.

## Burger and the Pan (2026-10-13, typechecked, server logic tested, not play-tested by hand)

- Chain: crate `raw_meat` -> chop -> `chopped_raw_meat` -> pan -> `patty` (shows `PanFoods/patty_raw` while cooking, `PanFoods/patty` once done) -> ladle onto a `bun` (in hand/counter, `Recipes.NoPlate`) or onto a plate holding one. Crate `cheese` -> chop -> `chopped_cheese`. `burger` (bun + patty, order Id 8) + `chopped_cheese` = `cheese_burger`; `bun_cheese` + `patty` = `cheese_burger|2`. `patty` and `chopped_cheese` are `NeedsBase`. Order Id 7 `cheese_burger` (bun, meat with Method "Pan", cheese) and Id 8 `burger` are on level 2 and the test level (renamed 2026-10-13: the old bun_patty state is now `burger`, the old `burger` is `cheese_burger`).
- Code: `CookingTools/Pan` (registered in `BinderService.cookingTools`), `Recipes.Pan`, and a new `CookingTool.Cooked` hook called from `finish()` (the pan swaps raw for cooked there).
- Studio: workspace burger meshes got identity pivots, SmoothPlastic, and the burger set was scaled x1.15 (full burger about 2.4 wide, close to the plate's 3), the cheese wedge x1.3. New `cheese slice` Part (2 x 0.12 x 2) since there was no plain slice. Templates: `RawFoods.bun`/`raw_meat`/`cheese`, `ChoppedFoods.chopped_raw_meat`/`chopped_cheese`, `PlatedFoods.plated_bun`/`plated_burger` (was `plated_bun_patty`)/`plated_bun_cheese`/`plated_cheese_burger` (was `plated_burger`), new folder `PanFoods` (`patty`, `patty_raw`). The originals are still loose in Workspace (`bun`, `buns patty`, `buns cheese`, `fullburger`, `patty`, `raw patty`, `melted cheese`, `cheese`, `raw meat`, `cheese slice`) and can be deleted; `melted cheese` is unused.
- Test/Basic: the stove at z 6 holds a stand-in **Pan** (invisible 2.8 x 0.35 x 2.8 root + welded `Disc` and `Handle`, `cookingToolClass=Pan`) in place of the second pot (its `DefObjectOnTop` points at it). New crates: bun (-180, 10), raw meat (-190, 2) and cheese (-200, 6); the last two replaced countertops. Collision audit clean.
- Icons (re-rendered, see art/icons/HANDOVER.md): burger 84533964238750, bun 90621736229104, meat 98317071199758, cheese 84478614105150, in `Levels.luau`, the new foods' FoodList and the crate lids (lid ImageLabels 135 px on the burger crates, since the new icons carry 14 % padding; the older crates are 100 px). The burger ingredients' FoodList badges show the icon at 1.0× the white circle (the older foods still use 1.2×, sized for icons without padding).
- Follow-up pass (same day, after the user's first test):
  - Art by subagents: `chopped_cheese` is now a CSG slice with holes (1.8 x 0.14 x 1.8, RGB 245/188/68); the patties (`chopped_raw_meat`, `PanFoods.patty`/`patty_raw`) scaled x0.75 to 1.72 wide; the Pan got real visuals (`Bowl` CSG, `Floor`, `HandleNeck`, `HandleGrip`, root now 3.1 x 0.3 x 3.1, bottom unchanged; `Floor` raised 0.03 above the bowl's inner bottom to stop z-fighting; `weldingOffset (0, 45, 0)` so it sits diagonally); the bun texture is toasted (`art/icons/toast_bun.py`, texture 117760325624272 on the bun meshes; patty/melted cheese meshes keep the old atlas 109374707048276).
  - Cooking tools keep ingredient icons: a food going into a pot or pan moves its FoodList frames onto the tool, ladling moves them onto the food or plate, `Empty` clears them (`CookingTool.moveIcons`/`clearIcons`). The patty's meat icon now reaches the burger. Verified by script.
  - Crates: items placed on a crate used to sit on the crate body, sunk into the separate lid part (a pot showed the lid inside it). `Slot.Place` now lifts by the station's `surfaceOffset` attribute; all 17 FoodContainers in `ServerStorage.Maps` have `surfaceOffset = 0.252`.
  - "NEEDS PLATE!" now shows for any held food at the serving counter (was only `chopped_*`) and at a customer table waiting for food (was silent).
- Tested by script on the server (the real classes, no binder): meat into pan, raw pan refuses the bun, cooked swap, pan onto bun, cheese onto bun_patty (now `burger`), cheese burger onto plate, cheese refused on an empty plate, bun + cheese on a plate then pan onto it. Not yet tested by hand: chopping the meat and cheese, the pan on the stove heating, serving the order, the plated model placement.

## Bear: Bear Toss and Sturdy (2026-10-13, typechecked, not play-tested with 2 players)

- Design: docs/design/characters/bear-toss.md.
- Shared: `Util/TossPath` (arc, landing search and checks, toss state from attributes, `Busy`), `Util/OpenFloor` (fit + floor check, shared with Phase's pop-out). `SkillEffects.Sturdy`.
- Server `Skills/BearToss` (aimed `Types.Skill`): Aim grabs the nearest free teammate (`TossHeldBy`) or catches a dasher in reach (`CustomerService.CatchRunner`, `CaughtByToss`); Release gets the landing root position as the "direction", checks it (`TossPath.Valid`) and writes the flight. Invalid or missing = put down with `CancelCooldown`.
- Client `Skills/BearToss`: ring aimed with the movement keys (no mouse aim in the game), auto-throws just before the hold limit and releases at once for a dasher (new optional `ClientSkill.AutoRelease` and `CanAim` hooks in `SkillController`). The held/thrown player's own client pins and carries its hidden character upright (PlatformStand, rooted "Toss") until `TossPath.EndsAt` (landing + `GetUpTime`). Every client hides the real character and its held item and draws a ragdoll copy instead (`Util/RagdollCopy`, shared with `RagdollController`; collision group `Ragdoll`): anchored torso CFramed from the data while held (tipped back, squirming) and flying (tumbling), let go at the landing with the arc's fall speed, faded out at the get-up. The aim guide is a row of short straight Beams (clones of `ArcBeam`, one per dash, laid along `TossPath.Position` and marching toward the landing; `Visuals.GuideDash`/`GuideGap`/`GuideSpeed`), styled like the Gecko's TongueGuide. One long curved Beam was tried first and went edge-on from the side. Ring and guide glide (`Visuals.AimSmoothing`).
- Sturdy: `SkillService.interrupt` skips sturdy characters, `CharacterService.setGroup` makes their parts `SturdyDensity` heavy, `DeepFreeze.stepIce` doesn't slide them.
- Held/thrown players are blocked in `InteractionService`, `SkillService` aim/use and `SkillController.IsBusy` (dash, interact, throw, superskill) and can't catch throws.
- To test: needs two players (Studio Test > 2 players). Check the lift, ring, flight over a counter, landing dust, the put-down, a dasher catch (level with `EnableTableCash`), and that the Bear isn't pushed.

## Bitmap UI font and new progress bar (2026-10-11, not play-tested)

- `BitmapText` tag + `BitmapTextController`: tagged TextLabels/TextButtons are drawn in Jersey 15 (14 labels tagged in Studio, list in `docs/TAGS.md`). `BitmapFont.SetTransparency` added.
- `Assets.UI.ProgressBar` rebuilt via MCP as Figma option B without the food icon (structure in `docs/UI-GUIDE.md`, placeholder row added). `ProgressController` draws fill / done (check + pop) / burn warning (orange drain, `!`, glow, shake) from `CookedAt`, `CookSafeTime`, `CookAlertDuration`, honoring `FrozenAt`; hides while `Fire` > 0. Tunables in `Config.UI.Progress`. `EffectsController` lost the old `CookingFinished` / `BurningWarning` popups (deleted from `Assets.UI`); it keeps the fire.
- Off-plate combining (not play-tested): `Recipes.NoPlate` lists results that combine without a plate (the sandwiches). `Classes/Food.luau` (Food tag binder) hides the food's part and welds `PlatedFoods.plated_<result>` in its place, renames it and sets `Combined`; `CookingTool.Accept` ladles a finished pot onto such a food. Everything else still needs a plate.
- Particles hard rule (CLAUDE.md): `src/client/Util/Particles.luau` `Stream`/`Stop` feed disabled emitters with `:Emit()`. Deep Freeze mist and snowfall, the Hustle aura and customer sweat use it; `EffectsController` adopts any emitter left Enabled in Workspace (stove burners).
- Burn smoke: `EffectsController.updateSmoke` clones `Assets.Effects.BurnSmoke` (Attachment + disabled ParticleEmitter `Smoke`, round grey puffs like the combo fire UI's smoke, `art/smoke/Circle.png`; look on the template) onto a pot while it cooks (light steam), in its burn warning or on fire; rate, color and size from `Config.UI.BurnSmoke`, stops while frozen.
- Tongue `DeadZone` lowered to 2.
- Studio superskill cooldowns: `StudioTestKeys` no longer zeroes cooldowns; that's now its own switch `Config.Skills.StudioNoCooldown` (false), so the card's refill ring shows in Studio.
- The user must save the place in Studio (template, tags, crates, stove links).

## Sandwiches and pot plating (2026-10-11, user play-testing)

- Gameplay (done, typechecked, not play-tested): `Plate.AddContent(name)` combines food or a pot's content; `CookingTool.Accept` ladles a cooked (Progress 100, not `Burned`, not burning) pot onto a plate and `Empty()`s the pot; the trash empties a held pot that isn't burning. Recipes: Pot `peanut_butter` (chopped_peanut); Combinations `jam_sandwich`, `peanut_butter_sandwich`, `pbj_sandwich` (+ `pbj_sandwich|2`: a `|n` suffix lets one result have several ways). `Recipes.NeedsBase` (the spreads) can't go on an empty plate, only onto bread. Orders 4-6 are on the `CoOp/Test/*` maps only (`levelTest.Recipes`).
- Art: the templates use the user's own imported models (the user found Claude's low-poly ones too dark). `art/bread/bread.py` (headless Blender) is unused except for the order icons it rendered (uploaded: bread 76745084892041, strawberry 88480103207997, peanut 95741673925949, jam sandwich 89481326698230, PB sandwich 113255624436887, PBJ 128987833845031); these are renders of the darker models and could be redone from the user's models. The original high-poly imports are still in Workspace.
- Studio done: `RawFoods.strawberry` / `peanut` / `bread`, `ChoppedFoods.chopped_bread`, `PlatedFoods.plated_chopped_bread`, `plated_jam_sandwich`, `plated_peanut_butter_sandwich`, `plated_pbj_sandwich` (root = lowest slice, `Layer1..` welded). Test/Basic has a column at x -180 with crates (bread, strawberry, peanut) and two stoves with pots (`PreloadedPickupables`). Six preloaded plates on the test maps moved to the `Pickupable` group. Test/Tables got bread, strawberry and peanut crates too (replacing the countertops at x -181/-185/-189, z -23), but it has no stove or pot. Crate lid icons on both test maps use the uploaded food icons. Pots on stoves: the Test/Basic stoves now link their pots through `DefObjectOnTop` (they had a stale, empty `DefaultTool` value, so the pots weren't on the stoves at all), and `Station.Preloaded` lets the stove switch on a pot the map places, which `Slot:Place` used to skip (the user saw cooking start only after lifting and re-placing the pot).
- Play-tested by Claude: crate pickup, board drop and chopping the loaf into `chopped_bread` work. The user is testing the rest (slice onto plate, strawberry/peanut into the pot, ladling, PB&J, NeedsBase refusal, trash emptying a pot, plated model placement). Note for scripted tests: plates on counters have `interactionDisabled`; target the counter.

## Order plates, combo fire, HUD move (2026-10-11)

- Design: Figma file `OjoXSKRZfjnwqdzddRlGgZ`, sections "Order UI: B plate rings, top-right row + animations" and "Order UI: B with cooking steps". Sprites (ring, glow, check, pot, pan, flame, spark) come from `art/orders/make_icons.py`; ids are in the Studio templates and `Config.UI.Orders.MethodIcons`.
- `OrdersController` (rewritten) clones `UIs.OrdersUIs.PlateOrder`/`StepTray`/`StepSlot` into `OrderList.list` (horizontal row, top-right) and animates everything per frame from `Config.UI.Orders`. Ring = two clipped halves driven by `Util/RadialRing`. The urgent state rocks only `Face` and the `Table` tag (rotating the plate would break the ring halves' clipping). `RecipeStep.Method` ("Pot"/"Pan") shows a method badge; no recipe uses it yet. Chopping never gets a badge.
- Orders carry `Table` (the trailing number of the customer's `CustomerTable_N` name) from `OrderService.Open`.
- Combo: level `EnableCombo` + `Combo` tuning (on in level2). `OrderService.serveAmount` raises `Combo_{team}` and `ComboEndsAt_{team}` on each serve and applies the multiplier; any expiry breaks it. `Close` now returns the amount, which `CustomerService` stores as the table cash. It is shared by the whole team (assumed; the user didn't pick). `ComboController` draws `InfoFrame.ComboFire` and `CoinsFrame.ComboBadge`.
- The HUD (`InfoFrame`) was rebuilt via MCP from the Figma PC mockup (pixel layout 400x91 at 720 px, `Scale` UIScale, flat cards with shadow frames and `TextShadow` labels) and is placed and scaled from `Config.UI.Hud`: bottom-right on PC, bottom-centre on touch screens. `OrderList.list` is anchored top-right so its UIScale keeps it flush right; orders draw at `DesktopScale` 0.8 on PC.
- Test maps' crates (`Test.Basic`, `Test.Tables`) had nil `Food` ObjectValues; relinked to `Assets.Foods.RawFoods` by their icons. `Maps.CoOp.Chapter1.Level2` now exists, so `Levels.DefaultFor.Manual` can go back to it when the user says so.
- Coin fire (replaced the flat layered flames, then a baked flipbook, both of which looked bad): `CoinsFrame.CoinFire` is a UI particle emitter cloning the round `Ember` Frame (tuning in `Config.UI.Combo` Fire*). It draws over the white `CoinSlot` and under the coin. `art/fire/make_fire.py` and its uploaded sheets (FireOrange `113417472201895`, FireBlue `79405223990519`) and `art/orders/FlameFlat.png` are unused now.
- Coin flights (`Util/CoinFly`, tuning `Config.UI.Coins` Fly*): pop in, hop, arc to the card. Paid on serve: `OrdersController` launches one from the ticket on `CompleteOrder` (every client), from `ShrinkDelay`, flying at `CoinDelay` 0.45 (storyboard); `Coins.LandDelay` 0.75 matches. Table cash: `CashController` launches one from the table (or the caught dasher) only for the collecting player, predicted or confirmed; `GameUIController.landDelay` then waits `CoinFly.Remaining()`, so others' counters update at once. No ticket coin with table cash. New order cards are drawn once before they're parented, so they no longer flash at rest before dropping in.
- Combo badge shakes (`BadgeShake`/`BadgeTilt` per tier, math.noise); coin fire sways as a travelling wave (`FireSway*`). Tester has `CollectCash`.
- Combo break (`Config.UI.Combo.Break*`, `Smoke*`): embers turn to smoke plus `BreakSmokeCount` puffs, the badge goes grey, swells, shakes, falls and spins out, the card shakes, and `CoinsFrame.ComboLost` (Studio TextLabel, no outline) pops the break text. Badge colors and `BadgeTextColors` picked for WCAG contrast against the card (x2 yellow with dark-brown text 9.0:1, x3 orange 5.0:1, x5 blue 5.8:1). No white ring on the badge (user: not our style).
- Figma pass (effects matched to the storyboards): "+" sparks (`Plus.png`), grey smoke puffs, a solid badge with a shadow and no ring, plate speed trail, rocking with sweat drops, served sparkles, the plate shrinking into the coin that flies (`CoinDelay`), and the coin card squash + number roll-up + yellow "+N", delayed by `Config.UI.Coins.LandDelay` when orders pay on serve. The coin sprite is cropped to the coin (`Util/Gif`) and sized 45x56 so it fills its slot.
- Combo rules (2026-10-11, user picked all four): per level in `Combo` tuning. `Fresh = { FreshUntil, LateAfter }` (fraction of the order's time used at serve: green +1, yellow holds and restarts the window, red resets with `Late`; Deep Freeze pauses count, so frozen orders stay fresh), `OldestFirst` (non-oldest serve resets with `OutOfOrder`, still paid at the base rate), `Fever = { At, Time, Multiplier }` (reaching At starts it: `FeverEndsAt_{team}`, `ComboEndsAt` = fever end, every serve pays Multiplier, expiries and failures don't break; at the end the server resets with `FeverOver`; clients swell, shake and pop the badge into a burst of falling fever embers and show a pink "FEVER OVER!" via `ComboLost`, no smoke, no flash; `FeverEnd*`/`FeverBurst*` tuning). `CoinsFrame` ZIndex is 3 so the badge draws over `TimerFrame`; the badge moved to the card's top-right corner (2026-10-11, user pick), leaning `BadgeLean`. Never rotate `ComboBadge` itself: rotation disables clipping and breaks the RadialRing halves, so code rotates Face/Shadow/Label. "+N" coin text flies at a random angle (`Config.UI.Coins.NotificationAngle`)). Level 2: Fresh only. Test maps use `levelTest` (Level 2 + all rules). Plate ring shows flat bands at the Fresh edges (`Config.UI.Orders.RingBlend`). Badge countdown ring `ComboBadge.Timer` (`TimerUrgent*`, `TimerThrob*`). Break texts per reason (`BreakTexts`); only `BreakShakeCard` reasons shake the card. Fever UI `GameInfo.Fever` (`Fever*` in `Config.UI.Combo`), toned down after the user said it hurt their eyes. No round music exists yet, so the proposed music speed-up wasn't built. Not seen in play yet: the FEVER! banner pop, and the real server path (only tester-simulated so far).
- Action tools (2026-10-11): `ActionToolController` welds `Assets.Tools.<Config.Interaction.ActionTools[action]>` to every character's `Right Arm` `RightGripAttachment` (client-only clone, pops in and shrinks away) from the `ActionAnimation` attribute. The local player predicts the chop in `InputController.predictUse` (target is an unlocked chopping board with raw food, hands empty) through `AnimationController.Predict`, which also starts the animation at once and rolls back after `ActionPredictTimeout` if the server doesn't agree; `stopUse` predicts the stop. The `Grip` orientation (hammer grip, the user's pick over blade-along-the-arm) was checked on a posed Bill and in play through a server-set attribute; the real predicted chop on a board isn't play-tested yet. Bat mesh (`art/bat/`, revised: shorter handle, longer barrel) is made but not imported or used.
- **Effect tester:** `StarterGui.EffectTester` + `EffectTesterController` (hidden; type `/testerui` in chat to toggle it, Studio only and only for `Config.UI.EffectTester.UserIds` (zebronr); the command is `TextChatService.TesterUICommand`, switched off for everyone else) play orders, urgency, serve, expire, freeze, combo and coin gains locally via `OrdersController.Simulate`, `ComboController.Simulate` and `GameUIController.Preview`/`PreviewGain`. Play-tested with it: orders, urgent glow/sweat, orange fire, smoke, coin gain all draw with no console errors; blue fire not seen yet.
- Not done: a "step done" state on trays (it needs a plate-to-order link), and deleting the old ticket templates.

## START opening shot (2026-10-11)

- After START, `IntroController` plays `Config.Round.Cinematic`: black hold, then `StarterGui.IntroIris.Hole` (black image with the Superchefs icon cut out, from the Figma vector "icon cutout", `art/intro/icon_hole.py`, `rbxassetid://93533641815475`) pops open and zooms past the screen; the camera (`CameraController.SetShot`) holds a wide shot of the whole map (map bounding box from the gameplay angle, or a BasePart `IntroCamera` in the map) and eases to the gameplay camera. The server only sends `Cinematic` with its start time (`RoundService`, first round after START only) and delays Ready-Set-Go by `Round.CinematicLength`. The presser predicts the black screen on click and adopts the server's time; no confirmation within `ConfirmTimeout` rolls it back. Figma export workflow: `docs/FIGMA-WORKFLOW.md`. Not play-tested yet.

## Start button and Ready-Set-Go (2026-10-10, later)

- The round waits for START (now on the loading screen `ReplicatedFirst.LoadingGui`, host-only via `Config.Round.StartHosts`, 2026-10-13; `StarterGui.StartRound` was removed) while `Config.Round.StartButton` is true. Clients send `Ready` on the `Round` remote after every controller has started; join-time messages moved to `RoundService.markReady`. Ready-Set-Go words pop in and out (`Config.UI.ReadySetGo`). Not play-tested yet.
- Frozen bubble: the 4 corner snowflake chips (`Frost.Corner1-4`) were deleted in Studio; the ice rim and the one snowflake badge stay.
- **Bitmap font system:** `python art/fonts/bitmap_font.py <ttf> <Name> [px]` bakes ASCII 32-126 into one atlas PNG (`art/fonts/<Name>.png`) plus `src/shared/Fonts/<Name>.luau` (glyph rects and metrics; re-running keeps the uploaded `Image` id). Upload the PNG once (MCP `upload_image` from a local `http.server`) and paste the id into the module. `BitmapFont.Render(font, text, parent, { Color, Alignment, ShadowColor, ShadowOffset, ... })` draws one line that fits its parent, in scale. Jersey 15 (OFL, `art/fonts/src/Jersey15-Regular.ttf`) is baked at its native 27 px (pixel-perfect, drawn with Pixelated resampling) as `rbxassetid://121071162139321`; Ready-Set-Go uses it: each `StarterGui.ReadySetGo` frame is a solid Figma-colored banner, and the word is drawn inside its TextLabel from the label's Text and TextColor3. Verified with a Studio preview.

## Session end (2026-10-10, late)

- **Deep Freeze ice shell:** the faceted `IceShell` MeshPart is imported into `Assets.Skills.DeepFreeze`, set up (Transparency 0.35, no collide/query/touch, anchored, `Edges` Highlight moved onto it). Still to do: delete the old `IceBlock` Part and rename `IceShell` to `IceBlock` (the code only looks for `IceBlock`), then play-test.
- **Deep Freeze now catches only customers inside the circle at cast** (`FreezeService.scanCustomers`, keyed per circle by owner + StartedAt). Cooking tools still freeze when carried in, per the design doc. Typecheck clean, not play-tested yet.
- **Figma:** Figma Console MCP (Southleft) runs locally (`figma-console` in the user config, Bridge plugin from `~/.figma-console-mcp/plugin`). The UI board is the file "Untitled" (order tickets, HUD mockup, Ready/Set/Go, buttons). Not designed yet: superskill HUD button, mobile skill button, customer bubble. Offered next: design those, tidy the board into sections, or write Studio build specs.
- **Customer bubble redesigned (2026-10-10):** designed in Figma (section "Customer Bubble", same layer names as Studio, shadows as their own layers) and rebuilt in `ReplicatedStorage.UIs.CustomerBubble` (Size 3 x 3.64 studs, StudsOffset Y 3.8, Global ZIndex). Old version backed up at `ServerStorage.CustomerBubbleOld`; delete it once happy. Placeholder row removed. Not play-tested in a live round yet.
- Halloween props paused for the modeller; Deep Freeze review item 4 (rim line, streak textures) still open.

## Config (2026-10-05)

One entry point: `local Config = require(Shared:WaitForChild("Config"))` (`src/shared/Config/init.luau`). Never require the child files directly, and children must never require the index.

- `Config.Character`: movement, dash, camera.
- `Config.Interaction`: stations, cooking, carry, throw (`.Cooking`, `.Throw`).
- `Config.Levels`: level data, per-level customer tuning, `GetCurrent()`.
- `Config.Recipes`: pot and plate combinations, soup colors.
- `Config.Round`: serve mode and round timings.
- `Config.Customers`: customer team, walking, animation, arrival.
- `Config.UI`: patience, ticket and coin colors.

Types are re-exported on the index (`Config.ServeMode`, `Config.Recipe`, `Config.CustomerTuning`, `Config.LevelData`). New tunables go in these files, never hardcoded in scripts.

- Preloading: background tiers load the local superskill and sounds, all shared assets and UI, server asset ids, then NPCs; superskill meshes are warmed after the first two tiers. The first tier also loads images that only live in code (`PreloadController.codeImages`: the current level's recipe food/ingredient icons and every `Shared.Fonts` atlas); add new code-only image ids there. `ReplicatedStorage.Remotes.Preload` is a RemoteFunction made in Studio 2026-10-06. Batch timing, character wait, warm-up and server roots are in `Config.Preload`.

## Assets layout (2026-10-05)

`ReplicatedStorage.Assets` (client templates):
- `UI`: BurningWarning, CookingFinished, ObjectNotification, ProgressBar (BillboardGuis).
- `Highlights`: CharacterHighlight, ErrorHighlight, VisibilityHighlight.
- `Effects`: BurnSmoke, DashTrail, FireEmitter, PlayerIndicator, ProjectileTrail.
- `Skills.<SkillName>`: one folder per skill, e.g. `Skills.TongueGrab` (TongueBody, TongueTip, TongueGuide, TongueHighlight, `VFX`).
- `Tools`: hand tools shown during actions, each a BasePart with a `Grip` Attachment (`Cleaver`, from `art/cleaver/`, 3.8 studs (user asked for 2x), SmoothPlastic, non-colliding, Massless; hammer grip: handle through the fist, blade out the top, edge forward; `Bat`, from `art/bat/`, imported at 69 studs and scaled to 4.5, SmoothPlastic, same grip orientation, held just above the knob).

`ServerStorage.Assets` keeps `Foods` and `Plates`. New templates go in the matching folder.

## Interactions

Chopping boards and sinks auto-use from one tap. Releasing Use does not stop them; moving, dashing, Interact, server distance checks, or completion does. A sink washes its entire dirty stack in one session, resetting progress and the safety timeout after each plate. The extinguisher remains hold-to-spray.

## Serve modes (Window / Manual)

- `src/shared/Config/Round.luau` `ServeMode` picks the mode once at server start: `"Manual"` (default) or `"Window"` (legacy serving window). `Levels.DefaultFor` maps the mode to the level path, and `LevelService` loads `ServerStorage.Maps` by that path. It also sets the `ServeMode` and `LevelPath` attributes on ReplicatedStorage; the client's `Levels.GetCurrent()` reads `LevelPath`.
- Window: unchanged (order sequence, ServingCounter, ambient NPCs) on `CoOp/Chapter1/Level1`.
- Manual: `CoOp/Chapter1/Level2` (`Levels.luau` `level2`: dirty plates, table cash, customers). The demo map was built in `Workspace.Level2` and moved to `Maps.CoOp.Chapter1.Level2` on 2026-10-13 (the earlier draft there was renamed `Level2_Old` for the user to check and delete); `Levels.DefaultFor.Manual` points at it, and `level2.Recipes` is the burger only (its crates are bun, meat and cheese). The test maps keep `levelTest`. Orders and customers carry a recipe's `Id`; look it up with `Levels.GetRecipe(id)`, never `Recipes[id]` (a level's list position is not its Id: the burger is Id 7 but first in Level 2's list). A manual map needs `CustomerTable_N` parts (`objectClass=CustomerTable`, `throwInteractable`, collision on) each with a `Seat` child, and a `CustomerSpawn`. A station can carry several `DefObjectOnTop` ObjectValues; each goes through `Station:PlaceDefault` (the slot by default), and `PlateTable` overrides it to push plates onto its stack, so a plate table starts with one plate per link (Level2 has 10). The `Seat` can be an invisible marker on a chair: its top face is the seat height; the server anchors the customer's root `Customers.SitHeight` above it facing the table, and `CustomerController` plays `Customers.SitAnimation` (R6 sit) while seated. Note: Level1's decor furniture has collision off and its `NPCBarriers` are the furniture's collision boxes. `CustomerService` spawns NPC models from `ReplicatedStorage.NPCs` every `Customers.SpawnInterval`; they walk to a free table, wait to order, you interact to take the order (`OrderService.Open` makes the ticket), cook, then deliver the plate to their table (`CustomerTable` station). They eat, leave a dirty plate (or a clean plate returns to the PlateTable when `EnableDirtyPlates` is false), and walk back. `CustomerController` shows the `UIs.CustomerBubble` (alert or recipe icon, patience bar).
- Barebones on purpose: block tables, no sitting animation, random recipes, single team (team 1), only the dirty plate can be picked up from a table.

## Table cash and dine-and-dash runners (2026-10-07)

Both are level settings (the per-level mechanics rule in CLAUDE.md): `EnableTableCash` on `LevelData` and `DashChance` on `CustomerTuning`. Only `level2` (Chapter1/Level2) turns them on (DashChance 0.15); `level1` behaves as before (paid at serve, nobody runs).

- Payment: with table cash on, `CustomerService.serveCustomer` stores `session.PaymentAmount` and closes the order with `OrderService.Close(..., pay = false)`. After eating, `CustomerTable.AddCash` sets `Cash`/`CashAt` on the table. Any interact on the table (after customer actions) collects it via the public `OrderService.Pay(team, amount, at)` and sets `CashCollectedBy`/`CashCollectedAt`; the same press also takes the dirty plate. `RefreshInteraction` keeps the table enabled while cash is on it; `CustomerService.Stop` clears it.
- Runners: `DashChance` is rolled at spawn (`session.WillDash`, published as the `WillDash` attribute); after eating, a runner goes to state `Dashing` (WalkSpeed `Customers.DashSpeed`), clears the table, tags the HumanoidRootPart as class `Runner` (`Classes/Runner.luau`, catch handler set by CustomerService) and runs to `CustomerSpawn`. Reaching it = escaped, no coins. Interact within `MinDistance.Runner` swings the bat (server stamps `CatchSwingAt` on the character, lag-compensated); the catch lands with the bonk after `WindTime + SlamTime` only if the runner is within `CatchSwing.HitRange`: state `Caught`, `CaughtAt`/`CaughtBy`, the catcher's team is paid, then after `CaughtPause` the customer is removed (no walk out). Every client hides the caught model and ragdolls a local copy flung away from the catcher (`RagdollController`, `Customers.Ragdoll`). `TargetController` outlines the whole model for a Runner target. The bat swing is a one-shot in `ActionToolController` (tool raised, then slammed down about the hand), predicted by `CashController.Predict` for the swinger (with the cash burst predicted at the bonk) and played from `CatchSwingAt` for everyone else. The arm temporarily loops the Chop animation (`CatchSwing.Animation`, `AnimationController.PlayUntil`) until a real swing animation exists.
- Runner tell (2026-10-11): while a `WillDash` customer sits (WaitingToOrder, WaitingForFood, Eating) and isn't frozen, `CustomerController` clones `ReplicatedStorage.Assets.Effects.SweatDrops` (Attachment + ParticleEmitter `Sweat`, texture from `art/sweat/sweat.py`) onto their Head and enables it. The look (rate, faintness, arc) lives on that template in Studio.
- Client: `CashController` draws the cash pile (`Customers.CashOffset`, a CFrame from the table's top centre, pile bottom on the surface), the pop-in, the fly-to-collector arc and the catch burst, and predicts both for the local player (`PredictTimeout` rollback; confirm only retargets, never restarts). `CustomerController` now plays the customers' walk animation on the client (sped up by `DashAnimSpeed` while dashing), the red `RunnerHighlight` and the bubble's `Dash` label.
- Studio (made 2026-10-07): `Assets.Customers.Cash` (MeshPart from `art/cash/out/Cash.fbx`, PivotOffset at its base), `Assets.Highlights.RunnerHighlight` (red, AlwaysOnTop), `UIs.CustomerBubble.Background.Dash` (TextLabel "CATCH!", placeholder).
- Later: the pile shows the amount paid (coin, more stacks, banknotes); see `docs/design/customers.md`.

## Session log (2026-10-07)

- Deep Freeze ice chunks get random sizes (`Visuals.ShardSizeMin/Max`).
- "Customer frozen forever" report: the freeze and thaw were correct; the bubble was missing (below). Real bug fixed too: a customer frozen while walking in had their patience clock shifted by the walk time; it now starts paused when they sit.
- Customer bubbles: with StreamingEnabled a customer can arrive before its Head, or the Head streams out and back; `CustomerController` rebuilds missing or detached bubbles every Heartbeat.
- Tables stuck disabled after eating: `Item.new` resumed `Item.Await` waiters synchronously, before the `DirtyPlate` constructor finished, so the table saw a plain Item. Waiters now resume with `task.defer`.
- Order Rush: the real Alien stays visible until the beam reaches them, then the see-through copy takes over.
- "You" ring hidden on the ice: the frost circle sat on the floor with its top face above the ring. The circle (and shockwave by the same amount) is now sunk so its top face is `GroundOffset` above the floor.
- Table cash and runners (section above), written by Codex and reviewed; level gating, prediction timing and cash placement fixed by Claude.
- New rule: every non-base mechanic is a level setting (CLAUDE.md, memory `feedback-mechanics-per-level`).
- Still waiting on the user: v0.6.0 release OK, removing the `legacy-snapshot` tag. Next planned: the Hustle superskill juice pass.

---

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
- Final parity audit done (2026-10-05): all 172 `docs/PARITY.md` items ticked (142 done, 26 deliberate changes, 2 N/A); the 2 gaps it found were fixed (stray CookingTool targeting priority, Sink interact during a wash). Deferred release work lives in `docs/RELEASE-TODO.md` (missed first ReadySetGo → waiting-for-players screen; the anti-teleport movement check proposed 2026-10-13, waiting for the user's review).
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

---

## Throwing (revamped 2026-10-05)

- Server (`ThrowService`): the start time is back-dated by half the thrower's ping (capped by `MaxLagCompensation`). Each Heartbeat it sweeps a sphere (`CastRadius`) along the arc with an exclude list built once per throw. A hit, or the end of the arc, is an impact: the item falls straight down with `FallGravity`, and a `throwInteractable` station under the impact point receives it.
- Catch: before the sweep, a player with empty hands, not mid-Use, within `CatchRadius` of the path and facing the item (`CatchFacingDot`) picks it up through `CarryService.Pickup`. If the pickup fails, the item falls instead.
- Client: `InputController.throwHeld` calls `ProjectileController.Predict` for Food. The thrower runs the flight locally, rolls back after `PredictionTimeout` without confirmation, and blends into the server timeline over `ReconcileTime` once the `Projectile` tag and `ThrowStartedAt` arrive. Other clients render from the replicated attributes.
- Tunables: `Interaction.Throw` in `src/shared/Config/Interaction.luau`.

## Super skills (2026-10-05)

- Server: `Services/SkillService` owns the `Skill` remote, per-player state and cooldown attributes. A skill is a module in `src/server/Skills/` returning `Types.Skill` (`Aim`, `Release`, `Interrupt`, `Cancel`, `HoldTimeout`, optional `FindIntercept`/`TakeThrown`); `Skills/TongueGrab` is the Gecko. It talks to the rest through `ThrowService.SetInterceptor` / `SetCharacterHitHandler` and `InteractionService.TakeFor` / `StationOf` / `IsUsing`.
- Client: `Controllers/SkillController` (key, mobile button, HUD, aim flow, rooting) and one module per skill in `src/client/Skills/` (`BeginAim`/`StepAim`/`ReleaseAim`/`EndAim`/`GetDirection`/`GetTarget`/`Setup`). `ReleaseAim` receives whether the player released (rather than timed out). `InputController` skips other actions while `SkillController.IsBusy()`.
- Gecko auto-aims to a nearby reachable item on press. Movement spins a virtual aim yaw; the Gecko turns quickly toward the reachable item closest to it, with a 10-degree switch margin. The guide and highlight follow the lock. Release sends that lock as a hint, which the server validates before targeting; invalid hints fall back to the aim line. Holding until timeout cancels without firing and applies a 0.5-second cooldown. The fired tongue and flying item use shared extend/retract easing.
- The releasing client draws its tongue immediately and hands off when a fresh `TongueStartedAt` arrives. The server backdates extending by capped half-ping and publishes state, timestamps and tip only; every client renders the effect.
- Add a skill: write the server module and the client module, register each in `SkillService` and `SkillController`, map the character in `Config.Skills.ByCharacter`, add its tuning to `Config/Skills.luau`, and add Studio UI/assets (see `docs/PLACEHOLDER-UI.md`).
- Studio instances needed: `Remotes.Skill`, `Assets.Skills.TongueGrab.TongueBody` (Beam), `TongueTip` (MeshPart), `VFX` (Thwip/Splat/Dust/Pop emitters, ItemTrail), `TongueGuide` / `TongueHighlight`, `GameInfo.InfoFrame.Superskill` (the superskill card; replaced `StarterGui.SkillHUD` 2026-10-11), `MobileControls.Skill`. Art sources live in `art/tongue/`: `tongue_tip.py` is a headless Blender script and `textures.py` uses Pillow; outputs are in `art/tongue/out/`. Optional sounds in `SoundService.SoundEffects`: `TongueThwip`, `TonguePop`, `TongueWhiff`.
- `Config.Character.StudioOverride` (default `"Gecko"`): in Studio every player gets that model; set nil to use the name mapping. Live servers ignore it.
- Design: `docs/design/characters/gecko-tongue-grab.md`.

### Instant skills: Hustle, Deep Freeze, Order Rush (2026-10-05, written by Claude, smoke-tested in Studio)
- Press-once skills sit beside the hold-to-aim ones. Server: `Types.InstantSkill` (`RequiresEmptyHands`, `AllowedWhileUsing`, `Use(ctx, startedAt)`, `Cancel`), registered in `SkillService.instantSkills`, used through the `"Use"` action (lag-compensated `startedAt`; any refusal fires `"Interrupted"`). Client: `Skills/InstantSkill` (type + helpers), registered in `SkillController.instantSkills`; press predicts (`Predict`), the server confirms by changing `SkillReadyAt` or `SkillState`, and `"Interrupted"` or `Skills.InstantConfirmTimeout` rolls back (`Rollback`).
- Shared rules in `src/shared/Util/SkillEffects.luau` (Hustle multipliers, frost circles, Order Rush targets/stops/timeline), read by the server and every client.
- `Controllers/SpeedController` now owns the local WalkSpeed/AutoRotate: named multipliers (Hustle, Ice) and named roots (Aim, OrderRush). The aim rooting in `SkillController` uses it.
- Hustle: `HustleUntil` on Bill; `ChoppingBoard`/`Sink` scale by `SkillEffects.WorkMultiplier`.
- Deep Freeze: `Services/FreezeService` scans the circles every `ScanInterval` and calls `CookingTool:Freeze/Unfreeze` and `CustomerService.SetFrozen` (which pauses the order with `OrderService.Pause/Resume`, sending `"UpdateOrder"` with `PausedAt`). `FireService` holds spread from and into circles. Client: frost circle, frozen highlight, ice slide (render step after the default controls, `humanoid:Move`), Penguin speed on own ice.
- Order Rush: server picks targets, stores the chain on the Alien and calls `CustomerService.TakeOrderFor` at each stop's halfway time; the Alien never moves. The server phases the Alien during the rush using the `Phased` collision group (registered in Studio; collides only with Default, PlayerBarrier and StudioSelectable). Clients hide the Alien and draw a UFO (2026-10-05 rework): it drops in and beams the Alien up, flies to each customer and beams a see-through copy of the Alien down and back up, returns, beams the Alien down and zips away. The UFO path is one pure function (`ufoPathAt`); the copy is drawn per part with squash and deterministic glitch. Purely visual from the same attributes; timings in `Config.Skills.OrderRush` (Vanish/Step/Return = 1.1/1.5/1.2 s; per stop the UFO flies 32%, the copy descends 18% so it lands when the order is taken, stands still, then rises during the last 22%), look in `.Visuals`. The local player is rooted for the chain and its camera follows its own UFO (`CameraController.SetFocus`), easing back to the Alien as the UFO leaves.
- "Alien" is a working name: rename the `ByCharacter` key with the model.
- **Superskill test keys removed (2026-10-13):** Q always uses the chef's own superskill; pick the chef on the boot screen.
- Smoke test (Studio, solo, character switched via the `CharacterModel` attribute): Hustle gives 20.8 walk speed plus the trail and ends on time; Deep Freeze freezes the Pot (highlight, FrozenAt), draws the circle, gives the Penguin 18.4 on its ice, and everything clears after 6 s; Order Rush hides and roots the Alien, draws afterimages, takes both waiting orders and restores the Alien. No console errors. Not yet tested: the ice slide for another player (needs 2 players), freezing a customer or fire, rollback on refusal.
- **Stand-ins made in Studio (MCP):** `ServerStorage.Characters.Penguin` (dark blue) and `ServerStorage.Characters.Alien` (green) are recoloured clones of Bill with the attribute `StandIn = true`; replace them with the real models. No player is mapped to them in `Config.Character.CharacterModels` yet.
- **Placeholder templates made in Studio (MCP)**, to be restyled to the art style; the code needs these names and classes (each is optional and warned once if missing):
  - `Assets.Skills.BearToss` (2026-10-13): `Ring` (invisible flat Part 6×0.05×6 with a white Decal `Ring` on top, texture 125802800790196 from `art/bear/textures.py`; the Decal is tinted per frame), `ArcBeam` (one dash: Beam with the rounded dash texture 128239757413333 from `art/bear/textures.py`, Stretch, width 0.4, transparency 0.25, FaceCamera, no curve; replaced `ArcDot`). Collision group `Ragdoll` (collides with `Default` and `Bounds` only), `Dust` (clone of Phase `Puff`, tan, Enabled false). `ServerStorage.Characters.Bear` is a brown stand-in clone of Bill (`StandIn = true`).
  - `Assets.Skills.Phase` (2026-10-13): `Wisps` (streamed from the root while moving), `Puff` (the start burst and its floor ring, the ring on a wall face at each crossing, and the spit-out) and `Pop` (end), round pale puffs (`art/smoke/Circle.png`), Enabled false. `ServerStorage.Characters.Ghost` is a pale stand-in clone of Bill (`StandIn = true`). Collision groups `Bounds` (every map's floors and `MapBarrier`) and `GhostPhase` were added for Phase; new maps must put their floors in `Bounds` (docs/COLLISION-GROUPS.md).
  - `Assets.Skills.Hustle`: `SpeedTrail` (Trail), `SpeedLines` (streamed from the root part while moving, `art/hustle/SpeedLine.png`), `Sweat` (copy of `Effects.SweatDrops.Sweat`), `Steam` and `Exhale` (round puffs, `art/smoke/Circle.png`), all emitters Enabled false.
  - `Assets.Skills.DeepFreeze`: `FrostCircle` (BasePart, flat, top face +Y, X/Z footprint scaled by `Visuals.FrostScale` beyond the gameplay circle; optional child Decals `Cracks` and `Frost`), `FrozenHighlight` (Highlight, tools and pots only), `Snow` and `Shatter` (ParticleEmitters, Enabled false). New Studio templates: `Shockwave` (BasePart, flat with a ring decal on top), `IceChunk` (MeshPart, about 1 stud), `IceSpike` (MeshPart, about 2 studs tall, origin at its base), `FrostCap` (MeshPart, about 2 studs wide, origin at its base), `IceBlock` (BasePart, optional children such as Highlight and Decals cloned), `Breath` and `Glint` (ParticleEmitters, Enabled false). Optional sounds in `SoundService.SoundEffects`: `FreezeStomp`, `FreezeWhoosh`, `FreezeCrack`, `FreezeShatter` (Sound). Every template and sound is optional. Made in Studio 2026-10-06: `FrostCircle` is now an invisible part with `Frost` and `Cracks` top Decals; `Shockwave` (ring Decal `Ring`), `Breath` and `Glint` exist; `Snow`/`Shatter` use the snowflake texture. Made 2026-10-10: `IceBlock` (Glass Part, 0.5 transparent, child Highlight `Edges` with a white outline) and the bubble stand-ins `Frost` (four frosty corner Frames), `Snowflake` and `Bar.Fill.FrostTexture` (snowflake texture, tiled). Also optional and made the same day: `Mist` and `Snowfall` (ParticleEmitters, Enabled false; Mist emits from the ice, Snowfall from an invisible part `SnowfallHeight` above it) and `PenguinGlow` (Highlight on the caster for the freeze), `StationFrost` (thin BasePart laid on top of stations inside the circle). Textures come from `art/frost/textures.py` (uploaded: FrostCircle 125514642344480 and Cracks 113212643169632 (ragged edge, round 2), IceSpike 99133773118124, Shockwave 93121245219042, Snowflake 111108598263073, Puff 86432852399068, IceChunk 79649555766222, FrostCap 121856961800044). `IceChunk`/`FrostCap`/`IceShell` meshes (`art/frost/out/*.fbx`) are imported by hand; `IceShell` (2026-10-10, faceted shell with crystals, origin at its base) replaces the `IceBlock` Part placeholder once imported. The four Freeze sounds are free Creator Store stand-ins (listed in docs/RELEASE-TODO.md).
  - `Assets.Skills.OrderRush`: `Ufo` (a MeshPart or a Model, pivot upright at its centre), `TractorBeam` (BasePart: a cone 1 tall, wide end down, scaled to length by the code), `AfterimageHighlight` (Highlight), `Sparkle` (ParticleEmitter). `Ufo` is `art/ufo/out/Ufo.fbx`, one mesh with the dome baked into `Ufo.png` (TextureID rbxassetid://132208650132118, ~8 studs wide, anchored, no collide/query/touch). `TractorBeam` is `TractorBeam.fbx` (TextureID rbxassetid://122107337116832, SmoothPlastic, Transparency 0.15, size 6×1×6). Re-exporting `Ufo.fbx` changes its UVs, so re-upload `Ufo.png` with it. FBX imports come in 100× too big (the UFO at 200 wide): set `Size = MeshSize * (8 / MeshSize.X)`. After importing, set the mesh's PivotOffset to identity (the UFO came in with a 12-stud offset and drew off screen). Sources: `art/ufo/textures.py` (Pillow) then `art/ufo/ufo.py` (headless Blender). The copy, UFO and beam use the `Afterimage` collision group (registered in Studio, collides with nothing) because the copy's Humanoid forces collisions back on.
- Untested edge cases to watch in playtest: ice feel with the top-down camera (input mapping falls back to `MoveDirection` without the PlayerModule controls), afterimage clones of the character (they copy accessories and anything parented to it), and Order Rush stop heights (afterimages stand at the Alien's height).
