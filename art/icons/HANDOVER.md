# Food icon pipeline: handover

Status as of 2026-10-13. These are the order and customer-bubble icons, rendered from the food models.

## Chosen style

**Flat + sharp shadow** (`<Name>_shadow.png`). It was picked from a 5-way comparison in Figma ("Food icon styles (meat test)").

- **Flat:** the same look as the existing icons in `art/bread/bread.py`.
  - Orthographic camera, 38° down and 25° to the side.
  - The texture is shown unlit, with tops a little lighter and undersides darker.
  - Faceted, on a transparent 512 px background.
- **Shadow:** a hard-edged copy of the icon's silhouette under it.
  - Offset 20 px straight down, no blur.
  - Warm dark brown `(40, 20, 15)` at 60 % opacity (was 14 px / 35 %, too faint at order-UI and billboard sizes; check at 64 px).
  - No outline, no white border.
- **Padding and centring:** the post pass crops the food to its alpha bounding box, scales it so food + shadow fit in the central 72 % of the 512 px canvas (369 px, so 14 % padding on every side), and centres that combined box. Every icon gets the same padding, whatever the model's shape. This matters for the bun, which used to cover its white circle. In game the FoodList badges show these icons at 1.0× the circle.
- **Weight centring:** a lopsided shape (the cheese wedge, thick on one side) looks off-centre even when its bounding box is centred. `MASS_CENTRE` (0.5) moves the icon horizontally halfway from the box centre toward the centre of its visible pixels. Symmetric icons barely move. Set it to 0 to centre by bounding box only. Tunables at the top of `food_icon_post.py`: `SHADOW_*`, `FILL`, `TONE`; at the top of `food_icon.py`: `PITCH`, `YAW`, `CAVITY`.
- **Tone:** `TONE` in `food_icon_post.py` shifts an icon's mean colour per icon. The cheese is toned to about `(242, 200, 95)`, because its raw texture reads too yellow in the unlit render. (The cheese slice inside the full burger is not toned.)
  - Pixels darker than 80 % of the median brightness (the tinted holes, see below) are left out of that mean, so tinting the holes doesn't brighten the rest.
- **Cavity tint:** `CAVITY` in `food_icon.py` (opt-in per icon) darkens the model's recesses so they read at 40–70 px.
  - It finds faces whose centre sits deeper than a threshold (a share of the model's size) inside the model's convex hull, stores them in a face attribute `cavity`, and the `Flat` material multiplies those faces by a tint.
  - Only the cheese uses it: `(0.62, 0.34, 0.12)`, depth 0.004, which turns its holes a warm orange-brown. Without it the wedge read as a plain yellow triangle at 48–64 px.
  - It only works for models whose outer shape is convex (a wedge, a block). Icons not in `CAVITY` render exactly as before.

## Which icons are needed

Icons are rendered only for **finished items**. The partial states (bun alone, bun + patty, bun + cheese) are not separate icons, because the game shows them as states.

| Icon | Model | Output |
|---|---|---|
| Burger (full) | `src/burger/bun_cheese_patty.obj` | `out/BunCheesePatty_shadow.png` |
| Plain burger (no cheese, order 8) | `src/burger/bun_patty.obj` | `out/PlainBurger_shadow.png` |
| Bun (order's bun step) | `src/burger/bun.obj` | `out/Bun_shadow.png` |
| Cheese | `src/burger/cheese.obj` | `out/Cheese_shadow.png` |
| Meat | `src/meat/meat.obj` | `out/Meat_shadow.png` |

Some renders in `out/` aren't needed and can be deleted:

- `BunPatty_*`, `BunCheese_*`: the state models, rendered by mistake. (Keep `Bun_shadow.png`: the order's bun step uses it. The burger (no cheese) icon is `PlainBurger_shadow.png`, rendered from the same bun + patty model.)
- `Meat_outline/sticker/soft/toon*` and `Meat_sheet.png`: the style comparison.
- `Burger_sheet.png`: a review sheet.

## How to render a new icon

Run both commands from the repo root. The model can be an OBJ or FBX with its texture next to it (e.g. exported from Studio).

```bash
"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup --python art/icons/food_icon.py -- <model> <Name> flat
python art/icons/food_icon_post.py <Name>
```

- **`food_icon.py`** (Blender 5.2, headless) writes `out/<Name>_flat.png`. It:
  - imports the model and joins its parts;
  - centres it and makes it faceted;
  - uses the model's first texture;
  - fits the camera to the model's outline.
- **`food_icon_post.py`** (system Python + Pillow) adds the shadow and writes `out/<Name>_shadow.png`.
  - Other comparison styles are made only when their source render exists.
  - The comparison sheet is made only when every style exists.
- Put source files in `src/<item>/` (model, `.mtl`, texture).

## Toasted bun texture

The burger models share one atlas (bun, cheese, patty, sesame). The bun was too pale, so there is a toasted copy:

- `toast_bun.py` (Pillow) reads `src/burger/Fullburger1_diff.png` and writes `src/burger/Burger_diff_toasted.png`.
  - It finds the bun by colour (orange-beige hue, medium saturation, bright) and multiplies it by `(0.955, 0.875, 0.78)`, so the bun goes warmer and slightly darker.
  - The cheese, the pale sesame block and the patty fall outside the mask and stay as they were.
  - It also writes `Burger_toast_mask.png`, so you can check the regions.
- The originals (`*1_diff.png`) are kept. `bun.mtl`, `bun_patty.mtl`, `bun_cheese.mtl` and `bun_cheese_patty.mtl` now point at the toasted file, so the renders match the game.
- In Studio it's `rbxassetid://117760325624272`. It's set on `workspace.bun`, `buns patty`, `buns cheese`, `fullburger`, `RawFoods.bun` and `PlatedFoods.plated_bun`, `plated_bun_patty`, `plated_bun_cheese`, `plated_burger`.
  - The patty and melted-cheese parts (`workspace.patty`, `melted cheese`, `PanFoods.patty`) still use the old atlas `109374707048276`. Their regions are unchanged, so that's fine.

## Shading setup as a .blend

`IconShading.blend` is the whole flat setup, with the full burger loaded and its texture packed in. It includes:

- the `Flat` material (texture × top light, emission);
- the fitted ortho camera;
- the render settings (512 px, transparent background).

Pressing F12 renders the flat icon. The sharp shadow is not in the .blend: it's added afterwards by `food_icon_post.py`.

Make one for any model by passing `blend` as the style: `food_icon.py -- <model> <Name> blend`.

## Notes and gotchas

- **Texture alpha:** the Studio OBJ exports set `map_d` to the texture. The script ignores that alpha (`alpha_mode = "NONE"`), otherwise faces turn see-through.
- **Shape changes framing:** the camera fits each model to the frame, so icons of different shapes fill it the same way. Flat or wedge shapes (the cheese) show mostly their top face. If one reads badly, rotate the model before export or add a per-model rotation to the script.
- **Other styles:** the comparison styles are still in the scripts. Render them with `food_icon.py ... <Name>` and no style list: `flat`, `soft` and `toonbase`; the post pass adds `outline`, `sticker` and `toon`.

## Open items

- Re-render the older icons (bread, slice, sandwiches, strawberry, peanut from `art/bread/bread.py`) in the shadow style so the set matches.
  - This needs a model export for each, run through this pipeline.
  - Or add the shadow step to `bread.py`'s output.
- Decide whether the shadow should stay translucent brown (works on any background) or become solid UI blue `(62, 102, 133)`. Translucent brown is the current choice.
- Done 2026-10-13: wired into the burger order (`Config/Levels.luau`, order 7), the crate lids and the foods' FoodList. The bun render is used for the order's bun step, so keep `Bun_shadow.png`. (The first upload's ids, burger 80966110339204, meat 129107794305640, cheese 70847568412436, bun 115120437773649, are no longer used.)
- Re-rendered 2026-10-13 with the toasted bun, the stronger shadow, the 72 % padding and the toned cheese. These are the ids in use:
  - burger `rbxassetid://84533964238750`
  - burger, no cheese `rbxassetid://120434787255772` (2026-10-13, order 8 `burger`; order 7 is now `cheese_burger`)
  - bun `rbxassetid://90621736229104`
  - meat `rbxassetid://98317071199758`
  - cheese `rbxassetid://84478614105150` (re-rendered with the cavity tint and re-centred by weight; the earlier cheese ids 78213878382147 and 83725103487773 are no longer used)
- Figma: rows 3–5 of the comparison section only have placeholder icons. Delete the section once the style is settled.
