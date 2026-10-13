# Audio list

Every sound the game needs, made or not. Add a row whenever a feature needs a sound; update the status when one
lands. Sounds live in `SoundService.SoundEffects` (made in Studio), named as in the **Name** column.

Status: **have** (a sound we keep), **stand-in** (a placeholder to replace), **missing**.
Demo: ✔ = needed for the demo video (~Nov 10–15).

Style: cartoon, bouncy and short, to match the squishy art (see [design/art-style.md](design/art-style.md)). Pitch
shift a little per play so repeats don't sound robotic. Like visuals, sounds of the player's own actions play at
once on their client (predicted); everyone else hears them from the server's data.

Today every server sound goes through `EffectService.PlaySound` (only `Interact`), and nothing is predicted yet.
Wiring the new sounds should move each one to the client that renders that effect.

## Kitchen actions

| Name | When | Idea | Status | Demo |
|---|---|---|---|---|
| `Interact` | pick up, put down, plate food, ladle | soft pop / tap | have (generic, used for everything) | ✔ |
| `Pickup` | an item lifts into your hands | light "fwip" | missing | ✔ |
| `PutDown` | an item lands on a counter | wooden clack | missing | ✔ |
| `Plate` | food goes onto a plate / combines | ceramic clink + squish | missing | ✔ |
| `Throw` | an item is thrown | whoosh | missing | ✔ |
| `Land` | a thrown item lands (counter, floor, caught) | thud / soft bounce | missing | ✔ |
| `Chop` | each chop tick | knife on board | have | ✔ |
| `Scrub` | each wash tick | squeaky scrub + bubbles | missing | ✔ |
| `PlateClean` | a plate finishes washing | sparkle "ting" | missing | ✔ |
| `Trash` | something goes in the bin | rustle thunk | missing | |
| `Dash` | a dash | quick whoosh | missing | ✔ |
| `Footsteps` | walking / running | soft taps, faster while running | missing (Roblox default) | |

## Cooking and fire

| Name | When | Idea | Status | Demo |
|---|---|---|---|---|
| `PotAdd` | an ingredient goes into a pot | plop / splash | missing | ✔ |
| `Bubbling` (loop) | a pot is cooking | gentle simmer, louder near done | missing | ✔ |
| `PanSizzle` (loop) | a pan is frying (the burger patty) | hot-oil sizzle, crackle near done | missing | |
| `CookDone` | a pot finishes | bright "ding" (the cooking-quality chime) | missing | ✔ |
| `BurnWarning` (loop) | the burn warning (the orange "!") | rising sizzle + beeping | missing | ✔ |
| `CatchFire` | a pot catches fire | whoomph | missing | ✔ |
| `Fire` (loop) | while something burns | crackle | missing | ✔ |
| `Extinguisher` (loop) | spraying | hiss spray | missing | ✔ |
| `FireOut` | a fire goes out | sizzle + puff | missing | ✔ |

## Orders, customers and coins

| Name | When | Idea | Status | Demo |
|---|---|---|---|---|
| `OrderIn` | a customer's order is taken (the squash puff at the table; `OrderTakeController`, predicted for the presser, from `CustomerState` for everyone else) | paper ticket "fwip" + soft pop, or a ticket "ding" | missing (Sound exists in `SoundEffects`, SoundId empty; code plays it once one is set) | ✔ |
| `OrderWarning` | an order is about to run out | tick-tock / nervous beep | missing | |
| `OrderFailed` | an order runs out | sad trombone blip | missing | |
| `Serve` | an order is served | cash register "cha-ching" | missing | ✔ |
| `Coins` | coins fly into the counter | coin clinks, one per coin | missing | ✔ |
| `ComboUp` | the combo tier goes up | rising chime, higher each tier | missing | ✔ |
| `ComboBreak` | the combo breaks | fizzle "pfff" | missing | |
| `FeverStart` / `FeverEnd` | fever mode | fanfare sting / wind-down | missing | ✔ |
| `CustomerArrive` | a customer walks in | door bell | missing | |
| `CustomerAngry` | patience gets low | grumble | missing | |
| `CustomerEat` | a customer eats | munch | missing | |
| `TableCash` | picking up table cash | coin scoop | missing | |
| `DashAlarm` | a dine-and-dasher runs | short alarm (everyone hears it) | missing | |
| `BatSwing` / `Bonk` | the bat swing, and the hit | whoosh / big cartoon bonk | missing | |

## Round flow

| Name | When | Idea | Status | Demo |
|---|---|---|---|---|
| `Ready` / `Set` / `Go` | the start banners | two beeps then a horn | missing | ✔ |
| `TimerTick` | the last 10 s of the round | clock ticks, faster at the end | missing | ✔ |
| `RoundEnd` | time's up | whistle | missing | ✔ |
| `Stars` | the results stars pop in | one rising "ding" per star | missing | |
| `ButtonClick` / `ButtonHover` | UI buttons (START, menus) | soft click / tick | missing | |

## Superskills

| Name | When | Idea | Status | Demo |
|---|---|---|---|---|
| `SkillReady` | the superskill card refills | short bright chime | missing | ✔ |
| `SkillRefused` | pressing Q when you can't | dull bonk | missing | |
| `TongueThwip` / `TongueSplat` / `TonguePop` / `TongueWhiff` | Gecko: shoot, stick, item arrives, miss | thwip / wet splat / pop / limp "bwomp" | missing | ✔ |
| `HustleStart` / `HustleEnd` | Bill: start, end | "hup!" + whoosh / breath out | missing | ✔ |
| `FreezeStomp` / `FreezeWhoosh` / `FreezeCrack` / `FreezeShatter` | Penguin: stomp, cold, last second, end | crunchy stomp / cold whoosh / crack / shatter | stand-in (see RELEASE-TODO) | ✔ |
| `UfoArrive` / `UfoBeam` / `UfoZip` / `UfoDone` | Alien: drop in, beam up, each table (pitch rising), back | hum / beam / sci-fi zip / register ding | missing | (if the Alien is in the demo) |
| `PhaseStart` / `PhaseWall` / `PhaseEnd` | Ghost: start, passing through a wall, end | soft "woooo" / wobbly bloop / pop | missing | |
| `BearLift` / `BearThrow` / `BearYelp` / `BearLand` | Bear: lift, throw, the thrown player (their client), landing | grunt / whoosh / "wahoo!" yelp / thud | missing | |

## Music and ambience

| Name | When | Idea | Status | Demo |
|---|---|---|---|---|
| `MusicLobby` | lobby | chill, light | missing | |
| `MusicRound` | during a round | upbeat kitchen tune, tempo up in the last 30 s | missing | ✔ |
| `MusicFever` | fever mode | a hotter layer over the round music | missing | |
| `MusicResults` | results screen | short jingle | missing | |
| `KitchenAmbience` (loop) | in a round | low kitchen hum, sizzles, distant chatter | missing | |

The demo video's own music is picked separately (royalty-free, see [marketing/tiktok-edit.md](marketing/tiktok-edit.md#music)).
