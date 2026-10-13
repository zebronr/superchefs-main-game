# Builds the bread foods, low poly and faceted, replacing the high-poly imports: a loaf (raw "bread"), a slice
# (chopped_bread, also its plated look) and the three sandwiches (strawberry jam, peanut butter, both). Spreads never
# sit on a plate alone (Config Recipes.NeedsBase), so they have no model of their own. Run headless from the repo root:
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup --python art/bread/bread.py
# Writes art/bread/out/<Name>.fbx (one object each) with its baked texture <Name>.png, a preview render of them all
# (Bread_preview.png), and order icons (Icon_<Name>.png, transparent) including a strawberry and a peanut that are
# only drawn for the icons.
# Units are studs. Blender +Z is Roblox +Y. Every object's origin is the middle of its bounding box.

import math
import os

import bpy
import bmesh
from mathutils import Vector

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out")
TEXTURE_SIZE = 256
ICON_SIZE = 512

os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)


def rgb(value):
	# Hex sRGB to the linear values vertex colours hold, so the baked texture keeps the hex colour.
	def linear(c):
		return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

	return tuple(linear(int(value[i : i + 2], 16) / 255) for i in (1, 3, 5)) + (1,)


CRUST = rgb("#C07A3E")
CRUST_TOP = rgb("#A8622C")  # the loaf's baked top
CRUST_RIM = rgb("#9C5A2A")  # the crust ring round a cut face
CRUMB = rgb("#F3D79C")
JAM = rgb("#D72F45")
JAM_D = rgb("#AE1F35")
PB = rgb("#E0A157")
PB_D = rgb("#B97A36")
BERRY = rgb("#E23A3A")
BERRY_D = rgb("#C22A30")
SEED = rgb("#FFE08A")
LEAF = rgb("#4DB33D")
LEAF_D = rgb("#3A9030")
SHELL = rgb("#D9A56A")
SHELL_D = rgb("#BF8A50")
PANEL = 0.9  # every other side facet this much darker


def shade(color, factor):
	return (color[0] * factor, color[1] * factor, color[2] * factor, 1)


def fill(face, layer, color):
	for loop in face.loops:
		loop[layer] = color


# Slice outline (u across, v up the slice), right half from the bottom corner to the top middle: straight sides that
# step out into the rounded "ears" of a bread slice. Mirrored for the left half.
HALF = [
	(0.95, -1.15),
	(1.07, -1.04),
	(1.07, 0.3),
	(1.22, 0.42),
	(1.3, 0.62),
	(1.26, 0.85),
	(1.1, 1.02),
	(0.8, 1.12),
	(0.4, 1.16),
]
OUTLINE = [Vector(p) for p in HALF] + [Vector((0, 1.15))] + [Vector((-u, v)) for u, v in reversed(HALF)]
RIM = 0.14  # crust ring width round a cut face
SLICE = 0.42  # slice thickness


def inset(points, distance, wobble=None):
	# Mitred inward offset of a counter-clockwise loop.
	count = len(points)
	out = []
	for i in range(count):
		a = (points[i] - points[i - 1]).normalized()
		b = (points[(i + 1) % count] - points[i]).normalized()
		na = Vector((-a.y, a.x))
		nb = Vector((-b.y, b.x))
		n = (na + nb).normalized()
		d = distance * (wobble[i] if wobble else 1)
		out.append(points[i] + n * (d / max(n.dot(nb), 0.5)))
	return out


def cut_face(bm, layer, outer, inner, place, flip):
	# A cut face: crumb in the middle, a crust ring round it. place(Vector2) -> 3D point.
	outer_v = [bm.verts.new(place(p)) for p in outer]
	inner_v = [bm.verts.new(place(p)) for p in inner]
	count = len(outer)
	for i in range(count):
		j = (i + 1) % count
		quad = (outer_v[i], outer_v[j], inner_v[j], inner_v[i])
		fill(bm.faces.new(tuple(reversed(quad)) if flip else quad), layer, CRUST_RIM)
	fill(bm.faces.new(tuple(reversed(inner_v)) if flip else tuple(inner_v)), layer, CRUMB)
	return outer_v


def band(bm, layer, lower, upper, color, dark=None):
	# Side wall between two equal loops of verts.
	count = len(lower)
	for i in range(count):
		j = (i + 1) % count
		fill(bm.faces.new((lower[i], lower[j], upper[j], upper[i])), layer, color if i % 2 else (dark or shade(color, PANEL)))


def slice_at(bm, layer, z0, tilt=0.0, offset=(0.0, 0.0)):
	# A slice lying flat from z0 up, its crust bevelled in a little at the top and bottom edge.
	inner = inset(OUTLINE, RIM)
	edge = inset(OUTLINE, 0.03)
	c, s = math.cos(tilt), math.sin(tilt)

	def at(z):
		def place(p):
			return (p.x * c - p.y * s + offset[0], p.x * s + p.y * c + offset[1], z)
		return place

	bottom = cut_face(bm, layer, edge, inner, at(z0), True)
	low = [bm.verts.new(at(z0 + 0.06)(p)) for p in OUTLINE]
	high = [bm.verts.new(at(z0 + SLICE - 0.06)(p)) for p in OUTLINE]
	top = cut_face(bm, layer, edge, inner, at(z0 + SLICE), False)
	band(bm, layer, bottom, low, CRUST)
	band(bm, layer, low, high, CRUST)
	band(bm, layer, high, top, CRUST)


def spread_at(bm, layer, z0, thickness, color, dark, seed):
	# A spread layer squished out between slices: the outline pulled in, bulging past the crust in places.
	# Per point: 1 = 0.1 inside the crust, -0.8 = 0.08 past it.
	wobble = [1 - 1.8 * ((math.sin(i * 2.3 + seed) + 1) / 2) ** 2 for i in range(len(OUTLINE))]
	loop = inset(OUTLINE, 0.1, wobble)
	low = [bm.verts.new((p.x, p.y, z0)) for p in loop]
	high = [bm.verts.new((p.x, p.y, z0 + thickness)) for p in loop]
	fill(bm.faces.new(tuple(reversed(low))), layer, dark)
	fill(bm.faces.new(tuple(high)), layer, color)
	band(bm, layer, low, high, color, dark)


def loaf(bm, layer):
	# The slice outline stood up (u across X, v up Z) and pushed along Y: cut crumb faces at both ends.
	length = 2.6
	inner = inset(OUTLINE, RIM)
	edge = inset(OUTLINE, 0.03)
	lift = 1.15

	def at(y):
		return lambda p: (p.x, y, p.y + lift)

	front = cut_face(bm, layer, edge, inner, at(-length / 2), False)
	back = cut_face(bm, layer, edge, inner, at(length / 2), True)
	mid_a = [bm.verts.new(at(-length / 2 + 0.08)(p)) for p in OUTLINE]
	mid_b = [bm.verts.new(at(length / 2 - 0.08)(p)) for p in OUTLINE]
	count = len(OUTLINE)

	def crust_color(i):
		v = (OUTLINE[i].y + OUTLINE[(i + 1) % count].y) / 2
		base = CRUST_TOP if v > 0.5 else CRUST
		return base if i % 2 else shade(base, PANEL)

	for a, b in ((front, mid_a), (mid_a, mid_b), (mid_b, back)):
		for i in range(count):
			j = (i + 1) % count
			fill(bm.faces.new((a[i], a[j], b[j], b[i])), layer, crust_color(i))


def lathe(bm, layer, profile, segments, top=None, bottom=None, center=(0, 0)):
	# (radius, z, colour) rings round Z.
	rings = []
	for r, z, _ in profile:
		rings.append([bm.verts.new((center[0] + r * math.cos(2 * math.pi * i / segments), center[1] + r * math.sin(2 * math.pi * i / segments), z)) for i in range(segments)])
	for k in range(len(rings) - 1):
		for i in range(segments):
			j = (i + 1) % segments
			fill(bm.faces.new((rings[k][i], rings[k][j], rings[k + 1][j], rings[k + 1][i])), layer, shade(profile[k][2], PANEL if i % 2 else 1.0))
	if bottom:
		fill(bm.faces.new(list(reversed(rings[0]))), layer, bottom)
	if top:
		fill(bm.faces.new(rings[-1]), layer, top)
	return rings


def sandwich(spreads):
	def build(bm, layer):
		slice_at(bm, layer, 0)
		z = SLICE
		for k, (color, dark) in enumerate(spreads):
			spread_at(bm, layer, z, 0.16, color, dark, k * 1.7)
			z += 0.16
		slice_at(bm, layer, z, tilt=math.radians(4), offset=(0.03, 0.02))
	return build


def strawberry(bm, layer):
	rings = lathe(
		bm,
		layer,
		[(0.0001, 0, BERRY_D), (0.35, 0.12, BERRY_D), (0.62, 0.45, BERRY), (0.72, 0.85, BERRY), (0.62, 1.15, BERRY), (0.3, 1.3, BERRY)],
		8,
		top=BERRY,
	)
	# Seeds: tiny flat squares stuck on the side facets.
	for k in (1, 2, 3):
		for i in range(8):
			if (i + k) % 2:
				continue
			a, b = rings[k][i].co, rings[k + 1][(i + 1) % 8].co
			m = (a + b) / 2
			n = Vector((m.x, m.y, 0)).normalized()
			t = Vector((-n.y, n.x, 0)) * 0.05
			u = Vector((0, 0, 0.05))
			o = m + n * 0.012
			fill(bm.faces.new([bm.verts.new(o - t - u), bm.verts.new(o + t - u), bm.verts.new(o + t + u), bm.verts.new(o - t + u)]), layer, SEED)
	# Leaf star on top.
	centre = bm.verts.new((0, 0, 1.36))
	for i in range(6):
		a = 2 * math.pi * i / 6
		tip = bm.verts.new((0.55 * math.cos(a), 0.55 * math.sin(a), 1.22))
		l = bm.verts.new((0.18 * math.cos(a - 0.5), 0.18 * math.sin(a - 0.5), 1.33))
		r = bm.verts.new((0.18 * math.cos(a + 0.5), 0.18 * math.sin(a + 0.5), 1.33))
		fill(bm.faces.new((centre, l, tip, r)), layer, LEAF if i % 2 else LEAF_D)
	lathe(bm, layer, [(0.06, 1.34, LEAF_D), (0.05, 1.6, LEAF_D)], 5, top=LEAF_D)


def peanut(bm, layer):
	# Two lobes with a waist, lying along X.
	profile = [(0.0001, -1.0), (0.32, -0.92), (0.48, -0.6), (0.44, -0.25), (0.33, 0.0), (0.42, 0.28), (0.46, 0.6), (0.3, 0.92), (0.0001, 1.0)]
	segments = 8
	rings = []
	for r, x in profile:
		rings.append([bm.verts.new((x, r * math.cos(2 * math.pi * i / segments), r * math.sin(2 * math.pi * i / segments))) for i in range(segments)])
	for k in range(len(rings) - 1):
		for i in range(segments):
			j = (i + 1) % segments
			fill(bm.faces.new((rings[k][i], rings[k][j], rings[k + 1][j], rings[k + 1][i])), layer, SHELL if (i + k) % 2 else SHELL_D)


def make(name, builder):
	bm = bmesh.new()
	layer = bm.loops.layers.float_color.new("Col")
	builder(bm, layer)
	bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0001)
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	# Origin at the middle of the bounding box.
	lo = Vector((min(v.co[i] for v in bm.verts) for i in range(3)))
	hi = Vector((max(v.co[i] for v in bm.verts) for i in range(3)))
	middle = (lo + hi) / 2
	for v in bm.verts:
		v.co -= middle
	mesh = bpy.data.meshes.new(name)
	bm.to_mesh(mesh)
	bm.free()
	obj = bpy.data.objects.new(name, mesh)
	bpy.context.scene.collection.objects.link(obj)
	for poly in mesh.polygons:
		poly.use_smooth = False
	return obj


def bake_and_export(obj):
	# Face colours lit softly from above (tops a little lighter, undersides darker), baked to one small texture.
	material = bpy.data.materials.new(obj.name)
	material.use_nodes = True
	nodes = material.node_tree.nodes
	links = material.node_tree.links
	nodes.clear()
	output = nodes.new("ShaderNodeOutputMaterial")
	emission = nodes.new("ShaderNodeEmission")
	colors = nodes.new("ShaderNodeVertexColor")
	colors.layer_name = "Col"
	geometry = nodes.new("ShaderNodeNewGeometry")
	separate = nodes.new("ShaderNodeSeparateXYZ")
	links.new(geometry.outputs["Normal"], separate.inputs["Vector"])
	light = nodes.new("ShaderNodeMapRange")
	light.inputs["From Min"].default_value = -1
	light.inputs["From Max"].default_value = 1
	light.inputs["To Min"].default_value = 0.8
	light.inputs["To Max"].default_value = 1.04
	links.new(separate.outputs["Z"], light.inputs["Value"])
	final = nodes.new("ShaderNodeMix")
	final.data_type = "RGBA"
	final.blend_type = "MULTIPLY"
	final.inputs["Factor"].default_value = 1.0
	links.new(colors.outputs["Color"], final.inputs[6])
	links.new(light.outputs["Result"], final.inputs[7])
	links.new(final.outputs[2], emission.inputs["Color"])
	links.new(emission.outputs["Emission"], output.inputs["Surface"])
	image = bpy.data.images.new(obj.name, TEXTURE_SIZE, TEXTURE_SIZE)
	image_node = nodes.new("ShaderNodeTexImage")
	image_node.image = image
	nodes.active = image_node
	obj.data.materials.append(material)

	for other in bpy.context.scene.objects:
		other.select_set(False)
	bpy.context.view_layer.objects.active = obj
	obj.select_set(True)
	bpy.ops.object.mode_set(mode="EDIT")
	bpy.ops.mesh.select_all(action="SELECT")
	bpy.ops.uv.smart_project(island_margin=0.03)
	bpy.ops.object.mode_set(mode="OBJECT")
	scene = bpy.context.scene
	scene.render.engine = "CYCLES"
	scene.cycles.device = "CPU"
	scene.cycles.samples = 8
	scene.render.bake.margin = 4
	bpy.ops.object.bake(type="EMIT")
	image.filepath_raw = os.path.join(OUT, f"{obj.name}.png")
	image.file_format = "PNG"
	image.save()

	nodes.clear()
	principled = nodes.new("ShaderNodeBsdfPrincipled")
	principled.inputs["Roughness"].default_value = 1
	textured = nodes.new("ShaderNodeTexImage")
	textured.image = image
	result = nodes.new("ShaderNodeOutputMaterial")
	links.new(textured.outputs["Color"], principled.inputs["Base Color"])
	links.new(principled.outputs["BSDF"], result.inputs["Surface"])

	bpy.ops.export_scene.fbx(
		filepath=os.path.join(OUT, f"{obj.name}.fbx"),
		use_selection=True,
		axis_forward="-Z",
		axis_up="Y",
		path_mode="COPY",
		embed_textures=True,
	)
	mesh = obj.data
	dims = tuple(round(d, 2) for d in obj.dimensions)
	triangles = sum(len(p.vertices) - 2 for p in mesh.polygons)
	print(f"{obj.name}: triangles {triangles}, size (Blender XYZ) {dims}", flush=True)


EXPORTS = [
	("Bread", loaf),
	("BreadSlice", lambda bm, layer: slice_at(bm, layer, 0)),
	("JamSandwich", sandwich([(JAM, JAM_D)])),
	("PeanutButterSandwich", sandwich([(PB, PB_D)])),
	("PBJSandwich", sandwich([(PB, PB_D), (JAM, JAM_D)])),
]
ICON_ONLY = [("Strawberry", strawberry), ("Peanut", peanut)]

objects = []
for name, builder in EXPORTS:
	obj = make(name, builder)
	bake_and_export(obj)
	objects.append(obj)
for name, builder in ICON_ONLY:
	obj = make(name, builder)
	bake_and_export(obj)
	objects.append(obj)

# Renders: flat-lit (the baked texture shown as is), orthographic.
scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.world = bpy.data.worlds.new("PreviewWorld")
scene.world.color = (1, 1, 1)
scene.view_settings.view_transform = "Standard"
for obj in objects:
	material = obj.data.materials[0]
	nodes = material.node_tree.nodes
	links = material.node_tree.links
	image = next(n.image for n in nodes if n.type == "TEX_IMAGE")
	nodes.clear()
	textured = nodes.new("ShaderNodeTexImage")
	textured.image = image
	emission = nodes.new("ShaderNodeEmission")
	result = nodes.new("ShaderNodeOutputMaterial")
	links.new(textured.outputs["Color"], emission.inputs["Color"])
	links.new(emission.outputs["Emission"], result.inputs["Surface"])

bpy.ops.object.camera_add()
camera = bpy.context.object
scene.camera = camera
camera.data.type = "ORTHO"


def aim(target, distance, pitch, yaw):
	direction = Vector((math.cos(pitch) * math.sin(yaw), -math.cos(pitch) * math.cos(yaw), math.sin(pitch)))
	camera.location = Vector(target) + direction * distance
	camera.rotation_euler = (Vector(target) - camera.location).to_track_quat("-Z", "Y").to_euler()


# Preview: everything in a row.
x = 0.0
for obj in objects:
	width = obj.dimensions.x
	obj.location = (x + width / 2, 0, obj.dimensions.z / 2)
	x += width + 0.6
scene.world.color = (0.32, 0.33, 0.35)
scene.render.film_transparent = False
scene.render.resolution_x = 2048
scene.render.resolution_y = 560
aim((x / 2, 0, 0.8), 30, math.radians(35), math.radians(-20))
camera.data.ortho_scale = x + 1
scene.render.filepath = os.path.join(OUT, "Bread_preview.png")
bpy.ops.render.render(write_still=True)

# Icons: one object at a time on a transparent background.
scene.render.film_transparent = True
scene.render.resolution_x = ICON_SIZE
scene.render.resolution_y = ICON_SIZE
for obj in objects:
	obj.hide_render = True
for obj in objects:
	obj.hide_render = False
	obj.location = (0, 0, 0)
	if obj.name == "Peanut":
		obj.rotation_euler = (0, 0, math.radians(35))
	bpy.context.view_layer.update()
	aim((0, 0, 0), 30, math.radians(38 if obj.name not in ("Strawberry", "Peanut") else 20), math.radians(-25))
	camera.data.ortho_scale = max(obj.dimensions) * 1.45
	scene.render.filepath = os.path.join(OUT, f"Icon_{obj.name}.png")
	bpy.ops.render.render(write_still=True)
	obj.hide_render = True
print("Bread done", flush=True)
