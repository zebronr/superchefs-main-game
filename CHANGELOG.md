# Changelog

Versions are git tags (`vMAJOR.MINOR.PATCH`). The rules are in `docs/VERSIONING.md`.

## Unreleased

- The round waits for a START button, so it begins only once you have loaded. Ready-Set-Go now actually shows: READY?, SET and GO! as crisp Jersey 15 pixel words on red, orange and green banners, each word popping in and shrinking away.
- Recipe icons and the Ready-Set-Go font now preload with the first assets, so they no longer pop in the first time they show.
- Frozen customer bubbles have one snowflake badge instead of five snowflakes.
- Table customers now leave their payment as a pile of coins and cash beside the plate; picking up the plate (or the table, once the plate is gone) collects the coins too. The cash pops onto the table and flies to whoever grabs it.
- Some customers dine and dash: they sprint for the door with a red outline and a "CATCH!" bubble. Chase them down and press interact to make them pay before they get away; caught runners burst into cash.
- Table cash and dine-and-dashers are level settings, on in the test tables level only, so later levels can introduce them one at a time.
- Nothing you carry can snag on a wall and pin you in place anymore: a stack of dirty plates and every part of a held item (like the fire extinguisher's nozzle) pass through walls like the item in your hands.

- New customer bubble design, matching the order tickets: a soft blue card with a tail, the dish in a white slot and a flat patience bar. Frozen customers get an icy rim and a snowflake badge; dine-and-dashers get a red "CATCH!" card.
- Customer bubbles are alive: they pop in with a squish, bounce when the order changes, float while waiting, pulse and shake when patience runs low, hold still while frozen, and shrink away when done.
- A customer's speech bubble and patience bar no longer go missing when they load in before their head, or after you walk away and come back.
- The table a customer just ate at can be used again, so you can pick up their dirty plate.

- Three new superskills (key `Q`), all instant and predicted locally:
  - Bill's Hustle: 5 s of +30% walk speed and +50% chopping and washing speed, usable while carrying or working.
  - The Penguin's Deep Freeze: a 12-stud frost circle for 6 s that pauses cooking, burn countdowns, customer patience, order tickets and fire spread inside it. Other players slide on the ice; the Penguin is faster on it.
    - The Penguin stomps, and the frost circle bursts out with a wobble and a shockwave.
    - Ice spikes burst out of the floor around the Penguin, and the frost has a jagged edge instead of a perfect circle.
    - Frozen pots get an icy cap, frozen customers puff cold breath, and everything frozen glints.
    - Frozen customers are sealed in a block of ice that snaps on, shivers, and cracks off when they thaw.
    - A frozen customer's bubble frosts over with a snowflake and an icy blue patience bar, and the frost cracks off when the timer runs again.
    - You can see how long a freeze has left: cracks spread across the ice the whole time and the circle melts in from the rim.
    - Cold mist drifts over the ice and snow falls inside the circle, and the Penguin glows frosty while their freeze lasts, so teammates see who froze things.
    - Counters, tables and other stations inside the freeze get a layer of frost on top, so you can tell what got frozen.
    - In its last second the ice cracks and shivers, then shatters into flying ice chunks of different sizes.
    - The ring under your character stays visible while you stand on the ice.
    - A customer frozen on the way to their seat no longer gets extra patience for the time they spent walking.
    - Only customers inside the circle when it is cast are frozen; customers who walk in afterwards are not.
  - The Alien's Order Rush: a UFO beams the Alien up, flies to up to 4 waiting customers (least patient first), beams down to take each order, and drops the Alien back where it started. Your camera follows your UFO.
    - The tractor beam shoots and retracts smoothly, swirls and squashes as it lands.
    - The UFO swoops between customers, overshoots and wobbles to a stop, squishes as it moves, and drifts while hovering.
    - The beamed copy of the Alien stretches in the beam, glitches apart, and lands with a squishy bounce.
    - The Alien lands beside each customer like a waiter, facing them.
    - The real Alien's outline and "you" ring hide during the rush, so only the copy shows them.
    - The Alien stays fully visible until the tractor beam reaches them, instead of turning see-through as soon as the superskill starts.
    - Using it while moving no longer pops the Alien back to where it was when the key was pressed.
    - The hidden Alien no longer blocks other players or customers during the rush.
    - The copy only glows while the beam is on it, and casts a shadow.
- Your "you" ring stays flat on the floor, even when jumping.
- Every player now sees the same serving-window NPCs walking the same routes.
- Meshes, textures and sounds now download in the background, your own superskill's effects first, so they no longer pop in the first time they appear.
- The superskill HUD button is hidden for now (`Config.UI.ShowSkillHud`); the superskill key and mobile button still work.
- Order tickets and customer patience bars turn ice blue while frozen.
- Customer tables only highlight when there is something to do there (taking an order, serving, or a dirty plate), not while customers walk up, eat or leave.
- The Gecko's tongue is now textured and wobbling with a sticky tip, effects for firing, sticking, missing a wall and catching, and a trail on the grabbed item.
- Tap once to chop food or wash a whole stack of plates; move or dash to stop early.
- Gecko's Tongue Grab now snaps toward nearby items, spins to lock onto reachable items, shows a striped aim guide, and fires a smoother tongue immediately on release; holding until the limit cancels without firing, and every lock switch restarts that limit.
- Superskills: a superskill framework (`SkillService`, `Skills/` on the server and client, a Skill HUD button, key `Q`) and the Gecko's Tongue Grab. Hold Q to aim and spin, release to shoot the tongue over counters and pull an item into your hands; thrown items can be caught by the tongue. In Studio every player is the Gecko (`Character.StudioOverride`).
- Manual serve mode: customers walk in, sit at tables, order, eat, and leave a dirty plate. `Round.ServeMode` toggles it against the legacy serving window.
- Carrying dirty plates, you can stack another one straight from a customer table.
- Clean test map `CoOp/Test/Basic`.
- Crates accept items on their lid, and the item on top is taken first.
- Class identity comes from the `objectClass` attribute, which generates `Class_<name>` tags at server start. Legacy tags were cleaned up.
- Throwing revamp:
  - sphere-sweep collision and a gravity fall;
  - lag compensation and instant local throws;
  - teammates can catch thrown items.
- One `Config` index module for all tunables.
- Food (or a pot) can be plated straight onto the top clean plate on the sink's drain board. A finished wash slides its new plate under a plated one instead of burying it.

## 0.5.0: Legacy (tag `v0.5.0`, commit `a446161`)

The original OOP prototype, as synced from Studio before the rewrite. It has pickup and drop, counters, chopping, plates and recipes, the serving window, the stove, pot cooking, fire and the extinguisher, the sink and dirty plates, throwing, trash, dash, and the round loop. Known bugs are logged in `docs/LEGACY-BUGS.md`.
