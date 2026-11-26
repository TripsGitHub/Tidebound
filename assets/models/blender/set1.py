import sys; sys.path.insert(0, '/tmp/models')
import bpy, bmesh, math, random
from mathutils import Vector
from lib import *

reset()
OUT = '/tmp/models/out/'

def offset(objs, dx, dy=0):
    for o in objs: o.location.x += dx; o.location.y += dy

def club():
    rng = random.Random(4); rings = []
    n, L = 14, 3.6
    for i in range(n+1):
        t = i/n
        r = 0.13 + 0.26*t**1.5
        if t > 0.86:
            k = (t-0.86)/0.14; r *= math.sqrt(max(0.05, 1-k*k*0.9))
        rings.append((Vector((0.14*t*t, 0, L*t)), r, 1.0))
    wood = loft(rings, 8, "Wood", mat("ClubWood", (112, 52, 32)), jitter=0.07, seed=4, twist=0.25)
    wrap = loft([(Vector((0,0,0.1)), 0.16, 1), (Vector((0,0,0.9)), 0.16, 1)], 8, "Wrap", mat("Wrap", (70, 46, 30)))
    return [wood, wrap]

def rocktool():
    return [rock(0.55, "Stone", mat("ToolStone", (132, 132, 138)), seed=3, squash=(1.1, 0.9, 0.8), subdiv=1, noise=0.18, flat_bottom=False)]

def pine(seed=2):
    rng = random.Random(seed)
    trunk = loft([(Vector((0,0,-0.5)), 0.75, 1), (Vector((0,0,3.2)), 0.55, 1)], 6, "Trunk", mat("Bark", (92, 62, 42)), jitter=0.06, seed=seed)
    tiers = []
    spec = [(2.2, 4.6, 4.6, (70, 132, 62)), (4.6, 4.4, 3.8, (78, 142, 66)), (7.0, 4.2, 3.0, (88, 154, 72)), (9.3, 4.4, 2.1, (98, 166, 78))]
    for i, (z, h, r, col) in enumerate(spec):
        tiers.append(cone(z, h, r, 10, f"Leaves{i+1}", mat(f"Leaf{i}", col), seed=seed*10+i,
                          tip_offset=(rng.uniform(-0.25, 0.25), rng.uniform(-0.25, 0.25)), jitter=0.1, star=0.28, droop=0.12))
    return [trunk] + tiers

def palm(seed=5):
    rng = random.Random(seed)
    rings = []; n = 12; H = 13
    top = None
    for i in range(n+1):
        t = i/n
        x = 2.2*t*t
        r = 0.62 - 0.22*t
        r *= 1.12 if i % 2 == 0 else 0.94   # segmented bark
        rings.append((Vector((x, 0, H*t)), r, 1.0))
    trunk = loft(rings, 7, "Trunk", mat("PalmBark", (146, 108, 70)), jitter=0.04, seed=seed)
    top = Vector((2.2, 0, H))
    fronds = []
    for f in range(8):
        a = 2*math.pi*f/8 + rng.uniform(-0.2, 0.2)
        d = Vector((math.cos(a), math.sin(a), 0)); side = Vector((-d.y, d.x, 0))
        bm = bmesh.new(); segs = 6; Lf = rng.uniform(5.5, 6.5)
        mids, lefts, rights = [], [], []
        for s in range(segs+1):
            t = s/segs
            p = top + d*(Lf*t) + Vector((0, 0, 1.3*t - 4.6*t*t))
            w = 1.3*math.sin(math.pi*min(1, t*1.15)) + 0.05
            fold = Vector((0, 0, -0.35*w))
            mids.append(bm.verts.new(p))
            lefts.append(bm.verts.new(p + side*w + fold))
            rights.append(bm.verts.new(p - side*w + fold))
        for s in range(segs):
            bm.faces.new((mids[s], lefts[s], lefts[s+1], mids[s+1]))
            bm.faces.new((mids[s], mids[s+1], rights[s+1], rights[s]))
        fronds.append(obj_from_bm(bm, f"Frond{f}", mat("Frond", (82, 156, 66) if f % 2 else (96, 170, 74))))
    leaves = join(fronds, "Leaves")
    # Make fronds double-sided in Roblox: add a solidify so they have thickness.
    mod = leaves.modifiers.new("Solid", 'SOLIDIFY'); mod.thickness = 0.12
    nuts = []
    for k in range(3):
        a = 2*math.pi*k/3 + 0.4
        nuts.append(rock(0.42, f"Nut{k}", mat("Coconut", (104, 72, 44)), seed=20+k, squash=(1,1,1.05), subdiv=1, noise=0.06, flat_bottom=False))
        nuts[-1].location = top + Vector((math.cos(a)*0.55, math.sin(a)*0.55, -0.55))
    nuts = join(nuts, "Coconuts")
    return [trunk, leaves, nuts]

def mossify(ob, threshold=0.8):
    """Faces that point up get the moss colour, like grass growing on top of rock."""
    ob.data.materials.append(mat("Moss", (92, 150, 70)))
    for p in ob.data.polygons:
        n = ob.matrix_world.to_3x3() @ p.normal
        if n.z > threshold:
            p.material_index = 1

def boulder(seed=7):
    main = rock(3.4, "Rock", mat("Basalt", (58, 58, 66)), seed=seed+20, squash=(1.15, 0.95, 1.05), subdiv=1, noise=0.34)
    main.location.z = 3.4*1.05*0.35
    third = rock(1.3, "Rock3", mat("Basalt", (58, 58, 66)), seed=seed+5, squash=(1, 1.1, 0.9), subdiv=1, noise=0.25)
    third.location = (-2.9, 1.8, 1.3*0.9*0.35)
    side = rock(1.7, "Rock2", mat("Basalt", (58, 58, 66)), seed=seed+1, squash=(1.1, 1.0, 0.8), subdiv=1, noise=0.2)
    side.location = (3.2, -1.4, 1.7*0.8*0.35)
    ob = join([main, side, third], "Rock")
    mossify(ob)
    return [ob]

def bush(seed=9):
    rng = random.Random(seed); blobs = []
    for i in range(5):
        r = rng.uniform(1.1, 1.6)
        b = rock(r, f"B{i}", mat("BushLeaf", (64, 128, 56) if i % 2 else (76, 142, 62)), seed=seed+i, squash=(1, 1, 0.85), subdiv=1, noise=0.15, flat_bottom=False)
        a = 2*math.pi*i/5; b.location = (math.cos(a)*1.1, math.sin(a)*1.1, 1.0 + rng.uniform(0, 0.6))
        blobs.append(b)
    top = rock(1.4, "Btop", mat("BushLeaf", (76, 142, 62)), seed=seed+9, squash=(1,1,0.85), subdiv=1, noise=0.15, flat_bottom=False)
    top.location = (0, 0, 2.1); blobs.append(top)
    leaves = join(blobs, "Leaves")
    berries = []
    for k in range(9):
        a = rng.uniform(0, 2*math.pi); z = rng.uniform(1.2, 2.8)
        rr = 1.75 - abs(z-2)*0.45
        b = rock(0.22, f"Berry{k}", mat("Berry", (196, 36, 60)), seed=40+k, squash=(1,1,1), subdiv=0, noise=0.05, flat_bottom=False)
        b.location = (math.cos(a)*rr, math.sin(a)*rr, z); berries.append(b)
    return [leaves, join(berries, "Berries")]

models = {
    'club': (club(), 0, 1.0),
    'rock': (rocktool(), 0, 1.0),
    'pine': (pine(), 0, 1.0),
    'palm': (palm(), 0, 1.0),
    'boulder': (boulder(), 0, 1.0),
    'bush': (bush(), 0, 1.0),
}

# Sizes relative to a 5.5-stud Roblox player.
SCALE = {'pine': 1.5, 'palm': 1.35, 'boulder': 1.25, 'bush': 1.0, 'club': 0.9, 'rock': 1.0}
for name, (objs, _, _) in models.items():
    k = SCALE[name]
    for o in objs:
        o.location = o.location * k; o.scale = (k, k, k)
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs: o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

# Export each model on its own, centred at the origin.
for name, (objs, _, _) in models.items():
    export(OUT + name + '.obj', objs)

def dummy(x, y, holding=None):
    # Blocky R15-sized player: 5.5 studs tall.
    skin = mat("Skin", (238, 196, 160)); shirt = mat("Shirt", (60, 110, 170)); pants = mat("Pants", (50, 50, 60))
    parts = [((0, 0, 4.9), (1.1, 1.1, 1.1), skin), ((0, 0, 3.4), (2, 1, 1.9), shirt),
             ((-1.5, 0, 3.4), (0.95, 1, 1.9), shirt), ((1.5, 0, 3.4), (0.95, 1, 1.9), shirt),
             ((-0.5, 0, 1.2), (0.95, 1, 2.4), pants), ((0.5, 0, 1.2), (0.95, 1, 2.4), pants)]
    for (px, py, pz), (sx, sy, sz), m in parts:
        bpy.ops.mesh.primitive_cube_add(size=1, location=(x+px, y+py, pz)); c = bpy.context.object
        c.scale = (sx, sy, sz); c.data.materials.append(m)

# Lineup for the preview: big things in back, hand items scaled up in front.
layout = {'pine': (-11, 6), 'palm': (-2, 7), 'boulder': (8, 5), 'bush': (15, -5), 'club': (-3, -6), 'rock': (2, -6)}
for name, (x, y) in layout.items():
    objs = models[name][0]
    offset(objs, x, y)
for (x, y) in [(-17, 0), (-2, 0), (12, 0), (22.5, 0), (32, 0)]:
    dummy(x, y)
ground(160)
setup_render((4, 0, 7), 62, OUT + 'lineup.png', res=1600, height=700, elev=0.18)
bpy.ops.render.render(write_still=True)
print("DONE")
