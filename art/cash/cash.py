# Builds one faceted pile of coins and banknotes for customer payments.
# Run from the repo root:
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup --python art/cash/cash.py
# Writes Cash.fbx and Cash.png in art/cash/out/.
# Like the frost meshes, FBX exports with -Z forward and Y up. Blender Z
# becomes Roblox Y on import. The origin is at the pile's bottom centre.

import math
import os
import random

import bpy
import bmesh
from mathutils import Euler, Vector


OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out")
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
RNG = random.Random(2906)

GOLD = ((0.80, 0.45, 0.08, 1), (0.94, 0.61, 0.13, 1))
GOLD_LIGHT = (1.0, 0.78, 0.27, 1)
GOLD_FACE = (0.98, 0.68, 0.18, 1)
GREEN = ((0.20, 0.51, 0.26, 1), (0.25, 0.60, 0.31, 1))
GREEN_DARK = (0.10, 0.36, 0.18, 1)
GREEN_FACE = (0.30, 0.66, 0.35, 1)
CREAM = (0.91, 0.83, 0.58, 1)
CREAM_EDGE = (0.76, 0.67, 0.43, 1)


def make_face(bm, verts, layer, shade):
    face = bm.faces.new(verts)
    for loop in face.loops:
        loop[layer] = shade
    return face


def vertex(bm, point, centre, rotation):
    return bm.verts.new(centre + rotation @ Vector(point))


def coin(bm, layer, centre, radius, thickness, rotation, phase):
    # Four 12-sided rings give each coin a dark edge and a bright bevel.
    turn = Euler(rotation, "XYZ").to_matrix()
    levels = ((-thickness / 2, radius * 0.91),
              (-thickness * 0.32, radius),
              (thickness * 0.32, radius),
              (thickness / 2, radius * 0.91))
    rings = []
    for z, r in levels:
        rings.append([vertex(bm,
                             (r * math.cos(2 * math.pi * i / 12 + phase),
                              r * math.sin(2 * math.pi * i / 12 + phase), z),
                             centre, turn) for i in range(12)])
    for band in range(3):
        for i in range(12):
            j = (i + 1) % 12
            shade = GOLD_LIGHT if band == 2 else GOLD[(i + band) % 2]
            make_face(bm, (rings[band][i], rings[band][j],
                           rings[band + 1][j], rings[band + 1][i]),
                      layer, shade)
    make_face(bm, tuple(reversed(rings[0])), layer, GOLD[0])
    make_face(bm, rings[-1], layer, GOLD_FACE)


def rectangle(bm, centre, half_x, half_y, z, angle):
    c, s = math.cos(angle), math.sin(angle)
    return [bm.verts.new((centre[0] + x * c - y * s,
                          centre[1] + x * s + y * c, z))
            for x, y in ((-half_x, -half_y), (half_x, -half_y),
                         (half_x, half_y), (-half_x, half_y))]


def slab(bm, layer, centre, width, depth, z, height, angle,
         edge, top, border=False):
    bottom = rectangle(bm, centre, width / 2, depth / 2, z, angle)
    upper = rectangle(bm, centre, width / 2, depth / 2, z + height, angle)
    for i in range(4):
        j = (i + 1) % 4
        make_face(bm, (bottom[i], bottom[j], upper[j], upper[i]),
                  layer, edge if i % 2 == 0 else top)
    make_face(bm, tuple(reversed(bottom)), layer, edge)
    if border:
        inset = rectangle(bm, centre, width / 2 - 0.07,
                          depth / 2 - 0.065, z + height, angle)
        for i in range(4):
            j = (i + 1) % 4
            make_face(bm, (upper[i], upper[j], inset[j], inset[i]),
                      layer, GREEN_DARK)
        make_face(bm, inset, layer, GREEN_FACE)
    else:
        make_face(bm, upper, layer, top)


def build_cash():
    bm = bmesh.new()
    layer = bm.loops.layers.float_color.new("Col")

    # Six hand-placed coins rise to about 0.75 units; the bottom touches Z=0.
    for i in range(6):
        x = -0.42 + (RNG.random() - 0.5) * 0.065
        y = 0.11 + (RNG.random() - 0.5) * 0.065
        tilt = (0, 0, 0) if i == 0 else (
            RNG.uniform(-0.06, 0.06), RNG.uniform(-0.06, 0.06), 0)
        coin(bm, layer, Vector((x, y, 0.061 + i * 0.123)),
             0.28, 0.122, tilt, RNG.uniform(-0.15, 0.15))

    # A seventh coin rests on its edge against the front of the stack.
    coin(bm, layer, Vector((-0.41, -0.24, 0.28)), 0.28, 0.115,
         (math.radians(66), math.radians(-5), math.radians(7)), 0.16)

    # The staggered notes stay thin, with a simple dark inset on the top note.
    for i in range(4):
        centre = (0.34 + RNG.uniform(-0.018, 0.018),
                  0.08 + RNG.uniform(-0.018, 0.018))
        slab(bm, layer, centre, 0.83, 0.65, i * 0.041, 0.037,
             RNG.uniform(-0.055, 0.055), GREEN[i % 2], GREEN[(i + 1) % 2],
             border=i == 3)

    # The paper band wraps across the short middle of the note stack.
    slab(bm, layer, (0.34, 0.08), 0.165, 0.67, 0.16, 0.018,
         0, CREAM_EDGE, CREAM)
    for y in (-0.252, 0.412):
        slab(bm, layer, (0.34, y), 0.165, 0.018, 0, 0.177,
             0, CREAM_EDGE, CREAM)

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new("Cash")
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new("Cash", mesh)
    bpy.context.scene.collection.objects.link(obj)
    for polygon in mesh.polygons:
        polygon.use_smooth = False
    return obj


def bake_and_export(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj

    material = bpy.data.materials.new(obj.name)
    material.use_nodes = True
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    nodes.clear()
    output = nodes.new("ShaderNodeOutputMaterial")
    emission = nodes.new("ShaderNodeEmission")
    colors = nodes.new("ShaderNodeVertexColor")
    colors.layer_name = "Col"
    links.new(colors.outputs["Color"], emission.inputs["Color"])
    links.new(emission.outputs["Emission"], output.inputs["Surface"])
    image = bpy.data.images.new(obj.name, 512, 512)
    target = nodes.new("ShaderNodeTexImage")
    target.image = image
    nodes.active = target
    obj.data.materials.append(material)

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
    image.filepath_raw = os.path.join(OUT, obj.name + ".png")
    image.file_format = "PNG"
    image.save()

    nodes.clear()
    textured = nodes.new("ShaderNodeTexImage")
    textured.image = image
    principled = nodes.new("ShaderNodeBsdfPrincipled")
    result = nodes.new("ShaderNodeOutputMaterial")
    links.new(textured.outputs["Color"], principled.inputs["Base Color"])
    links.new(principled.outputs["BSDF"], result.inputs["Surface"])
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(OUT, obj.name + ".fbx"),
        use_selection=True,
        axis_forward="-Z",
        axis_up="Y",
        path_mode="COPY",
        embed_textures=True,
    )
    print(obj.name, "done:", len(obj.data.polygons), "faces")


bake_and_export(build_cash())
