# Game modes

Status: **proposal.**

Don't put everything in one mode, but don't launch many modes on day one either. A small player base spread across empty queues kills Roblox games.

**Core (every mode):** super skills, customers at tables, tag orders mixed in with fixed recipes, cooking quality, plus the existing chop/cook/plate, fire, dirty plates, throwing and dash.

| Mode | Players | What's unique | Launch |
|---|---|---|---|
| **Co-op Shifts** | 1–4 | Runs of 3 levels, with a team vote on 1 of 3 kitchen upgrades between levels (resets after the run). Stars per level. Each chapter introduces one new mechanic, which doubles as the tutorial. | First |
| **Versus** | 2 teams | Mirrored kitchens, shared customers, sabotage. | Second (Teams already exists) |
| **Brigade** | 8–12 | Only the Head Chef sees tickets. | Weekend or limited-time event at first |

## Versus kitchens

- Two mirrored kitchens race for the same customers.
- Throwing becomes sabotage: lob bad ingredients into their pot, steal clean plates, or use Tongue Grab across the gap (counters only, never out of hands).
- The `Teams` field in level data and TeamService were built for this.

## Brigade rounds

- Bigger lobbies (8–12 players), a big kitchen with stations far apart.
- Only the **Head Chef** sees the order tickets and has to call them out. Line cooks only see their own station.
- Needs real talking and organizing, so it's harder than Overcooked.
- Roles come from characters, plus one role from the round itself.

## Open questions

- Is Co-op Shifts the main mode, or does the `CoOp/Chapter1/...` campaign look different?
