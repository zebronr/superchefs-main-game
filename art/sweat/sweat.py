"""Sweat drop particle sprite: white teardrop (round end up, tip down) with a soft sheen.

Usage: python art/sweat/sweat.py  ->  art/sweat/SweatDrop.png (tinted on the ParticleEmitter)
With Orientation = VelocityParallel the round end leads and the tip trails.
"""
import math
import os

from PIL import Image, ImageDraw, ImageFilter

SIZE = 128
SS = 4  # supersampling
HERE = os.path.dirname(os.path.abspath(__file__))


def teardrop(cx, cy, r, length, steps=200):
    """Circle of radius r centred at (cx, cy) that tapers to a tip `length` below its centre."""
    points = []
    tip_angle = math.asin(r / length)
    for i in range(steps + 1):
        # Walk the circle from one tangent point, over the top, to the other.
        a = -tip_angle + (math.pi + 2 * tip_angle) * i / steps
        points.append((cx + r * math.cos(a + math.pi), cy - r * math.sin(a + math.pi) * -1))
    points.append((cx, cy + length))
    return points


def main():
    s = SIZE * SS
    img = Image.new("RGBA", (s, s), (255, 255, 255, 0))
    cx, cy, r = s * 0.5, s * 0.36, s * 0.27
    shape = teardrop(cx, cy, r, s * 0.58)
    # Body: soft grey edge, white middle (baked shading so the tint reads as a wet drop).
    mask = Image.new("L", (s, s), 0)
    ImageDraw.Draw(mask).polygon(shape, fill=255)
    body = Image.new("RGBA", (s, s), (205, 215, 230, 255))
    inner = mask.filter(ImageFilter.GaussianBlur(s * 0.06)).point(lambda v: max(0, v - 60) * 255 // 195)
    white = Image.new("RGBA", (s, s), (255, 255, 255, 255))
    body = Image.composite(white, body, inner)
    img.paste(body, (0, 0), mask)
    # Sheen: a small bright oval at the upper left of the round end.
    sheen = Image.new("L", (s, s), 0)
    ImageDraw.Draw(sheen).ellipse((cx - r * 0.62, cy - r * 0.7, cx - r * 0.12, cy - r * 0.05), fill=255)
    sheen = sheen.filter(ImageFilter.GaussianBlur(s * 0.012))
    img.paste(Image.new("RGBA", (s, s), (255, 255, 255, 255)), (0, 0), Image.composite(sheen, Image.new("L", (s, s), 0), mask))
    img = img.resize((SIZE, SIZE), Image.LANCZOS)
    path = os.path.join(HERE, "SweatDrop.png")
    img.save(path)
    print(path)


if __name__ == "__main__":
    main()
