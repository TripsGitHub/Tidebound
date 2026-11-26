import sys; sys.path.insert(0, '/tmp/models')
import bpy, bmesh, math, random
from mathutils import Vector, Euler
from lib import *

reset()
OUT = '/tmp/models/out2/'
import os; os.makedirs(OUT, exist_ok=True)

def place(o, loc=(0,0,0), rot=(0,0,0), scale=None):
    o.location = loc; o.rotation_euler = rot
    if scale: o.scale = scale
    return o

def apply(objs):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs: o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

def logmesh(length, radius, name, m, seed=1, sides=7, end=None):
    """Faceted log lying along X, centred on the origin, with lighter end caps."""
    rings = []
    for i in range(5):
        t = i/4
        rings.append((Vector((0, 0, -length/2 + length*t)), radius*(1+0.06*math.sin(i*2.1+seed)), 1))
    ob = loft(rings, sides, name, m, jitter=0.07, seed=seed)
    if end:
        ob.data.materials.append(end)
        for p in ob.data.polygons:
            if abs(p.normal.z) > 0.9: p.material_index = 1
    ob.rotation_euler = (0, math.radians(90), 0)
    return ob

BARK = mat("Bark", (110, 74, 48)); WOODEND = mat("WoodEnd", (196, 156, 104))
PLANK = mat("Plank", (150, 108, 70)); PLANK2 = mat("Plank2", (134, 94, 60))
STONE = mat("Stone", (128, 128, 134)); STONE2 = mat("Stone2", (104, 104, 112))

# ---------- Boar ----------
def boar():
    HIDE = mat("Hide", (96, 64, 46)); HIDE2 = mat("HideDark", (70, 46, 34))
    SNOUT = mat("Snout", (176, 118, 102)); TUSK = mat("Tusk", (236, 226, 200)); HOOF = mat("Hoof", (44, 34, 30))
    EYE = mat("Eye", (20, 16, 14))
    # Body: barrel along Y (forward = -Y), humped shoulders.
    rings = []
    prof = [(-2.2, 0.75, 0.0), (-1.6, 1.15, 0.15), (-0.6, 1.3, 0.25), (0.6, 1.4, 0.45), (1.5, 1.35, 0.4), (2.1, 0.9, 0.2)]
    for y, r, lift in prof:
        rings.append((Vector((0, 0, y)), r, 0.85))
    body = loft(rings, 8, "Body", HIDE, jitter=0.08, seed=3)
    body.rotation_euler = (math.radians(-90), 0, 0); body.location = (0, 0, 1.85)
    # Mane ridge along the back
    mane = cone(0, 0.45, 0.45, 6, "Mane", HIDE2, seed=4); mane.scale = (0.9, 3.4, 1); mane.location = (0, -0.6, 2.85)
    # Head: tapered toward the snout, pointing -Y
    hr = [(Vector((0,0,0)), 0.95, 0.9), (Vector((0,0,0.9)), 0.8, 0.85), (Vector((0,-0.15,1.6)), 0.5, 0.8)]
    head = loft(hr, 7, "Head", HIDE, jitter=0.06, seed=5)
    head.rotation_euler = (math.radians(105), 0, 0); head.location = (0, -2.0, 1.95)
    snout = loft([(Vector((0,0,0)), 0.42, 0.8), (Vector((0,0,0.35)), 0.42, 0.8)], 7, "Snout", SNOUT, seed=6)
    snout.rotation_euler = (math.radians(100), 0, 0); snout.location = (0, -3.5, 1.6)
    parts = [body, mane, head, snout]
    for sx in (-1, 1):
        tusk = cone(0, 0.7, 0.12, 5, f"Tusk", TUSK, seed=7); tusk.rotation_euler = (math.radians(-30), sx*math.radians(20), 0)
        tusk.location = (sx*0.38, -3.35, 1.4); parts.append(tusk)
        ear = cone(0, 0.6, 0.25, 4, "Ear", HIDE2, seed=8); ear.rotation_euler = (math.radians(20), sx*math.radians(-35), 0)
        ear.location = (sx*0.55, -2.2, 2.65); parts.append(ear)
        eye = rock(0.09, "Eye", EYE, seed=9, subdiv=0, noise=0, flat_bottom=False); eye.location = (sx*0.5, -2.95, 2.2); parts.append(eye)
    head_all = join([head, snout] + [p for p in parts if p.name.startswith(("Tusk", "Ear", "Eye"))], "Head")
    legs = []
    for i, (lx, ly) in enumerate([(-0.65, -1.3), (0.65, -1.3), (-0.65, 1.3), (0.65, 1.3)]):
        leg = loft([(Vector((0,0,0.3)), 0.24, 1), (Vector((0,0,1.25)), 0.36, 1)], 6, f"Leg{i}", HIDE2, seed=10+i)
        hoof = loft([(Vector((0,0,0)), 0.26, 1), (Vector((0,0,0.32)), 0.25, 1)], 6, "Hoof", HOOF, seed=20+i)
        l = join([leg, hoof], ["LegFL", "LegFR", "LegBL", "LegBR"][i]); l.location = (lx, ly, 0); legs.append(l)
    tail = cone(0, 0.7, 0.1, 4, "Tail", HIDE2, seed=30); tail.rotation_euler = (math.radians(120), 0, 0); tail.location = (0, 2.2, 2.15)
    torso = join([body, mane, tail], "Body")
    objs = [torso, head_all] + legs
    apply(objs)
    return objs

# ---------- Campfire ----------
def campfire():
    rng = random.Random(3); stones = []
    for i in range(9):
        a = 2*math.pi*i/9
        s = rock(0.42, f"S{i}", STONE if i % 2 else STONE2, seed=50+i, squash=(1.2, 1, 0.8), subdiv=1, noise=0.2)
        s.location = (math.cos(a)*1.6, math.sin(a)*1.6, 0.25); stones.append(s)
    ring = join(stones, "Stones")
    logs = []
    for i in range(4):
        a = i*math.pi/2 + 0.3
        l = logmesh(2.4, 0.22, f"L{i}", BARK, seed=60+i, end=WOODEND)
        l.rotation_euler = (0, math.radians(90-28), a); l.location = (math.cos(a)*-0.45, math.sin(a)*-0.45, 0.55)
        logs.append(l)
    wood = join(logs, "Logs")
    ember = rock(0.55, "Embers", mat("Ember", (255, 120, 40)), seed=70, squash=(1.3, 1.3, 0.4), subdiv=1, noise=0.15)
    ember.location = (0, 0, 0.12)
    objs = [ring, wood, ember]; apply(objs); return objs

# ---------- Slime pool ----------
def slimepool():
    rng = random.Random(5); rims = []
    for i in range(11):
        a = 2*math.pi*i/11 + rng.uniform(-0.1, 0.1)
        s = rock(rng.uniform(0.6, 0.9), f"R{i}", mat("Basalt", (58, 58, 66)), seed=80+i, squash=(1.2, 1, 0.7), subdiv=1, noise=0.22)
        s.location = (math.cos(a)*2.6, math.sin(a)*2.2, 0.25); rims.append(s)
    rim = join(rims, "Rim")
    goo = rock(2.6, "Slime", mat("SlimeGoo", (120, 214, 84)), seed=90, squash=(1.0, 0.85, 0.14), subdiv=2, noise=0.04)
    goo.location = (0, 0, 0.18)
    bubbles = []
    for i in range(4):
        b = rock(rng.uniform(0.18, 0.32), f"Bub{i}", mat("SlimeLight", (168, 236, 120)), seed=95+i, subdiv=1, noise=0.05, flat_bottom=False)
        b.location = (rng.uniform(-1.3, 1.3), rng.uniform(-1, 1), 0.5); bubbles.append(b)
    objs = [rim, goo, join(bubbles, "Bubbles")]; apply(objs); return objs

# ---------- Building pieces ----------
def woodwall():
    logs = []
    for i in range(6):
        x = -3.35 + i*1.34; h = 8.2 + random.Random(i).uniform(-0.3, 0.3)
        l = logmesh(h, 0.62, f"P{i}", BARK, seed=100+i, sides=7, end=WOODEND)
        l.rotation_euler = (0, 0, 0); l.location = (x, 0, h/2)
        tip = cone(h, 1.0, 0.62, 7, f"T{i}", WOODEND, seed=110+i, jitter=0.05)
        tip.location = (x, 0, 0)
        logs += [l, tip]
    posts = join(logs, "Posts")
    braces = []
    for z in (2.2, 6.2):
        b = logmesh(8.4, 0.28, "Brace", mat("BarkDark", (88, 58, 38)), seed=int(z*10), end=WOODEND); b.location = (0, -0.7, z); braces.append(b)
    objs = [posts, join(braces, "Braces")]; apply(objs); return objs

def wooddoor():
    planks = []
    for i in range(4):
        bpy.ops.mesh.primitive_cube_add(size=1, location=(-1.65 + i*1.1, 0, 3.75)); p = bpy.context.object
        p.scale = (1.04, 0.5, 7.4 - (i % 2)*0.15); p.data.materials.append(PLANK if i % 2 else PLANK2); planks.append(p)
    door = join(planks, "Planks")
    bars = []
    for z in (1.5, 6.0):
        bpy.ops.mesh.primitive_cube_add(size=1, location=(0, -0.4, z)); b = bpy.context.object; b.scale = (4.4, 0.3, 0.55); b.data.materials.append(mat("BarkDark", (88, 58, 38))); bars.append(b)
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, -0.42, 3.75)); d = bpy.context.object; d.scale = (0.5, 0.28, 5.4); d.rotation_euler = (0, math.radians(38), 0); d.data.materials.append(mat("BarkDark", (88, 58, 38))); bars.append(d)
    handle = rock(0.18, "Handle", mat("Iron", (60, 60, 64)), seed=120, subdiv=0, noise=0, flat_bottom=False); handle.location = (1.5, -0.6, 3.7); bars.append(handle)
    objs = [door, join(bars, "Bars")]; apply(objs); return objs

def woodfloor():
    planks = []
    for i in range(8):
        bpy.ops.mesh.primitive_cube_add(size=1, location=(-7 + i*2, 0, 0.7)); p = bpy.context.object
        p.scale = (1.92, 15.0, 0.5); p.data.materials.append(PLANK if i % 2 else PLANK2); planks.append(p)
    deck = join(planks, "Deck")
    border = []
    for (x, y, rot, L) in [(0, -7.6, 0, 16.4), (0, 7.6, 0, 16.4), (-7.6, 0, 90, 15), (7.6, 0, 90, 15)]:
        l = logmesh(L, 0.55, "B", BARK, seed=130+int(x+y), end=WOODEND)
        l.rotation_euler = (0, math.radians(90), math.radians(rot)); l.location = (x, y, 0.6); border.append(l)
    objs = [deck, join(border, "Border")]; apply(objs); return objs

# ---------- Dropped items (hand/ground size) ----------
def item_log():
    l = logmesh(2.4, 0.42, "Log", BARK, seed=140, sides=7, end=WOODEND); l.location = (0, 0, 0.42); return [l]
def item_stick():
    rings = [(Vector((0.08*math.sin(t*3), 0, -1.1 + 2.2*t)), 0.09, 1) for t in [i/6 for i in range(7)]]
    s = loft(rings, 5, "Stick", mat("StickWood", (128, 90, 56)), seed=141); s.rotation_euler = (0, math.radians(90), 0)
    tw = cone(0, 0.6, 0.06, 4, "Twig", mat("StickWood", (128, 90, 56)), seed=142); tw.rotation_euler = (0, math.radians(50), 0); tw.location = (0.3, 0, 0.05)
    o = join([s, tw], "Stick"); o.location.z = 0.1; return [o]
def item_leaves():
    leaves = []
    for i in range(3):
        bm = bmesh.new()
        pts = [(0, -0.7, 0), (0.32, -0.2, 0.06), (0.26, 0.35, 0.04), (0, 0.75, 0), (-0.26, 0.35, 0.04), (-0.32, -0.2, 0.06)]
        vs = [bm.verts.new(p) for p in pts]; mid = bm.verts.new((0, 0, -0.06))
        for k in range(6): bm.faces.new((vs[k], vs[(k+1) % 6], mid))
        lf = obj_from_bm(bm, f"Leaf{i}", mat("LeafItem", (82, 150, 64) if i != 1 else (98, 168, 74)))
        lf.rotation_euler = (0, 0, i*2.1); lf.location = (0, 0, 0.1 + i*0.05)
        sol = lf.modifiers.new("S", 'SOLIDIFY'); sol.thickness = 0.05
        leaves.append(lf)
    return [join(leaves, "Leaves")]
def item_stone():
    s = rock(0.55, "Stone", STONE, seed=3, squash=(1.1, 0.9, 0.8), subdiv=1, noise=0.18); s.location.z = 0.2; return [s]
def item_berries():
    bs = []
    rng = random.Random(150)
    for i in range(5):
        b = rock(0.3, f"B{i}", mat("Berry", (196, 36, 60)), seed=150+i, subdiv=1, noise=0.05, flat_bottom=False)
        b.location = (rng.uniform(-0.35, 0.35), rng.uniform(-0.35, 0.35), 0.3 + (0.35 if i == 4 else 0)); bs.append(b)
    leaf = cone(0.85, 0.08, 0.4, 5, "Leaf", mat("LeafItem", (82, 150, 64)), seed=155)
    return [join(bs, "Berries"), leaf]
def meat(color, name):
    bone = loft([(Vector((0,0,0)), 0.1, 1), (Vector((0,0,1.0)), 0.1, 1)], 6, "Bone", mat("Bone", (236, 228, 208)), seed=160)
    bone.rotation_euler = (0, math.radians(90), 0); bone.location = (0.55, 0, 0.35)
    knob = rock(0.17, "Knob", mat("Bone", (236, 228, 208)), seed=161, subdiv=1, noise=0.05, flat_bottom=False); knob.location = (1.55, 0, 0.35)
    flesh = rock(0.48, "Flesh", mat(name, color), seed=162, squash=(1.3, 0.95, 0.8), subdiv=1, noise=0.12); flesh.location = (0.12, 0, 0.35)
    return [flesh, join([bone, knob], "Bone")]
def item_leather():
    bm = bmesh.new(); rng = random.Random(170); vs = []
    for k in range(10):
        a = 2*math.pi*k/10; r = (1.0 if k % 2 else 0.75) * rng.uniform(0.9, 1.1)
        vs.append(bm.verts.new((math.cos(a)*r*1.2, math.sin(a)*r*0.8, rng.uniform(0, 0.08))))
    c = bm.verts.new((0, 0, 0.1))
    for k in range(10): bm.faces.new((vs[k], vs[(k+1) % 10], c))
    h = obj_from_bm(bm, "Hide", mat("Leather", (140, 88, 52))); sol = h.modifiers.new("S", 'SOLIDIFY'); sol.thickness = 0.08
    h.location.z = 0.05; return [h]
def item_coconut():
    c = rock(0.45, "Coconut", mat("Coconut", (104, 72, 44)), seed=180, squash=(1, 1, 1.05), subdiv=1, noise=0.06, flat_bottom=False); c.location.z = 0.45; return [c]

models = {
    'boar': boar(), 'campfire': campfire(), 'slimepool': slimepool(),
    'woodwall': woodwall(), 'wooddoor': wooddoor(), 'woodfloor': woodfloor(),
    'log': item_log(), 'stick': item_stick(), 'leaves': item_leaves(), 'stone': item_stone(),
    'berries': item_berries(), 'raw_meat': meat((205, 92, 92), "MeatRaw"), 'cooked_meat': meat((150, 82, 44), "MeatCooked"),
    'leather': item_leather(), 'coconut': item_coconut(),
}
for name, objs in models.items():
    export(OUT + name + '.obj', objs)

def dummy(x, y):
    skin = mat("Skin", (238, 196, 160)); shirt = mat("Shirt", (60, 110, 170)); pants = mat("Pants", (50, 50, 60))
    for (px, py, pz), (sx, sy, sz), m in [((0,0,4.9),(1.1,1.1,1.1),skin), ((0,0,3.4),(2,1,1.9),shirt), ((-1.5,0,3.4),(0.95,1,1.9),shirt), ((1.5,0,3.4),(0.95,1,1.9),shirt), ((-0.5,0,1.2),(0.95,1,2.4),pants), ((0.5,0,1.2),(0.95,1,2.4),pants)]:
        bpy.ops.mesh.primitive_cube_add(size=1, location=(x+px, y+py, pz)); c = bpy.context.object; c.scale = (sx, sy, sz); c.data.materials.append(m)

def shift(objs, x, y, rz=0):
    for o in objs:
        o.rotation_euler.z = rz; o.location = (o.location.x + x, o.location.y + y, o.location.z)

MODE = sys.argv[-1] if len(sys.argv) > 1 else 'world'
if MODE == 'world':
    shift(models['woodfloor'], -6, 8)
    shift(models['woodwall'], -6, 16.5)
    shift(models['wooddoor'], 3.5, 15.9)
    shift(models['campfire'], 6, 2)
    shift(models['boar'], 10, 4, math.radians(-120))
    shift(models['slimepool'], 18, 10)
    dummy(-1, 4); dummy(15.5, 1)
    for n in ['log','stick','leaves','stone','berries','raw_meat','cooked_meat','leather','coconut']:
        for o in models[n]: o.hide_render = True
    ground(200)
    setup_render((5, 9, 3.5), 44, OUT + 'set2-world.png', res=1600, height=900, elev=0.42)
else:
    for n, objs in models.items():
        if n in ['boar','campfire','slimepool','woodwall','wooddoor','woodfloor']:
            for o in objs: o.hide_render = True
    items = ['log','stick','leaves','stone','berries','raw_meat','cooked_meat','leather','coconut']
    for i, n in enumerate(items):
        shift(models[n], (i % 5)*3.2 - 6.4, -(i // 5)*3.2 + 1.6)
    ground(200)
    setup_render((0, 0, 0.3), 16, OUT + 'set2-items.png', res=1400, height=800, elev=0.75)
bpy.ops.render.render(write_still=True)
print("DONE")
