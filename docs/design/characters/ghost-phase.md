# Ghost: Phase

Status: **design draft** (the user's idea, 2026-10-07). Job: Shortcut runner. Shape: **self buff**. Follows the [general superskill rules](../characters.md#general-superskill-rules) and the [art style](../art-style.md).

## Fantasy

A ghost chef who ignores the kitchen layout: straight through the wall, out to the dining room, back through the counter.

## Superskill: Phase

- **Press Q.** For a few seconds the Ghost goes see-through and walks **through walls, counters and stations**.
- **Carries normally**: whatever you hold phases with you. That's the point: shortcut a plate through the wall.
- **No interacting while phased.** Otherwise the Ghost could grab from counters through walls. Interact comes back the moment the phase ends.
- **Ending inside something:** the Ghost is pushed out to the nearest open floor, with a little "pop".
- **Map bounds still apply.** The Ghost can't leave the level or reach places players can't normally stand.
- Interrupt: overrides the general rule. Thrown items pass straight through a phased Ghost.

## Passive: Incorporeal

Always on: the Ghost **never gets body-blocked**. It passes through other players and customers, and it floats, so it doesn't slip on the Penguin's ice. Walls still block it outside Phase.

## Numbers (start)

| Knob | Start |
|---|---|
| Duration | 4 s |
| Cooldown | 12 s (from when Phase ends) |
| Move speed while phased | normal |

## Level design note

Like the Gecko's range, Phase can make a layout pointless if the level is built around long walks around walls. Playtest on a level with a wall between the kitchen and the dining room: the Ghost should feel clever there, not mandatory.

## Combos

- **Dine-and-dash:** the Ghost cuts straight through the wall to head off a runner (see [dine-and-dash.md](../dine-and-dash.md)).
- **Alien + Ghost:** the Alien takes the orders, the Ghost phases the plates out.

## Versus (later)

Phasing into the enemy kitchen would be strong. Options: the wall between kitchens can't be phased, or phase ends early inside enemy territory.

## VFX (art style: squishy, elastic)

- **Start:** the Ghost wobbles like jelly and fades to see-through, with a puff of wisps.
- **During:** a soft wavy shimmer, wisps trailing behind, held items also translucent.
- **Through a wall:** the wall ripples where the Ghost passes (a ripple decal that spreads and fades). The Ghost squishes as it enters and stretches as it leaves.
- **End:** a "pop" back to solid with a little bounce.
- **Sound:** a soft "woooo" on start, a wobbly "bloop" when passing through a wall, and a pop at the end.

## Playtest questions

1. Does the Ghost find shortcuts on its own, or forget Phase exists?
2. Does it make walking pointless on any level?
3. Is "no interacting while phased" frustrating?
