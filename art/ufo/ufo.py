# Builds the Alien's UFO (Order Rush), mid-to-low poly and faceted: a grey saucer with a sharp rim, a ring of lights, a pale dome, and an
# open tractor-beam cone. Run headless from the repo root, after art/ufo/textures.py:
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup --python art/ufo/ufo.py
# Writes art/ufo/out/Ufo.fbx (one object, Ufo), Ufo.png (its baked texture) and TractorBeam.fbx.
# Units: the saucer is 2 wide; the beam is a 1-tall cone, 1 wide at the bottom (scaled to length in game).

import math
import os

import bpy
import bmesh

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out")
TEXTURE_SIZE = 512
SEGMENTS = 16

os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)

# Dark grey metal, a darker rim band, a green emitter underneath and yellow lights. Every face is one flat colour
# and the shading is flat, so the facets and the sharp rim read clearly.
TOP = (0.36, 0.37, 0.4)
HULL = (0.3, 0.31, 0.34)
BAND = (0.15, 0.16, 0.18)
UNDER = (0.22, 0.23, 0.26)
GLOW = (0.45, 1.0, 0.6)
LIGHT = (1.0, 0.82, 0.25)
DOME = (0.75, 0.9, 0.95)
PANEL = 0.9  # every other panel this much darker


def lathe(bm, profile, segments, bottom=None, top=None, layer=None):
	"""Spins (radius, z, colour) rings around Z; a ring's colour fills the band up to the next ring.
	Optional (z, colour) fan caps at the ends. Panels alternate light and dark."""
	rings = []
	for radius, z, _ in profile:
		ring = []
		for i in range(segments):
			angle = 2 * math.pi * i / segments
			ring.append(bm.verts.new((radius * math.cos(angle), radius * math.sin(angle), z)))
		rings.append(ring)

	def paint(face, color, i):
		if layer is None or color is None:
			return
		shade = PANEL if i % 2 == 1 and color != GLOW else 1.0
		for loop in face.loops:
			loop[layer] = (color[0] * shade, color[1] * shade, color[2] * shade, 1)

	for k in range(len(rings) - 1):
		for i in range(segments):
			j = (i + 1) % segments
			face = bm.faces.new((rings[k][i], rings[k][j], rings[k + 1][j], rings[k + 1][i]))
			paint(face, profile[k][2], i)
	for cap, ring in ((bottom, rings[0]), (top, rings[-1])):
		if cap is None:
			continue
		center = bm.verts.new((0, 0, cap[0]))
		for i in range(segments):
			face = bm.faces.new((ring[i], ring[(i + 1) % segments], center))
			paint(face, cap[1], i)


def new_object(name, mesh):
	obj = bpy.data.objects.new(name, mesh)
	bpy.context.scene.collection.objects.link(obj)
	for poly in mesh.polygons:
		poly.use_smooth = False
	return obj


# Body (the object is named Ufo): two shallow cones meeting at a sharp rim with a thin vertical band, a stepped top, an emitter underneath.
body_mesh = bpy.data.meshes.new("Body")
bm = bmesh.new()
color_layer = bm.loops.layers.float_color.new("Col")
lathe(
	bm,
	[
		(0.24, -0.36, UNDER),
		(0.3, -0.31, UNDER),
		(0.98, -0.06, BAND),
		(1.0, -0.03, BAND),
		(1.0, 0.03, BAND),
		(0.98, 0.06, HULL),
		(0.62, 0.2, TOP),
		(0.6, 0.24, TOP),
		(0.44, 0.24, TOP),
	],
	SEGMENTS,
	bottom=(-0.36, GLOW),
	top=(0.24, TOP),
	layer=color_layer,
)
# Faceted yellow lights on the upper cone, one per light panel.
LIGHT_COUNT = SEGMENTS // 2
for index in range(LIGHT_COUNT):
	angle = 2 * math.pi * (2 * index + 0.5) / SEGMENTS
	center = (0.8 * math.cos(angle), 0.8 * math.sin(angle), 0.135)
	result = bmesh.ops.create_icosphere(bm, subdivisions=1, radius=0.065)
	for vert in result["verts"]:
		x, y, z = vert.co
		vert.co = (x + center[0], y + center[1], z * 0.7 + center[2])
	for face in {f for vert in result["verts"] for f in vert.link_faces}:
		for loop in face.loops:
			loop[color_layer] = (*LIGHT, 1)
# Dome: a faceted pale bubble on top, part of the same mesh and texture (one MeshPart in Roblox).
DOME_STEPS = 4
lathe(
	bm,
	[
		(0.4 * math.cos(math.pi / 2 * s / DOME_STEPS), 0.24 + 0.36 * math.sin(math.pi / 2 * s / DOME_STEPS), DOME)
		for s in range(DOME_STEPS)
	],
	SEGMENTS,
	top=(0.6, DOME),
	layer=color_layer,
)
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
bm.to_mesh(body_mesh)
bm.free()
body = new_object("Ufo", body_mesh)

# Body material: the face colours, a little lighter on top and darker underneath. Baked to Ufo.png.
material = bpy.data.materials.new("Ufo")
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
height.inputs["From Min"].default_value = -0.4
height.inputs["From Max"].default_value = 0.27
links.new(separate.outputs["Z"], height.inputs["Value"])
shade = nodes.new("ShaderNodeValToRGB")
shade.color_ramp.elements[0].position = 0.0
shade.color_ramp.elements[0].color = (0.8, 0.8, 0.82, 1)
shade.color_ramp.elements[1].position = 0.9
shade.color_ramp.elements[1].color = (1.08, 1.08, 1.08, 1)
links.new(height.outputs["Result"], shade.inputs["Fac"])

final = nodes.new("ShaderNodeMix")
final.data_type = "RGBA"
final.blend_type = "MULTIPLY"
final.inputs["Factor"].default_value = 1.0
links.new(colors.outputs["Color"], final.inputs[6])
links.new(shade.outputs["Color"], final.inputs[7])
links.new(final.outputs[2], emission.inputs["Color"])
links.new(emission.outputs["Emission"], output.inputs["Surface"])

image = bpy.data.images.new("Ufo", TEXTURE_SIZE, TEXTURE_SIZE)
image_node = nodes.new("ShaderNodeTexImage")
image_node.image = image
nodes.active = image_node
body.data.materials.append(material)

# UVs for the bake.
bpy.context.view_layer.objects.active = body
body.select_set(True)
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
image.filepath_raw = os.path.join(OUT, "Ufo.png")
image.file_format = "PNG"
image.save()

nodes.clear()
principled = nodes.new("ShaderNodeBsdfPrincipled")
textured = nodes.new("ShaderNodeTexImage")
textured.image = image
result = nodes.new("ShaderNodeOutputMaterial")
links.new(textured.outputs["Color"], principled.inputs["Base Color"])
links.new(principled.outputs["BSDF"], result.inputs["Surface"])

bpy.ops.export_scene.fbx(
	filepath=os.path.join(OUT, "Ufo.fbx"),
	use_selection=True,
	axis_forward="-Z",
	axis_up="Y",
	path_mode="COPY",
	embed_textures=True,
)
faces = len(body.data.polygons)

# Tractor beam: an open cone, narrow at the top, seen from inside and outside (two shells, so it needs
# no double-sided flag). V runs 1 at the top to 0 at the ground, matching TractorBeam.png.
beam_mesh = bpy.data.meshes.new("TractorBeam")
bm = bmesh.new()
uv_layer = bm.loops.layers.uv.new("UVMap")
TOP_RADIUS, BOTTOM_RADIUS, ROWS = 0.25, 0.5, 2
for inside in (False, True):
	grid = []
	for row in range(ROWS + 1):
		t = row / ROWS  # 0 at the ground, 1 at the top
		radius = BOTTOM_RADIUS + (TOP_RADIUS - BOTTOM_RADIUS) * t
		line = []
		for i in range(SEGMENTS + 1):
			angle = 2 * math.pi * i / SEGMENTS
			line.append((bm.verts.new((radius * math.cos(angle), radius * math.sin(angle), t - 0.5)), (i / SEGMENTS, t)))
		grid.append(line)
	for row in range(ROWS):
		for i in range(SEGMENTS):
			quad = [grid[row][i], grid[row][i + 1], grid[row + 1][i + 1], grid[row + 1][i]]
			if inside:
				quad.reverse()
			face = bm.faces.new([vert for vert, _ in quad])
			for loop, (_, uv) in zip(face.loops, quad):
				loop[uv_layer].uv = uv
bm.to_mesh(beam_mesh)
bm.free()
beam = new_object("TractorBeam", beam_mesh)
beam_material = bpy.data.materials.new("TractorBeam")
beam_material.use_nodes = True
beam_nodes = beam_material.node_tree.nodes
beam_texture = beam_nodes.new("ShaderNodeTexImage")
beam_texture.image = bpy.data.images.load(os.path.join(OUT, "TractorBeam.png"))
beam_bsdf = beam_nodes.get("Principled BSDF")
beam_material.node_tree.links.new(beam_texture.outputs["Color"], beam_bsdf.inputs["Base Color"])
beam_material.node_tree.links.new(beam_texture.outputs["Alpha"], beam_bsdf.inputs["Alpha"])
beam.data.materials.append(beam_material)

bpy.ops.object.select_all(action="DESELECT")
beam.select_set(True)
bpy.context.view_layer.objects.active = beam
bpy.ops.export_scene.fbx(
	filepath=os.path.join(OUT, "TractorBeam.fbx"),
	use_selection=True,
	axis_forward="-Z",
	axis_up="Y",
	path_mode="COPY",
	embed_textures=True,
)
print("Ufo done:", faces, "faces; TractorBeam:", len(beam_mesh.polygons), "faces")
