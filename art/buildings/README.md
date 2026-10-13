# City buildings and street props

Decorative low-poly set that fills the area outside the restaurant map. `buildings.py` is the source of truth, so re-run it to rebuild everything (about 10 s):

```
"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup --python art/buildings/buildings.py
```

Faceted flat shading. Every face maps to one cell of a shared 8x8 palette texture (32 px cells), the same pipeline as `art/cars/car.py`.

## Models (`out/*.fbx`)

| File | Size in studs (W x D x H, incl. overhangs) | Tris | Origin / front |
|---|---|---|---|
| `Bldg_Shop2.fbx` | 18 x 22 x 15 (awning sticks out 2.9 in front) | 1071 | bottom centre of front wall |
| `Bldg_Shop3.fbx` | 20 x 24 x 21 (canopy +2.55) | 1510 | bottom centre of front wall |
| `Bldg_Apartment4.fbx` | 22 x 24 x 27 body, 29.8 to the top of the water tank (steps +2.4) | 2466 | bottom centre of front wall |
| `Bldg_Narrow3.fbx` | 12 x 20 x 21 incl. chimney (roof overhang 0.7, steps +1.6) | 912 | bottom centre of front wall |
| `Bldg_Tower.fbx` | 24 x 28 x 44.5 | 2724 | bottom centre of front wall |
| `Bldg_Diner.fbx` | 16 x 16 x 9.7 incl. roof sign (door hood +1.3) | 664 | bottom centre of front wall |
| `Prop_StreetLamp.fbx` | 1.3 x 3.5 x 12.5 | 134 | bottom centre of the base, arm reaches toward the front |
| `Prop_Bench.fbx` | 6 x 2.3 x 3.05 | 156 | bottom centre of the bounding box, seat faces the front |

Front is Blender +Y, exported with `axis_forward=-Z`, `axis_up=Y`, so **front = the MeshPart's LookVector (-Z)**. For buildings, the front wall plane passes through the origin and the building extends **behind** it (along +Z in Roblox, i.e. -LookVector) by its depth. To line a street, put the origins on the pavement edge, facing the street. The ground floor sits on Y = 0. Cornices stick out about 0.4 past the walls.

## Textures (`out/*.png`)

All buildings share one palette layout, so any building palette works on any building:

- `Bldg_Palette.png`: the default (Salmon), embedded in the building FBXs
- `Bldg_Palette_Salmon.png`, `_Mint.png`, `_Butter.png`, `_Sky.png`, `_Lavender.png`, `_Cream.png`

A variant changes only the WALL cell, the WALL_DARK cell derived from it, and the AWNING accent cell (awnings, canopies, sign frames and the diner bands). Windows, trims and roofs stay the same. Lit windows (warm yellow) are picked by a seeded random per building, so they're the same on every rebuild.

The colours are warm, dusty and fairly dark so the street matches the warm restaurant interior (darkened 2026-10-13). Studio's sky light adds a cool cast, so the palette leans warmer than it looks in the Blender previews.

`Prop_Palette.png` is for the lamp and the bench. It has the same layout with the default colours. The props only use LAMP_POLE, LAMP_GLASS, METAL_DARK and WOOD, which were left unchanged, so the uploaded prop palette is still current.

## Roblox import

1. Import each FBX as a MeshPart (File > Import 3D). The scale is 1 unit = 1 stud.
2. Set `Material = SmoothPlastic`.
3. Set `TextureID` to an uploaded palette PNG: a `Bldg_Palette_*` variant for buildings, `Prop_Palette` for the props.
4. Rotate so the LookVector points at the street. These are decorative, so `CanCollide`/`CanQuery`/`CanTouch` can usually be off. Follow `docs/COLLISION-GROUPS.md` for the map folder.

Previews: `out/Buildings_lineup.png` (3/4 front, one variant each, the sedan for scale), `out/Buildings_back.png` (3/4 rear), `out/Props.png`. Blender scene: `Buildings.blend`.

## Uploaded to Roblox

The resized templates are in `ServerStorage.Assets.Scenery`; their `TextureID` is the Salmon palette. Building palettes (uploaded 2026-10-13, the darker set):

| Palette | Asset id |
|---|---|
| Salmon (default) | `rbxassetid://118663414210314` |
| Mint | `rbxassetid://106327162298727` |
| Butter | `rbxassetid://97371498158091` |
| Sky | `rbxassetid://122977337478746` |
| Lavender | `rbxassetid://118785982075994` |
| Cream | `rbxassetid://79150591623395` |

Prop palette (lamp `rbxassetid://86865490889298`, bench `rbxassetid://75596413824811`) was not re-uploaded.
