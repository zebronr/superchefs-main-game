# Orders and recipe creativity

Status: **tag orders liked by the user**; seasoning and combos are proposals.

Build order: tag orders, then seasoning, then combos.

## Tag orders

- Every ingredient has **tags** (sweet, sour, spicy, fresh, cooked, ...). The plate system (which already builds names like `salad(mango_cucumber)`) computes a dish's tags.
- Some customers order a **description** instead of a fixed recipe: "something sweet and cooked", "anything with mango". Any dish whose tags match counts.
- They're mixed in with normal fixed-recipe orders.

## Seasoning (tag adders)

- Not a required step on every dish. That would be busywork.
- Shakers on a counter add a tag to a plate: chili adds *spicy*, sugar adds *sweet*.
- It's a **clever shortcut** for tag orders: chili-shake a plain dish to satisfy "something spicy".
- Fixed recipes ignore seasoning. Wrong seasoning never fails a fixed order; at most it lowers the tip.

## Combos

- Hidden combinations score extra. The first time you serve one, it goes into your Cookbook ([meta-progression.md](meta-progression.md)).
- Later: a server-wide "dish of the day" to discover.
