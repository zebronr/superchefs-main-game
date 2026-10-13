# Food icon shading

This is how every food icon is shaded, so new ones match. The ready-made Blender file is `icons/IconShading.blend`, and the scripted pipeline is in `icons/` (see `icons/HANDOVER.md`).

## The look

- **Flat colour.** The model's own texture is shown unlit, with no real lights and no specular.
- **Top light.** Faces pointing up are a little lighter, and faces pointing down are a little darker. That gives the shape without shading.
- **Faceted.** Flat shading, with no smoothing between faces.
- **Sharp shadow.** A hard-edged copy of the silhouette sits under the icon, straight down. There's no outline and no white border.

## Material (Blender node setup)

Material `Flat`:

```
Image Texture (model texture, Interpolation: Closest) ──Color──┐
                                                               ├─ Mix (Color, Multiply, Factor 1) ── Emission (Strength 1) ── Material Output
Geometry ─Normal─ Separate XYZ ─Z─ Map Range ──Result──────────┘
                                   From -1..1  →  To 0.80..1.04
```

- In Map Range, a normal straight down gives 0.80 (20 % darker) and straight up gives 1.04 (4 % lighter).
- Set the texture image's Alpha to None. The Studio OBJ exports reuse the texture as opacity, and that makes faces see-through.
- All mesh faces use flat shading.

## Camera and render

| Setting | Value |
|---|---|
| Camera | Orthographic, 38° down, 25° to the side |
| Framing | Fit to the model's outline with an 18 % margin (ortho scale = widest extent × 1.18, centred with shift) |
| Engine | EEVEE, View Transform **Standard** (not AgX/Filmic, which wash out the colours) |
| Film | Transparent |
| Size | 512 × 512 PNG, RGBA |
| Lights | None needed (the material is emission only) |

## Shadow (post pass)

Made by `icons/food_icon_post.py` after the render, not in Blender:

| Setting | Value |
|---|---|
| Shape | The icon's own alpha silhouette, no grow, no blur |
| Offset | 14 px straight down (at 512 px) |
| Colour | Warm dark brown `(40, 20, 15)` |
| Opacity | 35 % |

In Figma or Photoshop, the same thing is a drop shadow with X 0, Y 14, blur 0, spread 0, colour `#28140F` at 35 %.

## Quick use

Run from the repo root.

1. Render the flat icon:

   ```bash
   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup --python art/icons/food_icon.py -- <model.obj> <Name> flat
   ```

2. Add the shadow. This writes `art/icons/out/<Name>_shadow.png`:

   ```bash
   python art/icons/food_icon_post.py <Name>
   ```

To do it by hand instead, open `icons/IconShading.blend`, import your model, give it the `Flat` material with your texture, re-fit the camera, and press F12. Then add the shadow as above.
