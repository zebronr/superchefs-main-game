# Food icon renderer: one textured model (OBJ or FBX, e.g. exported from Studio) to transparent order icons in several
# styles. The "flat" style matches the existing icons (art/bread/bread.py): orthographic, 38 degrees down, 25 to the
# side, texture shown flat with tops a little lighter and undersides darker.
# Run headless from the repo root:
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup --python art/icons/food_icon.py -- <model> <Name> [style ...]
# then the post pass (sticker border, comparison sheet), with normal Python + Pillow:
#   python art/icons/food_icon_post.py <Name>
# Writes art/icons/out/<Name>_<style>.png (style "blend" saves the setup as <Name>.blend instead). Renders: flat, soft, toonbase (default: all); the post pass makes outline and sticker from flat, toon from toonbase.

import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
MODEL = os.path.abspath(ARGS[0])
NAME = ARGS[1]
STYLES = ARGS[2:] or ["flat", "soft", "toonbase"]  # "sticker" is made from "flat" by the post pass
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out")
SIZE = 512
PITCH, YAW = 38, -25  # same view as the bread icons
# per icon, opt-in: tint the model's recesses (faces sunk below its convex hull, e.g. the cheese holes) so they read at
# small sizes. Value: (RGB multiplier, minimum depth as a share of the model's size).
CAVITY = {"Cheese": ((0.62, 0.34, 0.12), 0.004)}
os.makedirs(OUT, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene

# ------------------------------------------------------------------ import, centre, sit on the ground
if MODEL.lower().endswith(".obj"):
    bpy.ops.wm.obj_import(filepath=MODEL)
else:
    bpy.ops.import_scene.fbx(filepath=MODEL)
meshes = [o for o in sc.objects if o.type == "MESH"]
bpy.ops.object.select_all(action="DESELECT")
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1:
    bpy.ops.object.join()
obj = bpy.context.view_layer.objects.active
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
bpy.ops.object.origin_set(type="ORIGIN_GEOMETRY", center="BOUNDS")
obj.location = (0, 0, 0)
bpy.context.view_layer.update()
size = max(obj.dimensions)
for p in obj.data.polygons:
    p.use_smooth = False  # faceted, like the rest of the food
if NAME in CAVITY:
    # face attribute "cavity" = 1 for faces whose centre sits deeper than the threshold inside the convex hull
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    hull = bmesh.ops.convex_hull(bm, input=bm.verts[:])
    centre = sum((v.co for v in bm.verts), Vector()) / len(bm.verts)
    planes = []
    for f in (g for g in hull["geom"] if isinstance(g, bmesh.types.BMFace)):
        f.normal_update()
        n, p0 = f.normal.copy(), f.verts[0].co.copy()
        if n.dot(centre - p0) > 0:
            n = -n
        planes.append((n, p0))
    bm.free()
    min_depth = CAVITY[NAME][1] * size
    attr = obj.data.attributes.new("cavity", "FLOAT", "FACE")
    hits = 0
    for poly in obj.data.polygons:
        c = poly.center
        depth = min(n.dot(p0 - c) for n, p0 in planes)
        attr.data[poly.index].value = 1.0 if depth > min_depth else 0.0
        hits += depth > min_depth
    print("cavity faces", hits, "of", len(obj.data.polygons))
print("model", obj.name, "dims", tuple(round(d, 3) for d in obj.dimensions), "faces", len(obj.data.polygons))

# the model's own texture (first image found in its materials)
image = None
for m in obj.data.materials:
    if m and m.use_nodes:
        for n in m.node_tree.nodes:
            if n.type == "TEX_IMAGE" and n.image:
                image = image or n.image
assert image, "model has no texture"
image.alpha_mode = "NONE"  # the OBJ's map_d makes the importer wire the texture alpha as opacity; ignore it

# ------------------------------------------------------------------ materials per style
def new_material(name):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    m.node_tree.nodes.clear()
    return m, m.node_tree.nodes, m.node_tree.links


def texture(nodes):
    t = nodes.new("ShaderNodeTexImage")
    t.image = image
    t.interpolation = "Closest"
    return t


def multiply(nodes, links, a, b):
    m = nodes.new("ShaderNodeMix")
    m.data_type = "RGBA"
    m.blend_type = "MULTIPLY"
    m.inputs[0].default_value = 1
    links.new(a, m.inputs[6])
    links.new(b, m.inputs[7])
    return m.outputs[2]


def top_light(nodes, links, low=0.8, high=1.04):
    # same trick as bread.py: brightness from the face normal's up component
    geo = nodes.new("ShaderNodeNewGeometry")
    sep = nodes.new("ShaderNodeSeparateXYZ")
    rng = nodes.new("ShaderNodeMapRange")
    rng.inputs["From Min"].default_value = -1
    rng.inputs["From Max"].default_value = 1
    rng.inputs["To Min"].default_value = low
    rng.inputs["To Max"].default_value = high
    links.new(geo.outputs["Normal"], sep.inputs[0])
    links.new(sep.outputs["Z"], rng.inputs["Value"])
    return rng.outputs["Result"]


def flat_material():
    m, nodes, links = new_material("Flat")
    col = multiply(nodes, links, texture(nodes).outputs["Color"], top_light(nodes, links))
    if NAME in CAVITY:
        attr = nodes.new("ShaderNodeAttribute")
        attr.attribute_name = "cavity"
        tint = nodes.new("ShaderNodeMix")
        tint.data_type = "RGBA"
        links.new(attr.outputs["Fac"], tint.inputs[0])
        tint.inputs[6].default_value = (1, 1, 1, 1)
        tint.inputs[7].default_value = (*CAVITY[NAME][0], 1)
        col = multiply(nodes, links, col, tint.outputs[2])
    em = nodes.new("ShaderNodeEmission")
    out = nodes.new("ShaderNodeOutputMaterial")
    links.new(col, em.inputs["Color"])
    links.new(em.outputs[0], out.inputs["Surface"])
    return m


def soft_material():
    m, nodes, links = new_material("Soft")
    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Roughness"].default_value = 0.42
    bsdf.inputs["Specular IOR Level"].default_value = 0.6
    out = nodes.new("ShaderNodeOutputMaterial")
    links.new(texture(nodes).outputs["Color"], bsdf.inputs["Base Color"])
    links.new(bsdf.outputs[0], out.inputs["Surface"])
    return m


def toon_material():
    # two light bands from a diffuse pass, times the texture, plus a hard specular glint
    m, nodes, links = new_material("Toon")
    dif = nodes.new("ShaderNodeBsdfDiffuse")
    rgb = nodes.new("ShaderNodeShaderToRGB")
    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.interpolation = "CONSTANT"
    ramp.color_ramp.elements[0].position = 0.0
    ramp.color_ramp.elements[0].color = (0.66, 0.56, 0.64, 1)
    ramp.color_ramp.elements[1].position = 0.42
    ramp.color_ramp.elements[1].color = (1.0, 1.0, 1.0, 1)
    links.new(dif.outputs[0], rgb.inputs[0])
    links.new(rgb.outputs["Color"], ramp.inputs["Fac"])
    col = multiply(nodes, links, texture(nodes).outputs["Color"], ramp.outputs["Color"])
    gl = nodes.new("ShaderNodeBsdfGlossy")
    gl.inputs["Roughness"].default_value = 0.25
    grgb = nodes.new("ShaderNodeShaderToRGB")
    gramp = nodes.new("ShaderNodeValToRGB")
    gramp.color_ramp.interpolation = "CONSTANT"
    gramp.color_ramp.elements[0].color = (0, 0, 0, 1)
    gramp.color_ramp.elements[1].position = 0.55
    gramp.color_ramp.elements[1].color = (0.35, 0.35, 0.35, 1)
    links.new(gl.outputs[0], grgb.inputs[0])
    links.new(grgb.outputs["Color"], gramp.inputs["Fac"])
    add = nodes.new("ShaderNodeMix")
    add.data_type = "RGBA"
    add.blend_type = "ADD"
    add.inputs[0].default_value = 1
    links.new(col, add.inputs[6])
    links.new(gramp.outputs["Color"], add.inputs[7])
    em = nodes.new("ShaderNodeEmission")
    out = nodes.new("ShaderNodeOutputMaterial")
    links.new(add.outputs[2], em.inputs["Color"])
    links.new(em.outputs[0], out.inputs["Surface"])
    return m


MATERIALS = {"flat": flat_material(), "soft": soft_material(), "toonbase": toon_material()}
MATERIALS["outline"] = MATERIALS["flat"]  # same render, the post pass adds the outline

obj.data.materials.clear()
obj.data.materials.append(MATERIALS["flat"])
for p in obj.data.polygons:
    p.material_index = 0

# ------------------------------------------------------------------ scene
sc.render.engine = "BLENDER_EEVEE"
sc.render.film_transparent = True
sc.render.image_settings.file_format = "PNG"
sc.render.image_settings.color_mode = "RGBA"
sc.render.resolution_x = sc.render.resolution_y = SIZE
sc.view_settings.view_transform = "Standard"
sc.world = bpy.data.worlds.new("World")
sc.world.use_nodes = True
sc.world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.75, 0.78, 0.85, 1)
sc.world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.6

lights = []
for name, energy, rot, col in (("Key", 2.6, (40, 0, -40), (1, 0.97, 0.92)), ("Rim", 1.4, (-55, 0, 150), (0.9, 0.93, 1))):
    ld = bpy.data.lights.new(name, "SUN")
    ld.energy, ld.color, ld.angle = energy, col, math.radians(8)
    lo = bpy.data.objects.new(name, ld)
    lo.rotation_euler = [math.radians(a) for a in rot]
    sc.collection.objects.link(lo)
    lights.append(lo)

cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
sc.collection.objects.link(cam)
sc.camera = cam
cam.data.type = "ORTHO"
cam.data.ortho_scale = size * 1.45
p, y = math.radians(PITCH), math.radians(YAW)
cam.location = Vector((math.cos(p) * math.sin(y), -math.cos(p) * math.cos(y), math.sin(p))) * size * 10
cam.rotation_euler = (-cam.location).to_track_quat("-Z", "Y").to_euler()
cam.data.clip_end = size * 30
bpy.context.view_layer.update()
inv = cam.matrix_world.inverted()
pts = [inv @ (obj.matrix_world @ v.co) for v in obj.data.vertices]
lo_x, hi_x = min(q.x for q in pts), max(q.x for q in pts)
lo_y, hi_y = min(q.y for q in pts), max(q.y for q in pts)
cam.data.ortho_scale = max(hi_x - lo_x, hi_y - lo_y) * 1.18  # small margin, room for the post-pass borders
cam.data.shift_x = (lo_x + hi_x) / 2 / cam.data.ortho_scale
cam.data.shift_y = (lo_y + hi_y) / 2 / cam.data.ortho_scale

for style in STYLES:
    if style == "blend":
        # the whole setup as a .blend (flat material, camera, render settings) to open and tweak in Blender
        obj.data.materials[0] = MATERIALS["flat"]
        for lo in lights:
            lo.hide_render = True
        sc.render.filepath = os.path.join(OUT, f"{NAME}_flat.png")
        bpy.ops.file.pack_all()
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, f"{NAME}.blend"))
        print("wrote", os.path.join(OUT, f"{NAME}.blend"), flush=True)
        continue
    obj.data.materials[0] = MATERIALS[style]
    for lo in lights:
        lo.hide_render = style not in ("soft", "toonbase")
    sc.render.filepath = os.path.join(OUT, f"{NAME}_{style}.png")
    bpy.ops.render.render(write_still=True)
    print("wrote", sc.render.filepath, flush=True)
