"""Superskill HUD icons (white, tinted per superskill in game through ImageColor3).

Run from the repo root: python art/superskill/make_icons.py
Writes the PNGs next to this script. Same flat, fat, rounded look as art/orders/make_icons.py: one solid shape each,
no shading, readable at 40 px.
"""

import math
import os

from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
SIZE = 256
SS = 4  # supersampling for smooth edges
S = SIZE * SS
WHITE = (255, 255, 255, 255)


def canvas():
    return Image.new("L", (S, S), 0)


def soften(mask, radius):
    # Rounds every corner: blur, then cut at half so the shape keeps its size.
    return mask.filter(ImageFilter.GaussianBlur(radius * SS)).point(lambda v: 255 if v >= 128 else 0)


def finish(mask, name):
    out = Image.new("RGBA", (S, S), (255, 255, 255, 0))
    out.putalpha(mask)
    out.resize((SIZE, SIZE), Image.LANCZOS).save(os.path.join(HERE, name))


def stroke(d, points, width):
    d.line(points, fill=255, width=int(width), joint="curve")
    for x, y in (points[0], points[-1]):
        d.ellipse((x - width / 2, y - width / 2, x + width / 2, y + width / 2), fill=255)


def tongue():
    # Gecko's Tongue Grab: a fat tongue lashing out in a curl, ending in a round sticky tip.
    mask = canvas()
    d = ImageDraw.Draw(mask)
    # Spiral in from the root at the bottom left, curling round to the tip.
    points = []
    for i in range(61):
        t = i / 60
        a = math.radians(200 - 300 * t)
        r = 0.34 - 0.16 * t
        points.append(((0.52 + r * math.cos(a)) * S, (0.5 - r * math.sin(a)) * S))
    stroke(d, points, S * 0.15)
    tip = points[-1]
    r = S * 0.13
    d.ellipse((tip[0] - r, tip[1] - r, tip[0] + r, tip[1] + r), fill=255)
    finish(soften(mask, 3), "Tongue.png")


def hustle():
    # Bill's Hustle: a chunky lightning bolt.
    mask = canvas()
    d = ImageDraw.Draw(mask)
    bolt = [(0.58, 0.08), (0.24, 0.55), (0.47, 0.55), (0.38, 0.92), (0.78, 0.4), (0.54, 0.4), (0.66, 0.08)]
    d.polygon([(x * S, y * S) for x, y in bolt], fill=255)
    finish(soften(mask, 6), "Hustle.png")


def freeze():
    # Penguin's Deep Freeze: a six-armed snowflake with a V near each tip.
    mask = canvas()
    d = ImageDraw.Draw(mask)
    c = S / 2
    w = S * 0.1
    for k in range(6):
        a = math.radians(90 + k * 60)
        ux, uy = math.cos(a), -math.sin(a)
        end = (c + ux * S * 0.38, c + uy * S * 0.38)
        stroke(d, [(c, c), end], w)
        base = (c + ux * S * 0.24, c + uy * S * 0.24)
        for side in (-1, 1):
            b = a + side * math.radians(50)
            branch = (base[0] + math.cos(b) * S * 0.12, base[1] - math.sin(b) * S * 0.12)
            stroke(d, [base, branch], w * 0.85)
    finish(soften(mask, 2), "Freeze.png")


def rush():
    # Alien's Order Rush: a flying saucer with a dome and three portholes.
    mask = canvas()
    d = ImageDraw.Draw(mask)
    d.ellipse((0.3 * S, 0.22 * S, 0.7 * S, 0.62 * S), fill=255)  # dome
    d.ellipse((0.08 * S, 0.44 * S, 0.92 * S, 0.74 * S), fill=255)  # saucer
    for x in (0.3, 0.5, 0.7):
        r = S * 0.045
        d.ellipse((x * S - r, 0.59 * S - r, x * S + r, 0.59 * S + r), fill=0)
    stroke(d, [(0.36 * S, 0.8 * S), (0.3 * S, 0.88 * S)], S * 0.07)  # legs
    stroke(d, [(0.64 * S, 0.8 * S), (0.7 * S, 0.88 * S)], S * 0.07)
    finish(soften(mask, 2), "Rush.png")


if __name__ == "__main__":
    tongue()
    hustle()
    freeze()
    rush()
    print("ok")
