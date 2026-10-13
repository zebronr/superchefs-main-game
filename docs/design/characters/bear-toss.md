# Bear: Bear Toss

Status: **built 2026-10-13, not play-tested with 2 players** (from the idea pool; choices made by the user the same day). Job: Mover. Shape: **aimed**. Follows the [general superskill rules](../characters.md#general-superskill-rules) and the [art style](../art-style.md).

## Fantasy

A big, friendly, clumsy chef who solves problems by throwing them. The team's fast lane: it throws a teammate across the kitchen.

## Superskill: Bear Toss

- **Hold Q:** the Bear grabs the nearest teammate in front of it (within grab reach) and lifts them overhead. Both stop moving. A landing ring shows on the floor 15 studs ahead; the movement keys or stick slide it (the game has no mouse aim), and the Bear turns to face it.
- **Release:** the teammate flies in a high arc to the ring, **over counters and stations**. Tall walls still block it: the ring never goes behind one. A ring on a counter top snaps to the nearest open floor.
- **Landing:** the teammate keeps whatever they're holding, slams down as a ragdoll with a dust ring and gets up after 0.6 s (`GetUpTime`). The Bear strikes an "I meant to do that" pose.
- **Who can be grabbed:** any teammate who isn't busy, meaning not chopping, washing or using a superskill. No consent step (the user's choice): fast and clip-able, and a busy player is never pulled out of their work.
- **Nobody in reach:** pressing does nothing and costs no cooldown.
- **Cancel:** releasing with no valid ring puts the teammate down in front of the Bear (1 s cooldown). Sturdy means thrown items don't interrupt the Bear's lift.

## Second use: dine-and-dashers

If no teammate is in reach but a **running dine-and-dasher** is, the Bear catches them on the spot (it pays like a bat catch) and flings their ragdoll much further than the bat does. Only on levels with dine-and-dash turned on (`Config.Levels`). Changed while building: throwing them back to their seat would need customer pathing back to the table for no real gain, so it's an instant, showy catch with a shorter cooldown (8 s).

A solo power lob for held items was considered and dropped (the user's choice, 2026-10-13). See the playtest questions for the solo concern.

## Passive: Sturdy

Always on: thrown items never stagger it, the Penguin's ice never slides it, and other players and customers can't push it. The stable anchor of the kitchen.

## Numbers (start)

| Knob | Start |
|---|---|
| Grab reach | 5 studs, in front |
| Throw range | 6–30 studs |
| Flight time | 0.9 s |
| Arc height | about 9 studs |
| Max aim time | 4 s, then it throws at the current ring |
| Cooldown | 14 s, from the landing |

Strong with a long cooldown: saving it for the right moment is the skill (see [making a superskill matter](../characters.md#making-a-superskill-matter-even-a-dumb-one)).

## Combos

- **Bear + Ghost:** throw a phasing Ghost, and the flight ignores walls too.
- **Bear + Gecko:** the Gecko tongue-grabs an item off a flying teammate, or catches them.
- **Bear + Penguin:** land a teammate on ice and they slide further.
- **Bear + Alien:** throw the Alien toward the dining room right before Order Rush.

## Versus (later)

Throw an opponent away from a contested station (the "not busy" rule still protects someone mid-chop).

## Feel and VFX (art style: squishy, elastic)

- Lift: the Bear squashes down, then stretches up with the teammate; the teammate dangles and wiggles.
- Aim: a white ring on the floor and a white dashed guide (the Gecko tongue guide's look) along the arc from the Bear's hands to it, facing the camera from any side; both glide instead of snapping, and turn red on a blocked spot. The arc peaks 9 studs up.
- Held and flight: the teammate is a floppy ragdoll, lying back across the Bear's arms and squirming, then tumbling head over heels along the arc.
- Landing: big squash and wobble, a ring of dust puffs (round puffs, fed with `:Emit`), a thud.
- The Bear's throw follow-through, then the proud pose.
- Sounds (to list in AUDIO.md when built): lift grunt, whoosh, landing thud, a yelp from the thrown player.

## Implementation notes

- Server data, clients render: the server stores the flight as data on the thrown character (who is flying, StartedAt, From, To). The thrown player's own client moves its character along the arc (it owns its physics); every other client draws the tumble from the same data. The Bear predicts its own lift and throw locally and rolls back if the server refuses.
- The landing ring snaps to open floor with the same kind of search the Ghost's pop-out uses.
- The flying player can't interact, throw or dash until landing.
- It's a teleport-shaped move: once the [movement check](../../RELEASE-TODO.md#movement-check-anti-teleport) is built, the toss must grant the thrown player an allowance for the flight.
- Character model: a stand-in at first, like the Ghost.

## Playtest questions

- **Solo:** with no teammate and no dasher, the Bear has no superskill. Is that OK for a Mover, or does it need a solo use later (e.g. throwing itself)?
- Does throwing teammates feel like help or like griefing? If griefing, try requiring the teammate to walk into the Bear's open arms.
- Is 30 studs too far for the current maps?
