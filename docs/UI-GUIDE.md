# UI guide

How to build, remake or restyle any UI in the game without breaking the code. UIs are made by hand in Studio (they
are not in the repo); scripts find them **by name and type**, so those are the only things you can't change freely.
Everything else (colors, images, strokes, corners, gradients, layout, extra decoration) is yours.

Stand-in UIs still waiting for a remake are listed in [`PLACEHOLDER-UI.md`](PLACEHOLDER-UI.md).

## Golden rules

1. **Keep the names and classes listed below.** A renamed or retyped child is either skipped with a warning in the
   Output or stops the controller with an error. Add anything else you like: extra frames, `UIStroke`, `UICorner`,
   `UIGradient`, decoration images. Code ignores children it doesn't look up.
2. **Code owns `Enabled` on every ScreenGui listed here** and the `Visible`, `Size`, `Position`, `Text`, `Image` or
   color of the specific children marked "code sets". Set those however you want in Studio for previewing; code
   overrides them at runtime. Don't animate them yourself in a LocalScript, because the code is already doing it.
3. **Size in Scale, not Offset**, with a `UIAspectRatioConstraint` where shape matters. Players are on phones and 4K
   screens; offsets break one or the other.
4. **No scripts inside UIs.** All UI behavior lives in `src/client/Controllers`. If a UI needs new behavior, ask
   Claude to add it to the controller.
5. **Tunables live in `src/shared/Config/UI.luau`** (pop times, bounce sizes, bar colors). Change the feel there, not
   by editing code.
6. **Templates are cloned, not shown.** Anything in `ReplicatedStorage.UIs` or `ReplicatedStorage.Assets.UI` is a
   template: code clones it per order, customer or station. Leave the template itself `Enabled`/`Visible` the way
   it's described below.
7. **Images preload automatically.** `PreloadController` downloads everything under `PlayerGui`,
   `ReplicatedStorage.UIs` and `ReplicatedStorage.Assets`, plus recipe icons and font atlases. New images there need
   no extra work.

## Fonts

Use any Roblox font for normal text. For the chunky pixel look (Jersey 15) there is a bitmap font system, because
Roblox can't load custom fonts:

- `src/shared/Util/BitmapFont.luau` draws text from one atlas image: `BitmapFont.Render(font, text, parent, options)`
  fills `parent` with the text (keeps its proportions, pixel-sharp). Options: `Color`, `Transparency`, `Alignment`,
  `ZIndex`, `Name`, `ShadowColor`, `ShadowOffset`.
- To use it on a label you design in Studio, tag the `TextLabel` (or `TextButton`) `BitmapText`. `BitmapTextController`
  hides its own text and draws the bitmap words inside it, following `Text`, `TextColor3`, `TextTransparency` and
  `TextXAlignment`. A `UIStroke` on it (or `TextStrokeTransparency` < 1) becomes the drop shadow color. Most HUD text
  is tagged (list in `docs/TAGS.md`); Ready-Set-Go and the Fever banner draw their own in code. To center text by eye,
  center the white letters on the card and let the shadow hang below (move the label in Studio).
- Edit preview: the tagged labels in `StarterGui` hold a baked `BitmapText` copy (made by Claude through the MCP) and
  `MaxVisibleGraphemes = 0`, so Studio shows the game's look. The baked copy doesn't follow edits: after changing a
  label's text, color or size in Studio, ask Claude to rebake. In game the controller deletes the copy and redraws.
- New font: `python art/fonts/bitmap_font.py <font.ttf> <Name> [px]`, upload the PNG it writes to `art/fonts/`, and
  put the id in `src/shared/Fonts/<Name>.luau`. Pixel fonts must be baked at their native size (Jersey 15 = 27).

## Loading screen (`ReplicatedFirst.LoadingGui`)

Built from the Figma frame "Loading / mobile (Blue (HUD))". `src/first/LoadingScreen.client.luau` clones it into
PlayerGui as `LoadingScreen` the moment the client starts and removes Roblox's default loading screen. The server starts
with no map (an empty place, characters held in place). Until START a gray Roblox-style `Boot` screen shows the logo and
a simple character picker (every player, demo only) and the `Start` button (hosts only). START spins the logo for `BootTime` (a head start for recording), then tells the server,
slides the loading screen in over the boot screen and the server loads the map,
the screen shows the loading, and the round starts by itself once every chef has loaded; then the bar runs up to 100%
(`FillFinishSpeed`), holds for `FinishHold` and the screen slides up. Tuning (step icons, texts, colours, swing, tips) lives in
`Config.Loading`. Everything sits on a 1560x720 `Canvas` that `Scale` (UIScale) fits to the screen. Placeholder.

The four steps: 1 the map has streamed in around the character, 2 assets are preloaded and the client is ready (once the
bar has shown both, it sends `Loaded` on the `Round` remote), 3 every chef has the `Loaded` attribute, 4 the round is
starting. The bar fakes smooth progress: it creeps within a step, never jumps, and runs at most `FillSpeed`, so even an
instant load plays out for a few seconds. Each step runs the bar to the next icon, which lights up when reached.
START shows only for `Config.Round.StartHosts` (anyone in Studio while `StudioAnyoneStarts`), and the server checks the
same list.

| Path | Class | Code does |
|---|---|---|
| `Background.Pattern` | Frame (RelativeYY) | scrolls up-left along its repeat; tiles are free to change if the repeat stays 260x240 design px |
| `Canvas.Scale` | UIScale | fit to the screen |
| `Canvas.Swing` | Frame, size 0 | the pivot at the clip: code drops it in from above and swings its `Rotation` |
| `Swing.Ticket.Kicker`, `Level` | TextLabel | level number and `Title` from `Config.Levels` (`Level` is bitmap) |
| `Swing.Ticket.Menu.Dish` | Frame (template) | cloned per dish (up to `MaxMenu`); `Icon` gets the food image, `Name` the dish name |
| `NewMechanic` | Frame | shown with the level's `NewMechanic`; `Pop` scales the slap; `Name`, `Hint` set |
| `Progress.Fill` | Frame | X scale = progress |
| `Progress.StepN` | Frame | `Ring`, `Inner` colours and `Icon` tint per state; `Pop` on finish; `Check` (green badge with a two-bar tick) pops in |
| `Status` | TextLabel (bitmap) | step text and percent |
| `Party` | Frame | height = header + rows; `Rows.Row` cloned per chef: `Chef` colour, `Name`, `State.Face`/`Shadow`/`Label` READY or ... |
| `Tip.Text` | TextLabel | rotating chef tips (base plus the level's mechanics) |
| `Boot` | Frame (ZIndex 0, under the rest) | the gray screen before START; hidden once the loading screen covers it |
| `Boot.Stage.Scale` | UIScale | fit to the screen (Stage is 1560x720 like `Canvas`) |
| `Boot.Stage.Logo` | Frame | the Roblox-style logo (white tilted square with `Hole`); code spins its `Rotation` after START |
| `Boot.Stage.Chefs.Chef` | GuiButton (template) | cloned per `Config.Character.Selectable` chef: `Face` gets the chef colour, `Shadow` a darker one, `Label` the name, `Face.Selected` (UIStroke) outlines the current pick; `Activated` sends `PickCharacter` |
| `Boot.Stage.Start` | GuiButton | hosts only; `Activated` starts the round (after `BootTime`) |

## Screen UIs (`StarterGui`)

Each one is a `ScreenGui` with this exact name. Indented names are children (only the ones code needs).

### `GameInfo`: coins and timer HUD
Shown during Intro and Playing. Driven by `GameUIController` and `ComboController`. Code sets `InfoFrame.Position`
from `Config.UI.Hud`: bottom-right on PC, bottom-centre on touch screens.

| Path | Class | Code does |
|---|---|---|
| `InfoFrame` | GuiObject | positioned and anchored per device (above); laid out in pixels at 720 px screen height |
| `InfoFrame.Scale` | UIScale | code sets it to screen height / `Config.UI.Hud.DesignHeight` (times the device scale) |
| `InfoFrame.CoinsFrame.TextShadow`, `InfoFrame.TimerFrame.TextShadow` | TextLabel | optional; code copies the coin and timer text into them (drop shadow) |
| `CoinsFrame` | ImageLabel | ZIndex 3, one above `TimerFrame` (2), so the combo badge hanging off its left corner draws over the timer |
| `CoinsFrame.CoinFire` | Frame | the coin burns at x3+ (orange) and x5+ (blue, bigger): a hidden round Frame `Ember` (UICorner 0.5) that code clones into a particle emitter; embers rise from around the coin, taper to a tip, shrink and cool (colors and rates in `Config.UI.Combo`). ZIndex 3: over `CoinSlot` (2), under `CoinSprite` (4) |
| `CoinsFrame.CoinFireFront` | Frame | the embers that burn in front of the coin (`Config.UI.Combo.FireFront*`), so the fire wraps around it. Same size and place as `CoinFire`, empty (embers are cloned from `CoinFire.Ember`), ZIndex 5: over `CoinSprite` (4), under the coin count `TextLabel` (6) |
| `InfoFrame.ComboFire` | GuiObject | combo effects behind the coin card (same size and place as the card). `Sparks` (x2) and `BlueSparks` (x5) hold "+" ImageLabels that twinkle and bob; `Smoke` holds round Frames `Puff1..n` that puff up and fade when the combo breaks |
| `InfoFrame.CoinsFrame.ComboBadge` | GuiObject | `x{n}` combo badge: `Pop` (UIScale), `Face` (tinted per tier from `Config.UI.Combo.BadgeColors`), `Label` (TextLabel, colored per tier from `BadgeTextColors` for contrast), `Shadow`. Sits on the coin card's top-right corner; keep the badge's own Rotation 0 (Roblox stops clipping under a rotated frame, which breaks the `Timer` ring), the lean and shake rotate `Face`, `Shadow` and `Label` instead (`BadgeLean`); code shakes the badge (Position; children's Rotation) harder each tier, and on a break turns it grey, swells, shakes and drops it spinning while fading Face, Label and Shadow |
| `InfoFrame.CoinsFrame.ComboBadge.Timer` | Frame | countdown ring around the badge (the combo window, or the fever, draining): `Track` (ImageLabel, the faint full ring) and `RingLeft`/`RingRight` (clipping Frames with a `Ring` ImageLabel and `UIGradient`, as on the plate order; `Util/RadialRing`). Code sets Visible and the ring color (the badge face color) |
| `GameInfo.Fever` | Frame | fever overlay, full screen, ZIndex 0 (under the HUD). `Glow` holds edge Frames (`Top`, `Bottom`, `Left`, `Right`, each with a UIGradient fading inward); code sets their BackgroundTransparency to pulse. `Banner` (Frame, a copy of the GO banner) with a `TextLabel` drawn in Jersey 15; code sets its Size (pop in and out), Rotation and Visible |
| `InfoFrame.CoinsFrame.ComboLost` | TextLabel | "COMBO LOST!" (or why, or a pink "FEVER OVER!") stamp over the card on a break or fever end: `Pop` (UIScale) and optional UIStroke; code sets Text, TextColor3 (Studio color for breaks), Position (rises from its Studio position), Visible, TextTransparency and the stroke's Transparency |
| `InfoFrame.CoinsFrame.TextLabel` | TextLabel | sets text to the coin count, rolling up on gain (`Config.UI.Coins`) |
| `InfoFrame.CoinsFrame.Pop`, `InfoFrame.CoinsShadow.Pop` | UIScale | the coin card and its shadow squash on gain; both frames are anchored at their centre |
| `InfoFrame.CoinsFrame.CoinSprite` | ImageLabel | plays a spinning-coin sprite sheet (`Gif` util) on gain; frames are cropped to the coin, so keep the label 107:134 (45×56) |
| `InfoFrame.TimerFrame.TextLabel` | TextLabel | sets text to the time left (`m:ss`) |
| `CoinNotification` | TextLabel | template, hidden: cloned into `CoinsFrame` as a floating `+N` on each gain (size and rise in `Config.UI.Coins`) |

### `OrderList`: order plates
Shown with GameInfo. The plates themselves are templates in `ReplicatedStorage.UIs.OrdersUIs` (below).

| Path | Class | Code does |
|---|---|---|
| `list` | Frame | plates are parented here, newest on the left (`LayoutOrder = -orderNumber`): a horizontal, right-aligned `UIListLayout` at the top-right |
| `list.UIScale` | UIScale | code sets it to screen height / `Config.UI.Orders.DesignHeight` (times `TouchScale` on touch) |
| `list.Queue` | GuiObject | the queue strip for orders that don't fit (the row stops at the screen edge, or where Roblox's top-bar buttons end): code keeps it leftmost, sizes it and sets Visible. Holds a `UIListLayout` (code sets its Padding) and a hidden `Entry` template, cloned once per waiting recipe (oldest nearest the plates). Each `Entry` needs `Pop` (UIScale, popped when it appears or its count changes), `Badge.Icon` (ImageLabel, set to the dish's FoodImage) and `Count` (GuiObject, shown from 2 up) with a `Label` (TextLabel, `Config.UI.Orders.QueueCountLabel`). Queued orders reappear as plates when room frees up |

### `ReadySetGo`: round intro
| Path | Class | Code does |
|---|---|---|
| `Ready`, `Set`, `Go` | Frame (any GuiObject) | shows one per second, pops it in and out by scaling its `Size` and tilting `Rotation` (`Config.UI.ReadySetGo`). Keep `AnchorPoint` 0.5, 0.5 so it pops from its centre. Background is the banner; style freely. |
| `Ready.TextLabel` (same for Set, Go) | TextLabel | its text and `TextColor3` are drawn in Jersey 15 bitmap letters; the label's own text is hidden. Change the word or color here. |

### `IntroIris`: opening shot after START
Driven by `IntroController`, timings in `Config.Round.Cinematic`. Keep `IgnoreGuiInset` on, `ScreenInsets` None and a
high `DisplayOrder` so it covers everything.

| Path | Class | Code does |
|---|---|---|
| `Hole` | ImageLabel | black image with the icon cut out (transparent). Code sets its `Size` (Y Scale = screen heights, `SizeConstraint` RelativeYY), so keep `AnchorPoint` 0.5, 0.5 at the screen centre. To change the shape, see `docs/FIGMA-WORKFLOW.md`. |
| `Hole.Top`, `Bottom`, `Left`, `Right` | Frame | black, 20000 px offset frames around the image so the screen stays covered at any size. Not touched by code. |

### `RoundEnd`: results
| Path | Class | Code does |
|---|---|---|
| `Frame.Coins` | TextLabel | counts up to `N coins` |

### `Instructions`
Kept disabled by code. Free to remake or delete the contents; keep the ScreenGui.

### `GameInfo.InfoFrame.Superskill`: superskill card (desktop)
A card left of the timer, in the HUD style: blue card and shadow, white round slot with the superskill's icon in its color, a ring that drains through the cooldown with the seconds left, and a keycap. Shown only on non-touch devices for characters with a superskill. Looks per superskill (icon, color) come from `Config.UI.Superskill.Looks`.

| Path | Class | Code does |
|---|---|---|
| `Pop` | UIScale | press squash and ready pop |
| `Slot.Icon` | ImageLabel | image, color (grey while cooling) and transparency |
| `Slot.RingLeft` / `Slot.RingRight` | Frame | RadialRing halves (each with `Ring` ImageLabel + `UIGradient`): cooldown left |
| `Slot.Time` | TextLabel | seconds left, empty when ready |
| `Key.Label` | TextLabel | key name (`Q`) |

`Shadow`, `Card`, `Slot.Track` and `Key.Shadow`/`Key.Face` are decoration.

### `MobileControls`: touch buttons
Enabled only on touch devices. Layout is prototype A "Thumb Arc" from Figma: the buttons sit in the `Arc` Frame
(bottom-right, `SizeConstraint` RelativeYY so the cluster keeps its shape on every screen). Code finds each button by
name anywhere under the GUI. A button with `Face` and `Shadow` children gets the press effect (Face sinks onto Shadow
while held).

| Path | Class | Code does |
|---|---|---|
| `Interact` | TextButton | click = interact (the big yellow button). Code sets `Face.Label` to what the press would do (`Config.UI.InteractLabels`: GRAB, DROP, PLACE, ADD, SWAP, SERVE, ORDER, COLLECT, TRASH, EMPTY, WASH, CATCH) and hides `Face.Hint` |
| `Use` | TextButton | hold = use (chop, wash, spray) |
| `Dash` | TextButton | click = dash |
| `Throw` | TextButton | click = throw |
| `Skill` | TextButton | hold to aim, release to fire; hidden without a superskill. Child `Superskill` is the same card as `InfoFrame.Superskill` (without `Key`), drawn the same way. |

All five must be `TextButton`s (use an empty `Text` and an image child if you want an icon button).

## World UIs (templates)

### `ReplicatedStorage.UIs.CustomerBubble`: customer speech bubble
`BillboardGui`, cloned onto each customer's `Head`. `CustomerController` animates it (pop, bob, urge shake, frost),
so its own `Size` and `StudsOffset` are the resting values. Children are found **anywhere** in the tree by name.

| Name | Class | Code does |
|---|---|---|
| `Icon` | ImageLabel | shows the dish while the customer waits for food |
| `Alert` | GuiObject | shown while waiting to order |
| `Dash` | GuiObject | the "CATCH!" card on dine-and-dashers |
| `Bar` | GuiObject | patience bar, hidden while dashing |
| `Bar.Fill` | Frame (direct child of `Bar`) | X Scale = patience left; color blends `Config.UI.Patience` green → yellow → red, icy blue when frozen |
| `Bar.Fill.FrostTexture` | ImageLabel (optional) | shown while frozen |
| `Frost` | GuiObject (optional) | icy rim, pops in when frozen, cracks off on thaw |
| `Snowflake` | GuiObject (optional) | snowflake badge, spins while frozen |

Optional ones only warn when missing. A `UIScale` on `Frost` and `Snowflake` is used (or created) for their pops.

### `ReplicatedStorage.UIs.OrdersUIs`: order plate templates
Sizes (plate, trays, slots, gaps) come from `Config.UI.Orders` in pixels at 720 px screen height; code sizes the
clones, so the templates' own sizes don't matter.

| Name | Class | Code relies on |
|---|---|---|
| `PlateOrder` | GuiObject | one order. `Scale` (UIScale), `Body` with `Plate` and `Steps`. `Plate` holds `Glow` (ImageLabel, urgent pulse), `RingLeft`/`RingRight` (each a clipping Frame with a `Ring` ImageLabel and a `UIGradient`: the timer ring), `Face.Dish` (ImageLabel, the dish), `Served` (Frame with `Pop` UIScale, shown when served), `Table` (Frame with `Label` TextLabel, the customer's table; code re-anchors it at its centre to rock it with the dish), `Trail` (speed-line Frames `Line1..n`, shown while the plate drops in), `Sparkles` ("+" ImageLabels around the check, burst out on serve) and `Sweat` (drop ImageLabels `Drop1..n`, fly off while urgent). `Steps` has a `UIListLayout`; trays go in it |
| `StepTray` | GuiObject | one recipe step. `Pop` (UIScale), `Slots` (Frame with a `UIListLayout`; ingredient slots go in it), `Method` (Frame, the cooking-method badge, tinted per method, with `Icon` ImageLabel; hidden for chop-only steps) |
| `StepSlot` | GuiObject | one ingredient: `Ingredient` (ImageLabel) |

The old ticket templates (`smallFrame`, `bigFrame`, `noprocess1slot`, `process2slot`, `process3slot`) are unused and
can be deleted.

### `ReplicatedStorage.Assets.UI`: station popups
| Name | Class | Code relies on |
|---|---|---|
| `ProgressBar` | BillboardGui | Blue slab bar (Figma "Progress indicator" option B, no food icon). `Root` (GuiObject; code sets `Rotation` to shake) with `Scale` (UIScale, the done pop), `Glow` (ImageLabel, code sets `ImageTransparency` for the burn warning), `Face.Track.Fill` (code sets X Scale 0-1, `BackgroundColor3` and `Visible`), `Badge` (code sets `Visible`) with `Face` (tinted like the fill), `Check` and `Bang` (shown when cooked / burning soon). Colors and timing: `Config.UI.Progress`. Parented to the food, pot or sink's `WashPartMarker`, drawn below it (`StudsOffset` Y -1.5, so it doesn't cover the popups above items); hidden once the pot is on fire. |
| `ObjectNotification` | BillboardGui | child `TextLabel`: code sets the message and slides it to `Position` (0.5, 0, 0, 0) |

### Effects with a `SurfaceGui`
`ReplicatedStorage.Assets.Effects.PlayerIndicator` (the ring under your character) needs a `SurfaceGui` child holding
an `ImageLabel`. The TongueGrab guide is in `PLACEHOLDER-UI.md`.

## Remaking a UI, step by step

1. Build the new one next to the old one in Studio. Copy the names and classes from the tables above.
2. Delete the old one and give the new one the exact name.
3. Play-test: watch the Output for `is missing` warnings from the controllers.
4. If it was a placeholder, delete its row in `PLACEHOLDER-UI.md`. If you renamed something on purpose, tell Claude so
   the code and this guide are updated together.
