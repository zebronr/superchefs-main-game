"""Makes the toasted burger atlas: the bun areas go warmer and a little darker golden-brown, the rest stays as it was.

Run from the repo root: python art/icons/toast_bun.py
Reads art/icons/src/burger/Fullburger1_diff.png (the shared burger atlas: bun, cheese, patty, sesame) and writes
art/icons/src/burger/Burger_diff_toasted.png plus Burger_toast_mask.png (white = toasted) to check the regions.
The bun is picked by colour: orange-beige hue, medium saturation, bright. The cheese (too saturated), the pale
sesame/cream block (too unsaturated) and the patty (too dark) fall outside the mask.
"""

import os

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "src", "burger", "Fullburger1_diff.png")
DST = os.path.join(HERE, "src", "burger", "Burger_diff_toasted.png")
MASK = os.path.join(HERE, "src", "burger", "Burger_toast_mask.png")
GAIN = (0.955, 0.875, 0.78)  # per channel on the bun: beige (255,217,161) -> (244,190,126)


def ramp(x, a, b, c, d):
    """0 below a, rises to 1 at b, 1 until c, back to 0 at d."""
    if x <= a or x >= d:
        return 0.0
    if x < b:
        return (x - a) / (b - a)
    if x > c:
        return (d - x) / (d - c)
    return 1.0


src = Image.open(SRC).convert("RGBA")
hsv = src.convert("RGB").convert("HSV")  # Pillow HSV: all channels 0-255
out = src.copy()
mask = Image.new("L", src.size, 0)
sp, hp, op, mp = src.load(), hsv.load(), out.load(), mask.load()
for y in range(src.height):
    for x in range(src.width):
        h, s, v = hp[x, y]
        w = ramp(h, 10, 13, 26, 28.5) * ramp(s, 80, 88, 175, 188) * ramp(v, 125, 150, 256, 257)
        if w > 0:
            r, g, b, a = sp[x, y]
            op[x, y] = tuple(round(c * (1 - w + w * k)) for c, k in zip((r, g, b), GAIN)) + (a,)
            mp[x, y] = round(w * 255)
out.save(DST)
mask.save(MASK)
print("wrote", DST)
