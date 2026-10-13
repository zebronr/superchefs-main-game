# Cute pass on the Gecko body: big low eyes set close, tiny mouth, soft round chibi body, no gaps, one skin colour.
# Run headless from the repo root:
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup --python art/heads/cute.py
# Writes art/heads/out/Cute.png and CuteTop.png.

import math
import os

import bmesh
import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
src = open(os.path.join(HERE, "heads.py"), encoding="utf-8").read()
exec(src[: src.index("# ------------------------------------------------------------------ Gecko")])

G = 0.7  # matte, so it reads as soft vinyl, not glossy plastic
SKIN, BELLY, SPOT = (1.0, 0.84, 0.3), (1.0, 0.94, 0.7), (1.0, 0.6, 0.22)
COAT, APRON, SCARF = (0.98, 0.97, 0.94), (0.42, 0.76, 0.3), (0.98, 0.52, 0.2)
EYE = (0.08, 0.06, 0.07)


def limb(coll, name, a, b, r, rgb, r2=None):
    a, b = Vector(a), Vector(b)
    half = (b - a).length / 2
    r2 = r if r2 is None else r2

    def shape(p):
        w = r + (r2 - r) * (p.z + 1) / 2
        return Vector((p.x * w, p.y * w, p.z * (half + (r + r2) / 4)))

    o = blob(coll, name, (a + b) / 2, shape, rgb, gloss=G, seg=16, rings=10)
    o.rotation_mode = "QUATERNION"
    o.rotation_quaternion = (b - a).to_track_quat("Z", "Y")
    return o


def shell(coll, name, center, scale, keep, rgb):
    """Part of an ellipsoid surface (a clothing panel): keeps the faces whose local centre passes keep(Vector)."""
    o = blob(coll, name, center, ell(*scale), rgb, gloss=G, seg=28, rings=16)
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if not keep(f.calc_center_median())], context="FACES")
    bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.04)
    bm.to_mesh(o.data)
    bm.free()
    return o


def cute_gecko(x):
    c = new_coll("CuteGecko")
    H, HS = Vector((x, 0, 2.0)), (1.0, 0.9, 0.86)

    # head: round, a little wider than tall, soft flat front
    def head(p):
        q = Vector((p.x * HS[0], p.y * HS[1], p.z * HS[2]))
        if q.y < 0:
            q.y *= 1 - 0.12 * max(0, -q.y)
        return q

    blob(c, "Head", H, head, SKIN, gloss=G, seg=28, rings=16)
    # soft brow bumps over the eyes: the only "gecko eyes on top" hint left
    for sx in (-1, 1):
        blob(c, "Brow", H + Vector((sx * 0.4, -0.38, 0.5)), ell(0.3, 0.3, 0.24), SKIN, gloss=G)
    for sx in (-1, 1):
        p, n = on(H, HS, (sx * 0.36, -1, 0.06), -0.03)
        decal(c, "Eye", p, n, (0.17, 0.22, 0.08), EYE, gloss=0.15)
        ball(c, "Shine", p + n * 0.05 + Vector((-sx * 0.05, 0, 0.08)), 0.06, (1, 1, 1), outline=False)
        ball(c, "ShineSmall", p + n * 0.05 + Vector((sx * 0.06, 0, -0.08)), 0.028, (1, 1, 1), outline=False)
        p, n = on(H, HS, (sx * 0.62, -1, -0.22), -0.01)
        decal(c, "Blush", p, n, (0.16, 0.1, 0.03), (1.0, 0.6, 0.62), outline=False)
    # tiny "w" mouth between the eyes, low
    mouth = []
    for t, dz in ((-1, 0.0), (-0.5, -0.04), (0, 0.0), (0.5, -0.04), (1, 0.0)):
        p, _ = on(H, HS, (t * 0.12, -1, -0.28 + dz), 0.012)
        mouth.append(tuple(p))
    tube(c, "Mouth", mouth, 0.018, (0.45, 0.22, 0.1))
    for i, d in enumerate([(0.3, 0.3, 1), (-0.35, 0.5, 0.9), (0.6, 0.8, 0.5), (-0.65, 0.9, 0.35), (0, 1, 0.6)]):
        p, n = on(H, HS, d, 0.015)
        s = 0.13 + (i % 2) * 0.04
        decal(c, "Spot", p, n, (s, s * 0.85, 0.03), SPOT, roll=i * 41, outline=False)

    # body: a small soft pear tucked under the head (head overlaps it, so there's no neck gap)
    B, BS = Vector((x, 0.02, 0.92)), (0.66, 0.58, 0.66)
    blob(c, "Torso", B, ell(*BS), COAT, gloss=G, seg=24, rings=14)
    shell(c, "Apron", B, (BS[0] + 0.03, BS[1] + 0.03, BS[2] + 0.03),
          lambda m: m.y < -0.18 and m.z < 0.22, APRON)
    blob(c, "Neckerchief", (x, -0.02, 1.4), ell(0.46, 0.42, 0.1), SCARF, gloss=G)
    blob(c, "Knot", (x + 0.12, -0.42, 1.33), ell(0.12, 0.07, 0.11), SCARF, gloss=G)
    for sx in (-1, 1):
        limb(c, "Arm", (x + sx * 0.55, -0.02, 1.18), (x + sx * 0.78, -0.12, 0.82), 0.16, COAT, 0.15)
        ball(c, "Hand", (x + sx * 0.82, -0.15, 0.74), 0.17, SKIN, gloss=G)
        blob(c, "Foot", (x + sx * 0.28, -0.1, 0.15), ell(0.24, 0.3, 0.16), SKIN, gloss=G)
        limb(c, "Leg", (x + sx * 0.27, 0, 0.18), (x + sx * 0.27, 0.02, 0.42), 0.17, SKIN)
    # short tail that curls up at the end
    pts = [(0, 0.45, 0.55), (0, 0.85, 0.35), (0.22, 1.12, 0.38), (0.32, 1.12, 0.6)]
    for i in range(len(pts) - 1):
        a, b = Vector(pts[i]) + Vector((x, 0, 0)), Vector(pts[i + 1]) + Vector((x, 0, 0))
        limb(c, "Tail", a, b, 0.2 - i * 0.05, SKIN, 0.2 - (i + 1) * 0.05)
    # small puffy toque sitting back on the head
    for o in (blob(c, "ToqueBand", (x, 0.22, 2.78), ell(0.34, 0.32, 0.13), COAT, gloss=G),
              blob(c, "ToquePuff", (x, 0.3, 3.08), ell(0.44, 0.4, 0.28), COAT, gloss=G)):
        o.rotation_euler = (math.radians(-14), 0, 0)
    return c


cute_gecko(0)

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
for name, energy, rot, col in (("Key", 3.0, (50, 0, -35), (1, 0.98, 0.94)), ("Rim", 1.6, (-60, 0, 160), (0.85, 0.9, 1))):
    ld = bpy.data.lights.new(name, "SUN")
    ld.energy, ld.color = energy, col
    lo = bpy.data.objects.new(name, ld)
    lo.rotation_euler = [math.radians(a) for a in rot]
    sc.collection.objects.link(lo)
bpy.ops.mesh.primitive_plane_add(size=30)
bpy.context.object.data.materials.append(mat((0.86, 0.6, 0.38), 0.8))

cam_data = bpy.data.cameras.new("Cam")
cam = bpy.data.objects.new("Cam", cam_data)
sc.collection.objects.link(cam)
sc.camera = cam


def shoot(path, target, dist, res, yaw, pitch):
    sc.render.resolution_x, sc.render.resolution_y = res
    t = Vector(target)
    yr, pr = math.radians(yaw), math.radians(pitch)
    cam.location = t + Vector((math.sin(yr) * math.cos(pr), -math.cos(yr) * math.cos(pr), math.sin(pr))) * dist
    cam.rotation_euler = (t - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)


OUT = os.path.join(HERE, "out")
shoot(os.path.join(OUT, "Cute.png"), (0, 0.2, 1.6), 8.5, (900, 900), -22, 8)
shoot(os.path.join(OUT, "CuteTop.png"), (0, 0.2, 1.2), 9.5, (900, 900), 0, 55)
