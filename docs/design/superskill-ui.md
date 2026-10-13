# Superskill HUD

Status: **design proposal (2026-10-11). A simpler version was built** (`GameInfo.InfoFrame.Superskill`, see the UI guide): card, icon, ring, timer, keycap, press and ready pop. The states, liquid and effects below are not built. Replaces the placeholders `StarterGui.SkillHUD` and
`StarterGui.MobileControls.Skill` (see [`PLACEHOLDER-UI.md`](../PLACEHOLDER-UI.md)). Follows the
[art style](art-style.md) and the [UI guide](../UI-GUIDE.md).

Mockups (re-render with `python art/superskill-ui/render.py`; open `mockup.html` in a browser for a live loop):

| File | Shows |
|---|---|
| `art/superskill-ui/states.png` | every state for Gecko, Bill, Penguin and Alien, the reserved icons and colors for the draft characters, and the aim ring turning red |
| `art/superskill-ui/motion.png` | frames sampled from the curves below: cooldown then the just-ready pop, press and release into active, a refused press |
| `art/superskill-ui/desktop.png` | placement on PC next to the coin and timer cards (1280 x 720) |
| `art/superskill-ui/mobile.png` | placement on a landscape phone (844 x 390) with the touch buttons |

The HUD cards, orders and touch buttons in the mockups are approximations of the current UI, drawn only for scale.

## The idea in one line

One round, squishy "jelly" button per character, in that character's color with a white icon. It recharges by
draining a grey liquid out of the face (the cooldown), wraps itself in a ring while a superskill is aiming or running,
and pops with sparks when it's ready again.

## Layout

### Desktop

- **Where:** bottom-right, directly left of `GameInfo.InfoFrame` (the timer and coin cards), bottom-aligned with them,
  22 px gap (design pixels). It reads as part of the same HUD cluster.
- **Size:** 104 x 104 px at the 720 px design height, scaled like the cards: screen height / 720 x
  `Config.UI.Hud.DesktopScale` (0.85, so 88 px on a 720 p window). The ring adds 13% on each side (132 px footprint),
  the key cap hangs 4% past the bottom-left edge.
- **Key cap:** a small paper-colored key (`Q`, the name of `Config.Interaction.Controls.Skill`) on the bottom-left
  edge, like a keyboard key with its own drop shadow.
- The combo badge stays on the coin card's top-right corner, far from the button, so the two never overlap.

### Mobile

- **Where:** on the outer arc of the right-thumb cluster (`MobileControls`), above-left of `Throw`, toward the screen
  centre. Never under the thumb's resting spot on `Interact`, and clear of the bottom-centre HUD (`InfoFrame` sits
  there on touch screens).
- **Size:** 132 x 132 px at the 720 px design height x `Config.UI.Hud.TouchScale` (1.2), so about 86 px on an 844 x
  390 phone. It's the biggest button after `Interact`, so it's easy to find without looking.
- **No key cap.** Same face, ring, cooldown and pops as desktop.
- Hold to aim (Gecko) and tap for the rest, exactly as the controller works today.

## States

Colors come per superskill from the table under [Characters](#characters-icons-and-colors): `Color` (face), `Dark`
(outline, shadow, icon shadow) and `Light` (ring, sparks, shock ring). Grey is `#6E7380` (110, 115, 128), dark grey
`#3A3E48`.

| State | When (from the current controller) | Looks |
|---|---|---|
| **Hidden** | the character has no superskill | ScreenGui disabled / mobile button hidden (as today) |
| **Ready** | cooldown 0, not busy, usable | full color face, white icon, key cap up. A soft glint sweeps across the face every 6 s. No idle breathing: the combo and fever already move a lot, and the user found the fever too loud. |
| **Just ready** | cooldown fraction goes from above 0 to 0 | the ready pop (below), once |
| **Pressed** | key or finger down | squashed (scale 0.9, a bit wider than tall), key cap sinks and loses its shadow |
| **Aiming** (Gecko) | the local `aim` exists | stays pressed (0.92). The ring shows the hold limit left (3 s, refilled when the lock switches targets). In the last 25% the ring turns red (`#E2483D`) and throbs. The icon wiggles (±7°, 6 Hz). |
| **Active** | the superskill's effect is running (Hustle 5 s, Deep Freeze 6 s, the Order Rush chain) | full color, a soft white inner glow pulsing every 0.8 s, the ring drains the effect's time left in `Light`. Per-character icon motion: Bill's shoe hops, Penguin's snowflake spins slowly, Alien's beam pulses. |
| **Busy** | mid-action without a timer (the tongue flying, a pending prediction) | stays at the pressed look, no ring |
| **Cooldown** | cooldown fraction above 0 (after any active part) | a grey liquid fills the face from the bottom, at the height of the time left, with a wavy top edge that scrolls. The colored part above it is what's recharged, so the button "fills with color" from the top. The icon dims (transparency 0.65) and the whole seconds left show on top in Jersey 15 white with a dark grey drop. No counter when the whole cooldown is under 1.5 s (Gecko's 0.5 s cancel, 2.5 s miss still counts). |
| **Unavailable** | ready, but `updateHud` says no (hands full, nobody to serve, busy at a station) | whole face greyed (80% toward grey), icon at 0.55. A small red reason badge on the top-right: a hand (hands full: Gecko, Alien) or a crossed-out customer (Alien with nobody waiting). No badge for plain busy. |

Pressing while **Cooldown** or **Unavailable** plays the refused shake. When an unavailable button becomes usable again
(hands freed), it does a small "unblock" pop (scale 1.06 and back, 0.15 s), much smaller than the ready pop.

An **interrupt** (hit by a thrown item while aiming) plays the refused shake and goes straight back to Ready: the
design doc proposes no cooldown for an interrupt, so there's no pop either.

## Motion

Snappy and elastic, never linear (art style). All times in seconds. These are the curves `mockup.html` samples, so
`motion.png` shows exactly what they produce.

### Just ready (0.5 s total)

| Part | Timing | Curve |
|---|---|---|
| Anticipation: `Pop` 1 to 0.88 | 0 to 0.07 | Quad Out |
| Pop up: 0.88 to 1.15 | 0.07 to 0.19 | Quad Out |
| Settle: 1.15 to 1 | 0.19 to 0.45 | Back Out, overshoot 2.2 |
| Face wobble: X +w, Y -w (on `Face` and `Shadow` Size), w = 0.09 x e^(-7u) x sin(2πu / 0.175) | 0.07 to 0.42 (2 cycles) | decaying sine (the art style's secondary wobble) |
| White flash: `Flash` transparency 0.15 to 1 | 0.07 to 0.32 | Quad Out |
| Shock ring: `Shock` scale 1 to 1.55, transparency 0.2 to 1 | 0.07 to 0.47 | Expo Out |
| 6 "+" sparks (`Plus.png`, alternating white and `Light`) fly from 0.48 to 0.98 of the radius, shrink to 0.2 and fade over the second half | 0.07 to 0.47 | Expo Out |
| Glint sweeps across the face | 0.15 to 0.5 | Quad Out |
| Key cap hops up 6% of the size and back | 0.1 to 0.3 | sine |
| Sound: a short bright chime; on mobile an optional light haptic | at 0.07 | |

No pop on spawn or on a character change: only when a cooldown actually runs out while the same character is alive.

### Press and release

- Down: `Pop` 1 to 0.9 and Face X 1.06 / Y 0.94 in 0.06 s (Quad Out).
- Up: back to 1 in 0.22 s (Back Out, overshoot 2.4).
- The button reacts on the local press, never waiting for the server (the hard prediction rule). A press that the
  server later refuses (instant superskill rolled back) plays the refused shake and returns to Ready.

### Refused press (0.25 s)

- Side shake: X offset = 0.06 x size x (1 - k) x sin(2π x 3k), k = t / 0.25 (3 decaying cycles).
- Small bonk: `Pop` dips to 0.95 and back over the first 0.12 s.
- Reason badge: scale 1 to 1.25 and back in 0.2 s.
- Sound: a dull "bonk".

### Ring (aiming and active)

- Fills clockwise from 12 o'clock with `Util/RadialRing` (the same parts as the plate timer and the combo badge timer).
- Hold-limit refill when the lock switches (Gecko): the ring grows back to full over 0.12 s (Quad Out) instead of
  jumping.
- Urgent (last 25% of an aim): red, and the ring throbs (scale 1 to 1.04, 0.3 s period), matching the combo badge's
  urgent timer.
- When an active effect ends: the ring snaps away and the face drops into the cooldown with the liquid full, over
  0.2 s (the liquid rises from 0.9 to 1 with Quad Out so it lands with a little slosh).

### Cooldown liquid

- The wave strip scrolls 0.8 widths per second; it's a tiling image twice the face's width, so it loops seamlessly.
- In the last 0.4 s the counter shows 1 and the liquid's top edge brightens slightly, so the pop feels expected.

## Characters: icons and colors

One icon per superskill, keyed by skill module name (the same keys as `Config.Skills.ByCharacter`). Icons are white
silhouettes on transparent 256 x 256 PNGs, like `art/orders` (tinted by code through `ImageColor3`); the icon shadow
is the same image tinted `Dark`. The SVG sources are in `art/superskill-ui/mockup.html` (`ICONS`), ready to export.
Colors avoid the combo badge tiers sitting nearby (yellow, orange-brown, blue, magenta) as far as eight hues allow.

| Character | Superskill (key) | Icon | Color | Dark | Light |
|---|---|---|---|---|---|
| Gecko | Tongue Grab (`TongueGrab`) | gecko head with a curled tongue and a round tip | `#5FBF3A` | `#2C6A1A` | `#B6F07A` |
| Bill | Hustle (`Hustle`) | sneaker with three speed lines | `#FF8F1F` | `#94460A` | `#FFD08A` |
| Penguin | Deep Freeze (`DeepFreeze`) | chunky six-armed snowflake | `#3FA9F5` | `#1B4E8C` | `#A8E1FF` (close to `Config.UI.Patience.Frozen`) |
| Alien | Order Rush (`OrderRush`) | UFO with a beam (the faceted UFO from `art/ufo`) | `#9B5CF0` | `#4A2196` | `#D7B8FF` |
| Ghost (draft) | Phase | ghost with a wavy hem | `#4FD1BD` | `#1E7468` | `#C2FFF4` |
| Clown (draft) | Showtime | three juggling balls on a dotted arc | `#F25CA0` | `#8E1F55` | `#FFC2DE` |
| Fire type (draft) | Fire Breath | flame | `#E8382C` | `#7E1409` | `#FFAB8F` |
| Octopus (draft) | Multi-Arm | octopus head with four curled arms | `#5463D8` | `#232C80` | `#BCC5FF` |

Shared images: `Ring.png` and `Plus.png` (already in `art/orders`), plus new white images `Wave.png` (tiling wave
strip, whole-number frequency so the ends match), `Hands.png` and `Nobody.png` (reason badges). All made with a Pillow
script under `art/superskill-ui/` and uploaded as in [`FIGMA-WORKFLOW.md`](../FIGMA-WORKFLOW.md).

## Studio instance tree

Built in Studio through the MCP (never in code). Sizes are Scale relative to `Button` unless noted, so the same tree
works at any size. ZIndex is relative (the ScreenGui uses `ZIndexBehavior = Sibling`). **Code sets** marks properties
the controller overwrites.

```
StarterGui
└─ SkillHUD                 ScreenGui   ResetOnSpawn=false, ZIndexBehavior=Sibling, DisplayOrder = GameInfo's,
   │                                    IgnoreGuiInset=false. Code sets Enabled.
   └─ Button                Frame       Size {0,104},{0,104}, AnchorPoint (1,1), BackgroundTransparency 1.
      │                                 Code sets Position (left of InfoFrame). Never rotate it (it holds RadialRing
      │                                 clipping frames, which stop clipping under rotation).
      ├─ Scale              UIScale     code sets it to screen height / 720 x Hud.DesktopScale
      ├─ Pop                UIScale     code: pop, press, bonk
      ├─ Shadow             Frame       Size {1,0},{1,0}, AnchorPoint (.5,.5), Position (.5,0,.5,7), UICorner (.5,0),
      │                                 BackgroundTransparency .45, ZIndex 1. Code sets BackgroundColor3 (Dark), Size (wobble)
      ├─ Shock              Frame       Size 1x1 centred, BackgroundTransparency 1, UICorner (.5,0), UIStroke
      │                                 Thickness 5, ZIndex 1, Visible false. Code sets Visible, Size, stroke Color/Transparency
      ├─ Ring               Frame       Size 1.26x1.26 centred, BackgroundTransparency 1, ZIndex 2, Visible false (code)
      │  ├─ Track           ImageLabel  Ring.png, Size 1x1, ImageColor3 #1D1B26, ImageTransparency .65
      │  ├─ RingLeft        Frame       Size .5x1, ClipsDescendants, transparent
      │  │  └─ Ring         ImageLabel  Ring.png, Size 2x1, with UIGradient   (as on PlateOrder; Util/RadialRing)
      │  └─ RingRight       Frame       Position (.5,0), Size .5x1, ClipsDescendants, transparent
      │     └─ Ring         ImageLabel  Ring.png, Size 2x1, Position (-1,0), with UIGradient
      ├─ Face               CanvasGroup Size 1x1 centred, AnchorPoint (.5,.5), ZIndex 3. Rounds and clips everything in it.
      │  │                              Code sets BackgroundColor3 (Color or grey) and Size (wobble)
      │  ├─ UICorner                    CornerRadius (1,0)
      │  ├─ UIStroke                    Thickness 4.5 (scale it with the button), ApplyStrokeMode Border. Code sets Color (Dark)
      │  ├─ Shade           ImageLabel  bottom crescent (white image, ImageColor3 black, ImageTransparency .82), Size 1x1.
      │  │                              Color-agnostic, so it works for every character
      │  ├─ Sheen           Frame       Size .68x.34, Position (.16,.07), white, BackgroundTransparency .68, UICorner (.5,0)
      │  ├─ Cooldown        Frame       AnchorPoint (0,1), Position (0,0,1,0), Size (1,0,1,0), BackgroundColor3 #6E7380,
      │  │  │                           ClipsDescendants false. Code sets Size.Y.Scale (same contract as today)
      │  │  └─ Wave         ImageLabel  Wave.png, AnchorPoint (0,1), Position (0,0,0,0) (sits on the top edge),
      │  │                              Size (2,0,.07,0), ImageColor3 #6E7380. Code scrolls Position.X
      │  ├─ Glint           Frame       Size .22x1.4, Rotation 25, white, BackgroundTransparency .45. Code sets Position.X, Visible
      │  └─ Flash           Frame       Size 1x1, white, BackgroundTransparency 1 (code)
      ├─ IconShadow         ImageLabel  Size .6x.6, AnchorPoint (.5,.5), Position (.5,0,.5,4), transparent BG,
      │                                 ImageTransparency .3, ZIndex 4. Code sets Image, ImageColor3 (Dark)
      ├─ Icon               ImageLabel  Size .6x.6 centred, ImageColor3 white, ZIndex 5. Code sets Image,
      │                                 ImageTransparency, Rotation and Position (icon motion)
      ├─ Timer              TextLabel   Size .7x.5 centred, white, ZIndex 6. Drawn in Jersey 15 by BitmapFont
      │                                 (code hides the label's own text, as on Ready-Set-Go). Code sets Text, Visible
      ├─ Sparks             Frame       Size 1x1, transparent, ZIndex 6
      │  └─ Spark1..Spark6  ImageLabel  Plus.png, Size .18x.18, AnchorPoint (.5,.5), Visible false. Code sets Position,
      │                                 Size, Rotation, ImageColor3, ImageTransparency, Visible
      ├─ KeyShadow          Frame       same size and place as Key, offset 4 px down, #1D1B26, UICorner (.26,0), ZIndex 7
      ├─ Key                TextLabel   Size .32x.32, AnchorPoint (.5,.5), Position (.12,.88), BackgroundColor3 #FFF6E6,
      │                                 UICorner (.26,0), UIStroke 3 #1D1B26, ZIndex 8. Code sets Text (as today), Position (sink, hop)
      └─ Blocked            Frame       Size .34x.34, AnchorPoint (.5,.5), Position (.94,.06), BackgroundColor3 #E2483D,
         │                              UICorner (.5,0), UIStroke 3 #1D1B26, ZIndex 8, Visible false (code)
         ├─ Pop             UIScale     code: badge pulse
         ├─ Hands           ImageLabel  Hands.png, Size .7x.7 centred. Code sets Visible
         └─ Nobody          ImageLabel  Nobody.png, Size .7x.7 centred. Code sets Visible

StarterGui.MobileControls
└─ Skill                    TextButton  Text "", BackgroundTransparency 1, AutoButtonColor false, Size in Scale with a
                                        UIAspectRatioConstraint (1), placed on the thumb arc (above). Code sets Visible.
                                        Children: the same tree as Button above, minus Scale, Key and KeyShadow.
```

Notes for the builder:
- Only `Face`, `Cooldown` (and its `Wave`), `Ring`, `Icon`, `Timer` and `Key` are needed for the HUD to work; the rest
  are optional decoration the code skips with a warning, like the combo effects.
- Face shading is two color-agnostic overlays (`Shade`, `Sheen`), so changing a character's color is one Config line.
- A CanvasGroup renders at its own size, so it may look slightly soft at the top of the 1.15 pop; that's 0.1 s and
  fine. Keep it the only CanvasGroup in the button.

## Code: what works today and what needs changes

### Works with the current `SkillController` contract

- `SkillHUD.Enabled` from `ShowSkillHud` and having a superskill; `MobileControls.Skill` visibility.
- `Key.Text` set to the key name.
- `Cooldown` Y-scale fill anchored at the bottom (the liquid), as long as it stays a direct child of `Button` (see
  change 1).
- `Skill` TextButton: `MouseButton1Down` aims or uses, `MouseButton1Up` releases.

With no code change, a builder can make the new tree today and get the colors, icon and the liquid (with `Cooldown`
as a direct child and a square fill), but not the round clipping, states, ring, pops or per-character look.

### Needs code changes (SkillController + Config only; no server, attribute or remote changes)

1. **Find `Cooldown` inside `Face`.** `setCooldownFrame` only looks at direct children. Look in `Face` first, then fall
   back to a direct child, so the CanvasGroup can clip it round.
2. **Stop the old greying.** Today the code writes `Button.BackgroundTransparency` (0.6 / 0), `Key.TextTransparency`
   and the mobile button's `TextTransparency`. The new look keeps `Button` transparent, so these must go, replaced by
   the state renderer.
3. **Per-character look** from a new `Config.UI.SkillHud.Skills[skillName] = { Icon, Color, Dark, Light }`: set
   `Face` color and stroke, `Shadow`, `IconShadow`, `Icon.Image`, ring and spark colors.
4. **A state machine** (Hidden, Ready, Pressed, Aiming, Active, Busy, Cooldown, Unavailable) with a **reason** for
   Unavailable. `updateHud` already computes `unavailable` from several conditions; split them into reasons:
   `HandsFull` (needs empty hands and holding something), `NoTarget` (`CanUse` false, i.e. Order Rush with nobody
   waiting), `Busy` (pending prediction or `IsBusy`).
5. **Active window vs cooldown.** Hustle and Deep Freeze set `SkillCooldown` to Duration + Cooldown at the press, so
   today's fill would drain through the effect too. Add an optional `ActiveWindow(character): (startedAt, endsAt)?` to
   the client skill modules: Hustle reads `HustleUntil`, Deep Freeze `FreezeStartedAt`/`FreezeUntil`, Order Rush its
   chain (`RushStartedAt` + `SkillEffects.RushDuration`), Gecko's aim uses the local `HoldStartedAt` + `HoldLimit`.
   While inside the window: Active with the ring. After it: cooldown fraction = (ReadyAt - now) / (ReadyAt - endsAt),
   so the liquid starts full when the effect ends. All of this reads attributes the server already sets.
6. **Edge events:** the ready pop (fraction above 0 to 0, same character, not on spawn), the refused shake (a press
   while Cooldown or Unavailable, a server `Interrupted`, a rolled-back instant prediction) and the unblock pop.
   The predicted press shows Pressed/Active at once and is corrected by the server data, per the hard rule.
7. **Placement and scale on desktop:** set `Button.Scale` like `InfoFrame.Scale`, and place the button at
   `InfoFrame`'s left edge minus `DesktopGap` (read `InfoFrame.AbsolutePosition` / `AbsoluteSize`, so it follows the
   cards on any screen).
8. **Timer text** with `BitmapFont.Render` (Jersey 15), hidden when the whole cooldown is under `MinCountdown`.
9. **Per-frame animation** (wave scroll, glint, ring, icon motion) in the existing `RenderStepped` that calls
   `updateHud`. Squash goes on `Face` and `Shadow` Size (UIScale is uniform); rotation only on `Icon`, never on
   `Button` or `Ring`.
10. **Config:** a `Config.UI.SkillHud` table holding every number in the [Motion](#motion) section (pop scales and
    times, wobble, flash, sparks, shock, glint interval, press, refuse, ring urgent fraction and color, wave speed, icon
    motion, grey colors, `DesktopSize` 104, `TouchSize` 132, `DesktopGap` 22, `MinCountdown` 1.5) plus `Skills`
    above. `ShowSkillHud` turns on once the new UI is built.

New children the code relies on, beyond today's `Key` and `Cooldown`: `Scale`, `Pop`, `Face`, `Ring` (with the
RadialRing parts), `Icon`, `IconShadow`, `Timer`; optional: `Shadow`, `Shock`, `Sparks`, `Glint`, `Flash`, `Wave`,
`KeyShadow`, `Blocked` (with `Pop`, `Hands`, `Nobody`). **No new attributes, tags, remotes or bindables.** When it's
built: update the SkillHUD and MobileControls rows in `docs/UI-GUIDE.md` and `docs/PLACEHOLDER-UI.md`, and add a
`CHANGELOG.md` line (player-visible).

Sounds (optional, made in Studio): `SkillHUD.Sounds` with `Ready`, `Refused` and `Press` Sound instances; the code
plays them if present.

## Open questions

- **Cancel on mobile:** desktop has no cancel either (letting the hold limit run out cancels). Should dragging the
  finger off the Skill button cancel an aim? Cheap to add and a common mobile pattern.
- **Teammates' superskills:** a small row of teammates' character dots with their own mini cooldown rings (data is
  already on their characters) would help combos like Freeze then Tongue Grab. Out of scope here.
- **Round-end line per character** ("Penguin saved 2 customers", from [characters.md](characters.md)) is separate UI.
