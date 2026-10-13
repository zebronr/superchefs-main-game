# Builds a decorative low-poly 1980s sedan for level maps, faceted with flat colours: a chunky body with a sloped,
# chamfered hood, a trapezoid cabin with slightly inset windows, a grey grille with three slats and octagonal headlights,
# black bumpers with plates and yellow indicators, pink tail lights with red reflectors, door handles and panel lines,
# a dark-brown rocker strip, and black tyres with grey hubs in the wheel arches. Run headless from the repo root:
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup --python art/cars/car.py
# Writes art/cars/out/Car_Sedan.fbx (one object, Car_Sedan, wheels joined in), its palette textures Car_Sedan.png
# (orange), Car_Sedan_Red.png, Car_Sedan_Teal.png and Car_Sedan_Yellow.png, the preview renders Car_Sedan_preview.png
# (3/4 front), Car_Sedan_rear.png (3/4 rear) and Car_Sedan_colors.png (the four paints), and art/cars/Car_Sedan.blend.
# Every face is one cell of a small palette texture, so a colour variant is only a different texture on the same mesh
# (same UVs): swap the MeshPart's TextureID in Studio.
# Units are studs. The car faces Blender +Y (Roblox -Z, the LookVector, with the axes used below), up is Blender +Z
# (Roblox +Y). The origin is the bottom centre: the tyres touch Z = 0.

import math
import os

import bpy
import bmesh
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
NAME = "Car_Sedan"
GRID = 8  # palette cells per row
CELL = 32  # pixels per cell
TEXTURE_SIZE = GRID * CELL

os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)

# Palette (sRGB 0-255). The PAINT cells are the only ones a variant changes.
PALETTE = {
	"PAINT": (214, 112, 56),
	"PAINT_DARK": (150, 72, 34),  # door panel lines
	"WINDOW": (150, 166, 192),
	"GRILLE": (196, 196, 198),
	"SLAT": (120, 120, 126),
	"HEADLIGHT": (238, 220, 160),
	"BLACK": (34, 34, 36),
	"PLATE": (244, 244, 240),
	"YELLOW": (246, 206, 30),
	"TAIL": (240, 176, 178),
	"REFLECTOR": (220, 62, 66),
	"HANDLE": (214, 214, 216),
	"ROCKER": (104, 52, 30),
	"TYRE": (30, 30, 32),
	"HUB": (176, 176, 180),
	"HUB_DOT": (40, 40, 42),
	"UNDER": (52, 40, 36),  # underside and wheel wells
}
# Muted, slightly warm paints that sit next to the orange. PAINT_DARK is derived (same ratio as the orange's).
VARIANTS = {
	"": (214, 112, 56),
	"_Red": (190, 72, 58),
	"_Teal": (64, 138, 130),
	"_Yellow": (224, 176, 66),
}
CELLS = {name: index for index, name in enumerate(PALETTE)}


def cell_uv(name):
	index = CELLS[name]
	return ((index % GRID + 0.5) / GRID, 1 - (index // GRID + 0.5) / GRID)


bm = bmesh.new()
uv_layer = bm.loops.layers.uv.new("UVMap")


def make_face(points, name, outward):
	"""A face from world points, flipped so its normal points along `outward`, mapped to a palette cell."""
	face = bm.faces.new([bm.verts.new(p) if not isinstance(p, bmesh.types.BMVert) else p for p in points])
	face.normal_update()
	if face.normal.dot(Vector(outward)) < 0:
		face.normal_flip()
	paint(face, name)
	return face


def paint(face, name):
	u, v = cell_uv(name)
	spread = 0.2 / GRID
	count = len(face.loops)
	for k, loop in enumerate(face.loops):
		a = 2 * math.pi * k / count
		loop[uv_layer].uv = (u + spread * math.cos(a), v + spread * math.sin(a))


def box(x0, x1, y0, y1, z0, z1, name, skip=()):
	"""Axis-aligned box. `skip` names faces to leave out ('-x', '+x', '-y', '+y', '-z', '+z')."""
	v = {}
	for i, x in enumerate((x0, x1)):
		for j, y in enumerate((y0, y1)):
			for k, z in enumerate((z0, z1)):
				v[i, j, k] = bm.verts.new((x, y, z))
	sides = {
		"-x": ([v[0, 0, 0], v[0, 1, 0], v[0, 1, 1], v[0, 0, 1]], (-1, 0, 0)),
		"+x": ([v[1, 0, 0], v[1, 1, 0], v[1, 1, 1], v[1, 0, 1]], (1, 0, 0)),
		"-y": ([v[0, 0, 0], v[1, 0, 0], v[1, 0, 1], v[0, 0, 1]], (0, -1, 0)),
		"+y": ([v[0, 1, 0], v[1, 1, 0], v[1, 1, 1], v[0, 1, 1]], (0, 1, 0)),
		"-z": ([v[0, 0, 0], v[1, 0, 0], v[1, 1, 0], v[0, 1, 0]], (0, 0, -1)),
		"+z": ([v[0, 0, 1], v[1, 0, 1], v[1, 1, 1], v[0, 1, 1]], (0, 0, 1)),
	}
	for key, (quad, normal) in sides.items():
		if key not in skip:
			make_face(quad, name, normal)


def prism(center, axis, sign, radius, depth, sides, name, cap=None, phase=0.0):
	"""An n-sided prism standing on a surface: base ring at `center`, grown `depth` along axis*sign, outer cap only."""
	center = Vector(center)
	direction = Vector([sign if i == axis else 0 for i in range(3)])
	a1, a2 = [i for i in range(3) if i != axis]
	rings = []
	for offset in (0, depth):
		ring = []
		for i in range(sides):
			angle = 2 * math.pi * i / sides + phase
			p = center + direction * offset
			p[a1] += radius * math.cos(angle)
			p[a2] += radius * math.sin(angle)
			ring.append(bm.verts.new(p))
		rings.append(ring)
	for i in range(sides):
		j = (i + 1) % sides
		quad = [rings[0][i], rings[0][j], rings[1][j], rings[1][i]]
		mid = sum((q.co for q in quad), Vector()) / 4
		make_face(quad, name, mid - (center + direction * depth / 2))
	make_face(rings[1], cap or name, direction)
	return rings


# Dimensions (studs).
HW = 3.2  # body half width
CHAMFER = 0.32  # hood, trunk and shoulder chamfer inward
BOTTOM = 0.95
FRONT, REAR = 6.7, -6.7
WHEEL_R, WHEEL_Z = 1.25, 1.25
AXLES = (4.45, -4.35)
ARCH_R = 1.5
# Loft stations along Y: (y, shoulder z, top z). The shoulder is where the vertical side meets the chamfer.
STATIONS = [
	(REAR, 2.9, 3.12),
	(-4.0, 2.95, 3.22),
	(2.2, 2.95, 3.26),
	(FRONT, 2.6, 2.88),
]


def shoulder(y):
	for (ya, sa, _), (yb, sb, _) in zip(STATIONS, STATIONS[1:]):
		if ya <= y <= yb:
			return sa + (sb - sa) * (y - ya) / (yb - ya)
	return STATIONS[-1][1]


def side_profile():
	"""The body side outline in (y, z), counter-clockwise seen from +X: bottom (rear to front) with the two wheel
	arches cut out, then the shoulder line back."""
	points = [(REAR, BOTTOM)]
	for axle in sorted(AXLES):
		dz = BOTTOM - WHEEL_Z
		start = math.degrees(math.asin(dz / ARCH_R))  # below the centre, negative
		steps = 7
		# Rear edge of the arch to the front edge, over the top (angles measured from the -Y axis, clockwise up).
		for s in range(steps + 1):
			a = math.radians(180 - start) - math.radians(180 - 2 * start) * s / steps
			y = axle + ARCH_R * math.cos(a)
			# Flattened under the shoulder line where the hood dips, so the arch never breaks through.
			points.append((y, min(WHEEL_Z + ARCH_R * math.sin(a), shoulder(y) - 0.08)))
	points.append((FRONT, BOTTOM))
	for y, s, _ in reversed(STATIONS):
		points.append((y, s))
	return points


def body():
	profile = side_profile()
	count = len(profile)
	# Side slab: the profile extruded across the width. Bottom and wheel-well walls are dark.
	left = [bm.verts.new((-HW, y, z)) for y, z in profile]
	right = [bm.verts.new((HW, y, z)) for y, z in profile]
	for side, ring in ((1, right), (-1, left)):
		face = make_face(ring, "PAINT", (side, 0, 0))
		bmesh.ops.triangulate(bm, faces=[face], quad_method="BEAUTY", ngon_method="EAR_CLIP")
	for i in range(count):
		j = (i + 1) % count
		(ya, za), (yb, zb) = profile[i], profile[j]
		dy, dz = yb - ya, zb - za
		outward = (0, dz, -dy)  # clockwise turn of the edge, outward for a counter-clockwise outline
		is_shoulder = count - len(STATIONS) <= i < count - 1
		is_end = abs(dy) < 1e-6 and abs(ya) > FRONT - 0.01
		color = "PAINT" if (is_shoulder or is_end) else "UNDER"
		if is_shoulder:
			continue  # the loft below covers the top
		make_face([left[i], left[j], right[j], right[i]], color, outward)
	# Upper loft: shoulder line up to the chamfered hood, cabin deck and trunk.
	rows = []
	for y, s, t in STATIONS:
		rows.append([
			bm.verts.new((-HW, y, s)),
			bm.verts.new((-HW + CHAMFER, y, t)),
			bm.verts.new((HW - CHAMFER, y, t)),
			bm.verts.new((HW, y, s)),
		])
	for k in range(len(rows) - 1):
		ref = Vector((0, (STATIONS[k][0] + STATIONS[k + 1][0]) / 2, 0))
		for i in range(3):
			quad = [rows[k][i], rows[k][i + 1], rows[k + 1][i + 1], rows[k + 1][i]]
			mid = sum((q.co for q in quad), Vector()) / 4
			make_face(quad, "PAINT", mid - ref)
	make_face(rows[0], "PAINT", (0, -1, 0))
	make_face(rows[-1], "PAINT", (0, 1, 0))


def top_z(y):
	for (ya, _, ta), (yb, _, tb) in zip(STATIONS, STATIONS[1:]):
		if ya <= y <= yb:
			return ta + (tb - ta) * (y - ya) / (yb - ya)
	return STATIONS[-1][2]


# Cabin: a frustum leaning in on all four sides, windows inset into each face.
CAB_BASE = (-4.1, 2.3, 3.2)  # rear y, front y, z (sits just below the deck)
CAB_ROOF = (-3.3, 0.55, 5.5)
CAB_BASE_HW, CAB_ROOF_HW = HW - CHAMFER - 0.02, 2.45
INSET = 0.07


def lerp(a, b, t):
	return a + (b - a) * t


def paneled(corners, ubreaks, vbreaks, windows, centroid):
	"""Splits a planar quad (corners: u0v0, u1v0, u1v1, u0v1) into a grid; window cells are pushed in by INSET."""
	c00, c10, c11, c01 = [Vector(c) for c in corners]
	normal = (c10 - c00).cross(c01 - c00).normalized()
	center = (c00 + c10 + c11 + c01) / 4
	if normal.dot(center - centroid) < 0:
		normal = -normal
	grid = [[bm.verts.new(lerp(lerp(c00, c10, u), lerp(c01, c11, u), v)) for v in vbreaks] for u in ubreaks]
	for i in range(len(ubreaks) - 1):
		for j in range(len(vbreaks) - 1):
			quad = [grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1]]
			if (i, j) not in windows:
				make_face(quad, "PAINT", normal)
				continue
			inner = [bm.verts.new(q.co - normal * INSET) for q in quad]
			make_face(inner, "WINDOW", normal)
			mid = sum((q.co for q in quad), Vector()) / 4
			for k in range(4):
				m = (k + 1) % 4
				wall = [quad[k], quad[m], inner[m], inner[k]]
				wall_mid = sum((w.co for w in wall), Vector()) / 4
				make_face(wall, "PAINT", mid - wall_mid)


def cabin():
	yb0, yb1, zb = CAB_BASE
	yr0, yr1, zr = CAB_ROOF
	bw, rw = CAB_BASE_HW, CAB_ROOF_HW
	base = {(sx, sy): Vector((sx * bw, yb0 if sy < 0 else yb1, zb)) for sx in (-1, 1) for sy in (-1, 1)}
	roof = {(sx, sy): Vector((sx * rw, yr0 if sy < 0 else yr1, zr)) for sx in (-1, 1) for sy in (-1, 1)}
	centroid = Vector((0, (yb0 + yb1 + yr0 + yr1) / 4, (zb + zr) / 2))
	# Sides: rear (C) pillar, rear door window, B pillar, front door window, A pillar.
	side_u = [0, 0.09, 0.53, 0.575, 0.94, 1]
	side_v = [0, 0.07, 0.9, 1]
	for sx in (-1, 1):
		paneled([base[sx, -1], base[sx, 1], roof[sx, 1], roof[sx, -1]], side_u, side_v, {(1, 1), (3, 1)}, centroid)
	end_u = [0, 0.065, 0.935, 1]
	paneled([base[-1, 1], base[1, 1], roof[1, 1], roof[-1, 1]], end_u, [0, 0.07, 0.9, 1], {(1, 1)}, centroid)
	paneled([base[-1, -1], base[1, -1], roof[1, -1], roof[-1, -1]], end_u, [0, 0.1, 0.88, 1], {(1, 1)}, centroid)
	make_face([roof[-1, -1], roof[1, -1], roof[1, 1], roof[-1, 1]], "PAINT", (0, 0, 1))


def front():
	y = FRONT
	# Grille panel with three slats, octagonal headlights in black bezels at its ends.
	box(-2.6, 2.6, y - 0.05, y + 0.07, 1.62, 2.46, "GRILLE", skip=("-y",))
	for z in (1.86, 2.03, 2.2):
		box(-1.45, 1.45, y + 0.07, y + 0.1, z - 0.025, z + 0.025, "SLAT", skip=("-y",))
	for sx in (-1, 1):
		prism((sx * 1.98, y + 0.07, 2.04), 1, 1, 0.42, 0.04, 8, "BLACK", phase=math.pi / 8)
		prism((sx * 1.98, y + 0.11, 2.04), 1, 1, 0.34, 0.05, 8, "HEADLIGHT", phase=math.pi / 8)
	# Bumper, plate and indicators.
	box(-HW - 0.06, HW + 0.06, y - 0.15, y + 0.32, 0.78, 1.42, "BLACK")
	box(-0.62, 0.62, y + 0.32, y + 0.36, 0.94, 1.24, "PLATE", skip=("-y",))
	for sx in (-1, 1):
		box(sx * 1.95, sx * 2.75, y + 0.32, y + 0.35, 1.05, 1.17, "YELLOW", skip=("-y",))
		x = sx * HW
		box(min(x, x + sx * 0.03), max(x, x + sx * 0.03), y - 0.75, y - 0.1, 1.48, 1.6, "YELLOW", skip=("-x" if sx > 0 else "+x",))


def rear():
	y = REAR
	for sx in (-1, 1):
		box(sx * 1.7, sx * 2.75, y - 0.06, y + 0.02, 2.12, 2.65, "TAIL", skip=("+y",))
		x = sx * HW
		box(min(x, x + sx * 0.03), max(x, x + sx * 0.03), y + 0.1, y + 0.75, 1.48, 1.6, "YELLOW", skip=("-x" if sx > 0 else "+x",))
	box(-0.55, 0.55, y - 0.04, y + 0.02, 2.2, 2.52, "PLATE", skip=("+y",))
	box(-HW - 0.06, HW + 0.06, y - 0.32, y + 0.15, 0.78, 1.42, "BLACK")
	for x in (-2.55, -2.1, 2.1, 2.55):
		prism((x, y - 0.32, 1.1), 1, -1, 0.13, 0.04, 8, "REFLECTOR", phase=math.pi / 8)


def sides():
	for sx in (-1, 1):
		x = sx * HW
		out = sx * 0.012
		skip = ("-x" if sx > 0 else "+x",)
		# Panel lines: front door front edge, between the doors (under the B pillar), rear door rear edge.
		for y, z1 in ((2.98, 2.8), (-0.45, 2.86), (-2.85, 2.82)):
			box(min(x, x + out), max(x, x + out), y - 0.03, y + 0.03, BOTTOM + 0.14, z1, "PAINT_DARK", skip=skip)
		# Door handles near each door's rear edge.
		for y0 in (-0.3, -2.7):
			box(min(x, x + sx * 0.09), max(x, x + sx * 0.09), y0, y0 + 0.5, 2.48, 2.64, "HANDLE", skip=skip)
		# Rocker strip between and outside the arches.
		front_axle, rear_axle = AXLES
		reach = math.sqrt(ARCH_R ** 2 - (WHEEL_Z - BOTTOM) ** 2)
		for y0, y1 in ((REAR - 0.15, rear_axle - reach), (rear_axle + reach, front_axle - reach), (front_axle + reach, FRONT - 0.15)):
			box(min(x - sx * 0.05, x + sx * 0.06), max(x - sx * 0.05, x + sx * 0.06), y0, y1, 0.82, 1.12, "ROCKER")


def wheels():
	sides_n = 16
	for axle in AXLES:
		for sx in (-1, 1):
			outer = sx * (HW - 0.12)
			inner = sx * (HW - 0.95)
			rings = []
			for x in (inner, outer):
				rings.append([
					bm.verts.new((x, axle + WHEEL_R * math.cos(2 * math.pi * i / sides_n),
						WHEEL_Z + WHEEL_R * math.sin(2 * math.pi * i / sides_n)))
					for i in range(sides_n)
				])
			center = Vector(((inner + outer) / 2, axle, WHEEL_Z))
			for i in range(sides_n):
				j = (i + 1) % sides_n
				quad = [rings[0][i], rings[0][j], rings[1][j], rings[1][i]]
				mid = sum((q.co for q in quad), Vector()) / 4
				make_face(quad, "TYRE", mid - center)
			make_face(rings[0], "TYRE", (-sx, 0, 0))
			make_face(rings[1], "TYRE", (sx, 0, 0))
			prism((outer, axle, WHEEL_Z), 0, sx, 0.58, 0.06, 10, "HUB", phase=math.pi / 10)
			prism((outer + sx * 0.06, axle, WHEEL_Z), 0, sx, 0.15, 0.05, 6, "HUB_DOT")


body()
cabin()
front()
rear()
sides()
wheels()
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0001)
mesh = bpy.data.meshes.new(NAME)
bm.to_mesh(mesh)
bm.free()
car = bpy.data.objects.new(NAME, mesh)
bpy.context.scene.collection.objects.link(car)
for poly in mesh.polygons:
	poly.use_smooth = False

# Recentre: bottom centre at the origin (tyres on Z = 0).
coords_all = [v.co.copy() for v in mesh.vertices]
mins = Vector([min(c[i] for c in coords_all) for i in range(3)])
maxs = Vector([max(c[i] for c in coords_all) for i in range(3)])
shift = Vector(((mins.x + maxs.x) / 2, (mins.y + maxs.y) / 2, mins.z))
for v in mesh.vertices:
	v.co -= shift


# Palette textures, one per paint. Written straight to pixels (no bake): every cell is one flat colour.
def write_palette(suffix, paint_rgb):
	colors = dict(PALETTE)
	colors["PAINT"] = paint_rgb
	base = PALETTE["PAINT"]
	colors["PAINT_DARK"] = tuple(round(paint_rgb[i] * PALETTE["PAINT_DARK"][i] / base[i]) for i in range(3))
	image = bpy.data.images.new(NAME + suffix, TEXTURE_SIZE, TEXTURE_SIZE)
	pixels = [0.0] * (TEXTURE_SIZE * TEXTURE_SIZE * 4)
	for name, index in CELLS.items():
		r, g, b = (c / 255 for c in colors[name])
		cx, cy = index % GRID, GRID - 1 - index // GRID  # image rows start at the bottom
		for py in range(cy * CELL, (cy + 1) * CELL):
			for px in range(cx * CELL, (cx + 1) * CELL):
				o = (py * TEXTURE_SIZE + px) * 4
				pixels[o : o + 4] = (r, g, b, 1.0)
	image.pixels = pixels
	image.filepath_raw = os.path.join(OUT, NAME + suffix + ".png")
	image.file_format = "PNG"
	image.save()
	return image, colors


images = {}
for suffix, paint_rgb in VARIANTS.items():
	images[suffix], used = write_palette(suffix, paint_rgb)
	print("VARIANT", NAME + suffix, "PAINT", used["PAINT"], "PAINT_DARK", used["PAINT_DARK"], flush=True)


def textured_material(suffix):
	material = bpy.data.materials.new(NAME + suffix)
	material.use_nodes = True
	nodes = material.node_tree.nodes
	nodes.clear()
	principled = nodes.new("ShaderNodeBsdfPrincipled")
	principled.inputs["Roughness"].default_value = 1
	texture = nodes.new("ShaderNodeTexImage")
	texture.image = images[suffix]
	texture.interpolation = "Closest"
	output = nodes.new("ShaderNodeOutputMaterial")
	material.node_tree.links.new(texture.outputs["Color"], principled.inputs["Base Color"])
	material.node_tree.links.new(principled.outputs["BSDF"], output.inputs["Surface"])
	return material


car.data.materials.append(textured_material(""))

bpy.context.view_layer.objects.active = car
car.select_set(True)
bpy.ops.export_scene.fbx(
	filepath=os.path.join(OUT, NAME + ".fbx"),
	use_selection=True,
	axis_forward="-Z",
	axis_up="Y",
	path_mode="COPY",
	embed_textures=True,
)
coords_all = [v.co for v in mesh.vertices]
mins = tuple(round(min(v[i] for v in coords_all), 3) for i in range(3))
maxs = tuple(round(max(v[i] for v in coords_all), 3) for i in range(3))
triangles = sum(len(p.vertices) - 2 for p in mesh.polygons)
print("CAR faces", len(mesh.polygons), "triangles", triangles, "bounds", mins, maxs, flush=True)

# Preview renders (not exported).
scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.image_settings.file_format = "PNG"
scene.world = bpy.data.worlds.new("PreviewWorld")
scene.world.use_nodes = True
scene.world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.78, 0.6, 0.72, 1)
scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.9
scene.view_settings.view_transform = "Standard"
scene.render.resolution_x = 1200
scene.render.resolution_y = 900

bpy.ops.mesh.primitive_plane_add(size=80, location=(0, 0, 0))
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
camera.data.lens = 50


def aim(where, target):
	camera.location = Vector(where)
	camera.rotation_euler = (Vector(target) - camera.location).to_track_quat("-Z", "Y").to_euler()


target = Vector((0, 0, 2.3))
aim((15, 19, 11), target)
scene.render.filepath = os.path.join(OUT, NAME + "_preview.png")
bpy.ops.render.render(write_still=True)

aim((-14, -20, 11), target)
scene.render.filepath = os.path.join(OUT, NAME + "_rear.png")
bpy.ops.render.render(write_still=True)

# Colour sheet: the four paints side by side (object-level materials on linked copies).
copies = []
for index, suffix in enumerate(VARIANTS):
	copy = car.copy()
	copy.location = ((index - 1.5) * 9.0, 0, 0)
	bpy.context.scene.collection.objects.link(copy)
	copy.material_slots[0].link = "OBJECT"
	copy.material_slots[0].material = textured_material(suffix) if suffix else car.data.materials[0]
	copies.append(copy)
car.hide_render = True
scene.render.resolution_x = 1600
scene.render.resolution_y = 700
camera.data.type = "ORTHO"
camera.data.ortho_scale = 42
aim((16, 34, 20), (0, 0, 2.0))
scene.render.filepath = os.path.join(OUT, NAME + "_colors.png")
bpy.ops.render.render(write_still=True)
for copy in copies:
	bpy.data.objects.remove(copy)
car.hide_render = False
camera.data.type = "PERSP"
aim((15, 19, 11), target)

for image in images.values():
	image.pack()
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, NAME + ".blend"), compress=True)
print("Car done", flush=True)
