# Map layout blockouts: four proposed kitchens built from simple blocks, rendered at a high camera like the game's.
# Run headless from the repo root:
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup --python art/maps/blockouts.py
# Writes art/maps/out/<Layout>.png. 1 unit = 1 counter tile.

import math
import os

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
ICONS = os.path.join(HERE, "..", "icons", "out")
os.makedirs(OUT, exist_ok=True)

COL = {
    "tile": (0.62, 0.6, 0.56), "wood": (0.35, 0.22, 0.14), "wall": (0.55, 0.36, 0.26), "counter": (0.87, 0.68, 0.5),
    "counter_side": (0.55, 0.38, 0.26), "stove": (0.2, 0.2, 0.25), "flame": (1.0, 0.45, 0.1), "crate": (0.6, 0.4, 0.25),
    "board": (0.95, 0.9, 0.8), "sink": (0.3, 0.6, 0.95), "serve": (1.0, 0.82, 0.25), "table": (0.75, 0.5, 0.3),
    "chair": (0.85, 0.35, 0.3), "water": (0.25, 0.55, 0.85), "street": (0.3, 0.3, 0.33), "line": (0.95, 0.9, 0.6),
    "truck": (0.95, 0.4, 0.35), "grass": (0.3, 0.55, 0.25), "route": (1.0, 0.25, 0.05),
}
CUSTOMERS = [(0.55, 0.75, 1.0), (1.0, 0.7, 0.8), (0.7, 0.9, 0.6), (0.9, 0.8, 0.55)]
CHEFS = [(1.0, 0.82, 0.25), (0.35, 0.75, 0.95), (0.6, 0.9, 0.4)]
_mats = {}


def mat(rgb, emit=False):
    key = (rgb, emit)
    if key not in _mats:
        m = bpy.data.materials.new(str(key))
        m.use_nodes = True
        b = m.node_tree.nodes["Principled BSDF"]
        b.inputs["Base Color"].default_value = (*rgb, 1)
        b.inputs["Roughness"].default_value = 0.8
        if emit:
            b.inputs["Emission Color"].default_value = (*rgb, 1)
            b.inputs["Emission Strength"].default_value = 0.6
        _mats[key] = m
    return _mats[key]


def box(x, y, w, d, h, rgb, z=0.0, emit=False):
    bpy.ops.mesh.primitive_cube_add(size=1, location=(x + w / 2, y + d / 2, z + h / 2))
    o = bpy.context.object
    o.scale = (w, d, h)
    o.data.materials.append(mat(rgb, emit))
    return o


def cyl(x, y, r, h, rgb, z=0.0, verts=24):
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=h, vertices=verts, location=(x, y, z + h / 2))
    o = bpy.context.object
    o.data.materials.append(mat(rgb))
    return o


def blob(x, y, rgb, r=0.32):
    """A person: a squishy capsule with a head."""
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=(x, y, r * 1.3))
    b = bpy.context.object
    b.scale = (1, 1, 1.3)
    b.data.materials.append(mat(rgb))
    bpy.ops.object.shade_smooth()
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r * 0.75, location=(x, y, r * 2.9))
    h = bpy.context.object
    h.data.materials.append(mat(rgb))
    bpy.ops.object.shade_smooth()


def counter(x, y, w=1, d=1, top=None):
    box(x + 0.03, y + 0.03, w - 0.06, d - 0.06, 0.8, COL["counter_side"])
    box(x, y, w, d, 0.12, top or COL["counter"], z=0.8)


def stove(x, y):
    counter(x, y, top=COL["stove"])
    cyl(x + 0.5, y + 0.5, 0.3, 0.06, COL["flame"], z=0.92)


def crate(x, y, icon):
    box(x + 0.05, y + 0.05, 0.9, 0.9, 0.85, COL["crate"])
    img = bpy.data.images.load(os.path.join(ICONS, icon))
    m = bpy.data.materials.new("Icon" + icon)
    m.use_nodes = True
    n = m.node_tree.nodes
    t = n.new("ShaderNodeTexImage")
    t.image = img
    b = n["Principled BSDF"]
    m.node_tree.links.new(t.outputs["Color"], b.inputs["Base Color"])
    m.node_tree.links.new(t.outputs["Alpha"], b.inputs["Alpha"])
    bpy.ops.mesh.primitive_plane_add(size=0.85, location=(x + 0.5, y + 0.5, 0.86))
    bpy.context.object.data.materials.append(m)


def board(x, y):
    counter(x, y)
    box(x + 0.15, y + 0.2, 0.7, 0.6, 0.04, COL["board"], z=0.92)


def sink(x, y):
    counter(x, y)
    box(x + 0.12, y + 0.12, 0.76, 0.76, 0.03, COL["sink"], z=0.92)


def serve(x, y, w=1, d=1):
    counter(x, y, w, d, top=COL["serve"])


def table(x, y, seated=2, seed=0):
    cyl(x, y, 0.55, 0.7, COL["table"])
    for i in range(4):
        a = i * math.pi / 2
        cx, cy = x + math.cos(a) * 0.9, y + math.sin(a) * 0.9
        cyl(cx, cy, 0.22, 0.4, COL["chair"])
        if i < seated:
            blob(cx, cy, CUSTOMERS[(i + seed) % 4], r=0.24)


def floor(x, y, w, d, rgb):
    box(x, y, w, d, 0.05, rgb, z=-0.05)


def wall(x, y, w, d, h=1.3):
    box(x, y, w, d, h, COL["wall"])


def arc(a, b, height=1.6):
    """A throw route: a glowing arc from a to b."""
    cu = bpy.data.curves.new("Arc", "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = 0.05
    sp = cu.splines.new("BEZIER")
    sp.bezier_points.add(1)
    a, b = Vector(a), Vector(b)
    mid = (a + b) / 2 + Vector((0, 0, height))
    for p, co, hl, hr in ((sp.bezier_points[0], a, a, mid), (sp.bezier_points[1], b, mid, b)):
        p.co, p.handle_left, p.handle_right = co, hl, hr
    o = bpy.data.objects.new("Arc", cu)
    bpy.context.scene.collection.objects.link(o)
    o.data.materials.append(mat(COL["route"], emit=True))
    bpy.ops.mesh.primitive_cone_add(radius1=0.18, depth=0.35, location=b + Vector((0, 0, 0.15)))
    c = bpy.context.object
    c.rotation_euler = (math.pi, 0, 0)
    c.data.materials.append(mat(COL["route"], emit=True))


def path(points):
    """A walking route on the floor: a flat glowing line."""
    for p, q in zip(points, points[1:]):
        p, q = Vector((*p, 0.02)), Vector((*q, 0.02))
        v = q - p
        bpy.ops.mesh.primitive_cube_add(size=1, location=(p + q) / 2)
        o = bpy.context.object
        o.scale = (v.length, 0.08, 0.02)
        o.rotation_euler = (0, 0, math.atan2(v.y, v.x))
        o.data.materials.append(mat(COL["route"], emit=True))


# ------------------------------------------------------------------ layouts (x right, y back)
def diner():
    floor(0, 5, 14, 5, COL["tile"])
    floor(0, -1, 14, 6, COL["wood"])
    wall(-0.3, 10, 14.6, 0.3, 1.6)
    wall(-0.3, -1, 0.3, 11)
    wall(14, -1, 0.3, 11)
    crate(0, 9, "Meat_shadow.png"); crate(1, 9, "Cheese_shadow.png")
    board(3, 9); board(4, 9)
    stove(7, 9); stove(8, 9)
    for x in (10, 11):
        counter(x, 9)
    sink(13, 9)
    serve(1, 5.6, 12, 0.9)  # the bar: the whole thing is the pass
    for i in range(6):
        x = 1.8 + i * 2
        cyl(x, 4.7, 0.25, 0.5, COL["chair"])
        if i % 3 != 2:
            blob(x, 4.7, CUSTOMERS[i % 4], r=0.24)
    for i, x in enumerate((2.5, 7, 11.5)):
        table(x, 1.6, seated=2 + i % 2, seed=i)
    blob(4, 7.6, CHEFS[0]); blob(8, 7.4, CHEFS[1])
    path([(4, 7.2), (8, 7.2)])


def hatch():
    floor(0, 5, 14, 6, COL["tile"])
    floor(0, -1, 14, 6, COL["wood"])
    wall(-0.3, 11, 14.6, 0.3, 1.6)
    wall(-0.3, -1, 0.3, 12.3)
    wall(14, -1, 0.3, 12.3)
    # the divider: solid apart from the hatch
    wall(6.8, 9, 0.4, 2, 1.8)
    wall(6.8, 5, 0.4, 2.5, 1.8)
    counter(6.5, 7.5, 1, 1.5)  # the hatch counter
    # front wall to the dining room, a door at each end
    wall(1.5, 4.8, 3.5, 0.3)
    wall(5, 4.8, 3.5, 0.3)
    wall(11.5, 4.8, 1, 0.3)
    serve(8.5, 4.7, 3, 0.6)
    for y in (6, 7, 8, 9):
        crate(0, y, ("Meat_shadow.png", "Cheese_shadow.png", "BunCheesePatty_shadow.png", "Meat_shadow.png")[y - 6])
    board(2, 10); board(3, 10); board(4, 10)
    stove(8, 10); stove(9, 10); stove(10, 10)
    sink(13, 9); sink(13, 8)
    for i, x in enumerate((2, 6.5, 11)):
        table(x, 1.5, seated=2 + i % 2, seed=i)
    blob(3.5, 8, CHEFS[0]); blob(9.5, 8, CHEFS[1])
    arc((4.6, 8.2, 1.2), (8.6, 8.2, 1.0), 1.4)
    path([(3.5, 7.5), (3.5, 5.5), (2, 4.4), (2, 3.6), (12.8, 3.6), (12.8, 5.5), (9.5, 7.5)])


def gap():
    floor(0, -1, 5.5, 11, COL["tile"])
    floor(8.5, -1, 6, 11, COL["tile"])
    floor(5.5, -1, 3, 2, COL["wood"])  # the bridge, at the far end
    box(5.5, 1, 3, 9, 0.05, COL["water"], z=-0.4)
    wall(-0.3, 10, 15, 0.3, 1.6)
    wall(-0.3, -1, 0.3, 11)
    wall(14.5, -1, 0.3, 11)
    for x in (5.2, 8.5):
        box(x, 1, 0.3, 9, 0.35, COL["counter_side"])  # low rails along the gap
    for y in (5, 6, 7, 8):
        crate(0, y, ("Meat_shadow.png", "Cheese_shadow.png", "BunCheesePatty_shadow.png", "Meat_shadow.png")[y - 5])
    board(2, 9); board(3, 9); board(4, 9)
    counter(4.2, 4); counter(4.2, 5)
    stove(9, 9); stove(10, 9); stove(11, 9)
    counter(9, 5); counter(9, 6)
    serve(13.5, 5, 1, 2)
    sink(13.5, 9)
    table(11.5, 2, seated=2); table(11.5, -0.2 + 0.2, seated=0)
    blob(3, 7, CHEFS[0]); blob(10, 7.5, CHEFS[1]); blob(2, 3, CHEFS[2])
    arc((4.7, 4.5, 1.1), (9.5, 5.5, 1.0), 2.4)
    path([(2, 2.5), (2, 0), (12, 0), (12, 1)])


def truck():
    floor(-1, 4.5, 16, 7, COL["grass"])
    floor(-1, -2, 16, 6.5, COL["tile"])
    box(-1, -4.5, 16, 2.5, 0.05, COL["street"], z=-0.04)
    for x in range(0, 15, 2):
        box(x, -3.3, 1, 0.12, 0.02, COL["line"], z=0.01)
    # the truck: walls only, no roof, so the kitchen inside shows
    wall(2, 9.5, 9, 0.3, 1.9)
    wall(2, 5, 0.3, 4.8, 1.9)
    wall(10.7, 5, 0.3, 4.8, 1.9)
    wall(2, 5, 2.5, 0.3, 1.9)
    wall(8, 5, 3, 0.3, 1.9)
    for o in bpy.context.scene.objects:
        if o.type == "MESH" and o.material_slots and o.material_slots[0].material == mat(COL["wall"]):
            o.material_slots[0].material = mat(COL["truck"])
    floor(2, 5, 9, 4.8, COL["tile"])  # inside the truck
    serve(4.5, 4.8, 3.5, 0.6)  # the service window
    crate(2.4, 8.5, "Meat_shadow.png"); crate(3.4, 8.5, "Cheese_shadow.png")
    board(4.4, 8.5)
    stove(6.4, 8.5); stove(7.4, 8.5)
    sink(9.6, 8.5)
    cyl(2.5, 3.8, 0.35, 0.25, (0.15, 0.15, 0.15)); cyl(10.5, 3.8, 0.35, 0.25, (0.15, 0.15, 0.15))
    for i, (x, y) in enumerate(((2, 1.5), (6.2, 0.6), (10.5, 1.5), (13, 3.2))):
        table(x, y, seated=1 + i % 3, seed=i)
    blob(5, 7, CHEFS[0]); blob(8, 7, CHEFS[1])
    blob(14, -3, CUSTOMERS[1])  # a dine-and-dasher on the street
    path([(13, 2.5), (14, -3)])


LAYOUTS = {"A_Diner": (diner, 7, 4.5), "B_Hatch": (hatch, 7, 5), "C_Gap": (gap, 7.2, 4.5), "D_Truck": (truck, 7, 3)}

for name, (build, cx, cy) in LAYOUTS.items():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _mats.clear()
    sc = bpy.context.scene
    build()
    sc.render.engine = "BLENDER_EEVEE"
    sc.view_settings.view_transform = "Standard"
    sc.render.resolution_x, sc.render.resolution_y = 1200, 820
    w = bpy.data.worlds.new("W")
    sc.world = w
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs["Color"].default_value = (0.75, 0.8, 0.88, 1)
    w.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.45
    ld = bpy.data.lights.new("Sun", "SUN")
    ld.energy, ld.angle = 2.2, math.radians(4)
    lo = bpy.data.objects.new("Sun", ld)
    lo.rotation_euler = (math.radians(35), math.radians(10), math.radians(-30))
    sc.collection.objects.link(lo)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.lens = 35
    target = Vector((cx, cy, 0))
    pitch = math.radians(58)
    cam.location = target + Vector((0, -math.cos(pitch), math.sin(pitch))) * 19
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = os.path.join(OUT, name + ".png")
    bpy.ops.render.render(write_still=True)
    print("wrote", sc.render.filepath, flush=True)
