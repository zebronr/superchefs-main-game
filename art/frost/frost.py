# Builds three faceted meshes for the Penguin's Deep Freeze superskill.
# Run from the repo root:
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup --python art/frost/frost.py
# Writes IceChunk, FrostCap, IceSpike and IceShell FBX meshes and matching PNG textures
# in art/frost/out/.
# Like the UFO, FBX exports with -Z forward and Y up. Roblox imports the mesh in
# that orientation; resize the imported MeshPart in Studio to fit the pot or shatter.
# IceChunk is 1 stud long. FrostCap is about 2 studs wide, with its origin at
# the centre of the slab's bottom face. Blender Z becomes Roblox Y on import.

import math
import os
import random

import bpy
import bmesh

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out")
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
RNG = random.Random(2906)
SHADES = [(0.62, 0.83, 0.96, 1), (0.72, 0.90, 1.0, 1),
          (0.82, 0.95, 1.0, 1)]


def color(face, layer, shade):
    for loop in face.loops:
        loop[layer] = SHADES[shade % len(SHADES)]


def make_face(bm, verts, layer, shade, tip=False):
    face = bm.faces.new(verts)
    if tip:
        for loop in face.loops:
            loop[layer] = (0.94, 0.985, 1.0, 1)
    else:
        color(face, layer, shade)
    return face


def ring(bm, count, radius, z, angle=0, waviness=0, center=(0, 0)):
    vertices = []
    for i in range(count):
        theta = 2 * math.pi * i / count + angle
        r = radius * (1 + waviness * math.sin(3 * theta + 0.7))
        vertices.append(bm.verts.new((center[0] + r * math.cos(theta),
                                      center[1] + r * math.sin(theta), z)))
    return vertices


def connect(bm, lower, upper, layer, offset=0):
    count = len(lower)
    for i in range(count):
        j = (i + 1) % count
        make_face(bm, (lower[i], lower[j], upper[j], upper[i]),
                  layer, i + offset)


def fan(bm, rim, apex, layer, offset=0, reverse=False):
    for i in range(len(rim)):
        j = (i + 1) % len(rim)
        verts = (rim[j], rim[i], apex) if reverse else (rim[i], rim[j], apex)
        make_face(bm, verts, layer, i + offset)


def finish_mesh(name, bm):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    for polygon in mesh.polygons:
        polygon.use_smooth = False
    return obj


def build_chunk():
    bm = bmesh.new()
    layer = bm.loops.layers.float_color.new("Col")
    count = 6
    lower = ring(bm, count, 0.18, -0.26, angle=0.10, waviness=0.14)
    upper = ring(bm, count, 0.15, 0.25, angle=0.15, waviness=0.18,
                 center=(0.025, -0.025))
    bottom = bm.verts.new((-0.035, 0.015, -0.50))
    top = bm.verts.new((0.055, -0.035, 0.50))
    fan(bm, lower, bottom, layer, reverse=True)
    connect(bm, lower, upper, layer, offset=1)
    fan(bm, upper, top, layer, offset=2)
    return finish_mesh("IceChunk", bm)


def build_cap():
    bm = bmesh.new()
    layer = bm.loops.layers.float_color.new("Col")
    count = 12
    # Three rings form a broad, irregular octagon-like slab. Its bottom is Z=0.
    bottom = ring(bm, count, 0.87, 0.0, angle=math.pi / 12, waviness=0.07)
    waist = ring(bm, count, 1.02, 0.12, angle=math.pi / 12, waviness=0.07)
    top = ring(bm, count, 0.88, 0.30, angle=math.pi / 12, waviness=0.07)
    connect(bm, bottom, waist, layer)
    connect(bm, waist, top, layer, offset=1)
    bottom_center = bm.verts.new((0, 0, 0))
    top_center = bm.verts.new((0, 0, 0.30))
    fan(bm, bottom, bottom_center, layer, reverse=True)
    fan(bm, top, top_center, layer, offset=2)

    # Seven blunt pentagonal icicles, each rooted beneath the overhang.
    for i in range(7):
        angle = 2 * math.pi * (i + 0.18) / 7
        x, y = 0.81 * math.cos(angle), 0.81 * math.sin(angle)
        length = 0.34 + 0.09 * (i % 3)
        root = ring(bm, 5, 0.115, 0.025, angle=angle,
                    waviness=0.12, center=(x, y))
        shoulder = ring(bm, 5, 0.075, -length * 0.55,
                        angle=angle + 0.12, center=(x, y))
        tip = bm.verts.new((x + 0.04 * math.cos(angle),
                            y + 0.04 * math.sin(angle), -length))
        connect(bm, root, shoulder, layer, offset=i)
        fan(bm, shoulder, tip, layer, offset=i + 1, reverse=True)
        root_center = bm.verts.new((x, y, 0.025))
        fan(bm, root, root_center, layer, offset=i + 2)

    # Four small six-sided crystals rise from the top in a loose cluster.
    for i, (x, y, height) in enumerate(((0.0, 0.05, 0.39),
                                        (0.42, -0.12, 0.29),
                                        (-0.38, -0.22, 0.33),
                                        (-0.08, 0.43, 0.25))):
        base = ring(bm, 6, 0.13, 0.30, angle=i * 0.32, center=(x, y))
        neck = ring(bm, 6, 0.10, 0.30 + height * 0.55,
                    angle=i * 0.32 + 0.07, center=(x, y))
        tip = bm.verts.new((x + 0.035, y - 0.025, 0.30 + height))
        connect(bm, base, neck, layer, offset=i)
        fan(bm, neck, tip, layer, offset=i + 1)
        base_center = bm.verts.new((x, y, 0.30))
        fan(bm, base, base_center, layer, offset=i + 2, reverse=True)
    return finish_mesh("FrostCap", bm)


def build_spike():
    bm = bmesh.new()
    layer = bm.loops.layers.float_color.new("Col")

    # Four pentagonal and hexagonal shafts share a ground-level cluster. Each
    # shaft leans outward; a short collar, long prism, and white tip stay flat.
    spikes = ((0.02, 0.01, 2.00, 0.22, 6, 0.18, 0.16),
              (-0.23, 0.09, 1.42, 0.18, 5, 0.38, 2.70),
              (0.19, 0.19, 1.20, 0.17, 6, 0.48, 1.10),
              (0.17, -0.20, 1.00, 0.16, 5, 0.60, -0.85))
    for index, (x, y, height, width, sides, lean, direction) in enumerate(spikes):
        dx = math.tan(lean) * height * math.cos(direction)
        dy = math.tan(lean) * height * math.sin(direction)
        theta = index * 0.23
        base = ring(bm, sides, width, 0, angle=theta, center=(x, y))
        collar = ring(bm, sides, width * 1.13, height * 0.16,
                      angle=theta, center=(x + dx * 0.16, y + dy * 0.16))
        neck = ring(bm, sides, width * 0.75, height * 0.79,
                    angle=theta, center=(x + dx * 0.79, y + dy * 0.79))
        connect(bm, base, collar, layer, offset=index)
        connect(bm, collar, neck, layer, offset=index + 1)
        tip = bm.verts.new((x + dx, y + dy, height))
        for side in range(sides):
            make_face(bm, (neck[side], neck[(side + 1) % sides], tip),
                      layer, side, tip=True)
        bottom = bm.verts.new((x, y, 0))
        fan(bm, base, bottom, layer, reverse=True)

    # Three tiny shards fill the ground silhouette without raising the origin.
    for index, (x, y, height) in enumerate(((-0.42, -0.15, 0.32),
                                            (0.39, 0.04, 0.28),
                                            (-0.07, 0.39, 0.24))):
        base = ring(bm, 5, 0.09, 0, angle=index * 0.4, center=(x, y))
        tip = bm.verts.new((x * 1.12, y * 1.12, height))
        fan(bm, base, tip, layer, offset=index)
        bottom = bm.verts.new((x, y, 0))
        fan(bm, base, bottom, layer, reverse=True)
    return finish_mesh("IceSpike", bm)


def build_shell():
    bm = bmesh.new()
    layer = bm.loops.layers.float_color.new("Col")

    # A chunky faceted ice block for frozen customers: 2 x 2 footprint, 5 tall, origin at the
    # bottom centre. The code stretches it over each customer, so only the proportions matter.
    count = 6
    rings = [ring(bm, count, 1.0, 0.0, angle=0.20, waviness=0.08),
             ring(bm, count, 1.12, 0.6, angle=0.45, waviness=0.10),
             ring(bm, count, 0.95, 2.2, angle=0.15, waviness=0.14),
             ring(bm, count, 1.06, 3.5, angle=0.55, waviness=0.10),
             ring(bm, count, 0.72, 4.3, angle=0.30, waviness=0.16)]
    for k in range(len(rings) - 1):
        connect(bm, rings[k], rings[k + 1], layer, offset=k)
    fan(bm, rings[0], bm.verts.new((0, 0, 0)), layer, reverse=True)
    # Slanted, off-centre peak so the top reads as broken ice, not a lid.
    fan(bm, rings[-1], bm.verts.new((0.15, -0.1, 4.5)), layer, offset=2)

    # Big crystals breaking out of the top and the shoulders.
    for i, (x, y, z, radius, height, lean) in enumerate(((0.3, 0.2, 4.05, 0.32, 1.2, 0.3),
                                                         (-0.4, -0.05, 3.95, 0.28, 0.95, -0.5),
                                                         (0.05, -0.45, 4.0, 0.22, 0.7, 0.15),
                                                         (0.8, -0.3, 3.0, 0.26, 0.8, 1.1),
                                                         (-0.75, 0.4, 2.5, 0.24, 0.7, -1.1),
                                                         (0.55, 0.7, 1.4, 0.2, 0.55, 0.8))):
        base = ring(bm, 5, radius, z, angle=i * 0.5, center=(x, y))
        tip = bm.verts.new((x + lean * 0.4, y + lean * 0.1, z + height))
        for side in range(5):
            make_face(bm, (base[side], base[(side + 1) % 5], tip), layer, side, tip=side % 2 == 0)
        fan(bm, base, bm.verts.new((x, y, z)), layer, offset=i, reverse=True)

    # Small chunks piled around the feet so it sits frozen to the floor.
    for i in range(6):
        angle = 2 * math.pi * (i + 0.3) / 6 + RNG.uniform(-0.2, 0.2)
        x, y = 0.95 * math.cos(angle), 0.95 * math.sin(angle)
        base = ring(bm, 5, 0.2, 0.0, angle=angle, center=(x, y))
        tip = bm.verts.new((x * 1.03, y * 1.03, 0.35 + 0.15 * (i % 3)))
        fan(bm, base, tip, layer, offset=i)
        fan(bm, base, bm.verts.new((x, y, 0.0)), layer, offset=i + 1, reverse=True)
    return finish_mesh("IceShell", bm)


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


for mesh_object in (build_chunk(), build_cap(), build_spike(), build_shell()):
    bake_and_export(mesh_object)
