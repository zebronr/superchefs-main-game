# Characters and super skills

Status: **decided direction.** This is the game's core identity, starting with 6 characters.

## Rules

- **One active skill** per character, on a cooldown, with its own key and mobile button.
- Proposal: **plus one small passive** (about 10% better at something), added once the roster is designed. The prototype is skill-only.
- Each skill maps to one kitchen *job*. With strangers, your character tells you your role, so nobody has to coordinate who does what.
- Skills help but never replace the base loop. Every character can still do every task.
- **Skill upgrades (future feature, not in the MVP):** progression improves the one skill (e.g. a longer tongue) instead of adding new ones. Skill docs list upgrade ideas, but nothing is built or tuned for them yet.
- Later, maybe: an ultimate charged by serving orders. Only after the basic skills feel good.

## General skill rules

- **Interrupt:** if a thrown item hits you while you're using or aiming a skill, the skill is cancelled. Each skill can override this (ignore it, or react differently).
  - Proposal: an interrupt costs **no cooldown** (it wasn't your fault), and the thrown item is caught normally if your hands are empty. Otherwise teammates could grief by throwing at you.

## Roster (draft)

Only Gecko and Bill exist today. The other four are proposals.

| Character | Skill | Job | Details |
|---|---|---|---|
| Gecko | **Tongue Grab**: aim and yank an item from far away into your hands | Fetcher | [gecko-tongue-grab.md](characters/gecko-tongue-grab.md) |
| Bill (regular human, starter) | **Hustle**: a few seconds of faster movement plus faster chopping and washing | All-rounder | [bill-hustle.md](characters/bill-hustle.md) |
| Fire type (salamander/dragon) | **Fire Breath**: instantly advances cooking in a pot in front of you | Cook | Overdoing it starts a fire. |
| Penguin | **Deep Freeze**: stomp a frost circle that pauses cook timers, patience and fire spread | Saver | [penguin-deep-freeze.md](characters/penguin-deep-freeze.md) |
| Octopus | **Multi-Arm**: chop or wash 2–3x faster for a few seconds | Prep / dishes | Gives the boring jobs a hero. |
| Alien (teleporter) | **Order Rush**: blink to every waiting customer, take their orders, blink back | Waiter | [alien-order-rush.md](characters/alien-order-rush.md). Replaces the Sprint waiter. |

Mix input shapes across the roster (aimed, instant, zone, self buff, placed) so characters feel different to play.

## Skill idea pool

Not picked yet. Shape in brackets.
- **Fetching / movement:** Frog Super Leap over counters [aimed]; Mole Tunnel through walls [aimed]; Spider Web Line between two counters, a team zipline for items [placed]; Kangaroo Pouch holds one extra item [instant]
- **Cooking:** Electric Eel Overcharge, nearby stoves cook 2x with more fire risk [aura]
- **Prep / dishes:** Beaver Chomp chops the held item, no board [instant]; Crab Pincer Frenzy chops every nearby counter item [aura]; Otter Splash washes plates and puts out fires in an area [zone]
- **Customers:** Peacock Show Off refills nearby patience [aura]; Owl Foresight reveals the next 3 orders [instant]; Penguin Belly Slide with a plate [aimed]
- **Team support:** Bear Toss throws a teammate across the kitchen [aimed]; Bee Buzz speeds nearby teammates [aura]; Turtle Shell, can't be interrupted, blocks throws [self]
- **Versus chaos:** Monkey Banana Peel makes people drop items [placed]; Skunk Stink Cloud slows enemies [placed]; Magpie Snatch steals from hands [aimed]

Favourites so far: Otter Splash (two systems), Bear Toss (clip-able teamwork), Spider Web Line (changes the kitchen for everyone).

Passive ideas: Gecko walks faster on wet floor, the Ice type's plates stay fresh longer, the Octopus carries dirty plate stacks without slowing down, the Fire type ignores stove fire knockback.

## Unlocking: crates

The user's idea: you can't buy a character directly. You open crates to get them.
- Risk: if paid crates decide which skills you can use, players will call it pay-to-win, and someone who never pulls the Cook can't play that role.
- Proposal: everyone owns 1–2 starter characters. Character crates are bought with **coins earned in play**, have a **pity counter** (a guaranteed new character after N opens), and give coins back on duplicates. Robux go to cosmetic crates or extra coins.
- Roblox requires games to show the odds for any random item bought with Robux, directly or indirectly. Check the current policy before building this.

## Open questions

- Can two players pick the same character in one round?
- Big Carry (old Bill idea) is free for another character or the idea pool.
