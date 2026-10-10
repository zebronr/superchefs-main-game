# Builds the Halloween station set: the live stations' shapes (thick bevelled worktops over darker bases,
# slanted-lid bin, tray table, slatted crate, framed sink) at low poly, recoloured for Halloween.
# Run headless from the repo root:
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup --python art/halloween/props.py
# Writes one FBX and PNG per piece, plus lineup and individual preview renders, to art/halloween/out/.
# Units are studs: Blender Z becomes Roblox Y, -Y is the front, and every origin is at the bottom centre.

import math
import os

import bpy
import bmesh
from mathutils import Vector, Matrix


OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out")
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
VALIDATE_ONLY = os.environ.get("HALLOWEEN_VALIDATE_ONLY") == "1"

def rgb(value):
    return tuple(int(value[i:i + 2], 16) / 255 for i in (1, 3, 5)) + (1,)

LAV = rgb("#A48BCF")       # worktops: light so food reads on top
LAV_D = rgb("#7A5FA6")     # worktop bevels
PLUM = rgb("#3B2436")      # cabinets
PLUM_L = rgb("#4E3048")    # cabinet panels
PLUM_D = rgb("#2A1927")
PUMPKIN = rgb("#F2731A")
PUMPKIN_D = rgb("#C9520F")
PUMPKIN_DD = rgb("#8E3A0B")
STEM = rgb("#3F5A1E")
SLIME = rgb("#79E04F")
SLIME_D = rgb("#43A12E")
IRON = rgb("#1E1B22")
STONE = rgb("#776E8A")
STONE_L = rgb("#9086A3")
STONE_D = rgb("#575069")
WATER = rgb("#4FB86A")
WOOD = rgb("#8A5A3B")
WOOD_D = rgb("#61402C")
BONE = rgb("#E6D9B9")


def paint(faces, layer, top, side, edge=None, bottom=None):
    """Colours by facing: flat tops, chamfers (slanted) and sides each get their own flat colour."""
    for f in faces:
        n = f.normal
        if n.z > 0.95:
            color = top
        elif n.z < -0.95:
            color = bottom or side
        elif abs(n.z) > 0.2 and edge is not None:
            color = edge
        else:
            color = side
        for loop in f.loops:
            loop[layer] = color


def block(bm, layer, lo, hi, top, side, edge=None, bevel=0.0, bottom=None):
    """Axis box from corner lo to corner hi, optionally with every edge chamfered once."""
    before = set(bm.faces)
    result = bmesh.ops.create_cube(bm, size=1)
    verts = result["verts"]
    size = Vector(hi) - Vector(lo)
    centre = (Vector(hi) + Vector(lo)) / 2
    for v in verts:
        v.co = Vector((v.co.x * size.x, v.co.y * size.y, v.co.z * size.z)) + centre
    if bevel > 0:
        edges = list({e for v in verts for e in v.link_edges})
        bmesh.ops.bevel(bm, geom=verts + edges, offset=bevel, segments=1, affect="EDGES", profile=0.5)
    new = [f for f in bm.faces if f not in before]
    bmesh.ops.recalc_face_normals(bm, faces=new)
    for f in new:
        f.normal_update()
    paint(new, layer, top, side, edge or side, bottom)
    return new


def prism(bm, layer, profile, x0, x1, top, side, edge=None):
    """Extrudes a YZ profile (counter-clockwise seen from +X) between x0 and x1."""
    before = set(bm.faces)
    a = [bm.verts.new((x0, y, z)) for y, z in profile]
    b = [bm.verts.new((x1, y, z)) for y, z in profile]
    bm.faces.new(list(reversed(a)))
    bm.faces.new(b)
    for i in range(len(profile)):
        j = (i + 1) % len(profile)
        bm.faces.new((a[i], a[j], b[j], b[i]))
    new = [f for f in bm.faces if f not in before]
    bmesh.ops.recalc_face_normals(bm, faces=new)
    for f in new:
        f.normal_update()
    paint(new, layer, top, side, edge or side)


def lathe(bm, layer, centre, profile, segments=10, cap_top=None, cap_bottom=None, axis="Z"):
    """(radius, height, colour) rings around an axis through centre."""
    before = set(bm.faces)
    rings = []
    for radius, h, _ in profile:
        ring = []
        for i in range(segments):
            a = 2 * math.pi * (i + 0.5) / segments
            u, w = radius * math.cos(a), radius * math.sin(a)
            if axis == "Z":
                p = (centre[0] + u, centre[1] + w, centre[2] + h)
            else:  # axis "Y": discs facing the front
                p = (centre[0] + u, centre[1] + h, centre[2] + w)
            ring.append(bm.verts.new(p))
        rings.append(ring)
    for k in range(len(rings) - 1):
        for i in range(segments):
            j = (i + 1) % segments
            f = bm.faces.new((rings[k][i], rings[k][j], rings[k + 1][j], rings[k + 1][i]))
            for loop in f.loops:
                loop[layer] = profile[k][2]
    for cap, ring, flip in ((cap_bottom, rings[0], True), (cap_top, rings[-1], False)):
        if cap:
            f = bm.faces.new(list(reversed(ring)) if flip else ring)
            for loop in f.loops:
                loop[layer] = cap
    new = [f for f in bm.faces if f not in before]
    bmesh.ops.recalc_face_normals(bm, faces=new)


def pumpkin_knob(bm, layer, x, y, z, r=0.13):
    """Tiny pumpkin pull on a front face (axis toward -Y)."""
    lathe(bm, layer, (x, y, z), [(r * 0.6, 0, PUMPKIN_D), (r, -r * 0.3, PUMPKIN), (r, -r * 0.7, PUMPKIN),
                                 (r * 0.55, -r * 0.95, PUMPKIN_D)], 8, cap_top=PUMPKIN_D, axis="Y")
    block(bm, layer, (x - 0.025, y - r * 1.1, z - 0.025), (x + 0.025, y - r * 0.9, z + 0.025), STEM, STEM)


def worktop_cabinet(bm, c, depth, width=4.0, top_h=0.42, overhang=0.12, panel=True):
    """The live counters: a darker base under a thick worktop slab that overhangs a little."""
    hx, hy = width / 2, depth / 2
    base_top = 2.0 - top_h
    block(bm, c, (-hx + overhang, -hy + overhang, 0), (hx - overhang, hy - overhang, base_top + 0.02),
          PLUM, PLUM, bevel=0.05)
    block(bm, c, (-hx, -hy, base_top), (hx, hy, 2.0), LAV, LAV_D, LAV_D, bevel=0.1, bottom=PLUM_D)
    if panel:
        # Inset front panel with a pumpkin pull, like a door on the plain cabinet.
        y = -hy + overhang
        block(bm, c, (-hx + 0.45, y - 0.01, 0.22), (hx - 0.45, y + 0.02, base_top - 0.2),
              PLUM_L, PLUM_L, PLUM_D, bevel=0.008)
        pumpkin_knob(bm, c, 0, y - 0.01, base_top - 0.45, 0.09)
    # Dark toe kick so the cabinet sits on the floor.
    block(bm, c, (-hx + overhang + 0.06, -hy + overhang - 0.01, 0), (hx - overhang - 0.06, -hy + overhang + 0.2, 0.14),
          PLUM_D, PLUM_D)


def countertop(bm, c):
    worktop_cabinet(bm, c, 4.39)


def chopping_board(bm, c):
    worktop_cabinet(bm, c, 4.0)


def separate_board(bm, c):
    block(bm, c, (-1.695, -1.315, 0), (1.695, 1.315, 0.15), WOOD, WOOD_D, WOOD_D, bevel=0.04)
    # Hanging hole at one end, plus a slime-green stain so it reads as Halloween.
    lathe(bm, c, (1.35, 0, 0.15), [(0.16, 0.0, IRON), (0.16, 0.002, IRON)], 8, cap_top=IRON)
    lathe(bm, c, (-0.7, 0.45, 0.15), [(0.32, 0.0, SLIME_D), (0.32, 0.002, SLIME_D)], 8, cap_top=SLIME_D)


def plate_table(bm, c):
    # Live shape: base box, overhanging dark rim, lighter top plate with a round raised-rim tray.
    block(bm, c, (-1.85, -2.05, 0), (1.85, 2.05, 1.55), PLUM_L, PLUM_L, bevel=0.05)
    block(bm, c, (-2.0, -2.195, 1.5), (2.0, 2.195, 1.8), PLUM_D, PLUM_D, PLUM_D, bevel=0.07)
    block(bm, c, (-1.85, -2.05, 1.78), (1.85, 2.05, 1.95), LAV, LAV_D, LAV_D, bevel=0.05)
    lathe(bm, c, (0, 0, 0), [(1.62, 1.95, LAV_D), (1.55, 2.0, LAV), (1.32, 2.0, LAV_D), (1.25, 1.96, LAV_D)],
          12, cap_top=LAV_D)
    # Two pumpkin pulls on the front.
    for x in (-0.9, 0.9):
        pumpkin_knob(bm, c, x, -2.05, 1.05, 0.12)


def food_container(bm, c):
    # Slatted crate: dark inside, three planks per side, corner posts and a top rim.
    block(bm, c, (-1.85, -1.85, 0), (1.85, 1.85, 1.62), PUMPKIN_DD, PUMPKIN_DD)
    for i, z in enumerate((0.08, 0.62, 1.16)):
        color = PUMPKIN if i % 2 == 0 else PUMPKIN_D
        block(bm, c, (-1.92, -2.0, z), (1.92, -1.84, z + 0.46), color, color, PUMPKIN_D, bevel=0.04)
        block(bm, c, (-1.92, 1.84, z), (1.92, 2.0, z + 0.46), color, color, PUMPKIN_D, bevel=0.04)
        block(bm, c, (-2.0, -1.92, z), (-1.84, 1.92, z + 0.46), color, color, PUMPKIN_D, bevel=0.04)
        block(bm, c, (1.84, -1.92, z), (2.0, 1.92, z + 0.46), color, color, PUMPKIN_D, bevel=0.04)
    for x in (-1.75, 1.75):
        for y in (-1.75, 1.75):
            block(bm, c, (x - 0.26, y - 0.26, 0), (x + 0.26, y + 0.26, 1.77), WOOD, WOOD_D, WOOD_D, bevel=0.05)
    # Jack-o'-lantern eyes and grin on the middle front plank.
    y = -2.005
    for x in (-0.7, 0.7):
        f = bm.faces.new([bm.verts.new(p) for p in ((x - 0.24, y, 1.52), (x + 0.24, y, 1.52), (x, y, 1.25))])
        for loop in f.loops:
            loop[c] = IRON
    f = bm.faces.new([bm.verts.new(p) for p in ((-0.8, y, 0.98), (0.8, y, 0.98), (0.55, y, 0.7), (0.2, y, 0.8),
                                               (0, y, 0.68), (-0.2, y, 0.8), (-0.55, y, 0.7))])
    for loop in f.loops:
        loop[c] = IRON


def food_lid(bm, c):
    block(bm, c, (-2.01, -2.01, 0), (2.01, 2.01, 0.13), WOOD_D, WOOD_D, bevel=0.03)
    for i in range(5):
        x0 = -1.85 + i * 0.75
        color = PUMPKIN if i % 2 == 0 else PUMPKIN_D
        block(bm, c, (x0, -1.85, 0.1), (x0 + 0.7, 1.85, 0.2), color, color, PUMPKIN_D, bevel=0.025)
    # Diagonal brace like the live crate lid, flat on top of the planks.
    before = set(bm.faces)
    prism(bm, c, [(-0.17, 0.18), (0.17, 0.18), (0.17, 0.25), (-0.17, 0.25)], -1.9, 1.9, WOOD, WOOD_D)
    brace = [f for f in bm.faces if f not in before]
    turn = Matrix.Rotation(math.radians(45), 4, "Z")
    for v in {v for f in brace for v in f.verts}:
        v.co = turn @ v.co
        v.co.x *= 0.94
        v.co.y *= 0.94


def trash(bm, c):
    # Live shape: a box bin with a slanted lid; here a slime-green lid with drips over a dark bin.
    block(bm, c, (-1.8, -1.85, 0), (1.8, 1.85, 2.95), PLUM, PLUM, PLUM_D, bevel=0.08)
    for x in (-1.81, 1.81):
        block(bm, c, (x - 0.02, -1.4, 0.5), (x + 0.02, 1.4, 2.45), PLUM_L, PLUM_L)
    prism(bm, c, [(-2.0, 2.92), (1.95, 2.92), (1.95, 3.58), (-2.0, 3.12)], -1.95, 1.95, SLIME, SLIME_D, SLIME)
    block(bm, c, (-2.0, -2.0, 2.86), (2.0, 2.0, 2.98), SLIME_D, SLIME_D, bevel=0.03)
    # Handle on the front of the lid and slime dripping down the bin.
    block(bm, c, (-0.55, -2.0, 3.0), (0.55, -1.86, 3.1), IRON, IRON)
    for x, length in ((-1.2, 0.55), (-0.35, 0.3), (0.9, 0.75)):
        block(bm, c, (x - 0.12, -1.9, 2.92 - length), (x + 0.12, -1.83, 2.92), SLIME, SLIME_D, SLIME, bevel=0.03)
        lathe(bm, c, (x, -1.865, 2.92 - length), [(0.13, 0.0, SLIME), (0.13, 0.002, SLIME)], 8, cap_top=SLIME)


def sink(bm, c):
    # Drain board x=-3.6..-0.2 at 1.9; the basin (x=0.2..3.8) stays open, water at 2.06, rim 2.3.
    block(bm, c, (-4.0, -2.0, 0), (0.0, 2.0, 1.86), STONE, STONE, STONE_D, bevel=0.06)
    block(bm, c, (-3.6, -1.75, 1.8), (-0.2, 1.75, 1.9), STONE_L, STONE_L)
    for i in range(7):
        x = -3.3 + i * 0.45
        block(bm, c, (x - 0.07, -1.5, 1.9), (x + 0.07, 1.5, 1.93), STONE_D, STONE_D)
    for x0, x1 in ((-4.0, -3.6), (-0.2, 0.2)):
        block(bm, c, (x0, -2.0, 1.8), (x1, 2.0, 2.3), STONE_L, STONE, STONE_D, bevel=0.05)
    for y0, y1 in ((-2.0, -1.75), (1.75, 2.0)):
        block(bm, c, (-3.6, y0, 1.8), (-0.2, y1, 2.0), STONE_L, STONE, STONE_D, bevel=0.04)
    block(bm, c, (0.0, -2.0, 0), (4.0, 2.0, 0.35), STONE, STONE, bevel=0.05)
    for x0, x1 in ((0.0, 0.2), (3.8, 4.0)):
        block(bm, c, (x0, -2.0, 0.3), (x1, 2.0, 2.3), STONE_L, STONE, STONE_D, bevel=0.05)
    for y0, y1 in ((-2.0, -1.8), (1.8, 2.0)):
        block(bm, c, (0.2, y0, 0.3), (3.8, y1, 2.3), STONE_L, STONE, STONE_D, bevel=0.05)
    block(bm, c, (0.2, -1.8, 2.04), (3.8, 1.8, 2.06), WATER, WATER)
    # Iron tap rising behind the basin to the full height.
    block(bm, c, (1.9, 1.55, 2.3), (2.2, 1.85, 4.6), IRON, IRON, bevel=0.04)
    block(bm, c, (1.9, 0.75, 4.35), (2.2, 1.85, 4.65), IRON, IRON, bevel=0.04)
    block(bm, c, (1.92, 0.75, 4.0), (2.18, 1.0, 4.4), IRON, IRON, bevel=0.03)
    lathe(bm, c, (2.05, 1.7, 4.65), [(0.16, 0.0, PUMPKIN_D), (0.16, 0.2, PUMPKIN), (0.08, 0.28, STEM)], 8,
          cap_top=STEM)


def serving_counter(bm, c):
    # Long counter with a worktop, corner posts and a header beam framing the window.
    block(bm, c, (-4.06, -2.29, 0), (4.06, 2.29, 2.38), PLUM, PLUM, bevel=0.05)
    for i in range(6):
        x0 = -3.9 + i * 1.3
        block(bm, c, (x0 + 0.06, -2.33, 0.25), (x0 + 1.24, -2.27, 2.15), PLUM_L, PLUM_L, PLUM_D, bevel=0.03)
    block(bm, c, (-4.2, -2.42, 2.36), (4.2, 2.42, 2.78), LAV, LAV_D, LAV_D, bevel=0.1, bottom=PLUM_D)
    for x in (-3.85, 3.85):
        for y in (-2.05, 2.05):
            block(bm, c, (x - 0.22, y - 0.22, 2.78), (x + 0.22, y + 0.22, 6.2), WOOD, WOOD_D, bevel=0.05)
    for y in (-2.05, 2.05):
        block(bm, c, (-4.2, y - 0.3, 6.1), (4.2, y + 0.3, 6.6), PUMPKIN, PUMPKIN_D, PUMPKIN_DD, bevel=0.07)
    # A row of small jack-o'-lantern faces on the front beam.
    for x in (-2.4, 0, 2.4):
        for dx in (-0.18, 0.18):
            f = bm.faces.new([bm.verts.new(p) for p in ((x + dx - 0.09, -2.351, 6.45), (x + dx + 0.09, -2.351, 6.45),
                                                       (x + dx, -2.351, 6.32))])
            for loop in f.loops:
                loop[c] = IRON
        f = bm.faces.new([bm.verts.new(p) for p in ((x - 0.25, -2.351, 6.27), (x + 0.25, -2.351, 6.27),
                                                   (x, -2.351, 6.17))])
        for loop in f.loops:
            loop[c] = IRON


PIECES = [
    ("Countertop", (4, 4.39, 2), countertop),
    ("PlateTable", (4, 4.39, 2), plate_table),
    ("ChoppingBoard", (4, 4, 2), chopping_board),
    ("ChoppingBoardBoard", (3.39, 2.63, 0.15), separate_board),
    ("FoodContainer", (4.02, 4.02, 1.77), food_container),
    ("FoodContainerLid", (4.02, 4.02, 0.25), food_lid),
    ("Trash", (4, 4, 3.58), trash),
    ("Sink", (8, 4, 4.93), sink),
    ("ServingCounter", (8.4, 4.84, 6.6), serving_counter),
]


def build(name, expected, builder):
    bm = bmesh.new()
    layer = bm.loops.layers.float_color.new("Col")
    builder(bm, layer)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    for polygon in mesh.polygons:
        polygon.use_smooth = False
    painted = mesh.color_attributes.get("Col")
    assert painted and all(item.color[3] > 0.99 for item in painted.data), name
    coords = [v.co for v in mesh.vertices]
    mins = tuple(min(v[i] for v in coords) for i in range(3))
    maxs = tuple(max(v[i] for v in coords) for i in range(3))
    size = tuple(maxs[i] - mins[i] for i in range(3))
    valid = (all(abs(size[i] - expected[i]) < 0.02 for i in range(3))
             and all(abs(mins[i] + expected[i] / 2) < 0.02 for i in (0, 1))
             and abs(mins[2]) < 0.02 and 20 <= len(mesh.polygons) <= 700)
    if not VALIDATE_ONLY:
        assert valid, (name, len(mesh.polygons), mins, maxs, expected)
    print("PIECE", name, "faces", len(mesh.polygons), "bounds", mins, maxs, flush=True)
    return obj


def bake_and_export(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    mat = bpy.data.materials.new(obj.name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
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
    obj.data.materials.append(mat)
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
    principled.inputs["Roughness"].default_value = 1
    result = nodes.new("ShaderNodeOutputMaterial")
    links.new(textured.outputs["Color"], principled.inputs["Base Color"])
    links.new(principled.outputs["BSDF"], result.inputs["Surface"])
    bpy.ops.export_scene.fbx(filepath=os.path.join(OUT, obj.name + ".fbx"),
                             use_selection=True, axis_forward="-Z", axis_up="Y",
                             path_mode="COPY", embed_textures=True)


def render_previews(objects):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.world = bpy.data.worlds.new("PreviewWorld")
    scene.world.color = (0.22, 0.22, 0.22)
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "Medium High Contrast"
    scene.view_settings.exposure = 0
    scene.view_settings.gamma = 1
    floor_mat = bpy.data.materials.new("PreviewFloor")
    floor_mat.diffuse_color = (0.14, 0.14, 0.15, 1)
    floor_mat.use_nodes = True
    floor_mat.node_tree.nodes.get("Principled BSDF").inputs["Base Color"].default_value = (0.14, 0.14, 0.15, 1)
    bpy.ops.mesh.primitive_cube_add(size=1)
    floor = bpy.context.object
    floor.name = "PreviewFloor"
    floor.dimensions = (58, 23, 0.2)
    floor.location = (0, 0, -0.11)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    floor.data.materials.append(floor_mat)
    bpy.ops.object.light_add(type="AREA", location=(-9, -12, 18))
    bpy.context.object.data.energy = 4000
    bpy.context.object.data.shape = "DISK"
    bpy.context.object.data.size = 14
    bpy.ops.object.light_add(type="AREA", location=(12, 5, 14))
    bpy.context.object.data.energy = 2200
    bpy.context.object.data.size = 12
    bpy.ops.object.camera_add()
    camera = bpy.context.object
    scene.camera = camera
    def aim(where, target):
        camera.location = where
        camera.rotation_euler = (Vector(target) - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    # Tall silhouettes form the rear row; lower pieces sit in front without overlap.
    positions = {
        "Sink": (-18, 5.5, 0), "ServingCounter": (-5, 5.5, 0),
        "Countertop": (5, 5.5, 0), "PlateTable": (13, 5.5, 0),
        "ChoppingBoard": (21, 5.5, 0), "ChoppingBoardBoard": (21, 5.5, 2.0),
        "FoodContainer": (-18, -5.5, 0), "FoodContainerLid": (-18, -5.5, 1.77),
                "Trash": (15, -5.5, 0),
    }
    for obj in objects:
        obj.location = positions[obj.name]
    aim((8, -50, 40), (0, 0, 1.0))
    camera.data.ortho_scale = 57
    scene.render.resolution_x = 2000
    scene.render.resolution_y = 900
    scene.render.resolution_percentage = 100
    scene.render.filepath = os.path.join(OUT, "preview.png")
    bpy.ops.render.render(write_still=True)
    for obj in objects:
        # Isolate the requested mesh in the close-up; floor remains visible.
        for other in objects:
            other.hide_render = other != obj
        obj.location = (0, 0, 0)
        width = max(obj.dimensions.x, obj.dimensions.y, obj.dimensions.z)
        aim((width * 1.6, -width * 2.1, width * 1.65), (0, 0, obj.dimensions.z * 0.48))
        camera.data.ortho_scale = width * 1.85
        scene.render.resolution_x = 600
        scene.render.resolution_y = 600
        scene.render.filepath = os.path.join(OUT, "preview_" + obj.name + ".png")
        bpy.ops.render.render(write_still=True)
        obj.location = positions[obj.name]
    for obj in objects:
        obj.hide_render = False


objects = []
for name, expected, builder in PIECES:
    obj = build(name, expected, builder)
    if not VALIDATE_ONLY:
        bake_and_export(obj)
    objects.append(obj)
if not VALIDATE_ONLY:
    render_previews(objects)
print("Halloween props done", flush=True)
