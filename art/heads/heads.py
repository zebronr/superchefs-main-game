# Concept sculpts for the character heads (Gecko, Penguin, Alien): cartoon, mid-to-low poly, big readable shapes.
# Run headless from the repo root:
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup --python art/heads/heads.py
# Writes art/heads/out/Lineup.png, <Name>.png and <Name>Side.png (renders) and <Name>.fbx (one joined object, flat
# material colours, no outline shell). Units: each head is about 2 wide. Front is -Y, up is +Z.

import math
import os

import bpy
from mathutils import Vector

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out")
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)

SEG, RINGS = 24, 14
OUTLINE = 0.025  # inverted-hull outline thickness, render only
_materials = {}


def srgb(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def mat(rgb, gloss=0.45):
    key = (tuple(round(c, 3) for c in rgb), gloss)
    if key not in _materials:
        m = bpy.data.materials.new("C_%02x%02x%02x" % tuple(int(c * 255) for c in key[0]))
        m.use_nodes = True
        bsdf = m.node_tree.nodes["Principled BSDF"]
        lin = tuple(srgb(c) for c in key[0])
        bsdf.inputs["Base Color"].default_value = (*lin, 1)
        bsdf.inputs["Roughness"].default_value = gloss
        m.diffuse_color = (*lin, 1)
        _materials[key] = m
    return _materials[key]


INK = bpy.data.materials.new("Ink")
INK.use_nodes = True
INK.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.02, 0.015, 0.012, 1)
INK.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 1
INK.use_backface_culling = True


def finish(o, rgb, coll, gloss=0.45, outline=True):
    o.data.materials.append(mat(rgb, gloss))
    for p in o.data.polygons:
        p.use_smooth = True
    for c in list(o.users_collection):
        c.objects.unlink(o)
    coll.objects.link(o)
    if outline:
        o.data.materials.append(INK)
        s = o.modifiers.new("Outline", "SOLIDIFY")
        s.thickness = OUTLINE
        s.offset = 1
        s.use_flip_normals = True
        s.material_offset = 1
        s.show_viewport = True
    return o


def sphere(name, loc=(0, 0, 0), seg=SEG, rings=RINGS):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=rings, radius=1, location=loc)
    o = bpy.context.object
    o.name = name
    return o


def blob(coll, name, loc, shape, rgb, gloss=0.45, seg=SEG, rings=RINGS):
    """A unit sphere whose vertices are moved by shape(Vector) -> Vector, then placed at loc."""
    o = sphere(name, (0, 0, 0), seg, rings)
    for v in o.data.vertices:
        v.co = shape(v.co.copy())
    o.location = loc
    return finish(o, rgb, coll, gloss)


def ell(sx, sy, sz):
    return lambda p: Vector((p.x * sx, p.y * sy, p.z * sz))


def on(center, scale, d, out=0.0):
    """Point on the ellipsoid (center, scale) in direction d, pushed out by `out`, plus the surface normal there."""
    d = Vector(d).normalized()
    sx, sy, sz = scale
    t = 1 / math.sqrt((d.x / sx) ** 2 + (d.y / sy) ** 2 + (d.z / sz) ** 2)
    p = d * t
    n = Vector((p.x / sx ** 2, p.y / sy ** 2, p.z / sz ** 2)).normalized()
    return Vector(center) + p + n * out, n


def decal(coll, name, pos, normal, size, rgb, roll=0.0, gloss=0.45, outline=True, seg=16, rings=8):
    """A flattened ball lying on a surface: size = (width, height, thickness), thickness along the normal."""
    o = sphere(name, (0, 0, 0), seg, rings)
    o.scale = size
    q = Vector(normal).to_track_quat("Z", "Y")
    o.rotation_mode = "QUATERNION"
    from mathutils import Quaternion
    o.rotation_quaternion = q @ Quaternion((0, 0, 1), math.radians(roll))
    o.location = pos
    return finish(o, rgb, coll, gloss, outline)


def ball(coll, name, loc, r, rgb, gloss=0.45, outline=True):
    o = sphere(name, loc, 14, 8)
    o.scale = (r, r, r)
    return finish(o, rgb, coll, gloss, outline)


def tube(coll, name, pts, r, rgb, outline=False):
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = r
    cu.bevel_resolution = 2
    cu.use_fill_caps = True
    sp = cu.splines.new("NURBS")
    sp.points.add(len(pts) - 1)
    for i, p in enumerate(pts):
        sp.points[i].co = (*p, 1)
    sp.use_endpoint_u = True
    sp.order_u = min(3, len(pts))
    o = bpy.data.objects.new(name, cu)
    bpy.context.scene.collection.objects.link(o)
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.convert(target="MESH")
    return finish(bpy.context.object, rgb, coll, 0.6, outline)


def new_coll(name):
    c = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(c)
    return c


# ------------------------------------------------------------------ Gecko
# Leopard gecko: wide flat head with a rounded snout, eyes bulging up on top, amber eyes with slit pupils, orange
# spots, a long grin from cheek to cheek, a tongue blep and a pale chin.
def gecko(x):
    c = new_coll("Gecko")
    Y, SPOT, CHIN = (1.0, 0.8, 0.22), (0.93, 0.45, 0.12), (1.0, 0.93, 0.66)
    HS = (1.2, 1.05, 0.78)

    def head(p):
        q = Vector((p.x * HS[0], p.y * HS[1], p.z * HS[2]))
        if q.y < 0:  # snout: narrows toward the front and drops a little
            k = -q.y
            q.x *= 1 - 0.18 * k
            q.z -= 0.12 * k * k
            q.y *= 1.08
        if q.z < 0:
            q.z *= 0.8
        return q

    blob(c, "Head", (x, 0, 0), head, Y)
    # chin: a pale band under the jaw
    for sx in (-1, 1):
        ec = Vector((x + sx * 0.55, -0.32, 0.5))
        blob(c, "EyeBump", ec, ell(0.42, 0.4, 0.4), Y)
        eye_pos, n = on(ec, (0.42, 0.4, 0.4), (sx * 0.35, -1, 0.35), -0.06)
        decal(c, "Eye", eye_pos, n, (0.34, 0.34, 0.14), (1.0, 0.62, 0.08), gloss=0.2)
        p2, _ = on(ec, (0.42, 0.4, 0.4), (sx * 0.35, -1, 0.35), 0.06)
        decal(c, "Pupil", p2, n, (0.06, 0.26, 0.03), (0.05, 0.04, 0.04), outline=False, gloss=0.2)
        ball(c, "Shine", p2 + Vector((-sx * 0.1, -0.03, 0.12)), 0.065, (1, 1, 1), outline=False)
        cheek, n = on((x, 0, 0), (1.2, 1.05, 0.78), (sx * 0.85, -0.6, -0.15), 0.0)
        decal(c, "Blush", cheek, n, (0.17, 0.11, 0.04), (1.0, 0.52, 0.48), outline=False)
    for i, d in enumerate([(0, 0.4, 1), (-0.5, 0.6, 0.8), (0.55, 0.65, 0.75), (-0.9, 0.3, 0.3), (0.95, 0.3, 0.25),
                           (0.15, 0.9, 0.5), (-0.35, 1, 0.1), (0.5, 1, -0.05), (-1, 0.6, -0.2), (1, 0.7, -0.25),
                           (0.0, 0.1, 1)]):
        p, n = on((x, 0, 0), (1.2, 1.05, 0.78), d, -0.01)
        s = 0.11 + (i % 3) * 0.035
        decal(c, "Spot", p, n, (s, s * 0.85, 0.035), SPOT, roll=i * 37, outline=False)
    # grin along the snout's front, cheek to cheek, and the nostrils
    mouth = []
    for t in [-1, -0.7, -0.35, 0, 0.35, 0.7, 1]:
        p, _ = on((x, 0, -0.05), (1.06, 1.1, 0.7), (t * 1.3, -1, -0.32 + 0.32 * abs(t) ** 1.6), 0.015)
        mouth.append(tuple(p))
    tube(c, "Mouth", mouth, 0.03, (0.42, 0.2, 0.06))
    for sx in (-1, 1):
        p, n = on((x, 0, -0.05), (1.06, 1.1, 0.7), (sx * 0.14, -1, 0.05), 0.0)
        decal(c, "Nostril", p, n, (0.04, 0.03, 0.02), (0.4, 0.2, 0.06), outline=False)
    tp, n = on((x, 0, -0.05), (1.06, 1.1, 0.7), (0.22, -1, -0.32), 0.02)
    blob(c, "Tongue", tp + Vector((0, 0.02, -0.07)), ell(0.1, 0.05, 0.09), (1.0, 0.42, 0.56))
    return c


# ------------------------------------------------------------------ Penguin
# Round navy head, one big heart-shaped white face, big glossy eyes, a rounded orange beak, a three-feather tuft.
def penguin(x):
    c = new_coll("Penguin")
    NAVY, W, BEAK = (0.12, 0.16, 0.27), (0.98, 0.98, 1.0), (1.0, 0.62, 0.12)
    blob(c, "Head", (x, 0, 0), ell(1.05, 1.0, 0.98), NAVY)

    def face(p):  # a heart: two lobes up top, a point at the bottom, pressed onto the head's front
        q = Vector((p.x * 0.78, p.y * 0.42, p.z * 0.7))
        if q.z > 0:
            q.z *= 1 + 0.35 * math.cos(math.pi * q.x / 0.78) ** 2 - 0.3 * (1 - abs(q.x) / 0.78) ** 6
        else:
            q.x *= 1 + q.z * 0.55
        return q

    blob(c, "Face", (x, -0.68, 0.0), face, W)
    for sx in (-1, 1):
        p, n = on((x, -0.68, 0), (0.78, 0.42, 0.7), (sx * 0.42, -1, 0.3), -0.02)
        decal(c, "Eye", p, n, (0.12, 0.17, 0.07), (0.05, 0.05, 0.09), gloss=0.1, outline=False)
        ball(c, "Shine", p + Vector((-sx * 0.03, -0.05, 0.07)), 0.045, (1, 1, 1), outline=False)
        p, n = on((x, -0.68, 0), (0.78, 0.42, 0.7), (sx * 0.75, -1, -0.25), -0.01)
        decal(c, "Blush", p, n, (0.14, 0.09, 0.03), (1.0, 0.58, 0.64), outline=False)

    def beak(p):
        q = Vector((p.x * 0.24, p.y * 0.3, p.z * 0.15))
        if q.y < 0:
            q.x *= 1 + q.y * 1.6
            q.z *= 1 + q.y * 1.2
        return q

    blob(c, "Beak", (x, -1.12, -0.08), beak, BEAK, seg=16, rings=10)
    for i, (sx, tilt, h) in enumerate(((-0.13, -28, 0.3), (0.0, 0, 0.42), (0.13, 28, 0.3))):
        def tuft(p, h=h):
            k = (p.z + 1) / 2  # 0 at the base, 1 at the tip
            return Vector((p.x * 0.09 * (1 - k * 0.9), p.y * 0.07 * (1 - k * 0.9), p.z * h / 2))
        o = blob(c, "Tuft", (x + sx, 0.05, 1.0 + h / 2 - 0.08), tuft, NAVY, seg=10, rings=6)
        o.rotation_euler = (math.radians(-18), math.radians(tilt), 0)
    return c


# ------------------------------------------------------------------ Alien
# Mint lightbulb head, huge glossy almond eyes tilted up and out with two shines each, antennae with the UFO's yellow
# bulbs, a tiny smile.
def alien(x):
    c = new_coll("Alien")
    MINT, DARK, BULB = (0.5, 0.9, 0.68), (0.07, 0.09, 0.13), (1.0, 0.82, 0.25)

    def bulb(p):
        q = Vector((p.x * 1.08, p.y * 0.98, p.z * 1.05))
        if q.z < 0.2:  # narrow into a small chin
            k = (0.2 - q.z) / 1.25
            q.x *= 1 - 0.55 * k
            q.y *= 1 - 0.4 * k
        return q

    blob(c, "Head", (x, 0, 0.1), bulb, MINT)
    for sx in (-1, 1):
        p, n = on((x, 0, 0.1), (1.0, 0.95, 1.0), (sx * 0.42, -1, -0.08), -0.05)
        decal(c, "Eye", p, n, (0.36, 0.2, 0.09), DARK, roll=sx * 30, gloss=0.08)
        ball(c, "Shine", p + n * 0.06 + Vector((-sx * 0.06, 0, 0.08)), 0.075, (1, 1, 1), outline=False)
        ball(c, "ShineSmall", p + n * 0.06 + Vector((sx * 0.1, 0, -0.07)), 0.035, (1, 1, 1), outline=False)
        top, _ = on((x, 0, 0.1), (1.08, 0.98, 1.05), (sx * 0.35, 0.05, 1), -0.05)
        tip = Vector((x + sx * 0.72, -0.05, 1.75))
        mid = (top + tip) / 2 + Vector((sx * -0.12, 0, 0.05))
        tube(c, "Antenna", [tuple(top), tuple(mid), tuple(tip)], 0.045, MINT, outline=True)
        ball(c, "AntennaBulb", tip, 0.14, BULB, gloss=0.2)
    mouth = []
    for t in (-1, 0, 1):
        p, _ = on((x, 0, 0.1), (0.62, 0.72, 1.0), (t * 0.16, -1, -0.62 - 0.05 * (1 - abs(t))), 0.01)
        mouth.append(tuple(p))
    tube(c, "Mouth", mouth, 0.022, (0.16, 0.38, 0.27))
    return c


XS = (-3.1, 0.0, 3.1)
heads = [gecko(XS[0]), penguin(XS[1]), alien(XS[2])]

# ------------------------------------------------------------------ render: EEVEE, soft key + fill, inverted-hull outlines
sc = bpy.context.scene
sc.render.engine = "BLENDER_EEVEE"
sc.view_settings.view_transform = "Standard"
sc.render.film_transparent = False
world = bpy.data.worlds.new("World")
sc.world = world
world.use_nodes = True
# the camera sees a warm backdrop, the heads are lit by neutral light so their colours stay true
wn = world.node_tree.nodes
bg = wn["Background"]
bg.inputs["Color"].default_value = (srgb(0.85), srgb(0.76), srgb(0.6), 1)
amb = wn.new("ShaderNodeBackground")
amb.inputs["Color"].default_value = (0.8, 0.8, 0.82, 1)
amb.inputs["Strength"].default_value = 0.7
lp = wn.new("ShaderNodeLightPath")
mix = wn.new("ShaderNodeMixShader")
links = world.node_tree.links
links.new(lp.outputs["Is Camera Ray"], mix.inputs[0])
links.new(amb.outputs[0], mix.inputs[1])
links.new(bg.outputs[0], mix.inputs[2])
links.new(mix.outputs[0], wn["World Output"].inputs["Surface"])


def light(name, kind, energy, rot, color=(1, 1, 1)):
    ld = bpy.data.lights.new(name, kind)
    ld.energy = energy
    ld.color = color
    lo = bpy.data.objects.new(name, ld)
    lo.rotation_euler = [math.radians(a) for a in rot]
    sc.collection.objects.link(lo)


light("Key", "SUN", 2.6, (50, 0, -35), (1, 0.98, 0.94))
light("Rim", "SUN", 1.6, (-60, 0, 160), (0.85, 0.9, 1))

cam_data = bpy.data.cameras.new("Cam")
cam = bpy.data.objects.new("Cam", cam_data)
sc.collection.objects.link(cam)
sc.camera = cam


def shoot(path, target, dist, res, lens=50, yaw=-25, pitch=12):
    sc.render.resolution_x, sc.render.resolution_y = res
    cam_data.lens = lens
    t = Vector(target)
    yr, pr = math.radians(yaw), math.radians(pitch)
    cam.location = t + Vector((math.sin(yr) * math.cos(pr), -math.cos(yr) * math.cos(pr), math.sin(pr))) * dist
    cam.rotation_euler = (t - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)


for h, x in zip(heads, XS):
    for o in heads:
        o.hide_render = o is not h
    shoot(os.path.join(OUT, h.name + ".png"), (x, 0, 0.2), 6.8, (800, 800))
    shoot(os.path.join(OUT, h.name + "Side.png"), (x, 0, 0.2), 6.8, (800, 800), yaw=-75, pitch=8)
for o in heads:
    o.hide_render = False
shoot(os.path.join(OUT, "Lineup.png"), (0, 0, 0.3), 14, (1800, 800), yaw=-10, pitch=10)

# ------------------------------------------------------------------ export: one joined object per head, no outline shell
# Every part gets one flat colour, so the texture is a palette: one swatch per colour, and each part's UVs all sit at
# the centre of its swatch. One small shared PNG (HeadsPalette.png), embedded in each FBX so Roblox imports it too.
CELL, GRID = 16, 8
colours = []
rgb_of = {m.name: k[0] for k, m in _materials.items()}
for k in _materials:
    if k[0] not in colours:
        colours.append(k[0])
assert len(colours) <= GRID * GRID
img = bpy.data.images.new("HeadsPalette", CELL * GRID, CELL * GRID, alpha=False)
px = [1.0] * (CELL * GRID * CELL * GRID * 4)
for idx, rgb in enumerate(colours):
    cx, cy = idx % GRID, idx // GRID
    for yy in range(cy * CELL, cy * CELL + CELL):
        for xx in range(cx * CELL, cx * CELL + CELL):
            o4 = (yy * CELL * GRID + xx) * 4
            px[o4:o4 + 3] = rgb
img.pixels = px
img.filepath_raw = os.path.join(OUT, "HeadsPalette.png")
img.file_format = "PNG"
img.save()

pal = bpy.data.materials.new("HeadsPalette")
pal.use_nodes = True
tex = pal.node_tree.nodes.new("ShaderNodeTexImage")
tex.image = img
tex.interpolation = "Closest"
pal.node_tree.links.new(tex.outputs["Color"], pal.node_tree.nodes["Principled BSDF"].inputs["Base Color"])


def swatch_uv(rgb):
    idx = colours.index(rgb)
    return ((idx % GRID + 0.5) / GRID, (idx // GRID + 0.5) / GRID)


for h in heads:
    bpy.ops.object.select_all(action="DESELECT")
    objs = list(h.objects)
    for o in objs:
        for m in list(o.modifiers):
            o.modifiers.remove(m)
        uv = swatch_uv(rgb_of[o.data.materials[0].name])
        while len(o.data.uv_layers):
            o.data.uv_layers.remove(o.data.uv_layers[0])
        layer = o.data.uv_layers.new(name="UVMap")
        for loop in layer.data:
            loop.uv = uv
        o.data.materials.clear()
        o.data.materials.append(pal)
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    joined = bpy.context.object
    joined.name = h.name + "Head"
    bpy.ops.object.origin_set(type="ORIGIN_GEOMETRY", center="BOUNDS")
    bpy.ops.export_scene.fbx(filepath=os.path.join(OUT, h.name + ".fbx"), use_selection=True, apply_unit_scale=True,
                             bake_space_transform=True, object_types={"MESH"}, path_mode="COPY", embed_textures=True)
    print(h.name, "faces:", len(joined.data.polygons))
