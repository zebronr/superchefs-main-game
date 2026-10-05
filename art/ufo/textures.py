# Builds the tractor beam texture: a soft green glow, strong at the top (the UFO) and fading toward the
# ground, with gentle rings and streaks. Whole-number frequencies so it wraps around the cone cleanly.
# Run from the repo root: python art/ufo/textures.py
# Writes art/ufo/out/TractorBeam.png.

import math
import os

from PIL import Image

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out")
WIDTH, HEIGHT = 256, 512
TOP = (215, 255, 225)
BOTTOM = (110, 255, 160)

os.makedirs(OUT, exist_ok=True)
image = Image.new("RGBA", (WIDTH, HEIGHT))
pixels = image.load()
for y in range(HEIGHT):
	v = y / (HEIGHT - 1)  # 0 at the top of the image (the UFO end of the cone), 1 at the ground
	fade = 0.85 - 0.55 * v ** 1.4
	rings = 0.78 + 0.22 * math.sin(2 * math.pi * 7 * v) ** 2
	# A brighter lip where the beam hits the ground.
	lip = 1 + 0.35 * math.exp(-((1 - v) / 0.04) ** 2)
	color = tuple(round(TOP[i] + (BOTTOM[i] - TOP[i]) * v) for i in range(3))
	for x in range(WIDTH):
		u = x / WIDTH
		streaks = 0.82 + 0.18 * math.sin(2 * math.pi * 9 * u + 2 * math.pi * 2 * v)
		alpha = max(0.0, min(1.0, fade * rings * streaks * lip))
		pixels[x, y] = (*color, round(alpha * 255))

image.save(os.path.join(OUT, "TractorBeam.png"))
print("TractorBeam.png done")
