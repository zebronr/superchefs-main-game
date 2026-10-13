"""SVG versions of the superskill icons (same shapes as make_icons.py), for mockups in Figma.

Run from the repo root: python art/superskill/make_svgs.py
"""

import math
import os

HERE = os.path.dirname(os.path.abspath(__file__))


def f(v):
    return f"{v * 100:.1f}"


def svg(body):
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">{body}</svg>'


def tongue():
    pts = []
    for i in range(31):
        t = i / 30
        a = math.radians(200 - 300 * t)
        r = 0.34 - 0.16 * t
        pts.append((0.52 + r * math.cos(a), 0.5 - r * math.sin(a)))
    d = "M" + " L".join(f"{f(x)} {f(y)}" for x, y in pts)
    tx, ty = pts[-1]
    return svg(f'<path d="{d}" fill="none" stroke="#fff" stroke-width="15" stroke-linecap="round" stroke-linejoin="round"/>'
               f'<circle cx="{f(tx)}" cy="{f(ty)}" r="13" fill="#fff"/>')


def hustle():
    bolt = [(0.58, 0.08), (0.24, 0.55), (0.47, 0.55), (0.38, 0.92), (0.78, 0.4), (0.54, 0.4), (0.66, 0.08)]
    p = " ".join(f"{f(x)},{f(y)}" for x, y in bolt)
    return svg(f'<polygon points="{p}" fill="#fff" stroke="#fff" stroke-width="6" stroke-linejoin="round"/>')


def freeze():
    lines = []
    for k in range(6):
        a = math.radians(90 + k * 60)
        ux, uy = math.cos(a), -math.sin(a)
        lines.append(((0.5, 0.5), (0.5 + ux * 0.38, 0.5 + uy * 0.38), 10))
        bx, by = 0.5 + ux * 0.24, 0.5 + uy * 0.24
        for side in (-1, 1):
            b = a + side * math.radians(50)
            lines.append(((bx, by), (bx + math.cos(b) * 0.12, by - math.sin(b) * 0.12), 8.5))
    body = "".join(f'<line x1="{f(a[0])}" y1="{f(a[1])}" x2="{f(b[0])}" y2="{f(b[1])}" stroke="#fff" stroke-width="{w}" stroke-linecap="round"/>'
                   for a, b, w in lines)
    return svg(body)


def rush():
    holes = "".join(f'<circle cx="{x}" cy="59" r="4.5" fill="#000"/>' for x in (30, 50, 70))
    return svg('<mask id="m"><rect width="100" height="100" fill="#fff"/>' + holes + '</mask>'
               '<g mask="url(#m)"><circle cx="50" cy="42" r="20" fill="#fff"/><ellipse cx="50" cy="59" rx="42" ry="15" fill="#fff"/></g>'
               '<line x1="36" y1="80" x2="30" y2="88" stroke="#fff" stroke-width="7" stroke-linecap="round"/>'
               '<line x1="64" y1="80" x2="70" y2="88" stroke="#fff" stroke-width="7" stroke-linecap="round"/>')


if __name__ == "__main__":
    for name, make in (("Tongue", tongue), ("Hustle", hustle), ("Freeze", freeze), ("Rush", rush)):
        with open(os.path.join(HERE, f"{name}.svg"), "w", encoding="utf-8") as out:
            out.write(make())
    print("ok")
