# Penguin: Deep Freeze

Status: **code written and smoke-tested (2026-10-05);** placeholder VFX and a stand-in character model (see HANDOFF). Job: Saver (buys the team time). Shape: **instant zone** around the Penguin. Follows the [general skill rules](../characters.md#general-skill-rules) and the [art style](../art-style.md).

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
| **Customer patience** | Paused. Their meter turns icy blue. |
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
- **Frozen things:** pots get a frosty lid with little icicles. Customers get an ice-blue tint and a tiny "brr" shiver. Cook bars and patience meters turn blue with a frost texture.
- **Ending:** the last second, the ice cracks (a crack texture on the decal), then shatters into a few small ice chunks that fade. Everything "unpauses" with a little shake.
- **Sound:** a crunchy stomp, a whoosh of cold, and a crack and shatter at the end, so players hear the freeze ending without looking.

## Playtest questions

1. Does the Penguin player *hold* the skill for a clutch moment, or just fire it on cooldown? (Clutch use is the goal.)
2. Is 12 studs enough to cover a stove and a few tables, or does the level layout make it useless?
3. Is the ice floor fun chaos or just annoying?
