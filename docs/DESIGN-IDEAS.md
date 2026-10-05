# Design ideas

Backlog for after the parity refactor. Nothing here is decided until it's prototyped and playtested.

Goal: stop being "Overcooked on Roblox". Overcooked is built for 2–4 friends on a couch. Roblox players are mostly strangers in short sessions who come back for progress, flexing and chaos.

## Status

| # | Idea | Status |
|---|------|--------|
| 1 | Superchefs: every character has a super skill | **Yes.** Core identity. Start with 6 characters. |
| 2 | Customers at tables | **Yes.** The user had this idea before the pause. |
| 3 | Meta loop / progression | Persistent restaurant rejected (who owns it among strangers?). See alternatives below. |
| 4 | Versus kitchens | **Yes.** `Teams` in level data was built for this. |
| 5 | Brigade rounds with roles (Head Chef calls orders) | **Yes.** Harder than Overcooked; needs real talking. |
| 6 | Recipe creativity | Liked, but too vague. Concrete version below. |

## Game modes (proposal)

Don't put everything in one mode, but don't split into many modes on day one either. A small player base spread across empty queues kills Roblox games.

**Core (every mode):** super skills, customers at tables (patience, tips, special customers), tag orders mixed in with fixed recipes, plus the existing chop/cook/plate, fire, dirty plates, throwing and dash.

| Mode | Players | What's unique | Launch |
|------|---------|---------------|--------|
| **Co-op Shifts** | 1–4 | Short runs of 3 levels. Between levels the team votes on 1 of 3 kitchen upgrades (resets after the run). Stars per level. New mechanics come in gradually across chapters. | First |
| **Versus** | 2 teams | Mirrored kitchens, shared customers, sabotage by throwing, stealing plates, cross-kitchen Tongue Grab. | Second (Teams already exists) |
| **Brigade** | 8–12 | Only the Head Chef sees tickets and calls them out. Big kitchen, stations far apart. | Weekend or limited-time event at first |

## 1. Superchefs: 6 characters, one super skill each

Rules:
- One active skill per character, on a cooldown, on its own key and mobile button.
- Each skill maps to one kitchen *job*. With strangers, your character tells you your role, so no one has to coordinate who does what.
- Skills help but never replace the base loop. Every character can still do every task.

Draft roster. Only Gecko and Bill exist today; powers and the other four are proposals.

| Character | Skill | Job | Notes |
|-----------|-------|-----|-------|
| Gecko | **Tongue Grab**: yank an item or plate from ~25 studs into your hands | Fetcher | Reuses carry/pickup. Can also steal from the other team in versus. |
| Bill | **Big Carry**: hold up to 3 items or plates at once for a few seconds | Runner | Depends on Bill's look; swap if it doesn't fit. |
| Fire type (salamander/dragon) | **Fire Breath**: instantly advances cooking in a pot in front of you | Cook | Overdoing it starts a fire, so there's a skill element. |
| Ice type (penguin/yeti) | **Deep Freeze**: pauses all nearby cook timers or customer patience for ~6 s | Saver | Good "clutch" moment. |
| Many-armed (octopus) | **Multi-Arm**: chop or wash at 2–3x speed for a few seconds | Prep / dishes | Gives the boring jobs a hero. |
| Fast type (cheetah/hummingbird) | **Sprint**: a few seconds of super speed that also auto-catches thrown items | Waiter | Pairs with #2 (serving at tables). |

Unlocking: **crate system** (user's idea): you can't buy a character directly, you open crates to get them.
- Risk: if paid crates decide which skills you can use, players will call it pay-to-win, and someone who never pulls the Cook can't play that role.
- Proposal: everyone owns 1–2 starter characters. Crates are bought with **coins earned in play**, have a pity counter (a guaranteed new character after N opens), and give coins back on duplicates. Robux go to cosmetic crates or extra coins.
- Roblox requires games to show the odds for any random item bought with Robux, directly or indirectly. Check the current policy before building this.

Open questions:
- Can two players pick the same character in one round?
- First prototype: Gecko's Tongue Grab, since it reuses CarryService and the throw code.

## 2. Customers at tables

- NPCs (already pathing in) sit at tables with patience meters. You carry the plate to *them* instead of a serving window.
- Special customers: VIP critic (big score swing), picky eater (wants a variant), dine-and-dasher (block them).
- Tips scale with speed, so a waiter role is worth having.

## 3. Meta loop: alternatives to a shared restaurant

The problem: among strangers, nobody owns a shared restaurant. Everything persistent has to be **personal**, and anything **shared** has to reset after the run.

- **A. Chef progression (personal).** XP per round. Unlock characters, skill upgrades (e.g. longer Tongue Grab), and a mastery level per character.
- **B. Cosmetics (personal).** Hats, aprons, knife and pan skins, skill effect colors. Gives players something to show off and something to sell.
- **C. Cookbook (personal).** A collection book of every dish you've served, with rare ones. Ties into #6.
- **D. Run upgrades (shared, resets).** Roguelite: a run is several levels. Between levels the team votes on 1 of 3 upgrades (extra stove, faster sink, +5 s customer patience). This is the "upgrade the kitchen" fantasy without the ownership problem.
- **E. Personal restaurant in the Lobby place.** Your own small restaurant you decorate with what you earned, and friends can visit. Never used in rounds, so there's no ownership conflict. Big scope; later.
- **F. Stars and leaderboards (personal).** Stars per level, plus weekly leaderboards per level and mode.

Suggested combo: A + B + C for long-term goals, D for in-session variety. E only if the game takes off.

## 4. Versus kitchens

- Two mirrored kitchens race for the same customers.
- Throwing becomes sabotage: lob bad ingredients into their pot, steal clean plates, or use Tongue Grab across the gap.
- The `Teams` field and TeamService are already there.

## 5. Brigade rounds

- Bigger lobbies (8–12 players).
- Only the **Head Chef** sees the order tickets and has to call them out. Line cooks only see their own station.
- Fits #1: roles from characters, plus a role from the round itself.

## 6. Recipe creativity: a concrete version

- **Ingredient tags:** every ingredient has tags (sweet, sour, spicy, fresh, cooked, ...). The plate system (which already builds names like `salad(mango_cucumber)`) computes a dish's tags.
- **Vague orders:** some customers ask for a description ("something sweet and cooked", "anything with mango") instead of a fixed recipe. Any dish whose tags match satisfies them.
- **Combo bonuses:** some hidden combinations score extra. The first time you serve one, it goes into your Cookbook (#3C).
- Later: a server-wide "dish of the day" to discover.

This builds on systems that already exist (plates and recipes), and it can ship one small piece at a time.
