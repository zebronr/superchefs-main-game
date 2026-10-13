# Builds the cartoon baseball bat, low poly and faceted: a fat blond-wood barrel with a rounded cap, a strong taper
# to a thin handle wrapped in ridged charcoal grip tape, and a chunky knob. Run headless from the repo root:
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup --python art/bat/bat.py
# Writes art/bat/out/Bat.fbx (one object, Bat), Bat.png (its baked texture), Bat_preview.png (3/4) and Bat_side.png.
# Units are studs: 3.2 long along Blender +Z (Roblox +Y). The origin is the grip point on the handle, just above the
# knob, so the mesh can be a Roblox Tool's Handle.

import math
import os

import bpy
import bmesh
from mathutils import Vector

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out")
TEXTURE_SIZE = 512
SEGMENTS = 10

os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)


def rgb(value):
	return tuple(int(value[i:i + 2], 16) / 255 for i in (1, 3, 5))


# Warm blond wood, a deeper amber for the knob and the taper ring, charcoal tape with lighter ridges.
WOOD = rgb("#F0A23C")
WOOD_L = rgb("#F7B64C")
WOOD_D = rgb("#C9761F")
KNOB = rgb("#B8601A")
TAPE = rgb("#252427")
RIDGE = rgb("#3D3B40")
PANEL = 0.9  # every other panel around the circumference this much darker
LIGHT_DIR = Vector((-0.35, -0.55, 0.75)).normalized()  # baked face shading: lighter toward this side

# (radius, z, colour) rings from the knob up to the barrel cap; a ring's colour fills the band up to the next ring.
# z is measured from the grip point (the origin).
PROFILE = [
	(0.12, -0.36, KNOB),  # knob underside
	(0.19, -0.33, KNOB),
	(0.2, -0.25, KNOB),
	(0.17, -0.2, KNOB),  # knob top slope
	(0.1, -0.16, TAPE),
]
# Grip tape: alternating raised ridge and groove bands suggest the wrap.
TAPE_BOTTOM, TAPE_TOP, WRAPS = -0.16, 0.6, 4
step = (TAPE_TOP - TAPE_BOTTOM) / WRAPS
for k in range(WRAPS):
	z = TAPE_BOTTOM + k * step
	r = 0.1 + 0.008 * k  # the handle widens slightly under the tape
	PROFILE.append((r + 0.012, z + step * 0.25, RIDGE))
	PROFILE.append((r + 0.012, z + step * 0.6, TAPE))
	PROFILE.append((r, z + step * 0.85, TAPE))
PROFILE += [
	(0.15, TAPE_TOP, TAPE),  # tape end lip
	(0.15, TAPE_TOP + 0.04, WOOD),
	(0.12, TAPE_TOP + 0.06, WOOD),
	(0.125, 0.86, WOOD_D),  # taper ring
	(0.14, 0.93, WOOD),
	(0.19, 1.2, WOOD),
	(0.25, 1.5, WOOD),
	(0.29, 1.85, WOOD_L),  # long fat barrel
	(0.3, 2.62, WOOD_L),
	(0.29, 2.73, WOOD_L),  # rounded cap
	(0.24, 2.83, WOOD_L),
	(0.15, 2.89, WOOD_L),
]
CAP_Z = 2.91
BOTTOM_Z = PROFILE[0][1] - 0.02


def paint(face, color, i, layer):
	"""One flat colour per face: alternating panels, lighter facing the light, darker underneath."""
	face.normal_update()
	light = 0.82 + 0.3 * max(0.0, face.normal.dot(LIGHT_DIR))
	under = 0.9 if face.normal.z < -0.5 else 1.0
	shade = (PANEL if i % 2 == 1 else 1.0) * light * under
	for loop in face.loops:
		loop[layer] = (min(color[0] * shade, 1), min(color[1] * shade, 1), min(color[2] * shade, 1), 1)


bm = bmesh.new()
layer = bm.loops.layers.float_color.new("Col")
rings = []
for radius, z, _ in PROFILE:
	ring = []
	for i in range(SEGMENTS):
		a = 2 * math.pi * (i + 0.5) / SEGMENTS
		ring.append(bm.verts.new((radius * math.cos(a), radius * math.sin(a), z)))
	rings.append(ring)
for k in range(len(rings) - 1):
	for i in range(SEGMENTS):
		j = (i + 1) % SEGMENTS
		face = bm.faces.new((rings[k][i], rings[k][j], rings[k + 1][j], rings[k + 1][i]))
		paint(face, PROFILE[k][2], i, layer)
for z, ring, color, flip in ((BOTTOM_Z, rings[0], KNOB, True), (CAP_Z, rings[-1], WOOD_L, False)):
	center = bm.verts.new((0, 0, z))
	for i in range(SEGMENTS):
		verts = (ring[i], ring[(i + 1) % SEGMENTS], center)
		face = bm.faces.new(tuple(reversed(verts)) if flip else verts)
		paint(face, color, i, layer)
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
mesh = bpy.data.meshes.new("Bat")
bm.to_mesh(mesh)
bm.free()
bat = bpy.data.objects.new("Bat", mesh)
bpy.context.scene.collection.objects.link(bat)
for poly in mesh.polygons:
	poly.use_smooth = False

# Bake the face colours to Bat.png.
material = bpy.data.materials.new("Bat")
nodes = material.node_tree.nodes
links = material.node_tree.links
nodes.clear()
output = nodes.new("ShaderNodeOutputMaterial")
emission = nodes.new("ShaderNodeEmission")
colors = nodes.new("ShaderNodeVertexColor")
colors.layer_name = "Col"
links.new(colors.outputs["Color"], emission.inputs["Color"])
links.new(emission.outputs["Emission"], output.inputs["Surface"])
image = bpy.data.images.new("Bat", TEXTURE_SIZE, TEXTURE_SIZE)
image_node = nodes.new("ShaderNodeTexImage")
image_node.image = image
nodes.active = image_node
mesh.materials.append(material)

bpy.context.view_layer.objects.active = bat
bat.select_set(True)
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
image.filepath_raw = os.path.join(OUT, "Bat.png")
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
	filepath=os.path.join(OUT, "Bat.fbx"),
	use_selection=True,
	axis_forward="-Z",
	axis_up="Y",
	path_mode="COPY",
	embed_textures=True,
)
coords = [v.co for v in mesh.vertices]
mins = tuple(round(min(v[i] for v in coords), 3) for i in range(3))
maxs = tuple(round(max(v[i] for v in coords), 3) for i in range(3))
print("BAT faces", len(mesh.polygons), "bounds", mins, maxs, flush=True)

# Previews: the bat lies diagonally for the 3/4 view and flat for the side view, on a neutral grey.
scene.render.engine = "BLENDER_EEVEE"
scene.render.image_settings.file_format = "PNG"
scene.world = bpy.data.worlds.new("PreviewWorld")
scene.world.color = (0.32, 0.32, 0.34)
scene.view_settings.view_transform = "Standard"
scene.view_settings.look = "Medium High Contrast"
scene.render.resolution_x = 1024
scene.render.resolution_y = 768
bpy.ops.object.light_add(type="AREA", location=(-4, -6, 8))
bpy.context.object.data.energy = 900
bpy.context.object.data.size = 6
bpy.ops.object.light_add(type="AREA", location=(5, 3, 5))
bpy.context.object.data.energy = 350
bpy.context.object.data.size = 6
bpy.ops.object.camera_add()
camera = bpy.context.object
scene.camera = camera
camera.data.type = "ORTHO"


def aim(where, target):
	camera.location = where
	camera.rotation_euler = (Vector(target) - Vector(where)).to_track_quat("-Z", "Y").to_euler()


middle = (CAP_Z + BOTTOM_Z) / 2
bat.rotation_euler = (0, math.radians(-55), math.radians(20))
bpy.context.view_layer.update()
center = bat.matrix_world @ Vector((0, 0, middle))
aim(center + Vector((2.5, -6, 3.5)), center)
camera.data.ortho_scale = 3.6
scene.render.filepath = os.path.join(OUT, "Bat_preview.png")
bpy.ops.render.render(write_still=True)

bat.rotation_euler = (0, math.radians(-90), 0)
bpy.context.view_layer.update()
center = bat.matrix_world @ Vector((0, 0, middle))
aim(center + Vector((0, -8, 0)), center)
camera.data.ortho_scale = 3.5
scene.render.filepath = os.path.join(OUT, "Bat_side.png")
bpy.ops.render.render(write_still=True)
print("Bat done", flush=True)
