# Concept body mockups for the Gecko: three proportion styles, each with the same head from heads.py.
# Run headless from the repo root:
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup --python art/heads/bodies.py
# Writes art/heads/out/Bodies.png (3/4 front) and BodiesTop.png (the game's high camera). Parts are split like R15
# (head, torso, arms, hands, legs, feet) so a chosen style can be rigged on the R15 joint layout.

import math
import os

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
src = open(os.path.join(HERE, "heads.py"), encoding="utf-8").read()
exec(src[: src.index("XS = (")])  # helpers and the gecko() head, nothing rendered

SKIN, BELLY = (1.0, 0.8, 0.22), (1.0, 0.92, 0.62)
COAT, APRON, SCARF = (0.97, 0.95, 0.9), (0.33, 0.68, 0.24), (0.96, 0.5, 0.14)
BUTTON = (0.85, 0.3, 0.12)


def limb(coll, name, a, b, r, rgb, r2=None):
    """A soft capsule from a to b (r2 makes it taper)."""
    a, b = Vector(a), Vector(b)
    half = (b - a).length / 2
    r2 = r if r2 is None else r2

    def shape(p):
        k = (p.z + 1) / 2
        w = r + (r2 - r) * k
        return Vector((p.x * w, p.y * w, p.z * (half + (r + r2) / 4)))

    o = blob(coll, name, (a + b) / 2, shape, rgb, seg=14, rings=10)
    o.rotation_mode = "QUATERNION"
    o.rotation_quaternion = (b - a).to_track_quat("Z", "Y")
    return o


def tail(coll, x, root, pts, r0, r1):
    chain = [Vector(root)] + [Vector(p) for p in pts]
    n = len(chain) - 1
    for i in range(n):
        limb(coll, "Tail", chain[i] + Vector((x, 0, 0)), chain[i + 1] + Vector((x, 0, 0)),
             r0 + (r1 - r0) * i / n, SKIN, r0 + (r1 - r0) * (i + 1) / n)


def place_head(x, base, s, tilt=0.0):
    c = gecko(x)
    e = bpy.data.objects.new("HeadPivot", None)
    bpy.context.scene.collection.objects.link(e)
    e.location = (x, 0, 0)
    bpy.context.view_layer.update()
    for o in c.objects:
        o.parent = e
        o.matrix_parent_inverse = e.matrix_world.inverted()
    e.location = Vector((x, 0, 0)) + Vector(base)
    e.scale = (s, s, s)
    e.rotation_euler = (math.radians(tilt), 0, 0)
    return c


def toque(coll, center, s, lean=0.0):
    c = Vector(center)
    band = blob(coll, "ToqueBand", c, ell(0.38 * s, 0.36 * s, 0.16 * s), COAT)
    puff = blob(coll, "ToquePuff", c + Vector((0, 0, 0.36 * s)), ell(0.5 * s, 0.46 * s, 0.34 * s), COAT)
    for o in (band, puff):
        o.rotation_euler = (math.radians(lean), 0, 0)


def neckerchief(coll, center, w):
    blob(coll, "Neckerchief", center, ell(w, w * 0.85, 0.13), SCARF)
    blob(coll, "Knot", Vector(center) + Vector((0, -w * 0.82, -0.08)), ell(0.13, 0.08, 0.16), SCARF)


# ------------------------------------------------------------------ A: Chibi (Animal Crossing)
# ~2 heads tall. Big head, little round coat body, stubby legs, mitten hands, a short fat tail.
def chibi(x):
    c = new_coll("A_Chibi")
    for sx in (-1, 1):
        blob(c, "Foot", (x + sx * 0.33, -0.12, 0.13), ell(0.27, 0.38, 0.15), SKIN)
        limb(c, "Leg", (x + sx * 0.3, 0, 0.2), (x + sx * 0.3, 0, 0.62), 0.2, SKIN)
        limb(c, "Arm", (x + sx * 0.62, -0.05, 1.55), (x + sx * 0.92, -0.2, 1.05), 0.17, COAT, 0.15)
        ball(c, "Hand", (x + sx * 0.97, -0.24, 0.92), 0.19, SKIN)
    blob(c, "Torso", (x, 0, 1.2), ell(0.7, 0.6, 0.72), COAT)
    p, n = on((x, 0, 1.2), (0.7, 0.6, 0.72), (0, -1, -0.15), -0.02)
    decal(c, "Apron", p, n, (0.5, 0.58, 0.12), APRON)
    neckerchief(c, Vector((x, 0, 1.85)), 0.5)
    tail(c, x, (0, 0.45, 0.75), [(0, 0.95, 0.45), (0.2, 1.35, 0.3), (0.45, 1.6, 0.35)], 0.22, 0.08)
    place_head(x, (0, 0, 2.45), 0.92)
    toque(c, (x, 0.22, 3.22), 1.0)
    return c


# ------------------------------------------------------------------ B: Squishy brawler (Party Animals)
# One soft pear body that the head sinks into, chunky arms and feet, full-length apron, a thick tail. Wobbles.
def squishy(x):
    c = new_coll("B_Squishy")
    for sx in (-1, 1):
        blob(c, "Foot", (x + sx * 0.45, -0.18, 0.16), ell(0.34, 0.46, 0.18), SKIN)
        limb(c, "Leg", (x + sx * 0.42, 0, 0.22), (x + sx * 0.42, 0, 0.5), 0.27, SKIN)
        limb(c, "Arm", (x + sx * 0.88, -0.05, 1.45), (x + sx * 1.18, -0.3, 0.95), 0.24, SKIN, 0.22)
        ball(c, "Hand", (x + sx * 1.22, -0.36, 0.84), 0.24, SKIN)

    def pear(p):
        q = Vector((p.x, p.y, p.z))
        w = 1.02 - 0.22 * (q.z + 1) / 2  # wider at the bottom
        return Vector((q.x * w, q.y * w * 0.85, q.z * 0.95))

    blob(c, "Torso", (x, 0, 1.15), pear, SKIN)
    p, n = on((x, 0, 1.15), (0.95, 0.8, 0.95), (0, -1, -0.05), -0.03)
    decal(c, "Belly", p, n, (0.6, 0.75, 0.08), BELLY, outline=False)
    p, n = on((x, 0, 1.15), (0.95, 0.8, 0.95), (0, -1, -0.2), 0.0)
    decal(c, "Apron", p, n, (0.62, 0.78, 0.14), APRON)
    neckerchief(c, Vector((x, -0.05, 1.98)), 0.62)
    tail(c, x, (0, 0.6, 0.6), [(0, 1.2, 0.3), (-0.3, 1.7, 0.22), (-0.6, 1.95, 0.3)], 0.3, 0.1)
    place_head(x, (0, -0.05, 2.45), 0.98)
    toque(c, (x, 0.2, 3.28), 1.08)
    return c


# ------------------------------------------------------------------ C: Lanky lizard (A Short Hike / Ratchet-ish)
# ~3 heads tall, leaning forward like a real lizard on two legs, long arms and a long tail that drags. Double-breasted
# chef jacket, small tilted toque. Most creature-like, least like Overcooked.
def lanky(x):
    c = new_coll("C_Lanky")
    for sx in (-1, 1):
        blob(c, "Foot", (x + sx * 0.36, -0.3, 0.1), ell(0.22, 0.42, 0.12), SKIN)
        limb(c, "LowerLeg", (x + sx * 0.36, -0.12, 0.15), (x + sx * 0.36, 0.12, 0.75), 0.13, SKIN)
        limb(c, "UpperLeg", (x + sx * 0.36, 0.12, 0.75), (x + sx * 0.33, -0.12, 1.3), 0.18, SKIN, 0.2)
        limb(c, "UpperArm", (x + sx * 0.55, -0.35, 2.35), (x + sx * 0.72, -0.4, 1.8), 0.13, COAT)
        limb(c, "LowerArm", (x + sx * 0.72, -0.4, 1.8), (x + sx * 0.62, -0.75, 1.45), 0.1, SKIN)
        ball(c, "Hand", (x + sx * 0.6, -0.82, 1.38), 0.14, SKIN)
    torso = blob(c, "Torso", (x, -0.12, 1.85), ell(0.52, 0.44, 0.7), COAT)
    torso.rotation_euler = (math.radians(-18), 0, 0)
    for i in range(3):
        for sx in (-1, 1):
            ball(c, "Button", (x + sx * 0.17, -0.62 + i * 0.08, 2.15 - i * 0.28), 0.05, BUTTON, outline=False)
    neckerchief(c, Vector((x, -0.35, 2.48)), 0.36)
    tail(c, x, (0, 0.35, 1.4), [(0, 0.95, 0.85), (0, 1.55, 0.35), (0.35, 2.15, 0.15), (0.8, 2.5, 0.12)], 0.22, 0.06)
    place_head(x, (0, -0.55, 2.95), 0.72, tilt=8)
    toque(c, (x, -0.38, 3.6), 0.7, lean=-15)
    return c


XS = (-3.6, 0.0, 3.6)
groups = [chibi(XS[0]), squishy(XS[1]), lanky(XS[2])]

# ------------------------------------------------------------------ render (same look as heads.py)
sc = bpy.context.scene
sc.render.engine = "BLENDER_EEVEE"
sc.view_settings.view_transform = "Standard"
world = bpy.data.worlds.new("World")
sc.world = world
world.use_nodes = True
wn = world.node_tree.nodes
bg = wn["Background"]
bg.inputs["Color"].default_value = (srgb(0.85), srgb(0.76), srgb(0.6), 1)
amb = wn.new("ShaderNodeBackground")
amb.inputs["Color"].default_value = (0.8, 0.8, 0.82, 1)
amb.inputs["Strength"].default_value = 1.1
lp = wn.new("ShaderNodeLightPath")
mix = wn.new("ShaderNodeMixShader")
links = world.node_tree.links
links.new(lp.outputs["Is Camera Ray"], mix.inputs[0])
links.new(amb.outputs[0], mix.inputs[1])
links.new(bg.outputs[0], mix.inputs[2])
links.new(mix.outputs[0], wn["World Output"].inputs["Surface"])

for name, energy, rot, col in (("Key", 3.4, (50, 0, -35), (1, 0.98, 0.94)), ("Rim", 1.6, (-60, 0, 160), (0.85, 0.9, 1))):
    ld = bpy.data.lights.new(name, "SUN")
    ld.energy, ld.color = energy, col
    lo = bpy.data.objects.new(name, ld)
    lo.rotation_euler = [math.radians(a) for a in rot]
    sc.collection.objects.link(lo)

# floor, so the top view reads like the kitchen
bpy.ops.mesh.primitive_plane_add(size=30, location=(0, 0, 0))
floor = bpy.context.object
floor.data.materials.append(mat((0.86, 0.6, 0.38), 0.8))

cam_data = bpy.data.cameras.new("Cam")
cam = bpy.data.objects.new("Cam", cam_data)
sc.collection.objects.link(cam)
sc.camera = cam


def shoot(path, target, dist, res, lens=50, yaw=-20, pitch=10):
    sc.render.resolution_x, sc.render.resolution_y = res
    cam_data.lens = lens
    t = Vector(target)
    yr, pr = math.radians(yaw), math.radians(pitch)
    cam.location = t + Vector((math.sin(yr) * math.cos(pr), -math.cos(yr) * math.cos(pr), math.sin(pr))) * dist
    cam.rotation_euler = (t - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)


OUT = os.path.join(HERE, "out")
shoot(os.path.join(OUT, "Bodies.png"), (0, 0.3, 1.75), 17, (1800, 900), yaw=-22, pitch=8)
shoot(os.path.join(OUT, "BodiesTop.png"), (0, 0.3, 1.2), 19, (1800, 900), yaw=0, pitch=55)
