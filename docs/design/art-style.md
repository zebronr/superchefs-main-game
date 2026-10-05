# Art and VFX style

Set by the Gecko's Tongue Grab (2026-10-05), which the user approved as the look to follow. Reference: `art/tongue/` (sources) and `src/client/Skills/TongueGrab.luau` (renderer).

## Look
- **Squishy and elastic, cartoon-organic.** Things stretch, wobble, splat and pop rather than move rigidly. Soft rounded shapes, no hard edges.
- **Saturated warm colours** with simple baked shading: a lighter wet sheen on top, darker underneath and at the edges. No realism, no PBR detail.
- **Small surface detail, big silhouettes.** Bumps or blotches in the texture, never in the geometry. The game is **mid-to-low poly, never high poly**: meshes of a few hundred faces, round shapes from few segments (16 to 20 around).
- **Hard objects are faceted** (the user's call on the UFO, 2026-10-05): flat shading, sharp edges, one solid colour per face, alternating panel shades, no soft noise blotches (those read as "AI-looking"). Soft organic things (the tongue) stay smooth. Reference: `art/ufo/ufo.py`.

## Motion
- **Snappy easing, never linear.** Out with a fast-then-settle curve (Exponential Out), back with a slow-then-snap curve (Quart In).
- **Secondary wobble** that dies down as the motion settles (a decaying sine on `CurveSize`, scaled by length).
- **Stretch by adding, not by scaling.** Tiling textures (`TextureMode = Wrap`) so a longer thing shows more pattern, with a fixed-size end piece so the eye reads the middle as stretching.
- **Taper:** thick at the source, thinner toward the end.

## VFX
- **Short bursts at moments that matter:** a puff when something fires, a splat on a sticky hit, dust on hitting a wall, a pop on arrival, a light trail on anything flying. Each fires once per action.
- **Soft white textures tinted per effect** (`Puff`, `Splat`), so one texture serves many effects. Short lifetimes (0.15 to 0.5 s), quick drag, fade out.
- Effects are emitted from templates (`Enabled = false`, the code calls `:Emit(n)`); the look lives on the template in Studio, the counts and motion numbers in `Config`.

## Pipeline
- Meshes are made by headless Blender Python scripts (`blender --background --python ...`), with procedural materials baked to a texture. The script is the source of truth; re-running it reproduces the asset.
- Flat textures (tiling strips, particle sprites) are made with Pillow scripts. Tiling textures use whole-number frequencies so the edges match.
- Images are uploaded through the Studio MCP from a local HTTP server; meshes are imported by hand (File > Import 3D), then sized and set up through the MCP.
- All rendering is client-side from server data (see the "server simulates data, clients render" rule in `CLAUDE.md`).
