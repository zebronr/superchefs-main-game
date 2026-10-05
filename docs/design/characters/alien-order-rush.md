# Alien: Order Rush

Status: **code written and smoke-tested (2026-10-05);** placeholder VFX and a stand-in character model (see HANDOFF). The user's idea. Job: Waiter (order taking). Shape: **instant chain**. The character is a **little alien** (not an animal). Follows the [general skill rules](../characters.md#general-skill-rules) and the [art style](../art-style.md).

## Fantasy

The dining room is full of customers waving for service. The Alien vanishes in a UFO beam, blinks from table to table taking every order in a flash, and pops back to the kitchen before anyone notices.

## Use

- **Press Q** (no aiming). Only works if at least 1 customer is waiting to order; otherwise the button is greyed out.
- The Alien blinks to each waiting customer in turn, takes their order very fast (~0.3 s each), then **blinks back to where it started**.
- **Order of visits:** lowest patience first, so the most urgent customers are served first.
- **Cap:** up to 4 customers per use (raising the cap is a candidate for skill upgrades, a future feature).
- While the chain runs, the player has no control. It's short (a 4-table chain takes ~1.5 s).
- Anything in your hands stays in your hands.

## Why it returns to the start

The skill saves the walk to the dining room *and back*. Returning keeps the Alien in the kitchen, so it's a pure time-saver and doesn't strand them across the map.

Variant to test: end at the **last table** instead. That's better if the Alien is also the one serving food.

## Camera

Teleporting the camera 4 times in 1.5 s would be disorienting. The camera **stays where the skill was used**. The player watches their own afterimages pop up at each table, and the order tickets appear one by one. *(Changed 2026-10-05: with the UFO there are no jumps, so the camera eases along after the UFO instead.)*

## Interrupt

**Overrides the general rule:** once the chain starts it can't be interrupted. The character "isn't there" to get hit. Thrown items pass through the empty spot.

## Numbers (start)

| Knob | Start |
|---|---|
| Max customers per use | 4 |
| Time per customer | 0.3 s |
| Cooldown | 25 s |
| Order of visits | Lowest patience first |

The cooldown is long because the value scales with how many tables are waiting. Tune it once tables and patience exist.

## Synergy and overlap

- **Penguin + Alien:** freeze a room of impatient customers, then take every order in one blink.
- **Overlaps with Parrot Squawk** (take all orders at once). This replaces it; don't build both.
- Replaces the "Fast type: Sprint" waiter in the draft roster.

## Versus (later)

If customers are shared between teams, taking an order claims that customer for your team. This skill would claim 4 at once, which is very strong. Options: a lower cap in Versus, or only customers on your side of the room.

## VFX (art style: squishy, elastic, with a UFO-beam theme)

**Built (2026-10-05):** a UFO hovers above instead of blink-teleporting. It drops in and beams the Alien up, flies from customer to customer leaning into each flight, beams a see-through copy down beside each one (sparkle on landing) and back up, returns, beams the Alien down and zips off. The copy lands at a clear waiter spot beside each customer and faces them. Your own camera follows your UFO and eases back when it leaves. Mesh: `art/ufo/`. The bullets below are the original sketch; the streak trail was dropped (the UFO's flight shows the path).

- **Vanish:** a soft green beam drops onto the Alien from above. It squashes thin and tall, gets sucked up the beam with a pop and a puff.
- **Each table:** a short beam flashes down and an afterimage of the Alien appears for an instant (a translucent green-tinted copy), with a sparkle burst. The order ticket pops out above the customer with a bouncy scale (1.3x, then settle).
- **Between tables:** a light streak trail drawn from table to table, so other players can see the path.
- **Return:** a final beam drops it back in, stretched tall, then it wobbles down to normal.
- **Sound:** a sci-fi zip per blink, with the pitch rising each table (a satisfying combo feel), and a cash-register ding at the end.

## Character look

A **little alien** chef: big head and eyes, small body, antennae that wobble (secondary motion, per the art style). Green beam colour in config, so beam colours can be cosmetic skins later.

## Playtest questions

1. Does it feel amazing at 4 tables and useless at 1? (If so, the minimum or the cooldown needs work.)
2. Is losing control for ~1.5 s okay, or does it feel like a cutscene?
3. Does the Alien end up as "the order button" and nothing else between cooldowns?
