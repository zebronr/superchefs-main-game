# Ghost: Phase

Status: **first pass built 2026-10-13, not play-tested** (the user's idea, 2026-10-07). Code: `src/server/Skills/Phase.luau`, `src/client/Skills/Phase.luau`, tuning in `Config.Skills.Phase`. Collision: new groups `Bounds` (floors and the map edge) and `GhostPhase` (see [COLLISION-GROUPS.md](../../COLLISION-GROUPS.md)). Character model: a pale stand-in clone of Bill (`ServerStorage.Characters.Ghost`, `StandIn = true`). Wall warp built the same day: the body itself squashes along its heading going into a wall and stretches coming out, then wobbles back (a ring-decal ripple on the wall was tried first and dropped, it looked bad). Effects revamp built 2026-10-13: shrink-and-burst start with a floor ring, a pale blue glow (a faint fill on the player-color Highlight, stronger and drawn through walls while inside one, plus a soft haze emitter `Assets.Skills.Phase.Aura` and a pale PointLight `Assets.Skills.Phase.Glow`; a flat strong fill alone just read as "turned blue"), float with bob and spring lean, body echoes when fast, wall-face puff rings, a speeding-up flicker in the last 1.2 s, and a spit-out stretch when pushed out of a wall (tuning in `Config.Skills.Phase.Visuals`). Not built yet: sounds. Decided in the build: throwing is blocked while phased (a throw from inside a wall would start inside it); interacting was blocked too at first and is allowed since 2026-10-13; dashing works; Phase can't start while chopping or washing. Job: Shortcut runner. Shape: **self buff**. Follows the [general superskill rules](../characters.md#general-superskill-rules) and the [art style](../art-style.md).

## Fantasy

A ghost chef who ignores the kitchen layout: straight through the wall, out to the dining room, back through the counter.

## Superskill: Phase

- **Press Q.** For a few seconds the Ghost goes see-through and walks **through walls, counters and stations**.
- **Carries normally**: whatever you hold phases with you. That's the point: shortcut a plate through the wall.
- **Interacting while phased is allowed** (changed 2026-10-13, `Config.Skills.Phase.CanInteract`): the Ghost can pick up, put down and use stations while phased, also through walls. Throwing stays blocked. (First pass blocked all interacting so the Ghost couldn't grab from counters through walls; set `CanInteract = false` to go back.)
- **Ending inside something:** the Ghost is pushed out to the nearest open floor, with a little "pop". Built: the owning client searches rings around it (preferring the way it was heading) up to `PushOutRadius`; nothing open puts it back where Phase started.
- **Map bounds still apply.** The Ghost can't leave the level or reach places players can't normally stand.
- Interrupt: overrides the general rule. Thrown items pass straight through a phased Ghost.

## Passive: Incorporeal

Always on: the Ghost **never gets body-blocked**. It passes through other players and customers, and it floats, so it doesn't slip on the Penguin's ice. Walls still block it outside Phase. Built: the Ghost is always in the `Phased` group (`Config.Character.Incorporeal`). Deep Freeze has no slippery ice today, so the floating part has nothing to do yet.

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
- **Through a wall:** the Ghost squishes as it enters and stretches as it leaves, then wobbles back like jelly, with a few wisps puffing off the wall face. Built: each client scales the body parts (and the joint offsets, so limbs stay attached) along the heading, client-side only (`Warp*` in `Config.Skills.Phase.Visuals`).
- **End:** a "pop" back to solid with a little bounce.
- **Sound:** a soft "woooo" on start, a wobbly "bloop" when passing through a wall, and a pop at the end.

## Playtest questions

1. Does the Ghost find shortcuts on its own, or forget Phase exists?
2. Does it make walking pointless on any level?
3. Is interacting while phased (through walls) too strong? `CanInteract = false` turns it off.
