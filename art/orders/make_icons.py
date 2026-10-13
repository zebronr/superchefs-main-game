"""Order UI and combo fire sprites (white, tinted in game through ImageColor3).

Run from the repo root: python art/orders/make_icons.py
Writes the PNGs next to this script. FlameFlat.png is exported from the Figma flame vector (white), not drawn here. Shapes match the Figma mockups in "Order UI: B with cooking steps".
"""

import math
import os

from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
SIZE = 256
SS = 4  # supersampling for smooth edges


def canvas(size=SIZE):
    return Image.new("RGBA", (size * SS, size * SS), (255, 255, 255, 0))


def finish(img, name, size=SIZE):
    img = img.resize((size, size), Image.LANCZOS)
    img.save(os.path.join(HERE, name))


def ring():
    # Annulus: outer = full image, inner radius 84% (the timer ring around the plate).
    img = canvas()
    d = ImageDraw.Draw(img)
    s = SIZE * SS
    d.ellipse((0, 0, s - 1, s - 1), fill=(255, 255, 255, 255))
    inset = s * 0.08
    d.ellipse((inset, inset, s - 1 - inset, s - 1 - inset), fill=(255, 255, 255, 0))
    finish(img, "Ring.png")


def glow():
    # Soft round blob: urgent glow, smoke puffs.
    s = SIZE
    img = Image.new("L", (s, s), 0)
    px = img.load()
    for y in range(s):
        for x in range(s):
            r = math.hypot(x - s / 2 + 0.5, y - s / 2 + 0.5) / (s / 2)
            px[x, y] = int(255 * max(0.0, 1 - r) ** 1.6)
    out = Image.new("RGBA", (s, s), (255, 255, 255, 0))
    out.putalpha(img)
    out.save(os.path.join(HERE, "Glow.png"))


def check():
    # Fat rounded check, centred on its visual bounds.
    img = canvas()
    d = ImageDraw.Draw(img)
    s = SIZE * SS
    w = int(s * 0.17)
    pts = [(s * 0.2, s * 0.53), (s * 0.41, s * 0.73), (s * 0.8, s * 0.3)]
    d.line(pts, fill=(255, 255, 255, 255), width=w, joint="curve")
    for x, y in (pts[0], pts[2]):
        d.ellipse((x - w / 2, y - w / 2, x + w / 2, y + w / 2), fill=(255, 255, 255, 255))
    # Re-centre: bounds of the drawn pixels to the middle.
    box = img.getbbox()
    shifted = canvas()
    dx = (s - (box[2] - box[0])) // 2 - box[0]
    dy = (s - (box[3] - box[1])) // 2 - box[1]
    shifted.paste(img, (dx, dy))
    finish(shifted, "Check.png")


def pot():
    img = canvas()
    d = ImageDraw.Draw(img)
    u = SIZE * SS / 26
    c = SIZE * SS / 2
    white = (255, 255, 255, 255)
    d.rounded_rectangle((c - 8 * u, c - 6.5 * u, c + 8 * u, c - 4 * u), radius=1.2 * u, fill=white)  # lid
    d.rounded_rectangle((c - 1.5 * u, c - 8.5 * u, c + 1.5 * u, c - 6 * u), radius=1 * u, fill=white)  # knob
    d.rounded_rectangle((c - 7 * u, c - 3 * u, c + 7 * u, c + 7 * u), radius=3 * u, fill=white)  # body
    d.rounded_rectangle((c - 10.5 * u, c - 1.5 * u, c - 6 * u, c + 1.5 * u), radius=1.2 * u, fill=white)
    d.rounded_rectangle((c + 6 * u, c - 1.5 * u, c + 10.5 * u, c + 1.5 * u), radius=1.2 * u, fill=white)
    finish(img, "Pot.png")


def pan():
    img = canvas()
    d = ImageDraw.Draw(img)
    u = SIZE * SS / 26
    c = SIZE * SS / 2
    white = (255, 255, 255, 255)
    cx = c - 3 * u
    d.ellipse((cx - 7 * u, c - 7 * u, cx + 7 * u, c + 7 * u), fill=white)
    d.ellipse((cx - 4.5 * u, c - 4.5 * u, cx + 4.5 * u, c + 4.5 * u), fill=(255, 255, 255, 0))
    d.rounded_rectangle((cx + 6 * u, c - 1.6 * u, cx + 14 * u, c + 1.6 * u), radius=1.6 * u, fill=white)
    finish(img, "Pan.png")


def flame():
    # Soft teardrop flame, tip up, slightly blurred so it reads as fire rather than a hard shape.
    s = SIZE * SS
    img = canvas()
    d = ImageDraw.Draw(img)
    pts = []
    for i in range(181):
        t = i / 180 * 2 * math.pi
        # Teardrop: round bottom, pointed top.
        x = math.sin(t) * (0.5 - 0.5 * math.cos(t) ** 1) ** 0.9
        y = -math.cos(t)
        pts.append((s / 2 + x * s * 0.42, s * 0.56 - y * s * 0.42))
    d.polygon(pts, fill=(255, 255, 255, 255))
    img = img.filter(ImageFilter.GaussianBlur(s * 0.012)).transpose(Image.FLIP_TOP_BOTTOM)
    finish(img, "Flame.png")


def plus():
    # Fat "+" with rounded ends: combo sparks and the served-stamp sparkles (the Figma "Spark" crosses).
    img = canvas()
    d = ImageDraw.Draw(img)
    s = SIZE * SS
    w = s * 0.26
    white = (255, 255, 255, 255)
    d.rounded_rectangle((s * 0.06, s / 2 - w / 2, s * 0.94, s / 2 + w / 2), radius=w / 2, fill=white)
    d.rounded_rectangle((s / 2 - w / 2, s * 0.06, s / 2 + w / 2, s * 0.94), radius=w / 2, fill=white)
    finish(img, "Plus.png")


def spark():
    # Four-point twinkle.
    s = SIZE * SS
    img = canvas()
    d = ImageDraw.Draw(img)
    c = s / 2
    pts = []
    for i in range(8):
        a = i / 8 * 2 * math.pi - math.pi / 2
        r = s * 0.48 if i % 2 == 0 else s * 0.12
        pts.append((c + math.cos(a) * r, c + math.sin(a) * r))
    d.polygon(pts, fill=(255, 255, 255, 255))
    finish(img, "Spark.png")


if __name__ == "__main__":
    ring()
    glow()
    check()
    pot()
    pan()
    flame()
    spark()
    plus()
    print("done")
