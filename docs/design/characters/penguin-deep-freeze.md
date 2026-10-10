# Penguin: Deep Freeze

Status: **code written and smoke-tested (2026-10-05);** placeholder VFX and a stand-in character model (see HANDOFF). Job: Saver (buys the team time). Shape: **instant zone** around the Penguin. Follows the [general superskill rules](../characters.md#general-superskill-rules) and the [art style](../art-style.md).

## Fantasy

The kitchen is about to fall apart: a pot is about to burn and a customer is about to storm out. The Penguin waddles into the middle, stomps, and **everything nearby freezes in time** for a few seconds.

## Use

- **Press Q** (no aiming). The Penguin stomps, and a frost circle bursts out around it.
- The circle **stays where it was cast**. It doesn't follow the Penguin, so placement is the skill: you walk to the right spot first.
- No hold and no aim. It's the opposite shape from the Gecko, so the two feel different to play.

## What freezes (inside the circle, for the duration)

| Thing | Effect |
|---|---|
| **Cook timers** | Paused. A pot in the green zone stays green (ties into [cooking quality](../cooking-quality.md)). |
| **Customer patience** | Paused for customers inside when it is cast. Their meter turns icy blue. Customers who walk in later are not frozen. |
| **Fire** | Stops spreading and stops getting worse, but **isn't put out**. You still need the extinguisher (or the Otter later). |
| **Dirty plate / order timers** | Paused, if they're inside. |

**Not frozen:** players, chopping, washing (those are "doing" tasks), and items being carried. Freeze only stops *waiting* things, matching the waiting-versus-doing principle.

Items that leave the circle (a pot someone picks up and carries out) unfreeze right away. Items carried *into* the circle while it's active freeze.

## Ice floor (test knob, default on)

- The frozen circle is slippery: **other players slide** a bit when walking on it (less grip, some drift).
- The **Penguin doesn't slip**. It moves faster on ice (a candidate passive: "Penguin is faster on ice").
- This adds a cost and some chaos. If strangers find it annoying, turn it off.

## Numbers (start)

| Knob | Start |
|---|---|
| Radius | 12 studs |
| Duration | 6 s |
| Cooldown | 20 s (from when the freeze ends) |
| Ice floor grip for others | 50% |
| Penguin speed on ice | +15% |

## Interrupt

Casting is instant, so there's nothing to interrupt. Getting hit doesn't end the freeze once it's placed.

## Combos

- **Gecko + Penguin:** freeze a pot in the green zone, then the Gecko tongue-grabs it off the stove at leisure.
- **Fire type + Penguin:** Fire Breath speeds a pot toward green, and the Penguin locks it there.
- **Waiter + Penguin:** freeze a room full of impatient customers while the waiter serves them.

## Versus (later)

Freezing the **enemy's** kitchen would be brutal. Rule: the freeze only affects your own team's pots and customers. The ice floor still makes enemies slip, which is the fun part.

## VFX (art style: squishy, elastic)

- **Stomp:** the Penguin squashes down and pops back up. A snow puff at its feet.
- **Frost burst:** a flat icy ring expands with a wobble overshoot (fast out, settle), leaving a frosty circle decal on the floor. A few snowflake puffs.
- **Frozen things:** pots get a frosty lid with little icicles. Customers are encased in a shivering ice block, and their bubbles frost over with a snowflake. Cook bars and patience meters turn icy blue with a frost texture.
- **Ending:** the last second, the ice cracks (a crack texture on the decal), then shatters into a few small ice chunks that fade. Everything "unpauses" with a little shake.
- **Sound:** a crunchy stomp, a whoosh of cold, and a crack and shatter at the end, so players hear the freeze ending without looking.

### VFX review (2026-10-10, from a screenshot of the first real VFX)

What works: the jagged spiky rim reads as "ice" right away, and the circle size is easy to see.

Improvements, highest impact first. **Do 1 and 2 first:** they make the effect readable at a glance in a busy 4-player kitchen and in the TikTok clip.

1. **Frozen customers must read as frozen.** (Done 2026-10-10: `IceBlock` shell, snap-on, paused animations, shiver, cracks off on thaw. Faceted `IceShell` mesh built in `art/frost/frost.py`, waiting on import.) The blue tint over red shirts looks muddy and purple (sick, not frozen).
   - Encase each customer in a semi-transparent **ice shell or block** with white edge highlights and a few icicles along the bottom. Even a simple glassy box sells it better than a tint.
   - The ice **snaps on** with a squash and overshoot.
   - No idle animation while frozen, just a tiny shiver every couple of seconds.
2. **Freeze the UI bubble too.** (Done 2026-10-10: `Frost` overlay, spinning `Snowflake`, icy bar plus optional `FrostTexture`, frost cracks off on thaw.) Right now the "!" bubble looks exactly the same, so players who watch bubbles can't tell anything happened.
   - Frost on the bubble's corners and a **snowflake icon** next to the patience bar.
   - The bar turns clearly **icy blue with a frost texture** (currently only slightly blue).
   - On thaw, the frost cracks off the bubble so players know the timer is running again.
3. **Show the time left.** (Done 2026-10-10: the first two options, `CrackSpread` and `MeltShrink`; the melt stays outside the gameplay radius.) Nothing shows when the freeze ends. Options, cheapest first:
   - The circle **shrinks or melts in from the rim** over the duration.
   - **Cracks spread** across the decal over the whole duration (not only the last second).
   - A small ring timer above the Penguin.
4. **More contrast in the circle.** It's one flat pale blue that washes out the floor, and the edge blends into a white floor.
   - A **darker blue or cyan line around the rim** so it's clear what's inside.
   - **White streaks** across the surface so it reads as slippery ice, not a puddle or glass.
   - **Lower opacity in the middle**, strongest at the rim, so the floor shows through.
5. **Frost on things inside the circle.** (Done 2026-10-10: `StationFrost` slab on flat-topped stations whose centre is inside, popping in with the spike spread; sink and serving window skipped.) Counters and stations inside get **frost caps or white rims** on top (pots keep the frosty lid above). Today a counter half inside looks untouched, so players can't tell what got frozen.
6. **Atmosphere.** (Done 2026-10-10: `Mist` on the ice, `Snowfall` from `SnowfallHeight`; breath puffs and staggered spikes already existed.)
   - Low **cold mist** drifting over the floor inside the circle.
   - A few slow **snowflakes** falling inside it.
   - **Breath puffs** from frozen customers.
   - **Stagger the rim spikes** popping in around the circle, with a wobble, instead of all at once.
7. **The Penguin.** (Done 2026-10-10: `PenguinGlow` Highlight on the caster, fading with the circle.) It has no feedback of its own. Give it a frosty glow or a small snow puff that lasts the duration, so teammates see who froze things. The real model will help here too.

All of this is client-rendered from the server's freeze data (start time, position, radius), per the predict-every-effect rule. The snowflake and mist scatter can differ per client.

## Playtest questions

1. Does the Penguin player *hold* the superskill for a clutch moment, or just fire it on cooldown? (Clutch use is the goal.)
2. Is 12 studs enough to cover a stove and a few tables, or does the level layout make it useless?
3. Is the ice floor fun chaos or just annoying?
