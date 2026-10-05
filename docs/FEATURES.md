# Features

Planned features for the main game, written up enough to build. Broader brainstorming lives in `DESIGN-IDEAS.md`.

## Dine-and-dashers

Builds on Manual serve mode (customers at tables). Expands the "dine-and-dasher" special customer from `DESIGN-IDEAS.md` #2.

**The bit:** some customers eat, then jump up and sprint for the exit without paying. Someone has to drop what they're doing and chase them down. It's meant to be funny and chaotic, a "someone get him!" moment in the middle of a rush.

**Flow:**
1. A normal customer orders and is served. With a small chance per customer, they're a dasher. Maybe add a subtle tell: shifty eyes, a glance at the door, or a different bubble.
2. Partway through eating (or right after), they leap up with a funny yelp and run for `CustomerSpawn`. They're faster than a normal walk and zig-zag a bit, but a player can still catch them.
3. A player catches them by touching them or pressing interact near them. The dasher gets caught with a comedic animation and pays, maybe with a bonus tip as an "apology".
4. If they reach the exit, the team loses that order's coins (or never got them), and a "DINED AND DASHED!" notification appears.

**Open questions:**
- When do coins get paid? Today it's on serve. For dashers, either hold payment until the meal finishes, or take it back when they escape.
- How do you catch one? Touch, interact, a dash-tackle (the existing dash), or a thrown item that knocks them over. Throwing a tomato at a runner fits the game.
- Do they leave the plate behind, or run off with it so the team loses a plate?
- How often? Rare at first, more in later levels, maybe a "dasher gang" event.
- Super-skill ties: Gecko's Tongue Grab yanks them back; the Sprint character is the natural chaser.

**Builds on:**
- `CustomerService` state machine: add a `Dashing` state after `Eating`.
- `walkTo` toward `CustomerSpawn`, at a higher `WalkSpeed`.
- `ThrowService` and the dash, for catching.
- The customer bubble: a "$!" or an angry icon while running.
