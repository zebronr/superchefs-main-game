# Builds floor decals and particle sprites for the Penguin's Deep Freeze superskill.
# Run from the repo root: python art/frost/textures.py
# Writes art/frost/out/FrostCircle.png, Cracks.png, Shockwave.png, Snowflake.png, and Puff.png.
# A fixed seed and fixed polygon layout make reruns identical.

import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out")
os.makedirs(OUT, exist_ok=True)
RNG = random.Random(2906)
SIZE = 512
SCALE = 4
N = SIZE * SCALE
C = N / 2
R = 0.475 * N
# Gameplay radius maps to 78% of the image half-width. The code's
# Visuals.FrostScale must equal 1 / LOGICAL = 1.28.
LOGICAL = 0.78


def polar(angle, radius):
    return (C + radius * math.cos(angle), C + radius * math.sin(angle))


def downsample(image, size):
    return image.resize((size, size), Image.Resampling.LANCZOS)


# The ice is made of flat wedge faces. Twelve uneven, occasionally forked
# tendrils interrupt its edge; this is art for the Deep Freeze superskill.
ice = Image.new("RGBA", (N, N))
draw = ImageDraw.Draw(ice)
# A solid underlayer closes the narrow seams where different facet rings meet.
draw.ellipse((C * 0.28, C * 0.28, C * 1.72, C * 1.72),
             fill=(166, 220, 250, 196))
wedges = 24
shades = [(159, 216, 248, 196), (173, 226, 255, 198),
          (185, 233, 255, 196), (151, 209, 244, 196)]
rim_shades = [(210, 244, 255, 210), (221, 248, 255, 214),
              (197, 237, 254, 211)]
phase = -math.pi / 2
inner = [C * RNG.uniform(0.16, 0.31) for _ in range(wedges)]
middle = [C * RNG.uniform(0.51, 0.61) for _ in range(wedges)]
for i in range(wedges):
    j = (i + 1) % wedges
    a = phase + 2 * math.pi * i / wedges
    b = phase + 2 * math.pi * j / wedges
    draw.polygon([polar(a, inner[i]), polar(b, inner[j]),
                  polar(b, middle[j]), polar(a, middle[i])],
                 fill=shades[i % len(shades)])
draw.polygon([polar(phase + 2 * math.pi * i / wedges, inner[i])
              for i in range(wedges)], fill=(183, 231, 255, 197))

edge_steps = 48
step_angle = 2 * math.pi / edge_steps
base_radii = [C * RNG.uniform(0.72, 0.84) for _ in range(edge_steps)]
# A jittered four-sector rhythm leaves unequal gaps while keeping points apart.
point_sectors = {((i * 4 + RNG.choice((-1, 0, 0, 1))) % edge_steps): i
                 for i in range(12)}
edge = []
for i in range(edge_steps):
    angle = phase + i * step_angle
    edge.append((angle, base_radii[i]))
    if i in point_sectors:
        tip_r = C * RNG.uniform(0.90, 0.98)
        edge.append((angle + step_angle * 0.24, C * RNG.uniform(0.80, 0.85)))
        edge.append((angle + step_angle * 0.52, tip_r))
        if point_sectors[i] in (2, 7, 10):
            edge.append((angle + step_angle * 0.69, C * RNG.uniform(0.81, 0.85)))
            edge.append((angle + step_angle * 0.82, C * RNG.uniform(0.89, 0.94)))
        else:
            edge.append((angle + step_angle * 0.79, C * RNG.uniform(0.80, 0.85)))

# Facet and rim polygons use the very same vertices as the silhouette.
for i, (angle, radius) in enumerate(edge):
    next_angle, next_radius = edge[(i + 1) % len(edge)]
    draw.polygon([polar(angle, C * 0.55), polar(next_angle, C * 0.55),
                  polar(next_angle, next_radius), polar(angle, radius)],
                 fill=shades[(i + 2) % len(shades)])
    draw.polygon([polar(angle, radius - C * 0.043),
                  polar(next_angle, next_radius - C * 0.043),
                  polar(next_angle, next_radius), polar(angle, radius)],
                 fill=rim_shades[i % len(rim_shades)])

mask = Image.new("L", (N, N))
ImageDraw.Draw(mask).polygon([polar(angle, radius) for angle, radius in edge], fill=255)
alpha = ice.getchannel("A")
from PIL import ImageChops
ice.putalpha(ImageChops.multiply(alpha, mask))
downsample(ice, SIZE).save(os.path.join(OUT, "FrostCircle.png"))


# Branched cracks follow the same irregular edge, with some running up points.
cracks = Image.new("RGBA", (N, N))
crack_draw = ImageDraw.Draw(cracks)

def edge_radius(angle):
    relative = (angle - phase) % (2 * math.pi)
    for i in range(len(edge)):
        a, ra = edge[i]
        b, rb = edge[(i + 1) % len(edge)]
        aa = (a - phase) % (2 * math.pi)
        bb = (b - phase) % (2 * math.pi)
        if bb <= aa:
            bb += 2 * math.pi
        probe = relative + (2 * math.pi if relative < aa else 0)
        if aa <= probe <= bb:
            return ra + (rb - ra) * (probe - aa) / (bb - aa)
    return C * LOGICAL

for arm in range(9):
    if arm < 4:
        sector = list(point_sectors)[arm * 3]
        angle = phase + (sector + 0.52) * step_angle
    else:
        angle = 2 * math.pi * arm / 9 + RNG.uniform(-0.11, 0.11)
    radius = C * RNG.uniform(0.04, 0.15)
    points = [polar(angle, radius)]
    for step in range(1, 8):
        radius = C * (0.10 + step * 0.10)
        if arm >= 4:
            angle += RNG.uniform(-0.08, 0.08)
        points.append(polar(angle, radius))
        if step in (3, 5):
            branch_angle = angle + RNG.choice((-1, 1)) * RNG.uniform(0.27, 0.46)
            branch = [points[-1]]
            for k in range(1, 4):
                branch_angle += RNG.uniform(-0.11, 0.11)
                branch.append(polar(branch_angle, min(edge_radius(branch_angle) * 1.02,
                                                       radius + C * 0.09 * k)))
            crack_draw.line(branch, fill=(232, 247, 255, 236), width=9)
    points.append(polar(angle, edge_radius(angle) * 1.02))
    crack_draw.line(points, fill=(235, 248, 255, 246), width=RNG.choice((9, 11, 13, 15)))
cracks.putalpha(ImageChops.multiply(cracks.getchannel("A"), mask))
downsample(cracks, SIZE).save(os.path.join(OUT, "Cracks.png"))


# A narrow ring with a light inner shoulder. Its center remains fully clear.
shock = Image.new("RGBA", (SIZE, SIZE))
pixels = shock.load()
center = (SIZE - 1) / 2
radius = 0.475 * SIZE
for y in range(SIZE):
    for x in range(SIZE):
        d = math.hypot(x - center, y - center) / radius
        core = max(0.0, 1.0 - abs(d - 0.90) / 0.014)
        shoulder = max(0.0, 1.0 - abs(d - 0.88) / 0.055) ** 2
        opacity = min(1.0, core * 0.95 + shoulder * 0.36)
        pixels[x, y] = (236, 250, 255, round(opacity * 255))
shock.save(os.path.join(OUT, "Shockwave.png"))


# Chunky six-way snowflake, drawn as opaque polygons with clean antialiasing.
S = 128
K = 4
snow = Image.new("RGBA", (S * K, S * K))
sd = ImageDraw.Draw(snow)
cx = cy = S * K / 2
def rotated_polygon(coords, angle):
    ca, sa = math.cos(angle), math.sin(angle)
    return [(cx + x * ca - y * sa, cy + x * sa + y * ca) for x, y in coords]

arm = [(0, -10*K), (-5*K, -19*K), (-5*K, -45*K),
       (0, -53*K), (5*K, -45*K), (5*K, -19*K)]
twig_left = [(-4*K, -29*K), (-18*K, -39*K), (-21*K, -34*K), (-5*K, -20*K)]
twig_right = [(-x, y) for x, y in twig_left]
for i in range(6):
    angle = i * math.pi / 3
    for shape in (arm, twig_left, twig_right):
        sd.polygon(rotated_polygon(shape, angle), fill=(246, 253, 255, 255))
sd.ellipse((cx - 9*K, cy - 9*K, cx + 9*K, cy + 9*K), fill=(246, 253, 255, 255))
downsample(snow, S).save(os.path.join(OUT, "Snowflake.png"))


# A lumpy, soft-edged particle. Blur only this organic sprite, never the ice.
puff = Image.new("RGBA", (S * K, S * K))
pd = ImageDraw.Draw(puff)
for x, y, rad in [(64, 64, 38), (38, 65, 23), (49, 43, 25),
                  (77, 40, 24), (94, 60, 25), (73, 84, 27), (44, 84, 22)]:
    pd.ellipse(((x-rad)*K, (y-rad)*K, (x+rad)*K, (y+rad)*K),
               fill=(250, 254, 255, 223))
puff = puff.filter(ImageFilter.GaussianBlur(2.5 * K))
downsample(puff, S).save(os.path.join(OUT, "Puff.png"))

print("FrostCircle.png, Cracks.png, Shockwave.png, Snowflake.png, Puff.png done")
