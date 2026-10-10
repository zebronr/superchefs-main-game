# Customers at tables

Status: **in progress**. Order taking, serving, payment on the table, and dine-and-dash customers are built.

- NPCs sit at tables with patience meters. You carry the plate to *them* instead of a serving window.
- Special customers:
  - VIP critic: big score swing, wants *perfect* cooking quality
  - Picky eater: wants a variant
  - Dine-and-dasher: catch them with the interact button before they reach the exit. A baseball bat and animation are planned by the user. Noticing and catching ideas: [dine-and-dash.md](dine-and-dash.md).
- Table customers leave cash beside the plate after eating; picking up the dirty plate collects it in the same press (or interacting with the table when there is no plate). Both are level settings (`EnableTableCash`, `Customers.DashChance` in `Config/Levels`), off in starter levels; off means customers pay when served.
- Later (user, 2026-10-07): the cash pile shows how much the customer paid, from a single coin, to bigger or more coin stacks, to stacks with banknotes. Needs a few mesh variants (or one pile built from parts) picked by the `Cash` amount.
- Tips scale with speed and cooking quality, so a waiter role is worth having.
- Some customers place tag orders (see [orders-and-recipes.md](orders-and-recipes.md)).
