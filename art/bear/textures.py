# Flat textures for the Bear Toss aim (needs Pillow): python art/bear/textures.py
# ArcDash.png  - one white rounded dash, stretched over each short Beam of the aim guide (0.8 studs long, 0.4 wide,
#                the Gecko guide's dashes).
# RingDecal.png - the white landing ring, a Decal on the top of Assets.Skills.BearToss.Ring.

import os

from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out")
os.makedirs(OUT, exist_ok=True)
SCALE = 4


def dash() -> None:
	width, height = 128 * SCALE, 64 * SCALE
	image = Image.new("RGBA", (width, height), (255, 255, 255, 0))
	draw = ImageDraw.Draw(image)
	pad = 4 * SCALE
	draw.rounded_rectangle((pad, pad, width - pad, height - pad), radius=(height - 2 * pad) // 2, fill=(255, 255, 255, 255))
	image = image.resize((width // SCALE, height // SCALE), Image.LANCZOS)
	image.save(os.path.join(OUT, "ArcDash.png"))


def ring() -> None:
	size = 256 * SCALE
	image = Image.new("RGBA", (size, size), (255, 255, 255, 0))
	draw = ImageDraw.Draw(image)
	pad = 6 * SCALE
	thickness = 22 * SCALE
	# A faint fill so the spot reads on any floor, then the solid outline.
	draw.ellipse((pad, pad, size - pad, size - pad), fill=(255, 255, 255, 60))
	draw.ellipse((pad, pad, size - pad, size - pad), outline=(255, 255, 255, 255), width=thickness)
	# A small dot in the middle.
	dot = 14 * SCALE
	draw.ellipse((size // 2 - dot, size // 2 - dot, size // 2 + dot, size // 2 + dot), fill=(255, 255, 255, 255))
	image = image.resize((size // SCALE, size // SCALE), Image.LANCZOS)
	image.save(os.path.join(OUT, "RingDecal.png"))


dash()
ring()
