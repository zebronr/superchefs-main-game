# Characters and superskills

Status: **decided direction.** This is the game's core identity: every character has one superskill and one passive.

## Rules

- **One active superskill** per character, on a cooldown, with its own key and mobile button.
- **Plus one unique passive** (user, 2026-10-07): always on, no key. See [Passives](#passives).
- Each superskill maps to one kitchen *job*. With strangers, your character tells you your role, so nobody has to coordinate who does what.
- Superskills help but never replace the base loop. Every character can still do every task.
- **Superskill upgrades (future feature, not in the MVP):** progression improves the one superskill (e.g. a longer tongue) instead of adding new ones. Superskill docs list upgrade ideas, but nothing is built or tuned for them yet.
- Later, maybe: an ultimate charged by serving orders. Only after the basic superskills feel good.

## General superskill rules

- **Interrupt:** if a thrown item hits you while you're using or aiming a superskill, the superskill is cancelled. Each superskill can override this (ignore it, or react differently).
  - Proposal: an interrupt costs **no cooldown** (it wasn't your fault), and the thrown item is caught normally if your hands are empty. Otherwise teammates could grief by throwing at you.

## Making a superskill matter (even a dumb one)

A silly superskill is fine. A **useless** one isn't. A superskill is useless when the problem it solves rarely comes up, or when using it is never a decision. Ways to fix that:

1. **The game makes the problem.** A superskill is only as useful as the pressure it answers. Showtime is dead weight if patience never runs low; Phase is dead weight in an open kitchen. Levels and systems have to create that pressure (patience, walls, distance, fires, dashers). This ties into the "hero character per level" lever in [principles.md](principles.md#variety-no-same-level-different-skin).
2. **A second use.** Each superskill should touch at least two systems: a main job plus a side use good players find. Deep Freeze also stops fire spread, Tongue Grab also intercepts throws, and Showtime also stops dashers. The side use is where skill expression lives.
3. **A when, not just a button.** Either it's cheap and spammable (Bill), or it's strong with a long cooldown, so saving it for the clutch moment is the skill (Penguin). Avoid the middle: a medium-strength superskill on a medium cooldown just gets pressed on cooldown and forgotten.
4. **Combos with other characters.** A weak superskill becomes great next to a teammate's: Freeze a pot, then Tongue Grab it; Showtime holds a dasher in place while someone catches them. Every new superskill should list at least one combo.
5. **Show what it did.** Players judge usefulness by what they see. Pop up the result ("+4 s patience x3", "Saved!", "Order taken x4"), and give a round-end line per character ("Penguin saved 2 customers"). A superskill that helped invisibly feels like it did nothing.
6. **Juice it.** Big start, clear effect, satisfying end, a sound. A small effect with great feedback feels stronger than a big effect with none (see [art-style.md](art-style.md)).
7. **Lean into the dumb.** Funny is a feature on Roblox: it's what gets clipped. Keep the silly look and add a silly side effect (the Clown's pie in the face), but make the core effect real.
8. **Versus gets its own use.** A modest co-op superskill can be strong in Versus (Hustle to steal a contested station, Showtime to distract the other team's customers).

**The test:** play a round with the superskill turned off. If the team doesn't notice, change the superskill. In order: buff it, add a second use, then rework it.

## Roster (draft)

Gecko, Bill, Penguin and Alien superskills are built (see `CHANGELOG.md`). The rest are proposals. No passives are built yet.

| Character | Superskill | Job | Details |
|---|---|---|---|
| Gecko | **Tongue Grab**: aim and yank an item from far away into your hands | Fetcher | [gecko-tongue-grab.md](characters/gecko-tongue-grab.md) |
| Bill (regular human, starter) | **Hustle**: a few seconds of faster movement plus faster chopping and washing | All-rounder | [bill-hustle.md](characters/bill-hustle.md) |
| Fire type (salamander/dragon) | **Fire Breath**: instantly advances cooking in a pot in front of you | Cook | Overdoing it starts a fire. |
| Penguin | **Deep Freeze**: stomp a frost circle that pauses cook timers, patience and fire spread | Saver | [penguin-deep-freeze.md](characters/penguin-deep-freeze.md) |
| Octopus | **Multi-Arm**: chop or wash 2–3x faster for a few seconds | Prep / dishes | Gives the boring jobs a hero. |
| Alien (teleporter) | **Order Rush**: blink to every waiting customer, take their orders, blink back | Waiter | [alien-order-rush.md](characters/alien-order-rush.md). Replaces the Sprint waiter. |
| Ghost | **Phase**: walk through walls and counters for a few seconds, carrying items | Shortcut runner | [ghost-phase.md](characters/ghost-phase.md) |
| Clown (entertainer; other skins later) | **Showtime**: hold to perform; nearby customers regain patience and dine-and-dashers stop to watch | Entertainer | [clown-showtime.md](characters/clown-showtime.md) |

Mix input shapes across the roster (aimed, instant, zone, self buff, placed) so characters feel different to play.

## Superskill idea pool

Not picked yet. Shape in brackets.
- **Fetching / movement:** Frog Super Leap over counters [aimed]; Mole Tunnel through walls [aimed]; Spider Web Line between two counters, a team zipline for items [placed]; Kangaroo Pouch holds one extra item [instant]
- **Cooking:** Electric Eel Overcharge, nearby stoves cook 2x with more fire risk [aura]
- **Prep / dishes:** Beaver Chomp chops the held item, no board [instant]; Crab Pincer Frenzy chops every nearby counter item [aura]; Otter Splash washes plates and puts out fires in an area [zone]
- **Customers:** Peacock Show Off refills nearby patience [aura]; Owl Foresight reveals the next 3 orders [instant]; Penguin Belly Slide with a plate [aimed]
- **Team support:** Bear Toss throws a teammate across the kitchen [aimed]; Bee Buzz speeds nearby teammates [aura]; Turtle Shell, can't be interrupted, blocks throws [self]
- **Versus chaos:** Monkey Banana Peel makes people drop items [placed]; Skunk Stink Cloud slows enemies [placed]; Magpie Snatch steals from hands [aimed]

Favourites so far: Otter Splash (two systems), Bear Toss (clip-able teamwork), Spider Web Line (changes the kitchen for everyone).

## Passives

Every character has one **passive**: always on, no key. The user rejected plain stat bumps ("10% faster"): a passive must be **unique** to the character.

Rules:
- **Changes how you play**, not just a number. You should notice it working.
- **Fits the fantasy and the job**, and backs up the superskill without repeating it.
- **Visible to others**, so teammates learn what each character does.
- Never something the team *needs*: a lobby without that character must still be fine.

| Character | Passive (proposal) |
|---|---|
| Gecko | **Long Catch:** catches thrown items from twice the normal distance. The team's catcher. |
| Bill | **Double Dash:** two dash charges instead of one. Simple, for the starter. |
| Penguin | **Belly Slide:** its dash is a longer belly slide, and it keeps carrying. (It's already faster on its own ice.) |
| Alien | **Mind Reader:** sees which customers plan to dine and dash (a faint red glow before they run), and sees patience bars through walls. |
| Ghost | **Incorporeal:** never body-blocked; passes through players and customers, and doesn't slip on ice. |
| Clown | **Crowd Pleaser:** plates the Clown serves earn a bigger tip. (Alternative: Pratfall, customers laugh when the Clown slips.) |
| Fire type | **Heatproof:** walks through fire and can pick up a burning pot to move it. |
| Octopus | **Eight Arms:** carries two items at once (e.g. a plate and an ingredient). |

## Unlocking: crates

The user's idea: you can't buy a character directly. You open crates to get them.
- Risk: if paid crates decide which superskills you can use, players will call it pay-to-win, and someone who never pulls the Cook can't play that role.
- Proposal: everyone owns 1–2 starter characters. Character crates are bought with **coins earned in play**, have a **pity counter** (a guaranteed new character after N opens), and give coins back on duplicates. Robux go to cosmetic crates or extra coins.
- Roblox requires games to show the odds for any random item bought with Robux, directly or indirectly. Check the current policy before building this.

## Open questions

- Can two players pick the same character in one round?
- Big Carry (old Bill idea) is free for another character or the idea pool.
