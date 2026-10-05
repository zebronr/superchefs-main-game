# Flat textures for the Gecko tongue VFX (needs Pillow): python art/tongue/textures.py
# TongueBody.png  - the Beam body, seamless along its length (U) so it can tile.
# Puff.png        - soft white puff for the thwip and whiff dust particles (tinted in Studio).
# Splat.png       - white sticky splat with droplets for the hit particles (tinted in Studio).

import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out")
os.makedirs(OUT, exist_ok=True)
random.seed(7)


def body() -> None:
	width, height = 256, 64
	# Periodic noise: whole-number frequencies along U so the left and right edges match.
	waves = [(random.randint(1, 6), random.uniform(1, 5), random.uniform(0, math.tau), random.uniform(0.3, 1)) for _ in range(10)]
	image = Image.new("RGBA", (width, height))
	pixels = image.load()
	for x in range(width):
		u = x / width
		for y in range(height):
			v = y / (height - 1)
			across = abs(v - 0.5) * 2  # 0 at the middle, 1 at the edges
			noise = sum(a * math.sin(math.tau * k * u + p + f * v * 3) for k, f, p, a in waves) / 6
			# Bumps: small periodic dots.
			dots = math.sin(math.tau * 24 * u + 2.1 * math.sin(math.tau * 3 * u)) * math.sin(math.pi * 9 * v)
			r, g, b = 0.9, 0.42, 0.52
			shade = 1 - 0.35 * across**2 + 0.08 * noise + 0.04 * dots
			# The darker groove down the middle and a wet sheen just above it.
			shade -= 0.22 * math.exp(-((v - 0.5) / 0.05) ** 2)
			sheen = 0.35 * math.exp(-((v - 0.32) / 0.07) ** 2) * (0.7 + 0.3 * math.sin(math.tau * 2 * u))
			color = [min(1.0, c * shade + sheen) for c in (r, g, b)]
			pixels[x, y] = (*(round(c * 255) for c in color), 255)
	image.save(os.path.join(OUT, "TongueBody.png"))


def puff() -> None:
	size = 128
	image = Image.new("RGBA", (size, size))
	pixels = image.load()
	for x in range(size):
		for y in range(size):
			d = math.hypot(x - size / 2 + 0.5, y - size / 2 + 0.5) / (size / 2)
			wobble = 0.04 * math.sin(math.atan2(y - size / 2, x - size / 2) * 5) * d
			alpha = math.exp(-((d + wobble) * 2.2) ** 2) * max(0.0, 1 - d)
			pixels[x, y] = (255, 255, 255, round(alpha * 255))
	image.save(os.path.join(OUT, "Puff.png"))


def splat() -> None:
	size = 256
	scale = 4  # draw big, then shrink for smooth edges
	big = size * scale
	mask = Image.new("L", (big, big))
	draw = ImageDraw.Draw(mask)
	centre = big / 2
	# Main blob: a circle with lumpy edges.
	points = []
	for i in range(48):
		angle = math.tau * i / 48
		radius = big * 0.22 * (1 + 0.12 * math.sin(angle * 3 + 1) + 0.08 * math.sin(angle * 7))
		points.append((centre + math.cos(angle) * radius, centre + math.sin(angle) * radius))
	draw.polygon(points, fill=255)
	# Droplets flung outward.
	for _ in range(14):
		angle = random.uniform(0, math.tau)
		distance = big * random.uniform(0.27, 0.45)
		radius = big * random.uniform(0.015, 0.045)
		x, y = centre + math.cos(angle) * distance, centre + math.sin(angle) * distance
		draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=255)
	mask = mask.filter(ImageFilter.GaussianBlur(scale * 1.5)).resize((size, size), Image.LANCZOS)
	image = Image.new("RGBA", (size, size), (255, 255, 255, 0))
	image.putalpha(mask)
	image.save(os.path.join(OUT, "Splat.png"))


body()
puff()
splat()
print("textures done")
