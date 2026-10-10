# Halloween props (temporary seasonal set)

Status: **paused, handed to the modeller** (2026-10-10). Two script-built passes were rejected; the brief below stays as reference. The first pass (new haunted designs) was rejected as too plain and boxy; the second rebuilds the live stations' own shapes at low poly and recolours them. Sources: `art/halloween/` (Blender script, preview sheet).

## Direction (2026-10-10, from the user)

Keep the live models' shapes and style (thick bevelled worktop over a darker base, slanted-lid bin, tray table,
slatted crate, framed sink), make them cheaper, and recolour for Halloween with small accents (pumpkin pulls, slime
lid, jack-o'-lantern faces). The live meshes can't be read from Studio (no asset permission), so the shapes are
rebuilt by eye in `art/halloween/props.py`. Customer table and seat have no live mesh and are not in this pass.

## Goal

A temporary "haunted kitchen" skin for the stations, swapped in for the Halloween event and out after. Same footprint
and heights as today's meshes so every station still lines up, but in the UFO's look: **lower poly than the current
set, faceted, flat-shaded, one flat colour per face, alternating panel shades**, no soft noise (see
`docs/design/art-style.md`). Spooky-cute, not scary: this is a cartoon cooking game.

## Palette

| Use | Colour |
|---|---|
| Cabinet wood (dark plum), alternating planks | `#2A1A24` / `#3A2431` |
| Worktops (bone, light so food reads on top) | `#D9CCAD`, edge `#B8AA8A` |
| Pumpkin | `#F2731A`, shadow side `#C9520F`, stem `#3F5A1E` |
| Slime / cauldron glow | `#73FF4D` |
| Iron (cauldron, hinges) | `#1A1A1F` |
| Stone (sink) | `#6B6678` / `#57536A` |
| Cloth (customer tables) | `#5A1F73` |
| Candle wax / flame | `#F2E8C9` / `#FFC23D` |

## Rules for every piece

- **Same size and pivot as the live mesh** (table below), origin at the bottom centre, so a swap is MeshId + TextureID
  only. Top surfaces stay flat and at the same height: items are welded onto the top centre.
- **Readable at a glance:** each station keeps a distinct silhouette, and worktops are the lightest colour so food,
  plates and the "you" ring stand out.
- **Low poly:** 8 to 12 segments for anything round, bevels as one chamfer, 150 to 700 faces per piece.
- Decorations (wax drips, cobwebs, pumpkins) never stick up above a worktop where items land.

## Pieces

| Station | Size (studs, X×Y×Z) | Design |
|---|---|---|
| Countertop | 4 × 2 × 4.39 | Plum plank cabinet with a chamfered bone worktop, a coffin-shaped drawer front with a tiny skull knob, wax drips over the front edge. |
| PlateTable | 4 × 2 × 4.39 | The countertop cabinet with two open cubby shelves showing stacked plates, cobweb in one corner. |
| ChoppingBoard | 4 × 2 × 4 + `Board` 3.39 × 0.15 × 2.63 | Countertop cabinet; the separate `Board` is a chunky wooden plank with a cleaver notch, stuck-in cleaver silhouette at the back corner. |
| FoodContainer | 4.02 × 1.77 × 4.02 + lid 4.02 × 0.25 × 4.02 | Pumpkin-orange slatted crate with a jack-o'-lantern face cut into the front slats (dark faces); lid is a separate plank lid with a stem handle. |
| Trash | 4 × 3.58 × 4 | Witch's cauldron: black iron pot on three stubby legs, thick rim, green slime surface with two bubbles. |
| Sink | 8 × 4.93 × 4 | Stone trough in blocks: drain board on the left (surface 1.9 above the bottom), deep basin on the right (floor about 0.35, green-tinted water at about 2.06), curly iron tap, a small gargoyle-ish bat on the backsplash. |
| CustomerTable + Seat | 4 × 2.5 × 4, seat 2 × 1.5 × 2 | Table: plum legs and a purple cloth with a jagged (zig-zag) hem, a short candle off-centre at the back edge. Seat: a squat pumpkin stool. |
| ServingCounter | 8.4 × 6.6 × 4.84 | Haunted shop window: plank counter, crooked wooden frame, bat-wing awning. |

Extra decor (optional, same style): jack-o'-lantern (3 sizes), candle cluster, tombstone, cobweb corner card, bat.

## Swapping in and out (to decide)

Scripts can't change `MeshPart.MeshId` at runtime, so the swap happens in Studio. Options: a seasonal copy of each map
(`Maps.CoOp.<...>.Halloween`) that `Levels` points at during the event, or a one-off MCP pass that swaps MeshId and
TextureID on the live maps (and swaps back after). The map copy keeps both sets side by side and is safer.
