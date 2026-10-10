# Map themes

Status: **proposal** (2026-10-07). Target for the December beta: 3 themes, 6–12 levels.

See also [filipino.md](filipino.md): proposes **Pasko sa Barrio** (a Filipino Christmas map with a brownout mechanic) in place of the Winter Lodge for December.

A **theme** is a look plus one signature environment mechanic. **Levels** are milked from a theme by changing recipes, layout tweaks and which mechanics are on (every mechanic is a level setting in `Config/Levels`).

Rules for a theme:
- **Looks nothing like Overcooked** in a screenshot.
- **Home of one character:** its mechanic plays well with that character. Good for marketing ("the Alien's home turf").
- **One signature mechanic**, introduced in the theme's second level and remixed after that.

## 1. Roadside Diner (Bill's home): the starter

Warm 50s American diner: checkered floor, neon sign, booths, a parking lot outside the door.

Signature mechanic: none at first. This theme teaches the base game and introduces the existing mechanics one at a time.

| Level | Idea |
|---|---|
| 1-1 Opening Day | Base loop only. Doubles as the tutorial. |
| 1-2 Lunch Rush | Table customers and table cash. |
| 1-3 Night Shift | Dark with neon light, dine-and-dashers through the parking lot door. |
| 1-4 Drive-Thru | A drive-thru window: cars pull up and order from outside, on a timer. |

## 2. Space Station Café (the Alien's home)

A round station café with portholes looking at a planet, alien customers, bleepy machines.

Signature mechanic: **airlocks and low gravity.**
- Airlock doors between rooms open and close on a schedule. Plan your route around them (or Phase through, Ghost).
- Low-gravity zones: you float slower, and **thrown items fly much further**, so throwing across the station becomes a real strategy.

| Level | Idea |
|---|---|
| 2-1 Docking Bay | Plain station layout, alien customers. |
| 2-2 Airlock | Doors on a schedule split the kitchen. |
| 2-3 Zero-G Deck | A low-gravity section in the middle of the kitchen. |
| 2-4 Meteor Shower | The station shakes every so often and loose items slide. |

Later: alien customers with strange tag orders ("something green and cold").

## 3. Winter Lodge (the Penguin's home): the holiday map

A cozy snowy mountain lodge: fireplace, string lights, frozen lake outside. Perfect for a December release.

Signature mechanic: **ice and cold.**
- **Ice patches** on the floor: everyone slides (the Penguin is faster, the Ghost floats over them).
- **Cold:** food left out on a counter slowly freezes and has to be reheated. (Optional; test it.)
- Snowballs as throwables? Holiday fun, not essential.

| Level | Idea |
|---|---|
| 3-1 Ski Lodge | Plain lodge, holiday decorations. |
| 3-2 Frozen Lake | Kitchen half on the ice. |
| 3-3 Blizzard | Snow blows through an open door; visibility drops near it. |
| 3-4 Holiday Feast | Big orders, every mechanic on. The finale. |

## Later themes (post-beta updates)

| Theme | Home of | Signature mechanic |
|---|---|---|
| Haunted Mansion | Ghost | Moving furniture, secret doors, flickering lights. Good for an October update. |
| Circus Tent | Clown | Trampolines to bounce across, a crowd that cheers the show. |
| Food Truck | Bill / anyone | The truck turns, and loose items slide across the counters. |
| Volcano Grill | Fire type | Lava vents that cook food (and set things on fire). |
| Underwater Restaurant | Octopus | Currents that push players and items. |

## Order of work

1. Diner first: it's the demo level and the tutorial, and needs no new mechanic.
2. Winter Lodge second: the release is in December. Ice reuses the Penguin's slide code.
3. Space Station third: airlocks and low gravity are new systems, so it's the most work.

If time runs short, ship the beta with Diner + Winter Lodge and add Space Station as the first update.
