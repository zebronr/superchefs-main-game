"""Speed line particle sprite: a white streak with a round head at the top tapering to a point at the bottom.

Usage: python art/hustle/speedline.py  ->  art/hustle/SpeedLine.png (tinted on the ParticleEmitter)
With Orientation = VelocityParallel the round head leads and the tail trails.
"""
from pathlib import Path

from PIL import Image, ImageDraw

W, H, SS = 64, 256, 8
w, h = W * SS, H * SS
r = w * 0.3
cx = w / 2
img = Image.new("L", (w, h), 0)
draw = ImageDraw.Draw(img)
draw.ellipse((cx - r, SS * 4, cx + r, SS * 4 + 2 * r), fill=255)
# Tapering tail from the head's widest point down to a point.
top = SS * 4 + r
draw.polygon([(cx - r, top), (cx + r, top), (cx, h - SS * 4)], fill=255)
mask = img.resize((W, H), Image.LANCZOS)
out = Image.new("RGBA", (W, H), (255, 255, 255, 0))
out.putalpha(mask)
out.save(Path(__file__).with_name("SpeedLine.png"))
