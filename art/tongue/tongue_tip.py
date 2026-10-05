# Builds the Gecko tongue tip: a soft, slightly notched sticky pad with a baked texture.
# Run headless from the repo root:
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup --python art/tongue/tongue_tip.py
# Writes art/tongue/out/TongueTip.fbx, TongueTip.obj and TongueTip.png.

import math
import os

import bpy
import bmesh

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out")
TEXTURE_SIZE = 512

os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)

# Mesh: a squashed sphere, front (+Y in Blender, which the export maps to -Z, Roblox's forward) widened into a pad with a small notch.
mesh = bpy.data.meshes.new("TongueTip")
obj = bpy.data.objects.new("TongueTip", mesh)
bpy.context.scene.collection.objects.link(obj)

bm = bmesh.new()
bm.loops.layers.uv.new("UVMap")
bmesh.ops.create_uvsphere(bm, u_segments=24, v_segments=14, radius=0.5, calc_uvs=True)
for vert in bm.verts:
	x, y, z = vert.co
	front = max(0.0, y / 0.5)  # 0 at the back, 1 at the very front
	# Widen the front into a pad and flatten it top to bottom.
	x *= 1.0 + 0.35 * front
	z *= 0.62 - 0.12 * front
	# The back narrows where the beam body joins.
	back = max(0.0, -y / 0.5)
	x *= 1.0 - 0.3 * back
	z *= 1.0 - 0.2 * back
	# A shallow notch in the middle of the front edge.
	if front > 0.6:
		notch = math.exp(-(x / 0.12) ** 2) * (front - 0.6) / 0.4
		y -= 0.14 * notch
	vert.co = (x, y, z)
bm.to_mesh(mesh)
bm.free()
for poly in mesh.polygons:
	poly.use_smooth = True

# Material: pink flesh, darker blotches, a lighter wet top, a darker underside.
material = bpy.data.materials.new("TongueTip")
nodes = material.node_tree.nodes
links = material.node_tree.links
nodes.clear()

output = nodes.new("ShaderNodeOutputMaterial")
emission = nodes.new("ShaderNodeEmission")
coords = nodes.new("ShaderNodeTexCoord")

noise = nodes.new("ShaderNodeTexNoise")
noise.inputs["Scale"].default_value = 9.0
noise.inputs["Detail"].default_value = 6.0
noise.inputs["Roughness"].default_value = 0.6
links.new(coords.outputs["Object"], noise.inputs["Vector"])

blotch = nodes.new("ShaderNodeValToRGB")
blotch.color_ramp.elements[0].position = 0.35
blotch.color_ramp.elements[0].color = (0.62, 0.16, 0.25, 1)
blotch.color_ramp.elements[1].position = 0.65
blotch.color_ramp.elements[1].color = (0.93, 0.42, 0.52, 1)
links.new(noise.outputs["Fac"], blotch.inputs["Fac"])

# Bumps: small round papillae from a Voronoi distance.
voronoi = nodes.new("ShaderNodeTexVoronoi")
voronoi.feature = "DISTANCE_TO_EDGE"
voronoi.inputs["Scale"].default_value = 22.0
links.new(coords.outputs["Object"], voronoi.inputs["Vector"])
bumps = nodes.new("ShaderNodeValToRGB")
bumps.color_ramp.elements[0].position = 0.0
bumps.color_ramp.elements[0].color = (0.86, 0.86, 0.86, 1)
bumps.color_ramp.elements[1].position = 0.12
bumps.color_ramp.elements[1].color = (1, 1, 1, 1)
links.new(voronoi.outputs["Distance"], bumps.inputs["Fac"])

bumped = nodes.new("ShaderNodeMix")
bumped.data_type = "RGBA"
bumped.blend_type = "MULTIPLY"
bumped.inputs["Factor"].default_value = 1.0
links.new(blotch.outputs["Color"], bumped.inputs[6])
links.new(bumps.outputs["Color"], bumped.inputs[7])

# Height shading: lighter on top (wet sheen), darker underneath.
separate = nodes.new("ShaderNodeSeparateXYZ")
links.new(coords.outputs["Object"], separate.inputs["Vector"])
height = nodes.new("ShaderNodeMapRange")
height.inputs["From Min"].default_value = -0.3
height.inputs["From Max"].default_value = 0.3
links.new(separate.outputs["Z"], height.inputs["Value"])
shade = nodes.new("ShaderNodeValToRGB")
shade.color_ramp.elements[0].position = 0.0
shade.color_ramp.elements[0].color = (0.55, 0.45, 0.5, 1)
shade.color_ramp.elements[1].position = 0.85
shade.color_ramp.elements[1].color = (1.15, 1.1, 1.12, 1)
links.new(height.outputs["Result"], shade.inputs["Fac"])

final = nodes.new("ShaderNodeMix")
final.data_type = "RGBA"
final.blend_type = "MULTIPLY"
final.inputs["Factor"].default_value = 1.0
links.new(bumped.outputs[2], final.inputs[6])
links.new(shade.outputs["Color"], final.inputs[7])

links.new(final.outputs[2], emission.inputs["Color"])
links.new(emission.outputs["Emission"], output.inputs["Surface"])

image = bpy.data.images.new("TongueTip", TEXTURE_SIZE, TEXTURE_SIZE)
image_node = nodes.new("ShaderNodeTexImage")
image_node.image = image
nodes.active = image_node
obj.data.materials.append(material)

# Bake the emission colour into the UVs.
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 16
scene.render.bake.margin = 8
bpy.context.view_layer.objects.active = obj
obj.select_set(True)
bpy.ops.object.bake(type="EMIT")

image.filepath_raw = os.path.join(OUT, "TongueTip.png")
image.file_format = "PNG"
image.save()

# Swap the procedural material for the baked image so the exports carry it.
nodes.clear()
principled = nodes.new("ShaderNodeBsdfPrincipled")
textured = nodes.new("ShaderNodeTexImage")
textured.image = image
result = nodes.new("ShaderNodeOutputMaterial")
links.new(textured.outputs["Color"], principled.inputs["Base Color"])
links.new(principled.outputs["BSDF"], result.inputs["Surface"])

bpy.ops.export_scene.fbx(
	filepath=os.path.join(OUT, "TongueTip.fbx"),
	use_selection=True,
	axis_forward="-Z",
	axis_up="Y",
	path_mode="COPY",
	embed_textures=True,
)
bpy.ops.wm.obj_export(
	filepath=os.path.join(OUT, "TongueTip.obj"),
	export_selected_objects=True,
	forward_axis="NEGATIVE_Z",
	up_axis="Y",
)
print("TongueTip done:", len(mesh.polygons), "faces")
