# Set 4: creatures, bosses and world props, replacing the block models built in Lua.
#
#   animals: wolf, goat, crab, turtle          cave mobs: cave_crawler, cinder_beetle, bog_slime
#   bosses:  crawler_queen, crystal_warden, magma_golem
#   props:   skull_rock (Skull Key), signboard (big two-post sign), tent (A-frame hide tent)
#
# Conventions (same as set 2): Blender Z is up, the creature faces -Y (Roblox -Z),
# the origin is on the ground under the middle of the model. Sizes are studs.
# Every object has ONE material, and creature parts use the names the game animates:
#   Leg (swings about its top), Arm / Fist / Claw / Mandible (swing, pull back on a
#   wind-up), Head / Snout / Eye / Ear / Horn / Beard (bob together), Tail (sways).
# Anything else (Body, Shell, Shard, Seam, ...) stays fixed to the body.
#
# Run: python3 set4.py            (writes /tmp/models/out4/*.obj)
#      PREVIEW=1 python3 set4.py  (also renders docs/previews/set4-*.png)
import sys, os
sys.path.insert(0, '/tmp/models'); sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy, bmesh, math, random
from mathutils import Vector, Matrix, Euler
from lib import *

reset()
OUT = '/tmp/models/out4/'
os.makedirs(OUT, exist_ok=True)

# ---------------------------------------------------------------- helpers

def blob(name, m, c, radii, sub=2, noise=0.0, seed=1, flat=None):
    """A smooth-ish faceted ellipsoid centred on c. flat: cut everything below this z."""
    rng = random.Random(seed)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=1.0)
    for v in bm.verts:
        d = 1 + rng.uniform(-noise, noise)
        v.co = Vector((v.co.x * radii[0] * d + c[0], v.co.y * radii[1] * d + c[1], v.co.z * radii[2] * d + c[2]))
        if flat is not None and v.co.z < flat:
            v.co.z = flat
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.001)
    return obj_from_bm(bm, name, m)

def tube(name, m, pts, radii, sides=7, flat=1.0, jitter=0.0, seed=1):
    """A tube through points pts with a radius per point, capped at both ends."""
    rng = random.Random(seed)
    bm = bmesh.new(); rows = []
    pts = [Vector(p) for p in pts]
    for i, p in enumerate(pts):
        d = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        up = Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((0, 1, 0))
        a = d.cross(up).normalized(); b = d.cross(a).normalized()
        row = []
        for s in range(sides):
            t = 2 * math.pi * s / sides
            j = 1 + rng.uniform(-jitter, jitter)
            row.append(bm.verts.new(p + (a * math.cos(t) + b * math.sin(t) * flat) * radii[i] * j))
        rows.append(row)
    for i in range(len(rows) - 1):
        for s in range(sides):
            bm.faces.new((rows[i][s], rows[i][(s + 1) % sides], rows[i + 1][(s + 1) % sides], rows[i + 1][s]))
    bm.faces.new(list(reversed(rows[0]))); bm.faces.new(rows[-1])
    return obj_from_bm(bm, name, m)

def spike(name, m, base, tip, r, sides=5, seed=1):
    """A cone from base to tip."""
    base, tip = Vector(base), Vector(tip)
    d = (tip - base).normalized()
    up = Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((0, 1, 0))
    a = d.cross(up).normalized(); b = d.cross(a).normalized()
    rng = random.Random(seed)
    bm = bmesh.new()
    ring = [bm.verts.new(base + (a * math.cos(2 * math.pi * s / sides) + b * math.sin(2 * math.pi * s / sides)) * r * (1 + rng.uniform(-0.1, 0.1))) for s in range(sides)]
    t = bm.verts.new(tip)
    for s in range(sides):
        bm.faces.new((ring[s], ring[(s + 1) % sides], t))
    bm.faces.new(list(reversed(ring)))
    return obj_from_bm(bm, name, m)

def boxm(name, m, c, size, rot=(0, 0, 0), taper=1.0, bevel=0.0):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        k = taper if v.co.z > 0 else 1.0
        v.co = Vector((v.co.x * size[0] * k, v.co.y * size[1] * k, v.co.z * size[2]))
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=1, affect='EDGES')
    R = Euler(rot).to_matrix().to_4x4()
    bmesh.ops.transform(bm, matrix=Matrix.Translation(Vector(c)) @ R, verts=bm.verts)
    return obj_from_bm(bm, name, m)

def mirror(fn):
    return [fn(-1), fn(1)]

def flat_list(xs):
    out = []
    for x in xs:
        if isinstance(x, (list, tuple)): out += flat_list(x)
        elif x is not None: out.append(x)
    return out

models = {}
def model(name, objs):
    objs = flat_list(objs)
    # The game colours parts by name, so one name = one material within a model.
    # A part whose name is taken by another material gets the material's name added
    # (Eye -> EyeEyeWhite); the game still reads the first word (Eye) for animation.
    seen = {}
    for o in objs:
        base = o.name.split('.')[0]
        m = o.data.materials[0].name
        if seen.setdefault(base, m) != m:
            key = base + m
            seen.setdefault(key, m)
            o.name = key
    models[name] = objs
    export(OUT + name + '.obj', objs)
    return objs

def eyes(m, x, y, z, r, white=None):
    out = []
    for s in (-1, 1):
        if white:
            out.append(blob("Eye", white, (s * x, y, z), (r * 1.15, r * 0.7, r * 1.15), sub=1))
            out.append(blob("Eye", m, (s * x, y - r * 0.45, z), (r * 0.6, r * 0.5, r * 0.6), sub=1))
        else:
            out.append(blob("Eye", m, (s * x, y, z), (r, r * 0.7, r), sub=1))
    return out

# A quadruped leg: thigh to ankle to foot, as one piece, standing on z=0 at (x, y).
def qleg(m, x, y, top, r0, r1, knee=0.25, seed=1):
    return tube("Leg", m, [(x, y, top), (x, y + knee * 0.3, top * 0.55), (x, y - knee * 0.2, top * 0.18), (x, y - knee * 0.35, 0.05)],
                [r0, r0 * 0.78, r1, r1 * 1.15], sides=6, seed=seed)

EYE = mat("EyeDark", (22, 18, 16)); EYEW = mat("EyeWhite", (240, 236, 220))

# ---------------------------------------------------------------- animals

def wolf():
    FUR = mat("WolfFur", (122, 122, 128)); FUR2 = mat("WolfFurDark", (82, 82, 90)); BELLY = mat("WolfBelly", (200, 196, 186))
    NOSE = mat("WolfNose", (30, 26, 26))
    body = tube("Body", FUR, [(0, 2.4, 2.6), (0, 1.0, 2.85), (0, -0.6, 3.1), (0, -1.7, 3.15)], [0.85, 1.0, 1.15, 1.0], sides=8, flat=0.95, jitter=0.05, seed=1)
    ruff = blob("Ruff", FUR2, (0, -1.4, 3.35), (1.25, 0.9, 1.15), sub=2, noise=0.12, seed=2)
    belly = blob("Belly", BELLY, (0, 0.2, 2.25), (0.75, 1.7, 0.45), sub=2)
    head = blob("Head", FUR, (0, -2.75, 3.75), (0.8, 0.85, 0.72), sub=2, noise=0.05, seed=3)
    snout = tube("Snout", FUR, [(0, -3.2, 3.55), (0, -4.25, 3.35)], [0.5, 0.3], sides=6, flat=0.8)
    nose = blob("Snout", NOSE, (0, -4.35, 3.42), (0.18, 0.12, 0.14), sub=1)
    jaw = tube("Snout", BELLY, [(0, -3.0, 3.2), (0, -4.0, 3.12)], [0.35, 0.2], sides=5, flat=0.5)
    ears = mirror(lambda s: spike("Ear", FUR2, (s * 0.45, -2.5, 4.25), (s * 0.62, -2.35, 4.95), 0.24, sides=4))
    tail = tube("Tail", FUR2, [(0, 2.4, 2.8), (0, 3.2, 2.5), (0, 3.9, 1.9), (0, 4.1, 1.4)], [0.25, 0.42, 0.38, 0.12], sides=6, seed=4)
    legs = [qleg(FUR2, s * 0.62, y, 2.5, 0.36, 0.2, seed=10 + i) for i, (s, y) in enumerate([(-1, -1.6), (1, -1.6), (-1, 1.7), (1, 1.7)])]
    return model("wolf", [body, ruff, belly, head, snout, nose, jaw, ears, eyes(EYE, 0.38, -3.35, 3.95, 0.11, EYEW), tail, legs])

def goat():
    WOOL = mat("GoatWool", (226, 220, 206)); WOOL2 = mat("GoatWoolDark", (168, 156, 136)); HORN = mat("GoatHorn", (120, 104, 86))
    HOOF = mat("GoatHoof", (60, 50, 44))
    body = blob("Body", WOOL, (0, 0.1, 2.5), (1.0, 1.75, 0.95), sub=2, noise=0.08, seed=1)
    fleece = blob("Fleece", WOOL2, (0, 0.3, 3.05), (0.9, 1.4, 0.45), sub=2, noise=0.15, seed=2)
    neck = tube("Body", WOOL, [(0, -1.4, 2.8), (0, -1.9, 3.5)], [0.55, 0.45], sides=6)
    head = tube("Head", WOOL, [(0, -1.9, 3.85), (0, -2.55, 3.6), (0, -2.95, 3.3)], [0.42, 0.36, 0.22], sides=7, flat=0.85)
    beard = spike("Beard", WOOL2, (0, -2.75, 3.15), (0, -2.85, 2.55), 0.14, sides=4)
    horns = mirror(lambda s: tube("Horn", HORN, [(s * 0.22, -2.0, 4.15), (s * 0.4, -1.75, 4.7), (s * 0.7, -1.3, 4.85), (s * 0.85, -1.05, 4.5)], [0.14, 0.12, 0.09, 0.03], sides=5))
    ears = mirror(lambda s: tube("Ear", WOOL2, [(s * 0.35, -2.0, 3.9), (s * 0.85, -1.95, 3.8)], [0.12, 0.05], sides=4, flat=0.4))
    tail = spike("Tail", WOOL, (0, 1.75, 2.9), (0, 2.15, 3.3), 0.18, sides=4)
    legs = [tube("Leg", HOOF if False else WOOL2, [(s * 0.55, y, 2.1), (s * 0.55, y, 1.0), (s * 0.55, y - 0.05, 0.05)], [0.24, 0.17, 0.16], sides=6, seed=i)
            for i, (s, y) in enumerate([(-1, -1.15), (1, -1.15), (-1, 1.15), (1, 1.15)])]
    return model("goat", [body, fleece, neck, head, beard, horns, ears, eyes(EYE, 0.3, -2.4, 3.8, 0.08), tail, legs])

def crab():
    SHELL = mat("CrabShell", (214, 84, 52)); SHELL2 = mat("CrabShellDark", (160, 54, 36)); UNDER = mat("CrabUnder", (240, 196, 150))
    body = blob("Body", SHELL, (0, 0, 1.15), (1.5, 1.1, 0.55), sub=2, noise=0.04, seed=1)
    under = blob("Under", UNDER, (0, 0, 0.85), (1.3, 0.95, 0.3), sub=2)
    ridge = mirror(lambda s: spike("Spines", SHELL2, (s * 1.35, -0.4, 1.2), (s * 1.75, -0.6, 1.35), 0.18, sides=4))
    claws = []
    for s in (-1, 1):
        arm = tube("Claw", SHELL, [(s * 1.1, -0.7, 1.0), (s * 1.7, -1.3, 1.2), (s * 1.75, -1.9, 1.3)], [0.22, 0.2, 0.3], sides=6)
        pincer = blob("Claw", SHELL2, (s * 1.75, -2.3, 1.3), (0.42, 0.55, 0.32), sub=1)
        tip = spike("Claw", SHELL2, (s * 1.6, -2.6, 1.3), (s * 1.45, -3.15, 1.3), 0.15, sides=4)
        claws += [arm, pincer, tip]
    legs = []
    for s in (-1, 1):
        for k, y in enumerate((-0.35, 0.15, 0.6)):
            legs.append(tube("Leg", SHELL2, [(s * 1.25, y, 0.95), (s * 2.0, y + 0.1, 1.15), (s * 2.5, y + 0.2, 0.05)], [0.13, 0.1, 0.05], sides=5, seed=k))
    stalks = mirror(lambda s: tube("Eye", SHELL, [(s * 0.4, -0.85, 1.4), (s * 0.45, -0.95, 1.95)], [0.07, 0.07], sides=4))
    return model("crab", [body, under, ridge, claws, legs, stalks, eyes(EYE, 0.45, -0.98, 2.05, 0.14)])

def turtle():
    SHELL = mat("TurtleShell", (96, 120, 64)); PLATE = mat("TurtlePlate", (128, 150, 82)); SKIN = mat("TurtleSkin", (150, 160, 104))
    RIM = mat("TurtleRim", (190, 170, 110))
    shell = blob("Shell", SHELL, (0, 0.1, 1.1), (1.75, 2.2, 1.1), sub=2, flat=0.75, seed=1)
    rim = tube("Rim", RIM, [(0, 0.1, 0.72), (0, 0.1, 0.8)], [2.0, 2.0], sides=12, flat=1.25)
    plates = []
    for i, (x, y) in enumerate([(0, -0.9), (0, 0.2), (0, 1.25), (-0.95, -0.4), (0.95, -0.4), (-0.95, 0.8), (0.95, 0.8)]):
        z = 1.1 + 1.0 * math.sqrt(max(0, 1 - (x / 1.75) ** 2 - ((y - 0.1) / 2.2) ** 2))
        plates.append(blob("Plate", PLATE, (x, y, z), (0.5, 0.55, 0.14), sub=1, seed=i))
    head = blob("Head", SKIN, (0, -2.75, 1.05), (0.5, 0.65, 0.45), sub=2)
    neck = tube("Head", SKIN, [(0, -1.8, 0.9), (0, -2.4, 1.0)], [0.38, 0.35], sides=6)
    legs = [tube("Leg", SKIN, [(s * 1.35, y, 0.85), (s * 1.75, y - 0.15, 0.35), (s * 1.95, y - 0.35, 0.08)], [0.32, 0.3, 0.22], sides=6, flat=0.6, seed=i)
            for i, (s, y) in enumerate([(-1, -1.3), (1, -1.3), (-1, 1.4), (1, 1.4)])]
    tail = spike("Tail", SKIN, (0, 2.2, 0.85), (0, 2.75, 0.7), 0.18, sides=4)
    return model("turtle", [shell, rim, plates, head, neck, legs, tail, eyes(EYE, 0.33, -3.15, 1.2, 0.08)])

# ---------------------------------------------------------------- cave mobs

def spider(name, size, BODY, DARK, GLOW, abdomen_glow=None, crown=None):
    k = size
    out = []
    thorax = blob("Body", BODY, (0, -0.3 * k, 1.35 * k), (0.85 * k, 0.95 * k, 0.6 * k), sub=2, noise=0.05, seed=1)
    abdomen = blob("Abdomen", DARK, (0, 1.6 * k, 1.75 * k), (1.25 * k, 1.55 * k, 1.05 * k), sub=2, noise=0.06, seed=2)
    head = blob("Head", BODY, (0, -1.35 * k, 1.35 * k), (0.6 * k, 0.55 * k, 0.5 * k), sub=2, seed=3)
    out += [thorax, abdomen, head]
    for s in (-1, 1):
        out.append(tube("Mandible", DARK, [(s * 0.25 * k, -1.75 * k, 1.15 * k), (s * 0.35 * k, -2.15 * k, 0.9 * k), (s * 0.15 * k, -2.35 * k, 0.65 * k)], [0.13 * k, 0.1 * k, 0.03 * k], sides=5))
        for i, (y, spread) in enumerate([(-0.9, -0.6), (-0.4, -0.2), (0.1, 0.25), (0.5, 0.7)]):
            yy = y * k
            out.append(tube("Leg", DARK, [(s * 0.6 * k, yy, 1.35 * k), (s * 1.6 * k, yy + spread * 0.4 * k, 2.4 * k), (s * 2.6 * k, yy + spread * k, 0.05)],
                            [0.14 * k, 0.11 * k, 0.04 * k], sides=5, seed=i))
    # Six little eyes in two rows.
    for s in (-1, 1):
        for j, (x, z) in enumerate([(0.18, 1.6), (0.36, 1.5), (0.12, 1.42)]):
            out.append(blob("Eye", GLOW, (s * x * k, -1.82 * k, z * k), (0.08 * k, 0.06 * k, 0.08 * k), sub=1))
    if abdomen_glow:
        rng = random.Random(9)
        for i in range(7):
            a = rng.uniform(0, math.tau); h = rng.uniform(-0.5, 0.7)
            out.append(blob("Spots", abdomen_glow, (math.cos(a) * 1.15 * k * math.sqrt(1 - h * h * 0.5), 1.6 * k + math.sin(a) * 1.4 * k, 1.75 * k + h * k), (0.2 * k, 0.2 * k, 0.12 * k), sub=1))
    if crown:
        for i, x in enumerate((-0.4, -0.15, 0.15, 0.4)):
            out.append(spike("Crown", crown, (x * k, -1.25 * k, 1.75 * k), (x * 1.5 * k, -1.0 * k, (2.5 + (0.3 - abs(x)) * 1.5) * k), 0.1 * k, sides=4, seed=i))
    return out

def cave_crawler():
    return model("cave_crawler", spider("cave_crawler", 1.0, mat("CrawlerBody", (70, 60, 74)), mat("CrawlerDark", (40, 34, 44)), mat("CrawlerGlow", (140, 255, 170))))

def cinder_beetle():
    SHELL = mat("BeetleShell", (40, 32, 34)); UNDER = mat("BeetleUnder", (70, 50, 44)); LAVA = mat("Lava", (255, 120, 40))
    out = []
    out.append(blob("Shell", SHELL, (0, 0.3, 1.35), (1.4, 1.95, 0.95), sub=2, flat=0.6, noise=0.04, seed=1))
    out.append(blob("Under", UNDER, (0, 0.3, 0.8), (1.25, 1.75, 0.35), sub=2))
    out.append(tube("Seam", LAVA, [(0, -1.2, 2.05), (0, -0.4, 2.27), (0, 0.6, 2.3), (0, 1.6, 2.15), (0, 2.1, 1.85)], [0.08, 0.1, 0.1, 0.09, 0.06], sides=4))
    for s in (-1, 1):
        out.append(tube("Seam", LAVA, [(s * 0.6, -0.8, 1.9), (s * 1.0, 0.3, 1.95), (s * 0.7, 1.6, 1.7)], [0.07, 0.07, 0.05], sides=4))
    out.append(blob("Head", SHELL, (0, -1.85, 1.0), (0.7, 0.6, 0.5), sub=2))
    out.append(spike("Horn", SHELL, (0, -2.2, 1.25), (0, -3.0, 2.0), 0.2, sides=5))
    for s in (-1, 1):
        out.append(tube("Mandible", UNDER, [(s * 0.35, -2.25, 0.85), (s * 0.45, -2.75, 0.7), (s * 0.2, -3.0, 0.6)], [0.1, 0.08, 0.02], sides=4))
        for i, y in enumerate((-1.0, 0.2, 1.3)):
            out.append(tube("Leg", UNDER, [(s * 1.1, y, 0.9), (s * 1.8, y + 0.1, 1.1), (s * 2.2, y + 0.25, 0.05)], [0.13, 0.1, 0.05], sides=5, seed=i))
    out += eyes(LAVA, 0.35, -2.35, 1.15, 0.1)
    return model("cinder_beetle", out)

def bog_slime():
    GOO = mat("SlimeGoo", (110, 196, 80)); CORE = mat("SlimeCore", (60, 120, 40)); MUD = mat("SlimeMud", (90, 80, 52))
    out = [blob("Body", GOO, (0, 0, 1.45), (1.75, 1.75, 1.45), sub=3, flat=0.08, noise=0.03, seed=1)]
    out.append(blob("Core", CORE, (0, 0.1, 1.3), (0.8, 0.8, 0.7), sub=2, noise=0.15, seed=2))
    rng = random.Random(4)
    for i in range(5):
        a = rng.uniform(0, math.tau)
        out.append(blob("Muck", MUD, (math.cos(a) * 1.2, math.sin(a) * 1.2, rng.uniform(0.6, 2.2)), (0.22, 0.22, 0.18), sub=1, seed=i))
    for s in (-1, 1):
        out.append(blob("Eye", EYEW, (s * 0.55, -1.45, 2.0), (0.32, 0.2, 0.36), sub=1))
        out.append(blob("Eye", EYE, (s * 0.55, -1.62, 1.98), (0.16, 0.1, 0.18), sub=1))
    out.append(tube("Mouth", CORE, [(-0.45, -1.62, 1.35), (0, -1.72, 1.2), (0.45, -1.62, 1.35)], [0.08, 0.1, 0.08], sides=4))
    return model("bog_slime", out)

# ---------------------------------------------------------------- bosses

def crawler_queen():
    BODY = mat("QueenBody", (96, 52, 92)); DARK = mat("QueenDark", (54, 28, 56)); GLOW = mat("QueenGlow", (255, 120, 190))
    BONE = mat("QueenBone", (232, 222, 200))
    out = spider("crawler_queen", 3.2, BODY, DARK, GLOW, abdomen_glow=GLOW, crown=BONE)
    # Two raptorial front arms held up like scythes.
    for s in (-1, 1):
        out.append(tube("Arm", DARK, [(s * 1.5, -2.2, 4.6), (s * 2.6, -3.6, 7.4), (s * 2.8, -5.6, 7.0)], [0.55, 0.42, 0.3], sides=6))
        out.append(spike("Claw", BONE, (s * 2.8, -5.6, 7.0), (s * 2.4, -7.6, 4.8), 0.36, sides=5))
    # A spine ridge down the abdomen.
    for i in range(6):
        y = 2.4 + i * 1.1
        out.append(spike("Spines", BONE, (0, y, 8.7 - abs(i - 2.5) * 0.5), (0, y + 0.4, 10.0 - abs(i - 2.5) * 0.6), 0.32, sides=4, seed=i))
    return model("crawler_queen", out)

def golem(name, STONE, DARK, GLOW, crystals=None, lava=None):
    out = []
    out.append(blob("Body", STONE, (0, 0, 12.5), (5.4, 3.8, 5.2), sub=2, noise=0.1, seed=1))
    out.append(blob("Chest", DARK, (0, -2.6, 12.8), (3.6, 1.5, 3.4), sub=2, noise=0.08, seed=2))
    out.append(blob("Hips", DARK, (0, 0.3, 7.6), (4.2, 3.0, 2.3), sub=2, noise=0.1, seed=3))
    out.append(blob("Head", STONE, (0, -1.4, 18.6), (2.4, 2.2, 2.1), sub=2, noise=0.1, seed=4))
    out.append(boxm("Eye", GLOW, (0, -3.45, 18.8), (3.4, 0.4, 0.7)))
    out.append(blob("Head", DARK, (0, -2.2, 17.2), (1.9, 1.2, 0.9), sub=1, seed=5))
    for s in (-1, 1):
        out.append(blob("Shoulder", STONE, (s * 6.0, 0, 15.6), (2.6, 2.6, 2.4), sub=2, noise=0.12, seed=6))
        out.append(tube("Arm", STONE, [(s * 6.6, 0, 14.5), (s * 7.2, -0.4, 10.5), (s * 7.4, -0.8, 7.6)], [1.7, 1.5, 1.6], sides=7, jitter=0.1, seed=7))
        out.append(blob("Fist", crystals or DARK, (s * 7.6, -1.0, 5.6), (2.1, 2.1, 2.1), sub=1, noise=0.15, seed=8))
        out.append(tube("Leg", DARK, [(s * 2.6, 0, 7.0), (s * 2.9, -0.3, 3.5), (s * 3.0, -0.4, 0.0)], [1.9, 1.7, 2.1], sides=7, jitter=0.08, seed=9))
    if crystals:
        rng = random.Random(3)
        for i in range(11):
            a = (i - 5) * 0.3
            base = (math.sin(a) * 4.2, 2.2 + rng.uniform(-0.4, 0.4), 14.0 + math.cos(a) * 2.6)
            tip = (base[0] * 1.5, base[1] + rng.uniform(2.5, 4.5), base[2] + 3 + (5 - abs(i - 5)) * 0.9)
            out.append(spike("Shard", crystals, base, tip, rng.uniform(0.6, 1.0), sides=5, seed=i))
        for s in (-1, 1):
            out.append(spike("Shard", crystals, (s * 6.0, 0.6, 17.4), (s * 7.5, 1.4, 21.0), 0.8, sides=5))
    if lava:
        rng = random.Random(5)
        out.append(blob("Core", lava, (0, -3.9, 12.8), (1.8, 0.5, 1.8), sub=1))
        for i in range(9):
            x, z = rng.uniform(-3.8, 3.8), rng.uniform(9.5, 16)
            out.append(tube("Seam", lava, [(x, -3.7, z), (x + rng.uniform(-1, 1), -3.95, z + rng.uniform(1.5, 3))], [0.18, 0.12], sides=4))
            out.append(tube("Seam", lava, [(x * 0.9, 3.7, z), (x * 0.9 + rng.uniform(-1, 1), 3.95, z + rng.uniform(1.5, 3))], [0.18, 0.12], sides=4))
        for s in (-1, 1):
            out.append(tube("Seam", lava, [(s * 7.1, -1.4, 13.5), (s * 7.4, -1.6, 9.0)], [0.2, 0.15], sides=4))
    return model(name, out)

def crystal_warden():
    return golem("crystal_warden", mat("WardenStone", (84, 80, 108)), mat("WardenDark", (48, 44, 64)), mat("CrystalGlow", (210, 170, 255)), crystals=mat("Crystal", (170, 120, 250)))

def magma_golem():
    return golem("magma_golem", mat("GolemRock", (46, 38, 36)), mat("GolemDark", (28, 24, 24)), mat("Lava", (255, 120, 40)), lava=mat("Lava", (255, 120, 40)))

# ---------------------------------------------------------------- props

def skull_rock():
    BONE = mat("SkullBone", (226, 218, 198)); SHADE = mat("SkullShade", (178, 168, 146)); HOLE = mat("SkullHole", (30, 24, 22))
    MOSS = mat("Moss", (96, 128, 70)); GLOW = mat("Ember", (255, 96, 60))
    out = []
    # Cranium: a big dome, a bit longer than wide, sitting on the jaw. Faces -Y.
    out.append(blob("Cranium", BONE, (0, 2, 22), (15, 17, 14), sub=3, noise=0.03, seed=1, flat=9))
    out.append(blob("Brow", SHADE, (0, -10.5, 23.5), (13, 4.5, 4), sub=2, noise=0.05, seed=2))
    # Cheekbones and the upper jaw.
    for s in (-1, 1):
        out.append(blob("Cheek", BONE, (s * 9.5, -9.5, 14.5), (4.5, 5.5, 4.5), sub=2, noise=0.05, seed=3))
        # Eye sockets: dark, deep, with a glow at the back.
        out.append(blob("Socket", HOLE, (s * 6, -13.4, 18.5), (4.2, 3.2, 4.4), sub=2, seed=4))
        out.append(blob("Eye", GLOW, (s * 6, -15.9, 18.3), (1.9, 0.8, 1.9), sub=1))
        # Temple cracks.
        out.append(tube("Crack", HOLE, [(s * 13.5, -4, 27), (s * 14.4, -1, 24), (s * 14.6, 1.5, 25.5), (s * 14.8, 4, 22)], [0.4, 0.35, 0.3, 0.15], sides=4))
    # Nose cavity: an upside-down heart.
    out.append(spike("Nose", HOLE, (0, -15.2, 11.8), (0, -15.6, 16.6), 1.9, sides=3))
    out.append(blob("Maxilla", SHADE, (0, -10, 10.5), (9.5, 6, 2.8), sub=2, seed=5))
    # Teeth: a row along the upper jaw and the lower jaw, a few missing.
    for i in range(-4, 5):
        if i in (-2, 3): continue
        x = i * 1.9
        y = -15.2 + abs(i) * 0.5
        out.append(boxm("Teeth", BONE, (x, y, 7.6), (1.6, 1.4, 2.6), taper=0.75))
        if i not in (1,):
            out.append(boxm("Teeth", BONE, (x, y + 0.3, 5.0), (1.5, 1.3, 2.2), taper=1.2))
    # The jaw, half sunk into the sand.
    out.append(tube("Jaw", SHADE, [(-11, -2, 4), (-9.5, -12, 3.2), (0, -15.5, 3.2), (9.5, -12, 3.2), (11, -2, 4)], [3, 2.8, 2.6, 2.8, 3], sides=7, flat=0.8))
    # Moss in the cracks and on top.
    rng = random.Random(7)
    for i in range(9):
        a = rng.uniform(-2.6, 2.6)
        out.append(blob("Moss", MOSS, (math.sin(a) * 13, 2 + math.cos(a) * 12, 28 + rng.uniform(-3, 4)), (rng.uniform(1.5, 3), rng.uniform(1.5, 3), 0.7), sub=1, seed=i))
    return model("skull_rock", out)

def signboard():
    POST = mat("SignPost", (92, 62, 40)); BOARD = mat("SignBoard", (176, 132, 84)); EDGE = mat("SignEdge", (120, 84, 52))
    ROPE = mat("Rope", (206, 182, 128)); NAIL = mat("Nail", (60, 60, 64))
    out = []
    for s in (-1, 1):
        out.append(tube("Post", POST, [(s * 5, 0, -0.5), (s * 5.05, 0, 5), (s * 4.95, 0, 9.4)], [0.5, 0.46, 0.42], sides=7, jitter=0.08, seed=s + 3))
        out.append(spike("Post", POST, (s * 4.95, 0, 9.4), (s * 4.95, 0, 10.2), 0.42, sides=7))
        for z in (5.6, 8.4):
            out.append(tube("Rope", ROPE, [(s * 5, 0, z)] + [(s * 5, 0, z + 0.25)], [0.58, 0.58], sides=8))
    # Three planks, slightly uneven, nailed across, with pointed ends.
    for i, (z, w, tilt) in enumerate([(5.7, 11.5, 0.02), (7.0, 12.2, -0.015), (8.3, 11.8, 0.01)]):
        out.append(boxm("Board", BOARD if i != 1 else EDGE, (0.1 * (i - 1), -0.55, z), (w, 0.45, 1.25), rot=(0, tilt, 0), bevel=0.06))
        for s in (-1, 1):
            out.append(blob("Nail", NAIL, (s * 5, -0.85, z), (0.12, 0.08, 0.12), sub=1))
    out.append(boxm("Edge", EDGE, (0, -0.82, 4.95), (12.6, 0.2, 0.25)))
    out.append(boxm("Edge", EDGE, (0, -0.82, 9.05), (12.6, 0.2, 0.25)))
    return model("signboard", out)

def tent():
    HIDE = mat("TentHide", (226, 204, 158)); HIDE2 = mat("TentHideDark", (196, 170, 124)); POLE = mat("TentPole", (96, 66, 42))
    ROPE = mat("Rope", (206, 182, 128)); STRIPE = mat("TentStripe", (170, 70, 52)); DOOR = mat("TentDoor", (58, 40, 28))
    W, H, L = 9.6, 8.4, 12.0  # width, height, length (for r = 6; the game scales it)
    out = []
    # Two sagging hide slopes, each a curved sheet with a little thickness.
    for s in (-1, 1):
        bm = bmesh.new(); rows = []
        N, M = 6, 8
        for i in range(N + 1):
            u = i / N  # ridge -> ground
            row = []
            for j in range(M + 1):
                v = j / M  # back -> front
                sag = math.sin(u * math.pi) * 0.45 * (1 - 0.6 * math.sin(v * math.pi))
                x = s * (W / 2) * u - s * sag * 0.6
                z = H * (1 - u) + 0.15 - sag * 0.4
                y = L / 2 - v * L + (0.4 * u if v in (0, 1) else 0) * (1 if v == 0 else -1)
                row.append(bm.verts.new((x, y, z)))
            rows.append(row)
        for i in range(N):
            for j in range(M):
                q = (rows[i][j], rows[i + 1][j], rows[i + 1][j + 1], rows[i][j + 1])
                bm.faces.new(q if s > 0 else tuple(reversed(q)))
        bmesh.ops.solidify(bm, geom=list(bm.faces), thickness=0.18)
        out.append(obj_from_bm(bm, "Hide", HIDE if s > 0 else HIDE2))
        # A painted band and patches.
        out.append(tube("Stripe", STRIPE, [(s * W * 0.22, L / 2 + 0.05, H * 0.56 + 0.1), (s * W * 0.22, -L / 2 - 0.05, H * 0.56 + 0.1)], [0.28, 0.28], sides=4, flat=0.4))
        out.append(boxm("Patch", HIDE2 if s > 0 else HIDE, (s * W * 0.32, 1.5 * s, H * 0.36 + 0.2), (1.6, 1.4, 0.12), rot=(0, s * math.atan2(H, W / 2) * -1 + s * math.pi / 2, 0)))
    # Back wall, closed; front: two flaps tied open around a dark doorway.
    bm = bmesh.new()
    v = [bm.verts.new(p) for p in [(-W / 2, L / 2, 0.1), (W / 2, L / 2, 0.1), (0, L / 2, H + 0.1)]]
    bm.faces.new(v); bmesh.ops.solidify(bm, geom=list(bm.faces), thickness=0.15)
    out.append(obj_from_bm(bm, "Hide", HIDE2))
    bm = bmesh.new()
    v = [bm.verts.new(p) for p in [(-W * 0.3, -L / 2 + 0.3, 0.1), (W * 0.3, -L / 2 + 0.3, 0.1), (0, -L / 2 + 0.3, H * 0.8)]]
    bm.faces.new(v); out.append(obj_from_bm(bm, "Door", DOOR))
    for s in (-1, 1):
        out.append(tube("Flap", HIDE, [(s * W * 0.1, -L / 2 - 0.1, H * 0.85), (s * W * 0.32, -L / 2 - 0.5, H * 0.45), (s * W * 0.42, -L / 2 - 0.3, 0.3)], [0.35, 0.7, 0.9], sides=4, flat=0.25))
        out.append(tube("Rope", ROPE, [(s * W * 0.33, -L / 2 - 0.55, H * 0.45 - 0.2), (s * W * 0.33, -L / 2 - 0.55, H * 0.45 + 0.2)], [0.42, 0.42], sides=6))
    # Ridge pole sticking out both ends, crossed poles at the front, guy ropes and pegs.
    out.append(tube("Pole", POLE, [(0, L / 2 + 1.0, H + 0.25), (0, -L / 2 - 1.0, H + 0.25)], [0.22, 0.22], sides=6))
    for e in (-1, 1):
        y = e * (L / 2 + 0.2)
        for s in (-1, 1):
            out.append(tube("Pole", POLE, [(s * W * 0.5, y, 0), (-s * 0.6, y, H + 1.3)], [0.2, 0.17], sides=5))
        for s in (-1, 1):
            peg = (s * (W / 2 + 2.6), y + e * 2.4, 0.0)
            out.append(tube("Rope", ROPE, [(s * 0.3, y, H + 0.25), peg], [0.06, 0.06], sides=4))
            out.append(spike("Peg", POLE, (peg[0], peg[1], 0.6), (peg[0], peg[1], -0.5), 0.15, sides=4))
    return model("tent", out)

# ---------------------------------------------------------------- build

wolf(); goat(); crab(); turtle()
cave_crawler(); cinder_beetle(); bog_slime()
crawler_queen(); crystal_warden(); magma_golem()
skull_rock(); signboard(); tent()

if os.environ.get('PREVIEW'):
    # One small render per model, then a contact sheet: docs/previews/set4.png
    here = os.path.dirname(os.path.abspath(__file__))
    prev = os.path.join(here, '..', '..', '..', 'docs', 'previews')
    os.makedirs(prev, exist_ok=True)
    ground(2000)
    setup_render((0, 0, 1), 10, '/tmp/models/p.png', res=420, height=360, elev=0.45)
    cam = bpy.context.scene.camera
    tgt = [o for o in bpy.data.objects if o.name == 'T'][0]
    sc = bpy.context.scene
    shots = []
    for n in models:
        for m2 in models:
            for o in models[m2]: o.hide_render = (m2 != n)
        lo = Vector((1e9, 1e9, 1e9)); hi = -lo
        for o in models[n]:
            for c in o.bound_box:
                w = o.matrix_world @ Vector(c)
                lo = Vector((min(lo.x, w.x), min(lo.y, w.y), min(lo.z, w.z))); hi = Vector((max(hi.x, w.x), max(hi.y, w.y), max(hi.z, w.z)))
        ctr = (lo + hi) / 2; size = max((hi - lo).length, 1)
        tgt.location = ctr
        dist = size * 1.55
        cam.location = (ctr.x - dist * 0.55, ctr.y - dist * 0.8, ctr.z + dist * 0.42)
        sc.render.filepath = f'/tmp/models/prev_{n}.png'
        bpy.ops.render.render(write_still=True)
        shots.append(sc.render.filepath)
    from PIL import Image, ImageDraw
    cols = 5; W, H = 420, 360
    rows = (len(shots) + cols - 1) // cols
    sheet = Image.new('RGB', (cols * W, rows * H), (240, 232, 210))
    d = ImageDraw.Draw(sheet)
    for i, (n, f) in enumerate(zip(models, shots)):
        im = Image.open(f).convert('RGB'); x, y = (i % cols) * W, (i // cols) * H
        sheet.paste(im, (x, y)); d.text((x + 10, y + 8), n, fill=(40, 30, 20))
    sheet.save(os.path.join(prev, 'set4.png'))
    print("RENDERED", len(shots))
