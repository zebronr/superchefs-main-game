# Dine-and-dash: noticing and catching

Status: **proposal** (2026-10-07). The base mechanic is built: a dasher sprints for the door with a red outline and a "CATCH!" bubble, and you press interact to catch them. It's a level setting (`Customers.DashChance`). The user plans a baseball bat and animation.

Problem: runners are hard to notice and hard to reach, especially while you're busy in the kitchen.

## 1. Noticing (the floor: everyone gets this)

- **A tell before the run:** for a couple of seconds before standing up, the dasher looks around nervously, sweats, glances at the door, and shows a small eyes or sweat icon. Sharp players see it coming. This is the most important fix: it turns a surprise into a read.
- **An alarm when they run:** a short alarm sound for everyone, and the **exit door flashes red**.
- **An off-screen arrow:** a red arrow at the screen edge pointing to the runner while they're off-screen.
- Readability rule: a missed runner should always be "I saw it and didn't make it," never "what happened?".

## 2. Catching (the floor: everyone gets this)

- **Throw anything at them.** A thrown item that hits a runner **stuns them** for a moment, and then anyone can catch them with interact. This uses the throwing system you already have, so even a player stuck at the stove can help with a tomato.
- **The bat (user's plan):** a tool you grab from a spot near the door, like the extinguisher. Swing it to stop a runner from a bit further than interact range.
- The stun is short, so someone still has to walk over and catch. It's teamwork, not one button.

## 3. Every character has an answer (the ceiling)

| Character | Answer to a runner |
|---|---|
| Gecko | **Tongue-grab the runner** and yank them back. (Very clip-able.) |
| Penguin | The freeze zone stops them, and the ice makes them slide. |
| Ghost | Phase through the wall to cut them off. |
| Clown | Runners in range stop and watch the show. |
| Alien | Passive Mind Reader sees who's planning to run before they stand up. |
| Bill | Hustle to outrun them. |

That's a good design test for any new character: what do they do about a runner?

## Tuning

- What's lost when a runner escapes: only their payment, never a failed level.
- Starter levels have dashing off (level setting). It's introduced in a later level, together with the tell, the alarm and the throw-stun.

## Numbers (start)

| Knob | Start |
|---|---|
| Tell duration before running | 2.5 s |
| Throw-stun duration | 1.5 s |
| Bat range | 7 studs |
