# Follow-up orders

Status: **proposal** (the user's idea, 2026-10-07). Home: **Aling Inasal** (see [filipino.md](filipino.md)), where unli-rice refills are the signature.

## Idea

While a customer is eating, they can ask for **more**: a rice refill, a drink, a sauce. You bring it to the table. It's how a real restaurant feels after the food arrives, and in Aling Inasal it's the famous unli-rice server walking around with a bucket.

## Rules

- A follow-up appears **while eating** as a small icon bubble (a rice bowl, a glass, a sauce dish) with its own short timer.
- **Bring the item to the table** with interact. It never needs plating.
- **Served:** a tip bonus and a happy reaction ("Salamat po!").
- **Ignored:** the timer runs out and the tip shrinks. It **never fails the main order** and the customer doesn't leave. It's a ceiling mechanic: good teams squeeze out extra tips, new players can ignore it.
- A customer can ask for at most a couple of follow-ups per meal.
- Level setting: `EnableFollowUps`, plus the chance and which items are allowed, in `Config/Levels`. Off means eating works exactly as now.

## Follow-up items

| Item | Where it comes from |
|---|---|
| **Rice** (the main one) | The rice cooker, into a **rice bucket** |
| Drink | A drink dispenser or pitcher |
| Sauce (toyo-calamansi, sili) | A sauce station |

## The rice bucket (unli-rice)

- A carryable bucket filled at the rice cooker, holding a few scoops (like a plate stack holds plates).
- **One trip can refill several tables**, so a player can walk the dining room as the rice server. A natural job for the waiter.
- Empty bucket: back to the rice cooker.

## Ties to other systems

- **Brownout** (Pasko sa Barrio / Aling Inasal): the electric rice cooker stops. No power, no rice refills. Someone has to flip the breaker.
- **Alien:** Order Rush could also pick up follow-up requests (test it).
- **Gecko:** tongue-grab the rice bucket across the room.
- **Penguin:** freezes follow-up timers like any other waiting thing.
- **Clown:** Crowd Pleaser tips stack with follow-up tips.

## Numbers (start)

| Knob | Start |
|---|---|
| Follow-up chance per meal | 50% |
| Max follow-ups per customer | 2 |
| Follow-up timer | 15 s |
| Rice bucket scoops | 4 |
| Tip bonus per follow-up | +20% of the order |

## Readability

- The request icon pops up with a bounce and a short "ding".
- The icon shakes when its timer is almost out.
- The table highlights only while it has a request (matching how tables highlight now).
