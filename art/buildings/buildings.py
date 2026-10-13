# Builds the decorative low-poly city set that fills the space around the restaurant map: six buildings (a corner shop,
# a shop with flats, an apartment block, a narrow townhouse, a background tower and a diner) plus a street lamp and a
# bench. Same pipeline as art/cars/car.py: bmesh geometry, faceted flat shading, every face mapped to one cell of a small
# palette texture. Windows are inset faces with light reveals, sills and trims protrude, body corners are chamfered.
# Run headless from the repo root:
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup --python art/buildings/buildings.py
# Writes art/buildings/out/<Name>.fbx for every model (one object each, all parts joined), the shared palette textures,
# the preview renders Buildings_lineup.png (3/4 front, one colour variant each, the sedan for scale), Buildings_back.png
# (3/4 rear) and Props.png, and art/buildings/Buildings.blend.
# Palettes: every building uses the SAME cell layout, so any Bldg_Palette_<Variant>.png fits any building. A variant
# only changes the WALL cell (WALL_DARK is derived from it) and the AWNING accent cell. Bldg_Palette.png is the default
# (Salmon) and is embedded in the building FBXs; Bldg_Palette_Salmon/_Mint/_Butter/_Sky/_Lavender/_Cream.png are the
# variants. The props use Prop_Palette.png (same layout, default colours). Swap the MeshPart's TextureID in Studio.
# Units are studs. Front is Blender +Y (Roblox -Z, the LookVector, with the axes used below), up is Blender +Z (Roblox
# +Y). A building's origin is the bottom centre of its FRONT wall: the front wall is the plane Y = 0, the building runs
# back to Y = -depth, and only steps, awnings, canopies and balconies stick out in front. The lamp's origin is the
# bottom centre of its base (the arm reaches toward +Y); the bench's origin is its bottom centre (seat faces +Y).

import math
import os
import random

import bpy
import bmesh
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
REPO = os.path.dirname(os.path.dirname(HERE))
GRID = 8  # palette cells per row
CELL = 32  # pixels per cell
TEXTURE_SIZE = GRID * CELL

os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)

# Palette (sRGB 0-255), shared by every model. WALL, WALL_DARK and AWNING are the only cells a variant changes.
# Darker, warmer and less saturated than the first pass so the street sits with the warm restaurant interior. The
# in-game sky light adds a cool cast, so these lean warmer than they look in Blender.
# LAMP_POLE, LAMP_GLASS, METAL_DARK and WOOD are the cells the props use, so changing them changes Prop_Palette.png.
PALETTE = {
	"WALL": (180, 96, 68),
	"WALL_DARK": (148, 75, 53),  # derived per variant, see wall_dark()
	"AWNING": (56, 98, 84),
	"AWNING_LIGHT": (220, 200, 168),
	"TRIM": (204, 182, 148),  # cornices, sills, bands
	"FRAME": (178, 154, 122),  # window reveals
	"WINDOW": (78, 80, 88),
	"WINDOW_LIT": (244, 192, 100),
	"SHOPWIN": (48, 44, 46),
	"DOOR": (98, 60, 42),
	"SIGN": (220, 196, 152),
	"SIGN_TEXT": (168, 58, 46),
	"ROOF": (104, 88, 78),
	"ROOF_TILE": (146, 72, 52),
	"BASE": (92, 74, 64),
	"STEP": (150, 134, 116),
	"METAL": (140, 132, 126),
	"METAL_DARK": (68, 70, 80),
	"TANK": (138, 92, 60),
	"TANK_DARK": (92, 62, 46),
	"BRICK": (138, 72, 56),
	"WOOD": (186, 126, 80),
	"LAMP_POLE": (58, 78, 76),
	"LAMP_GLASS": (252, 226, 148),
}
CELLS = {name: index for index, name in enumerate(PALETTE)}
NAMES = list(PALETTE)
# Warm, dusty pastels (wall, awning accent). The first one is the default.
VARIANTS = {
	"Salmon": ((180, 96, 68), (56, 98, 84)),
	"Mint": ((124, 138, 96), (164, 64, 44)),
	"Butter": ((200, 150, 74), (64, 88, 96)),
	"Sky": ((114, 118, 120), (190, 110, 48)),
	"Lavender": ((140, 100, 104), (66, 100, 78)),
	"Cream": ((196, 168, 124), (142, 56, 42)),
}


def wall_dark(rgb):
	return (round(rgb[0] * 0.82), round(rgb[1] * 0.78), round(rgb[2] * 0.78))


def cell_uv(name):
	index = CELLS[name]
	return ((index % GRID + 0.5) / GRID, 1 - (index // GRID + 0.5) / GRID)


bm = None


def begin():
	global bm
	bm = bmesh.new()


def make_face(points, name, outward=None):
	"""A face from points (or verts), flipped so its normal points along `outward` (if given), tagged with its cell."""
	face = bm.faces.new([bm.verts.new(p) if not isinstance(p, bmesh.types.BMVert) else p for p in points])
	face.normal_update()
	if outward is not None and face.normal.dot(Vector(outward)) < 0:
		face.normal_flip()
	face.material_index = CELLS[name]
	return face


def block(corners, name, skip=(), cells=None):
	"""A convex hexahedron from corners keyed (i, j, k) in {0,1}^3. `skip` names faces to leave out ('-x' is i = 0,
	'+y' is j = 1, '-z' is k = 0 ...); `cells` overrides the cell per face."""
	v = {key: bm.verts.new(Vector(p)) for key, p in corners.items()}
	centroid = sum((x.co for x in v.values()), Vector()) / 8
	sides = {
		"-x": [v[0, 0, 0], v[0, 1, 0], v[0, 1, 1], v[0, 0, 1]],
		"+x": [v[1, 0, 0], v[1, 1, 0], v[1, 1, 1], v[1, 0, 1]],
		"-y": [v[0, 0, 0], v[1, 0, 0], v[1, 0, 1], v[0, 0, 1]],
		"+y": [v[0, 1, 0], v[1, 1, 0], v[1, 1, 1], v[0, 1, 1]],
		"-z": [v[0, 0, 0], v[1, 0, 0], v[1, 1, 0], v[0, 1, 0]],
		"+z": [v[0, 0, 1], v[1, 0, 1], v[1, 1, 1], v[0, 1, 1]],
	}
	for key, quad in sides.items():
		if key in skip:
			continue
		mid = sum((q.co for q in quad), Vector()) / 4
		make_face(quad, (cells or {}).get(key, name), mid - centroid)


def box(x0, x1, y0, y1, z0, z1, name, skip=(), cells=None):
	xs, ys, zs = (x0, x1), (y0, y1), (z0, z1)
	block({(i, j, k): (xs[i], ys[j], zs[k]) for i in (0, 1) for j in (0, 1) for k in (0, 1)}, name, skip, cells)


def prism(center, radius, z0, z1, sides, name, cap=None, bottom=None, radius_top=None, phase=None):
	"""A vertical n-sided prism (a frustum if radius_top is given). `cap`/`bottom` are the end cells (None = open)."""
	cx, cy = center
	phase = math.pi / sides if phase is None else phase
	rings = []
	for z, r in ((z0, radius), (z1, radius if radius_top is None else radius_top)):
		rings.append([bm.verts.new((cx + r * math.cos(2 * math.pi * i / sides + phase),
			cy + r * math.sin(2 * math.pi * i / sides + phase), z)) for i in range(sides)])
	for i in range(sides):
		j = (i + 1) % sides
		quad = [rings[0][i], rings[0][j], rings[1][j], rings[1][i]]
		mid = sum((q.co for q in quad), Vector()) / 4
		make_face(quad, name, mid - Vector((cx, cy, mid.z)))
	if cap and (radius_top is None or radius_top > 0.001):
		make_face(rings[1], cap, (0, 0, 1))
	if bottom:
		make_face(rings[0], bottom, (0, 0, -1))


def ring(rect, c, z, off):
	"""The chamfered rectangle outline (8 points, counter-clockwise from above), grown outward by `off`."""
	x0, x1, y0, y1 = rect[0] - off, rect[1] + off, rect[2] - off, rect[3] + off
	cc = max(0.03, c + off * 0.4142)
	pts = [(x0 + cc, y0), (x1 - cc, y0), (x1, y0 + cc), (x1, y1 - cc), (x1 - cc, y1), (x0 + cc, y1), (x0, y1 - cc), (x0, y0 + cc)]
	return [Vector((x, y, z)) for x, y in pts]


def loft(rect, c, profile, cells, top=None):
	"""A lathe-like band around the chamfered rectangle: `profile` is [(z, outward offset)] walked up the outside and
	down the inside (that order sets the face normals), `cells` one cell per segment (or one for all); `top` caps the
	last ring."""
	if isinstance(cells, str):
		cells = [cells] * (len(profile) - 1)
	rings = [[bm.verts.new(p) for p in ring(rect, c, z, off)] for z, off in profile]
	for k in range(len(rings) - 1):
		a, b = rings[k], rings[k + 1]
		for i in range(8):
			j = (i + 1) % 8
			normal = (a[j].co - a[i].co).cross(b[i].co - a[i].co)
			if normal.length < 1e-9:
				continue
			make_face([a[i], a[j], b[j], b[i]], cells[k], normal)
	if top:
		make_face(rings[-1], top, (0, 0, 1))


def band(rect, c, z0, z1, out, name):
	"""A protruding string course around the body."""
	loft(rect, c, [(z0, 0), (z0, out), (z1, out), (z1, 0)], name)


def cornice(rect, c, z, height, parapet, name_wall="WALL", depth=0.7):
	"""Bevelled cornice at the top of the body, then a parapet with a flat roof inside it. Returns the roof height."""
	roof = z + height - depth
	loft(rect, c, [
		(z, 0), (z + 0.35, 0.42), (z + 0.85, 0.42), (z + 1.0, 0.2),
		(z + height, 0.2), (z + height, -parapet), (roof, -parapet),
	], ["TRIM", "TRIM", "TRIM", name_wall, "TRIM", "WALL_DARK"], top="ROOF")
	return roof


def poly_prism(points, z0, z1, name, top=None, bottom=None):
	"""Extrudes a counter-clockwise 2D outline from z0 to z1."""
	a = [bm.verts.new((x, y, z0)) for x, y in points]
	b = [bm.verts.new((x, y, z1)) for x, y in points]
	for i in range(len(points)):
		j = (i + 1) % len(points)
		make_face([a[i], a[j], b[j], b[i]], name, (b[i].co - a[i].co).cross(a[j].co - a[i].co) * -1)
	if top:
		make_face(b, top, (0, 0, 1))
	if bottom:
		make_face(a, bottom, (0, 0, -1))


class Side:
	"""A flat wall: points are O + U*u + Z*z (+ N*t outward). Openings are punched in by facade()."""

	def __init__(self, origin, u_axis, normal, u0, u1):
		self.O, self.U, self.N = Vector(origin), Vector(u_axis).normalized(), Vector(normal).normalized()
		self.u0, self.u1 = u0, u1
		self.openings = []

	def P(self, u, z, t=0.0):
		return self.O + self.U * u + Vector((0, 0, z)) + self.N * t

	def open(self, ua, ub, za, zb, name, depth=0.25, reveal="FRAME"):
		self.openings.append((ua, ub, za, zb, name, depth, reveal))

	def slab(self, ua, ub, za, zb, t0, t1, name, skip=("-y",), cells=None):
		us, ts, zs = (ua, ub), (t0, t1), (za, zb)
		block({(i, j, k): self.P(us[i], zs[k], ts[j]) for i in (0, 1) for j in (0, 1) for k in (0, 1)}, name, skip, cells)


def sides_of(width, depth, c):
	hw = width / 2
	return {
		"front": Side((0, 0, 0), (1, 0, 0), (0, 1, 0), -hw + c, hw - c),
		"back": Side((0, -depth, 0), (1, 0, 0), (0, -1, 0), -hw + c, hw - c),
		"right": Side((hw, 0, 0), (0, -1, 0), (1, 0, 0), c, depth - c),
		"left": Side((-hw, 0, 0), (0, -1, 0), (-1, 0, 0), c, depth - c),
	}


def facade(side, z0, z1, wall="WALL"):
	"""The wall face split on a grid by its openings; opening cells are pushed in, with reveals on their borders."""
	us = sorted({side.u0, side.u1} | {u for o in side.openings for u in o[:2] if side.u0 < u < side.u1})
	zs = sorted({z0, z1} | {z for o in side.openings for z in o[2:4] if z0 < z < z1})
	nu, nz = len(us) - 1, len(zs) - 1
	owners = {}
	for i in range(nu):
		for j in range(nz):
			uc, zc = (us[i] + us[i + 1]) / 2, (zs[j] + zs[j + 1]) / 2
			owners[i, j] = next((k for k, o in enumerate(side.openings) if o[0] < uc < o[1] and o[2] < zc < o[3]), -1)
	outer, inner = {}, {}

	def vo(i, j):
		if (i, j) not in outer:
			outer[i, j] = bm.verts.new(side.P(us[i], zs[j]))
		return outer[i, j]

	def vi(k, i, j):
		if (k, i, j) not in inner:
			inner[k, i, j] = bm.verts.new(side.P(us[i], zs[j], -side.openings[k][5]))
		return inner[k, i, j]

	for i in range(nu):
		for j in range(nz):
			k = owners[i, j]
			corners = [(i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1)]
			if k < 0:
				make_face([vo(*c) for c in corners], wall, side.N)
				continue
			opening = side.openings[k]
			make_face([vi(k, *c) for c in corners], opening[4], side.N)
			center = side.P((us[i] + us[i + 1]) / 2, (zs[j] + zs[j + 1]) / 2, -opening[5])
			edges = (
				((i, j), (i + 1, j), (i, j - 1)),
				((i + 1, j), (i + 1, j + 1), (i + 1, j)),
				((i + 1, j + 1), (i, j + 1), (i, j + 1)),
				((i, j + 1), (i, j), (i - 1, j)),
			)
			for a, b, neighbour in edges:
				if owners.get(neighbour, -1) == k:
					continue
				quad = [vo(*a), vo(*b), vi(k, *b), vi(k, *a)]
				mid = sum((q.co for q in quad), Vector()) / 4
				make_face(quad, opening[6], center - mid)


def body(sides, rect, c, z0, z1, walls=None):
	"""The four facades plus the chamfered corner strips."""
	for key, side in sides.items():
		facade(side, z0, z1, (walls or {}).get(key, "WALL"))
	a = [bm.verts.new(p) for p in ring(rect, c, z0, 0)]
	b = [bm.verts.new(p) for p in ring(rect, c, z1, 0)]
	for i in (1, 3, 5, 7):
		j = (i + 1) % 8
		make_face([a[i], a[j], b[j], b[i]], (walls or {}).get("corner", "WALL"), (a[j].co - a[i].co).cross(b[i].co - a[i].co))


def window(side, uc, w, za, zb, rng, lit=0.3, sill=True, head=False, depth=0.25, name=None):
	"""An inset window (lit at random, deterministic per building) with an optional sill and head trim."""
	name = name or ("WINDOW_LIT" if rng.random() < lit else "WINDOW")
	side.open(uc - w / 2, uc + w / 2, za, zb, name, depth)
	if sill:
		side.slab(uc - w / 2 - 0.22, uc + w / 2 + 0.22, za - 0.24, za, 0, 0.3, "TRIM")
	if head:
		side.slab(uc - w / 2 - 0.14, uc + w / 2 + 0.14, zb, zb + 0.22, 0, 0.14, "TRIM")


def door(side, ua, ub, za, zb, glass=True, depth=0.35):
	side.open(ua, ub, za, zb, "DOOR", depth)
	if glass:
		m = (ub - ua) * 0.2
		side.slab(ua + m, ub - m, za + (zb - za) * 0.45, zb - m, -depth, -depth + 0.06, "SHOPWIN")
	side.slab(ub - 0.5, ub - 0.3, za + (zb - za) * 0.42, za + (zb - za) * 0.48, -depth, -depth + 0.14, "METAL")


def mullions(side, ua, ub, za, zb, count, depth=0.3, horizontal=None):
	"""Trim bars in front of a recessed shop window."""
	for k in range(1, count + 1):
		u = ua + (ub - ua) * k / (count + 1)
		side.slab(u - 0.12, u + 0.12, za, zb, -depth, -depth + 0.14, "TRIM")
	if horizontal is not None:
		side.slab(ua, ub, horizontal - 0.1, horizontal + 0.1, -depth, -depth + 0.14, "TRIM")


def letters(side, uc, zc, height, width, t0, rng, name="SIGN_TEXT"):
	"""A row of chunky blocks that reads as lettering from a distance."""
	widths = [rng.uniform(0.55, 1.0) for _ in range(rng.randint(5, 7))]
	gap = 0.28
	scale = width / (sum(widths) + gap * (len(widths) - 1))
	u = uc - width / 2
	for w in widths:
		w *= scale
		h = height * (1.0 if rng.random() < 0.8 else 0.7)
		side.slab(u, u + w, zc - height / 2, zc - height / 2 + h, t0, t0 + 0.12, name)
		u += w + gap * scale


def awning(side, ua, ub, z_top, z_edge, reach, stripes):
	"""Striped sloping awning (alternating accent and white) with a front valance."""
	thick, drop = 0.12, 0.6
	w = (ub - ua) / stripes
	for s in range(stripes):
		u0, u1 = ua + s * w, ua + (s + 1) * w
		name = "AWNING" if s % 2 == 0 else "AWNING_LIGHT"
		us, ts = (u0, u1), (0, reach)
		corners = {}
		for i in (0, 1):
			for j in (0, 1):
				z = z_top + (z_edge - z_top) * ts[j] / reach
				for k in (0, 1):
					corners[i, j, k] = side.P(us[i], z - (1 - k) * thick, ts[j])
		skip = ["-y", "+y"]
		if s > 0:
			skip.append("-x")
		if s < stripes - 1:
			skip.append("+x")
		block(corners, name, skip)
		skip = [] if s in (0, stripes - 1) else ["-x", "+x"]
		if s > 0:
			skip.append("-x")
		if s < stripes - 1:
			skip.append("+x")
		side.slab(u0, u1, z_edge - drop, z_edge + 0.02, reach - 0.02, reach + 0.1, name, skip=skip)


def roof_box(x0, x1, y0, y1, z, height, fan=True):
	"""Rooftop AC unit: a metal box with a dark grille and a fan on top."""
	box(x0, x1, y0, y1, z, z + height, "METAL", skip=("-z",))
	box(x0 + 0.3, x1 - 0.3, y1, y1 + 0.06, z + 0.3, z + height - 0.3, "METAL_DARK", skip=("-y",))
	if fan:
		prism(((x0 + x1) / 2, (y0 + y1) / 2), min(x1 - x0, y1 - y0) * 0.32, z + height, z + height + 0.08, 8, "METAL_DARK", cap="METAL_DARK")


# ---------------------------------------------------------------------------------------------------------------------
# Buildings. Each builder fills the current bmesh in place: front wall on Y = 0, bottom on Z = 0, centred on X.


def shop2():
	W, D, C = 18.0, 22.0, 0.45
	rect = (-W / 2, W / 2, -D, 0)
	rng = random.Random("Bldg_Shop2")
	S = sides_of(W, D, C)
	f, r, l, b = S["front"], S["right"], S["left"], S["back"]
	# Ground floor: big shop window with mullions, door, sign over a striped awning.
	f.open(-7.6, 2.2, 1.0, 5.6, "SHOPWIN", 0.3)
	f.slab(-7.9, 2.5, 0.0, 1.0, 0, 0.12, "WALL_DARK", skip=("-y",))  # stall riser
	mullions(f, -7.6, 2.2, 1.0, 5.6, 2, horizontal=4.5)
	door(f, 3.6, 6.4, 0.0, 5.7)
	awning(f, -8.3, 7.4, 6.5, 5.5, 2.8, 15)
	f.slab(-6.4, 6.4, 6.75, 8.15, 0, 0.18, "AWNING")
	f.slab(-6.1, 6.1, 6.9, 8.0, 0.18, 0.3, "SIGN")
	letters(f, 0, 7.45, 0.75, 10.0, 0.3, rng)
	band(rect, C, 8.5, 8.85, 0.16, "TRIM")
	for x in (-6, -2, 2, 6):
		window(f, x, 2.3, 9.7, 12.4, rng, head=True)
	# Corner side: the shopfront wraps round, flats above.
	r.open(1.6, 7.4, 1.0, 5.6, "SHOPWIN", 0.3)
	r.slab(1.3, 7.7, 0.0, 1.0, 0, 0.12, "WALL_DARK", skip=("-y",))
	mullions(r, 1.6, 7.4, 1.0, 5.6, 1, horizontal=4.5)
	for d in (4.5, 9.5, 14.5, 19.0):
		window(r, d, 2.2, 9.7, 12.4, rng)
	for d in (6.0, 15.0):
		window(l, d, 2.2, 9.7, 12.4, rng)
	window(l, 15.0, 1.6, 2.4, 4.8, rng, sill=False)
	door(b, 3.2, 5.8, 0.0, 5.4, glass=False)
	window(b, -4.0, 2.0, 2.2, 4.8, rng, sill=False)
	for x in (-5.5, 0.0, 5.5):
		window(b, x, 2.2, 9.7, 12.4, rng, sill=False)
	body(S, rect, C, 0.0, 13.3)
	roof = cornice(rect, C, 13.3, 1.7, 0.45)
	roof_box(-6.5, -3.4, -17.0, -14.8, roof, 1.3)
	prism((4.5, -18.0), 0.35, roof, roof + 1.4, 8, "METAL", cap="METAL_DARK")
	return W, D


def shop3():
	W, D, C = 20.0, 24.0, 0.45
	rect = (-W / 2, W / 2, -D, 0)
	rng = random.Random("Bldg_Shop3")
	S = sides_of(W, D, C)
	f, r, l, b = S["front"], S["right"], S["left"], S["back"]
	# Shopfront: two windows and a central door under a flat canopy, sign board above.
	for ua, ub in ((-8.7, -2.3), (2.3, 8.7)):
		f.open(ua, ub, 1.1, 5.7, "SHOPWIN", 0.3)
		f.slab(ua - 0.3, ub + 0.3, 0.0, 1.1, 0, 0.12, "WALL_DARK", skip=("-y",))
		mullions(f, ua, ub, 1.1, 5.7, 1)
	door(f, -1.5, 1.5, 0.0, 6.0)
	f.slab(-9.4, 9.4, 6.5, 6.9, 0, 2.4, "AWNING", cells={"-z": "TRIM"})
	f.slab(-9.5, 9.5, 6.35, 7.0, 2.4, 2.55, "AWNING_LIGHT", skip=())
	f.slab(-5.4, 5.4, 7.2, 8.45, 0, 0.25, "SIGN")
	letters(f, 0, 7.82, 0.7, 9.2, 0.25, rng)
	band(rect, C, 8.7, 9.05, 0.16, "TRIM")
	# Two floors of flats, four windows across, one small balcony in the middle of the top floor.
	for x in (-7.2, -2.4, 2.4, 7.2):
		window(f, x, 2.2, 10.0, 12.9, rng, head=True)
	for x in (-7.2, 7.2):
		window(f, x, 2.2, 15.2, 18.1, rng, head=True)
	for x in (-2.4, 2.4):
		window(f, x, 2.0, 14.3, 18.1, rng, sill=False, head=True)
	f.slab(-4.2, 4.2, 13.9, 14.3, 0, 1.7, "TRIM", cells={"-z": "WALL_DARK"})
	f.slab(-4.2, 4.2, 15.35, 15.5, 1.5, 1.7, "METAL_DARK", skip=())
	for x in (-4.2, 4.05):
		f.slab(x, x + 0.15, 15.35, 15.5, 0, 1.5, "METAL_DARK")
	for k in range(9):
		x = -4.1 + k * 8.2 / 8
		f.slab(x - 0.06, x + 0.06, 14.3, 15.35, 1.52, 1.64, "METAL_DARK", skip=())
	for d in (4.0, 9.5, 15.0, 20.5):
		window(r, d, 2.2, 10.0, 12.9, rng)
		window(r, d, 2.2, 15.2, 18.1, rng)
	r.open(2.4, 7.6, 1.1, 5.7, "SHOPWIN", 0.3)
	r.slab(2.1, 7.9, 0.0, 1.1, 0, 0.12, "WALL_DARK", skip=("-y",))
	for d in (5.0, 12.0, 19.0):
		window(l, d, 2.2, 10.0, 12.9, rng)
		window(l, d, 2.2, 15.2, 18.1, rng)
	door(b, -6.6, -4.0, 0.0, 5.6, glass=False)
	window(b, 3.0, 2.4, 2.4, 5.0, rng, sill=False)
	for x in (-7.0, -2.4, 2.4, 7.0):
		window(b, x, 2.2, 10.0, 12.9, rng, sill=False)
		window(b, x, 2.2, 15.2, 18.1, rng, sill=False)
	body(S, rect, C, 0.0, 19.2)
	roof = cornice(rect, C, 19.2, 1.8, 0.45)
	roof_box(3.0, 6.4, -19.5, -17.0, roof, 1.4)
	roof_box(-7.0, -4.2, -12.0, -9.8, roof, 1.2)
	prism((-2.0, -20.0), 0.32, roof, roof + 1.6, 8, "METAL", cap="METAL_DARK")
	return W, D


def apartment4():
	W, D, C = 22.0, 24.0, 0.5
	rect = (-W / 2, W / 2, -D, 0)
	rng = random.Random("Bldg_Apartment4")
	S = sides_of(W, D, C)
	f, r, l, b = S["front"], S["right"], S["left"], S["back"]
	P, FH = 1.2, 5.6  # plinth height, floor height
	floors = [P + FH * k for k in range(4)]
	balconies = {(1, -4.0), (1, 4.0), (3, -4.0), (3, 4.0)}
	loft(rect, C, [(0, 0.15), (P, 0.15), (P, 0)], "BASE")
	# Entrance: steps up to the door, transom light, small canopy.
	door(f, -1.5, 1.5, P, P + 4.6)
	f.open(-1.5, 1.5, P + 4.85, P + 5.35, "WINDOW_LIT", 0.2)
	for k in range(3):
		f.slab(-2.4 + 0.25 * k, 2.4 - 0.25 * k, 0.0, 0.4 * (k + 1), 0, 2.4 - 0.75 * k, "STEP", skip=("-y", "-z"))
	f.slab(-2.6, 2.6, P + 5.5, P + 5.85, 0, 2.2, "AWNING", cells={"-z": "TRIM"})
	for k, z in enumerate(floors):
		for x in (-8.0, -4.0, 0.0, 4.0, 8.0):
			if k == 0 and x == 0.0:
				continue
			if (k, x) in balconies:
				window(f, x, 2.0, z + 0.25, z + 4.4, rng, sill=False, head=True)
				f.slab(x - 1.9, x + 1.9, z - 0.15, z + 0.25, 0, 1.5, "TRIM", cells={"-z": "WALL_DARK"})
				f.slab(x - 1.9, x + 1.9, z + 0.25, z + 1.4, 1.36, 1.5, "TRIM", skip=())
				for sx in (-1, 1):
					f.slab(x + sx * 1.9 - (0.14 if sx > 0 else 0), x + sx * 1.9 + (0.14 if sx < 0 else 0), z + 0.25, z + 1.4, 0, 1.36, "TRIM")
			else:
				window(f, x, 2.2, z + 1.3, z + 4.4, rng, head=True)
	band(rect, C, P + FH - 0.3, P + FH, 0.14, "TRIM")
	for side in (r, l):
		for z in floors:
			for d in (5.0, 12.0, 19.0):
				window(side, d, 2.2, z + 1.3, z + 4.4, rng)
	for k, z in enumerate(floors):
		for x in (-8.0, -4.0, 0.0, 4.0, 8.0):
			if k == 0 and x == 0.0:
				door(b, -1.3, 1.3, P, P + 4.4, glass=False)
				continue
			window(b, x, 2.2, z + 1.3, z + 4.4, rng, sill=False)
	body(S, rect, C, P, P + FH * 4)
	# Fire escape on the left side: a platform per upper floor, a zigzag of stairs between them.
	for k in (1, 2, 3):
		z = floors[k]
		l.slab(7.0, 17.0, z - 0.2, z, 0, 1.6, "METAL_DARK")
		l.slab(7.0, 17.0, z + 1.0, z + 1.12, 1.48, 1.6, "METAL_DARK", skip=())
		for d in (7.0, 12.0, 16.9):
			l.slab(d, d + 0.1, z, z + 1.0, 1.48, 1.6, "METAL_DARK", skip=())
		if k < 3:
			lo, hi = (8.0, 16.0) if k % 2 else (16.0, 8.0)
			z1 = floors[k + 1]
			corners = {}
			for i, (d, zz) in enumerate(((lo, z), (hi, z1 - 0.2))):
				for j, t in enumerate((0.25, 1.35)):
					for kk in (0, 1):
						corners[(i, j, kk) if lo < hi else (1 - i, j, kk)] = l.P(d, zz - 0.2 + 0.2 * kk, t)
			block(corners, "METAL_DARK")
	roof = cornice(rect, C, P + FH * 4, 1.7, 0.5)
	# Water tank on legs, octagonal, with a pointed lid.
	tx, ty = 5.5, -17.0
	for sx in (-1, 1):
		for sy in (-1, 1):
			box(tx + sx * 1.2 - 0.15, tx + sx * 1.2 + 0.15, ty + sy * 1.2 - 0.15, ty + sy * 1.2 + 0.15, roof, roof + 1.5, "METAL_DARK", skip=("-z", "+z"))
	prism((tx, ty), 1.9, roof + 1.5, roof + 4.3, 8, "TANK", bottom="TANK_DARK")
	for z in (roof + 2.0, roof + 3.6):
		prism((tx, ty), 1.97, z, z + 0.22, 8, "TANK_DARK", cap=None)
	prism((tx, ty), 2.15, roof + 4.3, roof + 5.2, 8, "TANK_DARK", radius_top=0.0, bottom="TANK_DARK")
	roof_box(-6.5, -3.6, -9.0, -6.8, roof, 1.2)
	return W, D


def narrow3():
	W, D, C = 12.0, 20.0, 0.4
	rect = (-W / 2, W / 2, -D, 0)
	rng = random.Random("Bldg_Narrow3")
	S = sides_of(W, D, C)
	f, r, l, b = S["front"], S["right"], S["left"], S["back"]
	P, FH = 0.9, 4.9
	floors = [P + FH * k for k in range(3)]
	top = P + FH * 3  # eaves
	ridge, slope = 19.0, (19.0 - top) / (W / 2)
	loft(rect, C, [(0, 0.15), (P, 0.15), (P, 0)], "BASE")
	# Door with steps and a little hood on the right.
	door(f, 2.0, 4.4, P, P + 4.0)
	f.open(2.0, 4.4, P + 4.2, P + 4.6, "WINDOW_LIT", 0.2)
	for k in range(2):
		f.slab(1.6 + 0.2 * k, 4.8 - 0.2 * k, 0.0, 0.45 * (k + 1), 0, 1.6 - 0.8 * k, "STEP", skip=("-y", "-z"))
	f.slab(1.5, 4.9, P + 4.75, P + 5.0, 0, 1.0, "AWNING", cells={"-z": "TRIM"})
	for z in floors[1:]:
		window(f, 3.2, 2.2, z + 1.1, z + 4.0, rng, head=True)
	# Bay window column on the left, all three floors, chamfered at 45 degrees.
	bx0, bx1, by = -5.2, -0.6, 1.3
	poly_prism([(bx0, 0.0), (bx1, 0.0), (bx1 - by, by), (bx0 + by, by)], 0.0, P, "BASE")
	bay = [
		Side((bx0, 0, 0), (1, 1, 0), (-1, 1, 0), 0, by * math.sqrt(2)),
		Side((bx0 + by, by, 0), (1, 0, 0), (0, 1, 0), 0, (bx1 - bx0) - 2 * by),
		Side((bx1 - by, by, 0), (1, -1, 0), (1, 1, 0), 0, by * math.sqrt(2)),
	]
	for k, side in enumerate(bay):
		width = side.u1 - side.u0
		for z in floors:
			window(side, width / 2, width - 0.55 if k != 1 else width - 0.6, z + 1.0, z + 3.9, rng, sill=False)
		facade(side, P, top - 0.3)
	# Bay trims: a ledge per floor and a cap.
	for z, h, out in [(floors[1] - 0.2, 0.25, 0.12), (floors[2] - 0.2, 0.25, 0.12), (top - 0.3, 0.35, 0.22)]:
		pts = [(bx0 - out * 0.4, 0.0), (bx1 + out * 0.4, 0.0), (bx1 - by + out * 0.4, by + out), (bx0 + by - out * 0.4, by + out)]
		poly_prism(pts, z, z + h, "TRIM", top="TRIM", bottom="TRIM")
	window(l, 6.0, 2.0, floors[0] + 1.1, floors[0] + 3.9, rng)
	for side in (r, l):
		for z in floors[1:]:
			for d in (6.0, 14.0):
				window(side, d, 2.0, z + 1.1, z + 4.0, rng)
	door(b, 2.0, 4.2, P, P + 4.0, glass=False)
	window(b, -2.5, 2.0, floors[0] + 1.1, floors[0] + 3.9, rng, sill=False)
	for z in floors[1:]:
		for x in (-2.8, 2.8):
			window(b, x, 2.0, z + 1.1, z + 4.0, rng, sill=False)
	body(S, rect, C, P, top)
	# Gables (front and back) with a round attic window, pitched roof with overhangs, ridge cap, chimney.
	hw = W / 2 - C
	for y, n in ((0.0, 1), (-D, -1)):
		zc = top + slope * C
		make_face([(-hw, y, top), (hw, y, top), (hw, y, zc), (0, y, ridge), (-hw, y, zc)], "WALL", (0, n, 0))
	# Attic windows: octagons stood up on the gable faces (built flat, then rotated into place).
	for y, n in ((0.0, 1), (-D, -1)):
		cz = top + (ridge - top) * 0.42
		for r_, t0, t1, name in ((0.85, 0.0, 0.12, "FRAME"), (0.6, 0.12, 0.17, "WINDOW_LIT" if n > 0 else "WINDOW")):
			ring_a = [Vector((r_ * math.cos(2 * math.pi * i / 8 + math.pi / 8), y + n * t0, cz + r_ * math.sin(2 * math.pi * i / 8 + math.pi / 8))) for i in range(8)]
			ring_b = [p + Vector((0, n * (t1 - t0), 0)) for p in ring_a]
			va = [bm.verts.new(p) for p in ring_a]
			vb = [bm.verts.new(p) for p in ring_b]
			for i in range(8):
				j = (i + 1) % 8
				quad = [va[i], va[j], vb[j], vb[i]]
				mid = sum((q.co for q in quad), Vector()) / 4
				make_face(quad, "FRAME", mid - Vector((0, mid.y, cz)))
			make_face(vb, name, (0, n, 0))
	over, thick = 0.7, 0.4
	for sx in (-1, 1):
		corners = {}
		xs = (0.0, sx * (W / 2 + over))
		ys = (-D - over, over)
		for i in (0, 1):
			for j in (0, 1):
				for k in (0, 1):
					z = ridge + 0.25 - slope * abs(xs[i]) - (1 - k) * thick
					corners[(i, j, k) if sx > 0 else (1 - i, j, k)] = (xs[i], ys[j], z)
		block(corners, "ROOF_TILE", skip=("-x",) if sx > 0 else ("+x",), cells={"-z": "TRIM", "-y": "TRIM", "+y": "TRIM", "+x" if sx > 0 else "-x": "TRIM"})
	box(-0.3, 0.3, -D - over - 0.05, over + 0.05, ridge + 0.1, ridge + 0.45, "TRIM", skip=("-z",))
	box(2.0, 3.3, -15.0, -13.8, 15.0, 20.6, "BRICK", skip=("-z",))
	box(1.8, 3.5, -15.2, -13.6, 20.6, 21.0, "TRIM")
	return W, D


def tower():
	W, D, C = 24.0, 28.0, 0.7
	rect = (-W / 2, W / 2, -D, 0)
	rng = random.Random("Bldg_Tower")
	S = sides_of(W, D, C)
	f, r, l, b = S["front"], S["right"], S["left"], S["back"]
	G, FH, N = 5.6, 3.6, 9  # lobby height, floor height, floors
	# Lobby: glass front and door, a canopy band above.
	for ua, ub in ((-10.0, -2.2), (2.2, 10.0)):
		f.open(ua, ub, 0.6, 4.6, "SHOPWIN", 0.3)
		mullions(f, ua, ub, 0.6, 4.6, 2)
	door(f, -1.5, 1.5, 0.0, 4.6)
	for side in (r, l):
		for d in (5.0, 14.0, 23.0):
			side.open(d - 3.0, d + 3.0, 0.8, 4.4, "SHOPWIN", 0.3)
	door(b, -1.4, 1.4, 0.0, 4.4, glass=False)
	loft(rect, C, [(G - 0.6, 0), (G - 0.6, 0.45), (G, 0.45), (G, 0)], "TRIM")
	# Office floors: ribbon windows split by piers, lit per pane.
	front_runs = [(-11.0, -3.8), (-3.2, 3.2), (3.8, 11.0)]
	side_runs = [(1.2, 7.3), (7.9, 13.8), (14.4, 20.3), (20.9, 26.8)]
	for k in range(N):
		z = G + FH * k
		for side, runs in ((f, front_runs), (b, front_runs), (r, side_runs), (l, side_runs)):
			for ua, ub in runs:
				side.open(ua, ub, z + 0.8, z + 2.9, "WINDOW_LIT" if rng.random() < 0.28 else "WINDOW", 0.3)
	top = G + FH * N
	body(S, rect, C, 0.0, top)
	# Stepped crown and a rooftop plant room.
	loft(rect, C, [
		(top, 0), (top + 0.35, 0.4), (top + 0.9, 0.4), (top + 0.9, -1.3),
		(top + 2.6, -1.3), (top + 2.6, -1.1), (top + 2.9, -1.1), (top + 2.9, -2.8),
		(top + 4.2, -2.8), (top + 4.2, -2.6), (top + 4.5, -2.6), (top + 4.5, -3.3),
	], ["TRIM", "TRIM", "TRIM", "WALL_DARK", "TRIM", "TRIM", "TRIM", "WALL", "TRIM", "TRIM", "TRIM"], top="ROOF")
	z = top + 4.5
	box(-4.5, 3.5, -19.0, -11.0, z, z + 2.0, "WALL_DARK", skip=("-z",), cells={"+z": "ROOF"})
	box(-1.0, 1.0, -11.0, -10.9, z, z + 1.6, "DOOR", skip=("-y",))
	roof_box(5.0, 8.0, -9.0, -6.6, z, 1.2)
	return W, D


def diner():
	W, D, C = 16.0, 16.0, 0.5
	rect = (-W / 2, W / 2, -D, 0)
	rng = random.Random("Bldg_Diner")
	S = sides_of(W, D, C)
	f, r, l, b = S["front"], S["right"], S["left"], S["back"]
	H = 5.6
	for ua, ub in ((-7.0, -1.9), (1.9, 7.0)):
		f.open(ua, ub, 1.4, 4.3, "WINDOW_LIT", 0.25)
		mullions(f, ua, ub, 1.4, 4.3, 2, depth=0.25)
	door(f, -1.2, 1.2, 0.0, 4.3)
	f.slab(-1.8, 1.8, 4.55, 4.8, 0, 1.3, "AWNING", cells={"-z": "TRIM"})
	for side in (r, l):
		for d in (4.5, 11.5):
			side.open(d - 2.6, d + 2.6, 1.4, 4.3, "WINDOW_LIT" if rng.random() < 0.5 else "WINDOW", 0.25)
			mullions(side, d - 2.6, d + 2.6, 1.4, 4.3, 1, depth=0.25)
	door(b, 3.0, 5.2, 0.0, 4.2, glass=False)
	window(b, -3.5, 2.4, 2.0, 4.0, rng, sill=False)
	body(S, rect, C, 0.0, H)
	loft(rect, C, [(0, 0.12), (0.7, 0.12), (0.7, 0)], "AWNING_LIGHT")
	band(rect, C, 4.75, 5.15, 0.14, "AWNING")
	loft(rect, C, [(H, 0), (H + 0.2, 0.25), (H + 0.6, 0.25), (H + 0.6, -0.3), (H + 0.3, -0.3)], ["TRIM", "TRIM", "TRIM", "WALL_DARK"], top="ROOF")
	roof = H + 0.3
	# Big roof sign on two posts, framed in the accent colour, bulbs along the top.
	for x in (-3.6, 3.6):
		box(x - 0.2, x + 0.2, -3.4, -3.0, roof, roof + 1.0, "METAL_DARK", skip=("-z",))
	box(-5.6, 5.6, -3.5, -2.9, roof + 0.9, roof + 3.5, "AWNING")
	sign = Side((0, -2.9, 0), (1, 0, 0), (0, 1, 0), -5.6, 5.6)
	sign.slab(-5.2, 5.2, roof + 1.25, roof + 3.15, 0, 0.1, "SIGN")
	letters(sign, 0, roof + 2.2, 1.1, 9.0, 0.1, rng)
	for k in range(9):
		x = -4.8 + k * 1.2
		box(x - 0.14, x + 0.14, -3.35, -3.05, roof + 3.5, roof + 3.78, "WINDOW_LIT", skip=("-z",))
	roof_box(-5.5, -2.8, -12.5, -10.3, roof, 1.1)
	return W, D


def street_lamp():
	prism((0, 0), 0.6, 0.0, 0.5, 8, "LAMP_POLE")
	prism((0, 0), 0.6, 0.5, 0.95, 8, "LAMP_POLE", radius_top=0.3)
	prism((0, 0), 0.22, 0.95, 12.2, 8, "LAMP_POLE", radius_top=0.15)
	prism((0, 0), 0.24, 12.2, 12.5, 8, "LAMP_POLE", cap="LAMP_POLE", radius_top=0.1)
	corners = {}
	for j, (y, z) in enumerate(((0.0, 11.75), (2.2, 12.05))):
		for i, x in enumerate((-0.1, 0.1)):
			for k in (0, 1):
				corners[i, j, k] = (x, y, z + 0.24 * k)
	block(corners, "LAMP_POLE", skip=("-y",))
	box(-0.08, 0.08, 2.15, 2.31, 11.75, 12.05, "LAMP_POLE", skip=("+z",))
	prism((0, 2.25), 0.72, 11.3, 11.75, 8, "LAMP_POLE", cap="LAMP_POLE", radius_top=0.3)
	prism((0, 2.25), 0.42, 10.75, 11.3, 8, "LAMP_GLASS", radius_top=0.62, bottom="LAMP_GLASS")


def bench():
	# Seat slats (seat faces +Y), two tilted back slats, cast side frames.
	for y0, y1 in ((0.15, 0.7), (-0.42, 0.08), (-0.99, -0.49)):
		box(-3.0, 3.0, y0, y1, 1.35, 1.55, "WOOD")
	for zc in (2.05, 2.75):
		corners = {}
		lean = 0.16  # backward lean per stud of height
		for i, x in enumerate((-3.0, 3.0)):
			for k, z in enumerate((zc - 0.25, zc + 0.25)):
				yb = -1.1 - lean * (z - 1.55)
				for j, y in enumerate((yb - 0.16, yb)):
					corners[i, j, k] = (x, y, z)
		block(corners, "WOOD")
	for x in (-2.45, 2.45):
		x0, x1 = x - 0.1, x + 0.1
		box(x0, x1, 0.4, 0.6, 0.0, 2.1, "METAL_DARK")
		box(x0, x1, -1.0, 0.65, 1.15, 1.35, "METAL_DARK")
		box(x0, x1, -1.05, 0.75, 2.1, 2.25, "METAL_DARK")
		corners = {}
		for k, z in enumerate((0.0, 3.05)):
			yb = -1.1 - 0.16 * (z - 1.55) + 0.02
			for j, y in enumerate((yb - 0.2, yb)):
				for i, xx in enumerate((x0, x1)):
					corners[i, j, k] = (xx, y, z)
		block(corners, "METAL_DARK")


def finish(name, recentre=False):
	"""Welds, merges coplanar same-cell faces, triangulates n-gons, maps every face to its cell, makes the object."""
	global bm
	bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
	bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(0.5), use_dissolve_boundaries=False, verts=list(bm.verts), edges=list(bm.edges), delimit={"MATERIAL"})
	bmesh.ops.triangulate(bm, faces=[face for face in bm.faces if len(face.verts) > 4], quad_method="BEAUTY", ngon_method="EAR_CLIP")
	uv_layer = bm.loops.layers.uv.new("UVMap")
	spread = 0.2 / GRID
	for face in bm.faces:
		u, v = cell_uv(NAMES[face.material_index])
		count = len(face.loops)
		for k, loop in enumerate(face.loops):
			a = 2 * math.pi * k / count
			loop[uv_layer].uv = (u + spread * math.cos(a), v + spread * math.sin(a))
		face.material_index = 0
	mesh = bpy.data.meshes.new(name)
	bm.to_mesh(mesh)
	bm.free()
	bm = None
	obj = bpy.data.objects.new(name, mesh)
	bpy.context.scene.collection.objects.link(obj)
	for poly in mesh.polygons:
		poly.use_smooth = False
	if recentre:
		coords = [v.co.copy() for v in mesh.vertices]
		mins = Vector([min(c[i] for c in coords) for i in range(3)])
		maxs = Vector([max(c[i] for c in coords) for i in range(3)])
		shift = Vector(((mins.x + maxs.x) / 2, (mins.y + maxs.y) / 2, mins.z))
		for v in mesh.vertices:
			v.co -= shift
	return obj


# Palette textures. Written straight to pixels (no bake): every cell is one flat colour.
def write_palette(file_name, wall=None, accent=None):
	colors = dict(PALETTE)
	if wall:
		colors["WALL"], colors["WALL_DARK"], colors["AWNING"] = wall, wall_dark(wall), accent
	image = bpy.data.images.new(file_name, TEXTURE_SIZE, TEXTURE_SIZE)
	pixels = [0.0] * (TEXTURE_SIZE * TEXTURE_SIZE * 4)
	for name, index in CELLS.items():
		r, g, b = (c / 255 for c in colors[name])
		cx, cy = index % GRID, GRID - 1 - index // GRID  # image rows start at the bottom
		for py in range(cy * CELL, (cy + 1) * CELL):
			for px in range(cx * CELL, (cx + 1) * CELL):
				o = (py * TEXTURE_SIZE + px) * 4
				pixels[o : o + 4] = (r, g, b, 1.0)
	image.pixels = pixels
	image.filepath_raw = os.path.join(OUT, file_name + ".png")
	image.file_format = "PNG"
	image.save()
	return image


def textured_material(name, image):
	material = bpy.data.materials.new(name)
	material.use_nodes = True
	nodes = material.node_tree.nodes
	nodes.clear()
	principled = nodes.new("ShaderNodeBsdfPrincipled")
	principled.inputs["Roughness"].default_value = 1
	texture = nodes.new("ShaderNodeTexImage")
	texture.image = image
	texture.interpolation = "Closest"
	output = nodes.new("ShaderNodeOutputMaterial")
	material.node_tree.links.new(texture.outputs["Color"], principled.inputs["Base Color"])
	material.node_tree.links.new(principled.outputs["BSDF"], output.inputs["Surface"])
	return material


default_wall, default_accent = VARIANTS["Salmon"]
materials = {"": textured_material("Bldg_Palette", write_palette("Bldg_Palette", default_wall, default_accent))}
for variant, (wall, accent) in VARIANTS.items():
	materials[variant] = textured_material("Bldg_Palette_" + variant, write_palette("Bldg_Palette_" + variant, wall, accent))
prop_material = textured_material("Prop_Palette", write_palette("Prop_Palette"))

BUILDINGS = [
	("Bldg_Diner", diner, "Cream"),
	("Bldg_Shop2", shop2, "Salmon"),
	("Bldg_Narrow3", narrow3, "Sky"),
	("Bldg_Apartment4", apartment4, "Butter"),
	("Bldg_Shop3", shop3, "Mint"),
	("Bldg_Tower", tower, "Lavender"),
]
PROPS = [("Prop_StreetLamp", street_lamp, False), ("Prop_Bench", bench, True)]

objects = {}
footprints = {}
for name, build, _ in BUILDINGS:
	begin()
	footprints[name] = build()
	objects[name] = finish(name)
	objects[name].data.materials.append(materials[""])
for name, build, recentre in PROPS:
	begin()
	build()
	objects[name] = finish(name, recentre)
	objects[name].data.materials.append(prop_material)


def export(obj):
	bpy.ops.object.select_all(action="DESELECT")
	bpy.context.view_layer.objects.active = obj
	obj.select_set(True)
	bpy.ops.export_scene.fbx(
		filepath=os.path.join(OUT, obj.name + ".fbx"),
		use_selection=True,
		axis_forward="-Z",
		axis_up="Y",
		path_mode="COPY",
		embed_textures=True,
	)
	mesh = obj.data
	mins = tuple(round(min(v.co[i] for v in mesh.vertices), 2) for i in range(3))
	maxs = tuple(round(max(v.co[i] for v in mesh.vertices), 2) for i in range(3))
	triangles = sum(len(p.vertices) - 2 for p in mesh.polygons)
	size = tuple(round(maxs[i] - mins[i], 2) for i in range(3))
	print("MODEL", obj.name, "triangles", triangles, "size", size, "bounds", mins, maxs, flush=True)


for obj in objects.values():
	export(obj)

# Preview renders (not exported).
scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.image_settings.file_format = "PNG"
scene.world = bpy.data.worlds.new("PreviewWorld")
scene.world.use_nodes = True
scene.world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.78, 0.6, 0.72, 1)
scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.9
scene.view_settings.view_transform = "Standard"

bpy.ops.mesh.primitive_plane_add(size=400, location=(0, 0, 0))
ground = bpy.context.object
ground_material = bpy.data.materials.new("Ground")
ground_material.use_nodes = True
ground_material.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.55, 0.42, 0.5, 1)
ground.data.materials.append(ground_material)

bpy.ops.object.light_add(type="SUN", location=(0, 0, 20))
sun = bpy.context.object
sun.data.energy = 3.2
sun.data.angle = math.radians(8)
sun.rotation_euler = (math.radians(35), math.radians(0), math.radians(150))
bpy.ops.object.light_add(type="SUN", location=(0, 0, 20))
fill_sun = bpy.context.object
fill_sun.data.energy = 1.2
fill_sun.rotation_euler = (math.radians(60), math.radians(0), math.radians(-40))

bpy.ops.object.camera_add()
camera = bpy.context.object
scene.camera = camera
camera.data.type = "ORTHO"
camera.data.clip_end = 1000


def aim(where, target):
	camera.location = Vector(where)
	camera.rotation_euler = (Vector(target) - camera.location).to_track_quat("-Z", "Y").to_euler()


# Lineup: every building side by side along X, fronts on Y = 0, one colour variant each.
GAP = 6.0
total = sum(footprints[name][0] for name, _, _ in BUILDINGS) + GAP * (len(BUILDINGS) - 1)
cursor = -total / 2
for name, _, variant in BUILDINGS:
	obj = objects[name]
	width = footprints[name][0]
	obj.location = (cursor + width / 2, 0, 0)
	obj.material_slots[0].link = "OBJECT"
	obj.material_slots[0].material = materials[variant]
	cursor += width + GAP
for name, _, _ in PROPS:
	objects[name].hide_render = True

# The sedan from art/cars for scale, parked in front of the corner shop.
car_blend = os.path.join(REPO, "art", "cars", "Car_Sedan.blend")
car = None
if os.path.exists(car_blend):
	with bpy.data.libraries.load(car_blend, link=False) as (data_from, data_to):
		data_to.objects = [n for n in data_from.objects if n == "Car_Sedan"]
	for car in data_to.objects:
		scene.collection.objects.link(car)
		car.location = (-total / 2 - 9.0, 3.0, 0)  # past the diner end of the row
		car.rotation_euler = (0, 0, math.radians(-90))

scene.render.resolution_x = 2400
scene.render.resolution_y = 1100
camera.data.ortho_scale = total * 1.12
center = Vector((-6.5, -10, 15))
aim(center + Vector((0.45, 1.0, 0.55)).normalized() * 300, center)
scene.render.filepath = os.path.join(OUT, "Buildings_lineup.png")
bpy.ops.render.render(write_still=True)

aim(center + Vector((-0.45, -1.0, 0.55)).normalized() * 300, center)
scene.render.filepath = os.path.join(OUT, "Buildings_back.png")
bpy.ops.render.render(write_still=True)

# Props, with the sedan for scale.
for name, _, _ in BUILDINGS:
	objects[name].hide_render = True
objects["Prop_StreetLamp"].hide_render = False
objects["Prop_Bench"].hide_render = False
objects["Prop_StreetLamp"].location = (4.0, 0, 0)
objects["Prop_Bench"].location = (-1.0, 0, 0)
if car:
	car.location = (-10.0, -3.0, 0)
	car.rotation_euler = (0, 0, 0)
scene.render.resolution_x = 1600
scene.render.resolution_y = 1000
camera.data.ortho_scale = 30
center = Vector((-3.0, 0, 5.5))
aim(center + Vector((0.6, 1.0, 0.45)).normalized() * 100, center)
scene.render.filepath = os.path.join(OUT, "Props.png")
bpy.ops.render.render(write_still=True)

for name, _, _ in BUILDINGS:
	objects[name].hide_render = False
for material in list(materials.values()) + [prop_material]:
	for node in material.node_tree.nodes:
		if node.type == "TEX_IMAGE":
			node.image.pack()
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "Buildings.blend"), compress=True)
print("Buildings done", flush=True)
