# Clown: Showtime

Status: **design draft** (the user's idea, 2026-10-07). Job: Entertainer (keeps customers happy). Shape: **channel** (hold to keep it going), a shape no other character uses yet. Follows the [general superskill rules](../characters.md#general-superskill-rules) and the [art style](../art-style.md).

## Fantasy

The dining room is getting angry. The Clown jumps on the spot, juggles, honks a horn, and everyone nearby forgets how long they've waited.

## Superskill: Showtime

- **Hold Q** to perform. Release to stop. There's a max duration.
- The Clown **stands still** and juggles. Empty hands: juggling balls. Holding an item: it juggles **that item** (funny, and safe: it never drops it).
- **Customers in range regain patience** every second while the show runs.
- **Dine-and-dashers in range stop and watch** the show while it runs, plus a short moment after. That's the Clown's answer to runners (see [dine-and-dash.md](../dine-and-dash.md)).
- Cooldown starts when the show ends, and scales with how long it ran (a short show = a short cooldown).
- **Interrupt:** default rule. A thrown item that hits the Clown ends the show, with a pie-in-the-face reaction.

## How it differs from the Penguin

- **Penguin Deep Freeze:** instant, a zone in the kitchen *or* dining room, **pauses** everything waiting (pots, patience, fire). Short and clutch.
- **Clown Showtime:** channelled, dining room, **refills** patience only. The Clown gives up their own time to buy the team time.

## Passive: Crowd Pleaser

Always on: plates the **Clown serves** earn a bigger tip. Watching the show is part of the meal.

Fun alternative to test: **Pratfall.** When the Clown slips (Penguin ice, later banana peels), nearby customers laugh and gain patience.

## Numbers (start)

| Knob | Start |
|---|---|
| Range | 15 studs |
| Patience refill | +10% of max per second |
| Max show length | 5 s |
| Dasher "watching" after the show | 1.5 s |
| Cooldown | 4 s per second of show, minimum 6 s |
| Crowd Pleaser tip bonus | +25% |

## Skins

The character is "an entertainer". The Clown is the default look; other entertainer skins can reuse the same superskill later as cosmetics: a stage magician (vanishing cards), a DJ (a little speaker and dancing), a mime.

## VFX (art style: squishy, elastic)

- **Start:** a honk and a spotlight cone drops from above onto the Clown.
- **During:** juggling arcs with squash on each catch, confetti puffs on the beat, customers in range clap with "HAHA" bubbles popping above them, their patience bars refilling with a green sparkle.
- **Dashers watching:** they stop mid-sprint, turn, and clap, with a little "!?" first.
- **Interrupted:** a pie splat on the Clown's face, the spotlight snaps off.
- **Sound:** a horn honk, a short circus loop while it runs, applause when it ends.

## Playtest questions

1. Is standing still worth it, or does the team feel one player short?
2. Does it overlap the Penguin in practice?
3. Is a clown fun or creepy to Roblox players? (If creepy, swap the default skin.)
