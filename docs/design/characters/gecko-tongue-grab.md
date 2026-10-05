# Gecko: Tongue Grab

Status: **prototype built (v2), first playtest passed** (2026-10-05: "feels better"). Job: Fetcher. Follows the [general skill rules](../characters.md#general-skill-rules).

Grabs must be intentional, but there's no mouse aiming.

## Aiming (hold Q)

- **Hold Q** and the Gecko stops in place.
- On press, the Gecko snaps toward the best reachable item, balancing distance and turning angle, and locks onto it. Steering starts when movement input changes.
- **Point to select:** while WASD (or the stick) is held, the lock goes to the reachable item whose direction is closest to the input direction, camera-relative like movement. There is no hidden aim, so pressing the same way twice never drifts: left is always the left item and one press of right goes right. Letting go keeps the lock. The Gecko quickly turns to face the lock.
- With nothing in reach, WASD spins the Gecko freely (the shorter way, at the spin speed).
- **Mobile:** hold the skill button. The joystick gives a full 360° target direction, with the same spin speed and rules.
- **Camera:** eases a few studs out in the aim direction and tilts slightly lower, so you can see down the line. It stays top-down enough to keep the room in view, and eases back on release.
- **Hold limit:** ~3 s, restarted every time the lock switches items. Holding until time runs out cancels the aim with a short cooldown and no tongue shot.

## Targeting

- A striped **guide** shows from the mouth to the highlighted item, or to the whiff tip when no item is targeted.
- The locked item is highlighted. While input is held, the lock moves only when another item is more than 10 degrees closer to the input direction. Reachability uses range, height and line of sight.
- Walls stop the line of sight. When no item is reachable, the Gecko spins freely with input and the guide shows the whiff tip.
- **Dead zone:** items within ~4 studs are ignored. That's Interact range, so the tongue never grabs what's right next to you.
- The preview line isn't physical. Items thrown across it while you aim do nothing.

**Can't grab:**
- Anything LOCKED (mid-chop, being washed)
- A pot that's on fire
- Anything in another player's hands
- Crates (v1). Grabbing from crates might make walking pointless; test it later.

**Hands:** must be empty. With full hands the skill button greys out. (Later idea: grab food straight onto the plate you're holding.)

## Firing (release Q)

- **With a target:** the tongue shoots out (~0.2 s) and the item flies back (~0.3 s). Then the full cooldown (8 s), counted from when the item lands in your hands.
- **No target (a miss):** the tongue whiffs to full length. Then a short cooldown (~2.5 s).
- Holding until the time limit cancels without firing and gives a 0.5 s cooldown. A normal release with no reachable lock can still whiff.
- While it's flying back, the item belongs to nobody, and nobody else can interact with it.
- If you die mid-grab, the item drops where it is.

## Thrown items

- **Hit while aiming:** the aim cancels (general interrupt rule).
- **Hits the tongue while it's extending:** the thrown item is grabbed **instead of** the target. The tongue retracts with it, and the original target stays where it was. This counts as a grab (full cooldown), even if the shot was going to whiff.
- **Hits the tongue while it's retracting with an item:** the tongue keeps its original item, and the thrown item passes through.
- Tuning: the extend phase is short, so if interceptions feel impossible, give the extending tongue a fatter hitbox before slowing it down.

## Server

The client sends its facing direction and locked item on release. The server accepts the hint only if it is a bound, grabbable item within range and height, in line of sight, and within 25 degrees of the release direction. Otherwise it falls back to finding an item along that direction. A timeout or late release cancels without setting tongue state.

## Feel

A stretchy tongue, a *thwip* sound, a pop when the item arrives, a funny whiff animation on a miss, and a cooldown ring on the button.

## Visuals

Every client draws a textured Beam tongue with a sideways wobble and a sticky tip. A Thwip burst fires at the mouth; Splat marks an item hit, or Dust marks a wall hit on a whiff. Pop plays when an item reaches the mouth. A Trail follows each grabbed item during its return flight.

### VFX

All client-side. Other players draw it from the replicated tongue state.

**Priority (build first):**
1. **Tongue Beam:** a fleshy pink texture, thick at the mouth and thin at the tip (`Width0`/`Width1`), with a slight `CurveSize` wobble so it whips instead of looking like a rigid stick.
2. **Tip blob:** a small rounded sticky ball at the end of the tongue.
3. **Hit splat:** a small goo particle burst plus a quick ring (a flat part that scales up and fades) when the tongue reaches the item.

**Later, one at a time:**
- **Aiming:** a slight mouth glow or drool drip, so others see the Gecko is about to fire. The guide becomes a dotted Beam scrolling toward the target (`TextureSpeed`). The locked item gets a soft pulsing outline.
- **Extend:** speed lines (a Trail on the tip). The head lunges forward a bit (squash and stretch).
- **Hit:** the item wobbles and squashes for a moment. Hitstop: the tongue freezes for ~0.05 s on contact.
- **Retract:** the tongue thins as it stretches back. Drool droplets fall off the item, which spins a little in flight.
- **Arrival:** a sparkle pop and a scale pulse on the item (1.2x, then back to 1). Maybe a gulp or lick animation.
- **Whiff:** the tongue flops at full length, droops, and slurps back limp. A sad drip splat on the floor. Keep it funny so missing doesn't feel bad.
- **Catch (intercepting a throw):** a bigger splat, a brighter flash, and maybe a "NICE CATCH!" popup. It's the highlight moment.

**Rules:**
- Keep particle counts low for mobile. Several Geckos can fire at once.
- Tongue and goo colors live in config, so they can become cosmetic skins later (a rainbow tongue or a gold tongue from crates).

## Starting numbers

| Knob | Start |
|---|---|
| Range | 25 studs |
| Dead zone | 4 studs |
| Spin speed | ~180°/s |
| Hold limit | 3 s |
| Lock turn speed | 900 degrees/s |
| Lock switch margin | 10 degrees |
| Hint angle slack | 25 degrees |
| Cancel cooldown | 0.5 s |
| Cooldown after a grab | 8 s |
| Cooldown after a miss | 2.5 s |
| Extend / retract time | 0.2 s / 0.3 s |

## Versus (later)

Grabbing off the other kitchen's counters is allowed, but never out of their hands.

## Playtest questions

1. Do you plan around it, or forget it exists?
2. Does it make walking pointless? If so, cut the range before raising the cooldown.
3. Is the spin speed comfortable, or clunky, or too twitchy to land small items?
4. Do intentional tongue catches happen, and are they fun?

## Implementation notes

- The tongue passes **over counters**: only walls and other geometry without a class block the line of sight. Stations and items never block it. The fallback line search picks the closest candidate along the line.
- The Gecko stays **rooted** from pressing Q until the grab or whiff is completely over (the item is in its hands or the tongue is back).
- The actor draws the tongue immediately on release, then hands off to a fresh server timeline. The server backdates the extend start by capped half-ping. Other players draw from replicated attributes.
- Extension eases out, while the empty tongue and grabbed item ease in on retract.
- Two knobs the design did not name: `LineRadius` (how far to the side of the aim line a target can be) and `MaxHeightDifference`. Both are in `Config.Skills.TongueGrab`, with every other number.
- In Studio, `Config.Character.StudioOverride` makes every player the Gecko.
