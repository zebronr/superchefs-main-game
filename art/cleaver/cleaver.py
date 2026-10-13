# Builds the chopping knife (a cartoon meat cleaver), low poly and faceted: a thick steel blade with a lighter
# bevelled cutting edge, a spine highlight and a real hole near the top-front corner, a steel bolster, and a
# chunky orange-brown wooden handle with three rivets on each side. Run headless from the repo root:
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup --python art/cleaver/cleaver.py
# Writes art/cleaver/out/Cleaver.fbx (one object, Cleaver), Cleaver.png (its baked texture), and the preview
# renders Cleaver_preview.png (3/4 view) and Cleaver_side.png (flat side view).
# Units are studs. The long axis (handle butt to blade front) is Blender +Z (Roblox +Y), the blade's flat faces
# face +-Y, the cutting edge faces -X and the spine +X. The origin is the middle of the handle grip (Tool handle).

import math
import os

import bpy
import bmesh
from mathutils import Vector

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out")
TEXTURE_SIZE = 512

os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)


def rgb(value):
	return tuple(int(value[i : i + 2], 16) / 255 for i in (1, 3, 5)) + (1,)


# Cool light grey-blue steel with a lighter bevel and spine; warm orange-brown wood; light steel rivets.
STEEL = rgb("#8CA6CC")  # blade flat faces
STEEL_D = rgb("#6F86A8")  # thin rims round the back, spine and front
BEVEL = rgb("#E6F0FB")  # bevel strip along the cutting edge
BEVEL_D = rgb("#C9DAEE")  # every other bevel facet
EDGE = rgb("#F2F7FC")  # the sharp edge itself
SPINE = rgb("#BFD0E8")  # spine and front chamfer highlight
HOLE = rgb("#5E6E86")  # inside of the hole
BOLSTER = rgb("#B4C2D4")
WOOD = rgb("#DA6E22")
WOOD_END = rgb("#A84B16")
RIVET = rgb("#DCE4EE")
RIVET_D = rgb("#AEBBCB")
PANEL = 0.88  # every other handle and bolster panel this much darker


def shade(color, factor):
	return (color[0] * factor, color[1] * factor, color[2] * factor, 1)


def fill(face, layer, color):
	for loop in face.loops:
		loop[layer] = color


# Blade outline in the XZ plane: (x, z, sharp). The spine runs along +X, the cutting edge along -X and curves out
# (a belly), and the blade gets taller toward the front. "sharp" points get the wide bevel down to a thin edge.
OUTLINE = [
	(0.12, 0.50, False),  # heel of the spine, behind the bolster
	(0.15, 1.00, False),
	(0.16, 1.47, False),
	(0.12, 1.55, False),  # chamfered top-front corner
	(-0.44, 1.58, False),  # front
	(-0.58, 1.55, False),  # rounded bottom-front corner
	(-0.65, 1.46, True),
	(-0.67, 1.28, True),
	(-0.66, 1.08, True),
	(-0.63, 0.88, True),
	(-0.58, 0.70, True),
	(-0.51, 0.56, True),
	(-0.44, 0.50, False),  # heel of the edge
]
FLAT = 0.04  # half thickness of the blade's flat faces
RIM = 0.022  # half thickness at the outline (spine, front, back)
SHARP = 0.006  # half thickness at the cutting edge
BEVEL_WIDTH = 0.12
SPINE_WIDTH = 0.035
HOLE_CENTER, HOLE_RADIUS, HOLE_SEGMENTS = (-0.03, 1.38), 0.075, 10


def blade(bm, layer):
	count = len(OUTLINE)
	points = [Vector((x, z)) for x, z, _ in OUTLINE]
	area = sum(points[i].x * points[(i + 1) % count].y - points[(i + 1) % count].x * points[i].y for i in range(count))
	# Inward normal of each outline edge, then a mitred inset per corner.
	edge_in = []
	for i in range(count):
		d = (points[(i + 1) % count] - points[i]).normalized()
		n = Vector((-d.y, d.x)) if area > 0 else Vector((d.y, -d.x))
		edge_in.append(n)
	inner = []
	for i, (_, _, sharp) in enumerate(OUTLINE):
		n = (edge_in[i - 1] + edge_in[i]).normalized()
		width = BEVEL_WIDTH if sharp else SPINE_WIDTH
		inner.append(points[i] + n * (width / max(n.dot(edge_in[i]), 0.6)))

	def vert(p, y):
		return bm.verts.new((p.x, y, p.y))

	hole = [
		Vector((HOLE_CENTER[0] + HOLE_RADIUS * math.cos(2 * math.pi * (k + 0.5) / HOLE_SEGMENTS),
			HOLE_CENTER[1] + HOLE_RADIUS * math.sin(2 * math.pi * (k + 0.5) / HOLE_SEGMENTS)))
		for k in range(HOLE_SEGMENTS)
	]
	sides = {}
	for side in (1, -1):
		outer_v = [vert(points[i], side * (SHARP if OUTLINE[i][2] else RIM)) for i in range(count)]
		inner_v = [vert(inner[i], side * FLAT) for i in range(count)]
		hole_v = [vert(p, side * FLAT) for p in hole]
		sides[side] = (outer_v, inner_v, hole_v)
		# Flat face with the hole cut out (scanfill treats the hole loop as a hole).
		edges = [bm.edges.new((inner_v[i], inner_v[(i + 1) % count])) for i in range(count)]
		edges += [bm.edges.new((hole_v[k], hole_v[(k + 1) % HOLE_SEGMENTS])) for k in range(HOLE_SEGMENTS)]
		result = bmesh.ops.triangle_fill(bm, use_beauty=True, use_dissolve=True, edges=edges, normal=(0, side, 0))
		for face in [g for g in result["geom"] if isinstance(g, bmesh.types.BMFace)]:
			fill(face, layer, STEEL)
		# Bevel strip (sharp side) or spine chamfer (elsewhere), one flat colour per facet.
		for i in range(count):
			j = (i + 1) % count
			face = bm.faces.new((outer_v[i], outer_v[j], inner_v[j], inner_v[i]))
			if OUTLINE[i][2] or OUTLINE[j][2]:
				color = BEVEL if i % 2 == 0 else BEVEL_D
			else:
				color = SPINE
			fill(face, layer, color)
	# Rim round the outline, joining both sides; the cutting edge itself is near white.
	front, back = sides[1], sides[-1]
	for i in range(count):
		j = (i + 1) % count
		face = bm.faces.new((front[0][i], back[0][i], back[0][j], front[0][j]))
		fill(face, layer, EDGE if OUTLINE[i][2] and OUTLINE[j][2] else STEEL_D)
	# Wall of the hole.
	for k in range(HOLE_SEGMENTS):
		m = (k + 1) % HOLE_SEGMENTS
		face = bm.faces.new((front[2][k], front[2][m], back[2][m], back[2][k]))
		fill(face, layer, shade(HOLE, 1.0 if k % 2 == 0 else PANEL))


def lathe_z(bm, layer, profile, rx, ry, segments=8, bottom=None, top=None):
	"""(scale, z, colour) rings round Z, elliptical (rx, ry); flat faces face +-X and +-Y. Panels alternate."""
	rings = []
	for s, z, _ in profile:
		ring = []
		for i in range(segments):
			a = 2 * math.pi * (i + 0.5) / segments
			ring.append(bm.verts.new((s * rx * math.cos(a), s * ry * math.sin(a), z)))
		rings.append(ring)
	for k in range(len(rings) - 1):
		for i in range(segments):
			j = (i + 1) % segments
			face = bm.faces.new((rings[k][i], rings[k][j], rings[k + 1][j], rings[k + 1][i]))
			fill(face, layer, shade(profile[k][2], PANEL if i % 2 else 1.0))
	if bottom:
		fill(bm.faces.new(list(reversed(rings[0]))), layer, bottom)
	if top:
		fill(bm.faces.new(rings[-1]), layer, top)


HANDLE_RX, HANDLE_RY = 0.12, 0.082
RIVETS_Z = (-0.24, 0.0, 0.24)


def handle(bm, layer):
	# Chunky grip: a flared, rounded-off butt, straight flat sides for the rivets, a slight taper into the bolster.
	lathe_z(
		bm,
		layer,
		[
			(0.72, -0.47, WOOD_END),
			(1.08, -0.43, WOOD),
			(1.08, -0.35, WOOD),
			(1.0, -0.29, WOOD),
			(1.0, 0.3, WOOD),
			(0.95, 0.42, WOOD),
		],
		HANDLE_RX,
		HANDLE_RY,
		bottom=WOOD_END,
		top=WOOD_END,
	)
	# Steel bolster between the handle and the blade.
	lathe_z(
		bm,
		layer,
		[(1.0, 0.39, BOLSTER), (1.14, 0.42, BOLSTER), (1.14, 0.5, BOLSTER), (1.0, 0.53, BOLSTER)],
		HANDLE_RX,
		HANDLE_RY,
		bottom=BOLSTER,
		top=BOLSTER,
	)
	# Rivets: small six-sided domed studs on the flat faces of both sides.
	face_y = HANDLE_RY * math.cos(math.pi / 8)
	for side in (1, -1):
		for z in RIVETS_Z:
			rings = []
			for radius, rise in ((0.042, -0.004), (0.042, 0.012), (0.024, 0.024)):
				ring = []
				for i in range(6):
					a = 2 * math.pi * i / 6
					ring.append(bm.verts.new((radius * math.cos(a), side * (face_y + rise), z + radius * math.sin(a))))
				rings.append(ring)
			for k in range(2):
				for i in range(6):
					j = (i + 1) % 6
					face = bm.faces.new((rings[k][i], rings[k][j], rings[k + 1][j], rings[k + 1][i]))
					fill(face, layer, RIVET_D if k == 0 else (RIVET if i % 2 else shade(RIVET, 0.93)))
			fill(bm.faces.new(rings[-1]), layer, RIVET)


bm = bmesh.new()
color_layer = bm.loops.layers.float_color.new("Col")
blade(bm, color_layer)
handle(bm, color_layer)
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
mesh = bpy.data.meshes.new("Cleaver")
bm.to_mesh(mesh)
bm.free()
cleaver = bpy.data.objects.new("Cleaver", mesh)
bpy.context.scene.collection.objects.link(cleaver)
for poly in mesh.polygons:
	poly.use_smooth = False

# Material: the face colours, a little lighter toward the blade (top when held) and darker toward the butt. Baked.
material = bpy.data.materials.new("Cleaver")
material.use_nodes = True
nodes = material.node_tree.nodes
links = material.node_tree.links
nodes.clear()
output = nodes.new("ShaderNodeOutputMaterial")
emission = nodes.new("ShaderNodeEmission")
coords = nodes.new("ShaderNodeTexCoord")
colors = nodes.new("ShaderNodeVertexColor")
colors.layer_name = "Col"
separate = nodes.new("ShaderNodeSeparateXYZ")
links.new(coords.outputs["Object"], separate.inputs["Vector"])
height = nodes.new("ShaderNodeMapRange")
height.inputs["From Min"].default_value = -0.47
height.inputs["From Max"].default_value = 1.58
links.new(separate.outputs["Z"], height.inputs["Value"])
ramp = nodes.new("ShaderNodeValToRGB")
ramp.color_ramp.elements[0].position = 0.0
ramp.color_ramp.elements[0].color = (0.84, 0.84, 0.86, 1)
ramp.color_ramp.elements[1].position = 1.0
ramp.color_ramp.elements[1].color = (1.06, 1.06, 1.06, 1)
links.new(height.outputs["Result"], ramp.inputs["Fac"])
final = nodes.new("ShaderNodeMix")
final.data_type = "RGBA"
final.blend_type = "MULTIPLY"
final.inputs["Factor"].default_value = 1.0
links.new(colors.outputs["Color"], final.inputs[6])
links.new(ramp.outputs["Color"], final.inputs[7])
links.new(final.outputs[2], emission.inputs["Color"])
links.new(emission.outputs["Emission"], output.inputs["Surface"])

image = bpy.data.images.new("Cleaver", TEXTURE_SIZE, TEXTURE_SIZE)
image_node = nodes.new("ShaderNodeTexImage")
image_node.image = image
nodes.active = image_node
cleaver.data.materials.append(material)

bpy.context.view_layer.objects.active = cleaver
cleaver.select_set(True)
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.uv.smart_project(island_margin=0.02)
bpy.ops.object.mode_set(mode="OBJECT")

scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 16
scene.render.bake.margin = 8
bpy.ops.object.bake(type="EMIT")
image.filepath_raw = os.path.join(OUT, "Cleaver.png")
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
	filepath=os.path.join(OUT, "Cleaver.fbx"),
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
print("CLEAVER faces", len(mesh.polygons), "triangles", triangles, "bounds", mins, maxs, flush=True)


# Preview renders (not exported): the cleaver laid on its long side, blade forward and edge down.
scene.render.engine = "BLENDER_EEVEE"
scene.render.image_settings.file_format = "PNG"
scene.world = bpy.data.worlds.new("PreviewWorld")
scene.world.color = (0.32, 0.33, 0.35)
scene.view_settings.view_transform = "Standard"
scene.view_settings.look = "Medium Contrast"
scene.render.resolution_x = 1024
scene.render.resolution_y = 768
cleaver.rotation_euler = (0, -math.pi / 2, 0)
cleaver.location = (0, 0, 0)
bpy.context.view_layer.update()
# After the turn the blade points along -X world (left in the side view), edge down (-Z); centre the framing on the whole knife.
corners = [cleaver.matrix_world @ Vector(c) for c in cleaver.bound_box]
centre = sum(corners, Vector()) / 8

bpy.ops.object.light_add(type="SUN", location=(0, 0, 10))
sun = bpy.context.object
sun.data.energy = 1.4
sun.rotation_euler = (math.radians(40), math.radians(-20), math.radians(30))
bpy.ops.object.light_add(type="AREA", location=(centre.x - 2, -4, 3))
fill_light = bpy.context.object
fill_light.data.energy = 80
fill_light.data.size = 4
fill_light.rotation_euler = (Vector((centre.x, 0, 0)) - fill_light.location).to_track_quat("-Z", "Y").to_euler()

bpy.ops.object.camera_add()
camera = bpy.context.object
scene.camera = camera
camera.data.type = "ORTHO"


def aim(where, target):
	camera.location = where
	camera.rotation_euler = (Vector(target) - camera.location).to_track_quat("-Z", "Y").to_euler()


aim(centre + Vector((-1.6, -3.2, 2.2)), centre)
camera.data.ortho_scale = 2.6
scene.render.filepath = os.path.join(OUT, "Cleaver_preview.png")
bpy.ops.render.render(write_still=True)

aim(centre + Vector((0, -5, 0)), centre)
camera.data.ortho_scale = 2.5
scene.render.filepath = os.path.join(OUT, "Cleaver_side.png")
bpy.ops.render.render(write_still=True)
print("Cleaver done", flush=True)
