# Set 3: armour, swords, harvesters and bags.
#
# Armour comes in four styles (wood, stone, forged metal, crystal). Every tier uses
# its style's meshes and the game recolours them, so each part is named by its role:
#   Plate  - the main armour/blade colour      Trim   - bands, rivets, guards, rope
#   Accent - gems, plumes, leaves, horns       Strap  - leather
#   Handle - wooden handles (never recoloured)
# Every model also has an invisible "Bounds" box centred on its origin. Meshes.build
# uses that box instead of the visible bounds, so:
#   armour: the origin is the centre of the body part it's worn on, and the box is the
#           R15 reference part size times FACTOR, so fit = part.Size * FACTOR fits any avatar.
#   tools:  the origin is the grip. Bags: the origin is the middle of the bag.
#
# Run: python3 set3.py            (writes /tmp/models/out3/*.obj and bounds.json)
#      PREVIEW=1 python3 set3.py  (also renders the preview sheets)
import sys, os, math, random, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy, bmesh
from mathutils import Vector as V, Matrix, Euler
from lib import reset, mat, obj_from_bm

reset()
OUT = os.environ.get('OUT', '/tmp/models/out3/')
os.makedirs(OUT, exist_ok=True)
PREVIEW = os.environ.get('PREVIEW')
SAMPLES = int(os.environ.get('SAMPLES', '24'))

# R15 reference part sizes in studs (Roblox X, Y, Z = width, height, depth).
REF = {
    'Head': (1.2, 1.2, 1.2), 'UpperTorso': (2, 1.6, 1), 'LowerTorso': (2, 0.4, 1),
    'UpperArm': (1, 1.169, 1), 'UpperLeg': (1, 1.217, 1), 'LowerLeg': (1, 1.193, 1),
}
PIECE_PART = {'helmet': 'Head', 'chest': 'UpperTorso', 'pauldron': 'UpperArm',
              'hip': 'LowerTorso', 'thigh': 'UpperLeg', 'boot': 'LowerLeg'}

# Default colours per style (the game recolours per tier; these are for the OBJ).
FAMILY = {
    'wood':    {'Plate': (150, 108, 66), 'Trim': (196, 170, 118), 'Accent': (96, 132, 58), 'Strap': (92, 62, 40), 'Handle': (110, 76, 48)},
    'stone':   {'Plate': (128, 126, 122), 'Trim': (110, 72, 44), 'Accent': (232, 222, 196), 'Strap': (96, 62, 40), 'Handle': (110, 76, 48)},
    'metal':   {'Plate': (206, 210, 218), 'Trim': (120, 124, 134), 'Accent': (70, 120, 210), 'Strap': (88, 58, 38), 'Handle': (110, 76, 48)},
    'crystal': {'Plate': (170, 236, 240), 'Trim': (60, 70, 86), 'Accent': (220, 250, 255), 'Strap': (52, 44, 52), 'Handle': (60, 54, 60)},
}
BAGS = {'Pouch': (128, 82, 48), 'Flap': (104, 66, 40), 'Buckle': (196, 168, 96), 'Strap': (78, 52, 34),
        'Roll': (176, 150, 108), 'Fur': (172, 140, 104), 'Frame': (120, 84, 52), 'Canvas': (150, 132, 96)}

MAT = {}
CUR = []
def use(family):
    global MAT
    cols = FAMILY[family] if family in FAMILY else BAGS
    MAT = {k: mat(f'{family}_{k}', v) for k, v in cols.items()}
    MAT['Bounds'] = mat('Bounds', (255, 0, 255))

# ---------------------------------------------------------------- geometry

def xform(bm, loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1)):
    M = Matrix.Translation(V(loc)) @ Euler(rot).to_matrix().to_4x4() @ Matrix.Diagonal((*scale, 1))
    bmesh.ops.transform(bm, matrix=M, verts=bm.verts)

def make(bm, role):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = obj_from_bm(bm, role, MAT[role])
    CUR.append(ob)
    return ob

def se(a, rx, ry, n):
    """Point on a superellipse (n=2 is an ellipse, higher is boxier)."""
    c, s = math.cos(a), math.sin(a)
    e = 2 / n
    return math.copysign(abs(c) ** e, c) * rx, math.copysign(abs(s) ** e, s) * ry

def lathe(role, prof, az=(0, 360), nu=16, thick=0.05, n=2.0, loc=(0, 0, 0), rot=(0, 0, 0),
          seed=0, jitter=0.0, cap_top=False, offset=0.0):
    """Surface swept around Z. prof: [(z, rx, ry)] bottom to top. az in degrees: 0 = +X, 90 = front (+Y)."""
    rng = random.Random(seed)
    full = abs(az[1] - az[0]) >= 359.9
    cols = nu if full else nu + 1
    bm = bmesh.new(); grid = []
    jit = [1 + rng.uniform(-jitter, jitter) for _ in range(cols * len(prof))]
    for r, (z, rx, ry) in enumerate(prof):
        row = []
        for i in range(cols):
            a = math.radians(az[0] + offset + (az[1] - az[0]) * i / nu)
            x, y = se(a, rx, ry, n)
            j = jit[r * cols + i]
            row.append(bm.verts.new((x * j, y * j, z)))
        grid.append(row)
    for r in range(len(grid) - 1):
        for i in range(nu):
            i2 = (i + 1) % cols if full else i + 1
            bm.faces.new((grid[r][i], grid[r][i2], grid[r + 1][i2], grid[r + 1][i]))
    if cap_top and full:
        bm.faces.new(grid[-1])
    if thick:
        bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=thick)
    xform(bm, loc, rot)
    return make(bm, role)

def dome(rx, ry, z0, h, nv=5, power=0.6, el0=0.0):
    """Profile for a dome: rings from the rim (z0) up to near the top."""
    out = []
    for k in range(nv):
        t = math.radians(el0 + (86 - el0) * k / (nv - 1))
        c = math.cos(t) ** power
        out.append((z0 + h * math.sin(t), rx * c, ry * c))
    return out

def tube(role, pts, sides=6, flat=1.0, roll=0.0, jitter=0.0, seed=0, cap0=True):
    """Sweep along a polyline. pts: [(pos, radius)]; a last radius of 0 makes a point."""
    rng = random.Random(seed)
    bm = bmesh.new(); rows = []; tip = None; prev = None
    for k, (p, r) in enumerate(pts):
        p = V(p)
        if k == 0: t = V(pts[1][0]) - p
        elif k == len(pts) - 1: t = p - V(pts[k - 1][0])
        else: t = V(pts[k + 1][0]) - V(pts[k - 1][0])
        t.normalize()
        if prev is None:
            ref = V((0, 0, 1)) if abs(t.z) < 0.9 else V((1, 0, 0))
            n1 = t.cross(ref).normalized()
        else:
            n1 = (prev - t * prev.dot(t)).normalized()
        prev = n1
        n2 = t.cross(n1)
        if r <= 1e-6:
            tip = bm.verts.new(p); continue
        row = []
        for s in range(sides):
            a = roll + 2 * math.pi * s / sides
            j = 1 + rng.uniform(-jitter, jitter)
            row.append(bm.verts.new(p + (n1 * math.cos(a) * flat + n2 * math.sin(a)) * r * j))
        rows.append(row)
    for i in range(len(rows) - 1):
        for s in range(sides):
            bm.faces.new((rows[i][s], rows[i][(s + 1) % sides], rows[i + 1][(s + 1) % sides], rows[i + 1][s]))
    if cap0: bm.faces.new(list(reversed(rows[0])))
    if tip is not None:
        for s in range(sides): bm.faces.new((rows[-1][s], rows[-1][(s + 1) % sides], tip))
    else:
        bm.faces.new(rows[-1])
    return make(bm, role)

def box(role, size, loc=(0, 0, 0), rot=(0, 0, 0), bevel=0.0, taper=(1, 1), jitter=0.0, seed=0, segs=1):
    rng = random.Random(seed)
    bm = bmesh.new(); bmesh.ops.create_cube(bm, size=1)
    for v in bm.verts:
        x, y, z = v.co; t = z + 0.5
        x *= 1 + (taper[0] - 1) * t; y *= 1 + (taper[1] - 1) * t
        v.co = V((x * size[0] * (1 + rng.uniform(-jitter, jitter)),
                  y * size[1] * (1 + rng.uniform(-jitter, jitter)),
                  z * size[2] * (1 + rng.uniform(-jitter, jitter))))
    if bevel:
        bmesh.ops.bevel(bm, geom=bm.edges[:], offset=bevel, segments=segs, affect='EDGES', profile=0.5)
    xform(bm, loc, rot)
    return make(bm, role)

def gem(role, r, loc, squash=(1, 1, 1), rot=(0, 0, 0), sub=0):
    bm = bmesh.new(); bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=r)
    xform(bm, loc, rot, squash)
    return make(bm, role)

def shard(role, base, d, length, r, sides=5, seed=0):
    d = V(d).normalized(); b = V(base)
    return tube(role, [(b - d * 0.05, r * 0.6), (b + d * length * 0.2, r), (b + d * length * 0.72, r * 0.86),
                       (b + d * length, 0)], sides=sides, roll=seed * 0.7)

def prism(role, outline, thick, loc=(0, 0, 0), edge=None, jitter=0.0, seed=0):
    """Flat shape in the YZ plane, extruded along X. edge: indices of outline points that
    get sharpened (thickness * 0.25)."""
    rng = random.Random(seed)
    bm = bmesh.new(); a = []; b = []
    for i, (y, z) in enumerate(outline):
        y += rng.uniform(-jitter, jitter); z += rng.uniform(-jitter, jitter)
        t = thick * (0.25 if edge and i in edge else 1) / 2
        a.append(bm.verts.new((-t, y, z))); b.append(bm.verts.new((t, y, z)))
    n = len(outline)
    bm.faces.new(a); bm.faces.new(list(reversed(b)))
    for i in range(n):
        bm.faces.new((a[i], a[(i + 1) % n], b[(i + 1) % n], b[i]))
    bmesh.ops.triangulate(bm, faces=bm.faces[:], ngon_method='EAR_CLIP')
    xform(bm, loc)
    return make(bm, role)

def rivets(role, z, rx, ry, n, count, r=0.035, az=(0, 360), lift=0.0):
    full = abs(az[1] - az[0]) >= 359.9
    for i in range(count):
        f = (i + 0.5) / count if full else i / max(1, count - 1)
        a = math.radians(az[0] + (az[1] - az[0]) * f)
        x, y = se(a, rx, ry, n)
        gem(role, r, (x, y, z + lift), squash=(1, 1, 0.8))

def mirror_x(fn):
    for sx in (-1, 1): fn(sx)

# ---------------------------------------------------------------- pieces

LIB = {}       # model name -> list of objects (kept for previews)
BOUNDS = {}    # armour piece -> factor (bounds / reference size), tools/bags -> bounds size
HIDDEN = None

def finish(name, family, kind, ref=None):
    """Join objects by role, add the Bounds box, export, and stash for previews."""
    global CUR, HIDDEN
    by = {}
    for o in CUR: by.setdefault(o.name.split('.')[0], []).append(o)
    objs = []
    for role, os_ in by.items():
        if len(os_) > 1:
            bpy.ops.object.select_all(action='DESELECT')
            for o in os_: o.select_set(True)
            bpy.context.view_layer.objects.active = os_[0]
            bpy.ops.object.join()
        os_[0].name = role
        objs.append(os_[0])
    lo = V((1e9,) * 3); hi = V((-1e9,) * 3)
    for o in objs:
        for v in o.data.vertices:
            lo = V(map(min, lo, v.co)); hi = V(map(max, hi, v.co))
    ext = V(map(lambda a, b: max(abs(a), abs(b)), lo, hi))  # half-size, symmetric about the origin
    if kind == 'armour':
        rx, ry, rz = REF[ref]  # Roblox width, height, depth -> Blender x, z, y
        fx = math.ceil((2 * ext.x / rx + 0.04) * 20) / 20
        fy = math.ceil((2 * ext.z / ry + 0.04) * 20) / 20
        fz = math.ceil((2 * ext.y / rz + 0.04) * 20) / 20
        BOUNDS[name] = (fx, fy, fz)
        size = (rx * fx, rz * fz, ry * fy)
    else:
        size = tuple(math.ceil((2 * e + 0.04) * 20) / 20 for e in ext)
        BOUNDS[name] = (size[0], size[2], size[1])  # Roblox X, Y, Z
    CUR = []
    bnd = box('Bounds', size)
    CUR = []
    objs.append(bnd)
    for o in objs:
        o.data.name = o.name
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs: o.select_set(True)
    bpy.ops.wm.obj_export(filepath=OUT + name + '.obj', export_selected_objects=True, export_materials=True,
                          up_axis='Y', forward_axis='NEGATIVE_Z', apply_modifiers=True)
    if HIDDEN is None:
        HIDDEN = bpy.data.collections.new('lib'); bpy.context.scene.collection.children.link(HIDDEN)
    for o in objs:
        for c in o.users_collection: c.objects.unlink(o)
        HIDDEN.objects.link(o)
    HIDDEN.hide_render = True
    LIB[name] = (family, objs)

# ---- helmets (on Head, 1.2 cube; the head fills +-0.6) ----

def helmet_wood():
    lathe('Plate', dome(0.8, 0.8, -0.04, 0.8, nv=5, power=0.5), nu=10, n=2.6, jitter=0.03, seed=2, thick=0.06, cap_top=True)
    lathe('Plate', [(-0.12, 0.9, 0.9), (-0.03, 0.84, 0.84)], nu=10, n=2.6, thick=0.05, seed=3, jitter=0.03)
    lathe('Trim', [(0.0, 0.85, 0.85), (0.13, 0.84, 0.84)], nu=14, n=2.6, thick=0.05)
    gem('Trim', 0.08, (0.86, -0.12, 0.06), squash=(0.8, 1, 1))
    for i, (dy, dz, ang) in enumerate([(0.0, 0.0, 0.2), (-0.12, 0.02, -0.25), (0.1, 0.02, 0.6)]):
        b = V((0.86, -0.14 + dy, 0.08 + dz))
        d = V((0.15, -0.35 + ang * 0.3, 0.9)).normalized()
        tube('Accent', [(b, 0.02), (b + d * 0.14, 0.1), (b + d * 0.34, 0.08), (b + d * 0.5, 0)], sides=4, flat=0.18)
    tube('Strap', [((0.66, 0.0, -0.02), 0.05), ((0.6, 0.12, -0.38), 0.05), ((0.36, 0.42, -0.62), 0.05),
                   ((0, 0.5, -0.68), 0.05), ((-0.36, 0.42, -0.62), 0.05), ((-0.6, 0.12, -0.38), 0.05),
                   ((-0.66, 0.0, -0.02), 0.05)], sides=4, flat=0.35)

def helmet_stone():
    lathe('Plate', dome(0.82, 0.82, -0.04, 0.8, nv=4, power=0.5), nu=8, n=2.6, jitter=0.07, seed=5, thick=0.08, cap_top=True)
    box('Plate', (1.3, 0.28, 0.24), (0, 0.76, 0.1), (math.radians(12), 0, 0), bevel=0.05, jitter=0.05, seed=6)
    lathe('Strap', [(-0.05, 0.86, 0.86), (0.1, 0.85, 0.85)], nu=12, n=2.6, thick=0.04)
    def horn(sx):
        tube('Accent', [((sx * 0.66, 0.05, 0.26), 0.13), ((sx * 0.98, 0.04, 0.4), 0.11),
                        ((sx * 1.12, 0.0, 0.7), 0.08), ((sx * 1.06, -0.08, 0.95), 0.04), ((sx * 0.96, -0.12, 1.05), 0)], sides=6)
        box('Trim', (0.16, 0.2, 0.18), (sx * 0.8, 0.04, 0.3), bevel=0.03, jitter=0.1, seed=7)
    mirror_x(horn)
    for x in (-0.25, 0.25):
        box('Trim', (0.12, 0.08, 0.16), (x, 0.88, 0.04), bevel=0.02, jitter=0.1, seed=8)

def helmet_metal():
    lathe('Plate', dome(0.8, 0.81, -0.04, 0.8, nv=6, power=0.5), nu=18, n=2.6, thick=0.05, cap_top=True)
    # Cheek and neck guard: everything but the face.
    lathe('Plate', [(-0.6, 0.86, 0.87), (-0.3, 0.83, 0.84), (-0.03, 0.81, 0.82)], az=(128, 412), nu=16, n=2.6, thick=0.05)
    box('Plate', (0.13, 0.07, 0.46), (0, 0.85, -0.14), bevel=0.02, taper=(1.3, 1))
    lathe('Trim', [(-0.08, 0.84, 0.85), (0.1, 0.835, 0.845)], nu=18, n=2.6, thick=0.04)
    rivets('Trim', 0.01, 0.85, 0.86, 2.6, 10)
    # Crest ridge from brow to nape, and a plume behind it.
    pts = []
    for k in range(9):
        t = math.radians(20 + 150 * k / 8)  # angle from +Y over the top to the back
        pts.append(((0, 0.84 * math.cos(t), -0.04 + 0.84 * math.sin(t) ** 0.9), 0.06))
    tube('Trim', pts, sides=4, flat=1.6)
    tube('Accent', [((0, 0.2, 0.86), 0.06), ((0, -0.15, 0.95), 0.12), ((0, -0.55, 0.85), 0.13),
                    ((0, -0.86, 0.5), 0.1), ((0, -0.95, 0.12), 0.05), ((0, -0.96, -0.05), 0)], sides=6, flat=0.55)

def helmet_crystal():
    lathe('Plate', dome(0.84, 0.84, -0.04, 0.8, nv=3, power=0.45), nu=6, n=2.0, offset=30, thick=0.07, cap_top=True)
    lathe('Trim', [(-0.12, 0.9, 0.9), (0.1, 0.87, 0.87)], nu=6, offset=30, thick=0.06)
    lathe('Trim', [(-0.55, 0.9, 0.9), (-0.1, 0.88, 0.88)], az=(150, 390), nu=4, thick=0.06)
    for i, (a, length, r, tilt) in enumerate([(90, 0.75, 0.11, 0.15), (55, 0.5, 0.08, 0.45), (125, 0.5, 0.08, 0.45),
                                              (15, 0.4, 0.07, 0.7), (165, 0.4, 0.07, 0.7), (270, 0.45, 0.08, 0.5)]):
        ar = math.radians(a)
        base = V((math.cos(ar) * 0.64, math.sin(ar) * 0.64, 0.4))
        d = V((math.cos(ar) * tilt, math.sin(ar) * tilt, 1))
        shard('Accent', base, d, length, r, seed=i)

# ---- chest (on UpperTorso, 2 x 1.6 x 1) + pauldron (on the right UpperArm, outward +X) ----

def shoulder_straps(z=0.8):
    for sx in (-1, 1):
        tube('Strap', [((sx * 0.62, 0.68, z - 0.06), 0.09), ((sx * 0.62, 0.3, z + 0.1), 0.09),
                       ((sx * 0.62, -0.3, z + 0.1), 0.09), ((sx * 0.62, -0.68, z - 0.06), 0.09)], sides=4, flat=0.35)

def chest_wood():
    n = 20
    pts = [se(2 * math.pi * i / n, 1.12, 0.64, 4) for i in range(n)]
    rng = random.Random(4)
    for i in range(n):
        x0, y0 = pts[i - 1]; x1, y1 = pts[(i + 1) % n]; x, y = pts[i]
        ang = math.atan2(y1 - y0, x1 - x0)
        w = math.hypot(x1 - x0, y1 - y0) * 0.55
        h = 1.5 + rng.uniform(-0.08, 0.1)
        box('Plate', (w, 0.09, h), (x, y, -0.04 + rng.uniform(-0.04, 0.04)), (rng.uniform(-0.03, 0.03), 0, ang),
            bevel=0.025, jitter=0.04, seed=i)
    for z in (0.42, -0.42):
        lathe('Trim', [(z - 0.06, 1.2, 0.72), (z + 0.06, 1.2, 0.72)], nu=24, n=4, thick=0.06)
    shoulder_straps()
    for i, (dx, ang) in enumerate([(0, 0.1), (0.1, -0.5), (-0.08, 0.6)]):
        b = V((-0.45 + dx, 0.76, 0.42))
        d = V((ang * 0.5, 0.15, 1)).normalized()
        tube('Accent', [(b, 0.02), (b + d * 0.16, 0.11), (b + d * 0.36, 0.09), (b + d * 0.52, 0)], sides=4, flat=0.18)

def chest_stone():
    box('Plate', (1.75, 0.18, 1.32), (0, 0.6, 0.04), (math.radians(-4), 0, math.radians(2)), bevel=0.06, jitter=0.05, seed=11)
    box('Plate', (0.9, 0.14, 0.6), (-0.42, 0.72, 0.38), (0, 0, math.radians(-6)), bevel=0.05, jitter=0.08, seed=12)
    box('Plate', (1.82, 0.18, 1.36), (0, -0.6, 0.02), bevel=0.06, jitter=0.05, seed=13)
    for sx in (-1, 1):
        box('Plate', (0.18, 0.95, 1.05), (sx * 1.04, 0, -0.06), bevel=0.05, jitter=0.06, seed=14 + sx)
    lathe('Strap', [(-0.62, 1.2, 0.74), (-0.46, 1.2, 0.74)], nu=24, n=4, thick=0.05)
    for sx in (-1, 1):
        tube('Strap', [((sx * 0.92, 0.72, 0.72), 0.08), ((0, 0.78, 0.06), 0.08), ((-sx * 0.92, 0.72, -0.56), 0.08)], sides=4, flat=0.3)
    shoulder_straps()
    gem('Trim', 0.1, (0, 0.82, 0.06), squash=(1.2, 0.7, 1.2))
    for i, dx in enumerate((-0.16, 0, 0.16)):
        b = V((dx, 0.84, 0.0))
        tube('Accent', [(b, 0.05), (b + V((dx * 0.4, 0.06, -0.18)), 0.045), (b + V((dx * 0.8, 0.12, -0.32)), 0.03),
                        (b + V((dx, 0.2, -0.4)), 0)], sides=5)

def chest_metal():
    prof = [(-0.84, 1.1, 0.62), (-0.4, 1.13, 0.67), (0.2, 1.15, 0.72), (0.6, 1.13, 0.68), (0.84, 1.1, 0.66)]
    lathe('Plate', prof, nu=28, n=4, thick=0.06)
    box('Plate', (0.1, 0.07, 1.5), (0, 0.71, 0), rot=(math.radians(-2), 0, 0), bevel=0.02)
    lathe('Trim', [(-0.9, 1.15, 0.68), (-0.74, 1.15, 0.68)], nu=28, n=4, thick=0.05)
    lathe('Trim', [(-0.68, 1.16, 0.7), (-0.54, 1.16, 0.7)], nu=28, n=4, thick=0.04)
    rivets('Trim', -0.82, 1.16, 0.69, 4, 14)
    lathe('Trim', [(0.74, 0.66, 0.52), (0.98, 0.58, 0.46)], nu=20, n=2.4, thick=0.05)
    box('Trim', (0.34, 0.05, 0.34), (0, 0.75, 0.24), (0, math.radians(45), 0), bevel=0.02)
    gem('Accent', 0.13, (0, 0.78, 0.24), squash=(1, 0.5, 1), sub=1)
    shoulder_straps(0.84)
    for sx in (-1, 1):
        box('Strap', (0.08, 0.36, 0.14), (sx * 1.16, 0, 0.1), bevel=0.02)
        box('Trim', (0.1, 0.1, 0.1), (sx * 1.19, 0.12, 0.1), bevel=0.015)

def chest_crystal():
    prof = [(-0.84, 1.1, 0.64), (-0.25, 1.17, 0.74), (0.45, 1.16, 0.73), (0.84, 1.06, 0.64)]
    lathe('Plate', prof, nu=8, n=2.6, thick=0.07)
    lathe('Trim', [(-0.92, 1.16, 0.7), (-0.74, 1.16, 0.7)], nu=8, n=2.6, thick=0.06)
    lathe('Trim', [(0.76, 0.7, 0.55), (0.98, 0.6, 0.48)], nu=8, n=2.2, thick=0.06)
    shard('Accent', (0, 0.74, -0.05), (0, 0.3, 1), 0.62, 0.15, sides=5, seed=1)
    shard('Accent', (-0.18, 0.72, -0.12), (-0.5, 0.3, 1), 0.36, 0.08, sides=5, seed=2)
    shard('Accent', (0.18, 0.72, -0.12), (0.5, 0.3, 1), 0.36, 0.08, sides=5, seed=3)
    for sx in (-1, 1):
        shard('Plate', (sx * 0.62, -0.2, 0.78), (sx * 0.4, -0.3, 1), 0.5, 0.09, seed=4)
        shard('Plate', (sx * 0.3, -0.72, 0.4), (sx * 0.2, -0.8, 0.8), 0.42, 0.08, seed=5)

PAUL_ROT = (0, math.radians(22), 0)
PAUL_LOC = (0.1, 0, 0.42)

def pauldron_wood():
    lathe('Plate', dome(0.68, 0.66, 0, 0.36, nv=4), nu=9, n=2.2, jitter=0.05, seed=21, thick=0.07, cap_top=True,
          loc=PAUL_LOC, rot=PAUL_ROT)
    lathe('Plate', [(-0.2, 0.74, 0.7), (0.02, 0.7, 0.67)], az=(-80, 80), nu=5, thick=0.06, jitter=0.05, seed=22,
          loc=PAUL_LOC, rot=PAUL_ROT)
    lathe('Trim', [(0.06, 0.66, 0.64), (0.16, 0.6, 0.58)], nu=12, n=2.2, thick=0.05, loc=PAUL_LOC, rot=PAUL_ROT)
    lathe('Strap', [(-0.32, 0.58, 0.58), (-0.2, 0.58, 0.58)], nu=12, n=4, thick=0.04)

def pauldron_stone():
    box('Plate', (0.92, 0.96, 0.22), (0.3, 0, 0.66), (0, math.radians(24), 0), bevel=0.06, jitter=0.06, seed=31)
    box('Plate', (0.62, 0.78, 0.2), (0.6, 0, 0.3), (0, math.radians(58), 0), bevel=0.05, jitter=0.07, seed=32)
    lathe('Strap', [(-0.1, 0.6, 0.6), (0.06, 0.6, 0.6)], nu=12, n=4, thick=0.05)
    tube('Accent', [((0.42, 0, 0.78), 0.1), ((0.62, 0, 0.98), 0.08), ((0.86, 0, 1.08), 0.04), ((1.0, 0, 1.08), 0)], sides=6)

def pauldron_metal():
    lathe('Plate', dome(0.68, 0.66, 0, 0.36, nv=5), nu=16, n=2.2, thick=0.05, cap_top=True, loc=PAUL_LOC, rot=PAUL_ROT)
    lathe('Plate', [(-0.2, 0.74, 0.7), (-0.02, 0.71, 0.68)], az=(-100, 100), nu=10, thick=0.045, loc=PAUL_LOC, rot=PAUL_ROT)
    lathe('Plate', [(-0.36, 0.76, 0.72), (-0.18, 0.74, 0.7)], az=(-90, 90), nu=10, thick=0.045, loc=PAUL_LOC, rot=PAUL_ROT)
    lathe('Trim', [(-0.03, 0.71, 0.69), (0.05, 0.7, 0.68)], nu=16, n=2.2, thick=0.04, loc=PAUL_LOC, rot=PAUL_ROT)
    for a in (-50, 0, 50):
        ar = math.radians(a)
        p = Euler(PAUL_ROT).to_matrix() @ V((math.cos(ar) * 0.72, math.sin(ar) * 0.7, 0.01)) + V(PAUL_LOC)
        gem('Trim', 0.035, p)
    lathe('Strap', [(-0.3, 0.58, 0.58), (-0.18, 0.58, 0.58)], nu=12, n=4, thick=0.04)

def pauldron_crystal():
    lathe('Plate', dome(0.7, 0.68, 0, 0.36, nv=3, power=0.5), nu=6, thick=0.06, cap_top=True, loc=PAUL_LOC, rot=PAUL_ROT)
    lathe('Trim', [(-0.08, 0.74, 0.72), (0.04, 0.72, 0.7)], nu=6, thick=0.05, loc=PAUL_LOC, rot=PAUL_ROT)
    shard('Accent', (0.3, 0, 0.72), (0.55, 0, 1), 0.6, 0.11, seed=1)
    shard('Accent', (0.35, 0.22, 0.62), (0.6, 0.35, 0.8), 0.38, 0.07, seed=2)
    shard('Accent', (0.35, -0.22, 0.62), (0.6, -0.35, 0.8), 0.38, 0.07, seed=3)
    lathe('Strap', [(-0.3, 0.58, 0.58), (-0.18, 0.58, 0.58)], nu=12, n=4, thick=0.04)

# ---- hip (on LowerTorso, 2 x 0.4 x 1) + thigh (on UpperLeg, 1 x 1.217 x 1) ----

TASSETS = [(18, 82), (98, 162), (200, 340)]

def hip_wood():
    lathe('Strap', [(-0.15, 1.13, 0.64), (0.15, 1.13, 0.64)], nu=24, n=4, thick=0.05)
    lathe('Trim', [(-0.05, 1.17, 0.68), (0.06, 1.17, 0.68)], nu=24, n=4, thick=0.05)
    rng = random.Random(41)
    for a0, a1 in TASSETS:
        k = 3 if a1 - a0 < 100 else 5
        for i in range(k):
            a = math.radians(a0 + (a1 - a0) * (i + 0.5) / k)
            x, y = se(a, 1.16, 0.7, 4)
            h = 0.62 + rng.uniform(-0.06, 0.06)
            box('Plate', (0.3, 0.08, h), (x * 1.02, y * 1.02, -0.12 - h / 2), (math.radians(-8) * math.sin(a), 0, a + math.pi / 2),
                bevel=0.02, jitter=0.05, seed=i + a0)

def hip_stone():
    lathe('Strap', [(-0.16, 1.14, 0.65), (0.16, 1.14, 0.65)], nu=24, n=4, thick=0.06)
    for i, (x, y, w, rz) in enumerate([(-0.5, 0.7, 0.72, 0), (0.5, 0.7, 0.72, 0), (0, -0.7, 1.4, math.pi)]):
        box('Plate', (w, 0.15, 0.6), (x, y, -0.42), (math.radians(-6) if y > 0 else math.radians(6), 0, rz),
            bevel=0.05, jitter=0.06, seed=50 + i)
    gem('Trim', 0.1, (0, 0.72, 0.0), squash=(1.2, 0.6, 1))
    for i, dx in enumerate((-0.9, 0.9)):
        tube('Accent', [((dx, 0.66, -0.1), 0.06), ((dx * 1.02, 0.7, -0.4), 0.05), ((dx * 1.0, 0.72, -0.62), 0.03),
                        ((dx * 0.96, 0.74, -0.74), 0)], sides=5)

def hip_metal():
    lathe('Strap', [(-0.14, 1.13, 0.65), (0.14, 1.13, 0.65)], nu=28, n=4, thick=0.05)
    box('Trim', (0.3, 0.06, 0.26), (0, 0.68, 0), bevel=0.02)
    gem('Accent', 0.06, (0, 0.72, 0), squash=(1, 0.5, 1))
    for a0, a1 in TASSETS:
        lathe('Plate', [(-0.44, 1.2, 0.75), (-0.1, 1.16, 0.7)], az=(a0, a1), nu=8, n=4, thick=0.045)
        lathe('Plate', [(-0.8, 1.26, 0.82), (-0.4, 1.22, 0.77)], az=(a0 + 3, a1 - 3), nu=8, n=4, thick=0.045)
        rivets('Trim', -0.17, 1.17, 0.71, 4, 3, az=(a0 + 12, a1 - 12))

def hip_crystal():
    lathe('Trim', [(-0.15, 1.14, 0.66), (0.15, 1.14, 0.66)], nu=8, n=2.6, thick=0.06)
    shard('Accent', (0, 0.72, -0.12), (0, 0.15, 1), 0.3, 0.09, seed=3)
    for a0, a1 in TASSETS:
        lathe('Plate', [(-0.78, 1.26, 0.84), (-0.12, 1.18, 0.74)], az=(a0, a1), nu=3, n=2.6, thick=0.06)

def thigh_wood():
    rng = random.Random(61)
    for i in range(5):
        a = math.radians(25 + 130 * i / 4)
        x, y = se(a, 0.62, 0.63, 4)
        box('Plate', (0.24, 0.08, 1.0 + rng.uniform(-0.05, 0.05)), (x, y, 0.0), (0, 0, a + math.pi / 2), bevel=0.02, jitter=0.05, seed=i)
    for z in (0.32, -0.3):
        lathe('Trim', [(z - 0.05, 0.68, 0.69), (z + 0.05, 0.68, 0.69)], nu=16, n=4, thick=0.05)

def thigh_stone():
    box('Plate', (0.86, 0.14, 0.9), (0, 0.6, 0.02), (math.radians(-4), 0, 0), bevel=0.05, jitter=0.06, seed=71)
    box('Plate', (0.12, 0.6, 0.7), (0.6, 0.18, 0.06), bevel=0.04, jitter=0.07, seed=72)
    for z in (0.34, -0.28):
        lathe('Strap', [(z - 0.06, 0.7, 0.7), (z + 0.06, 0.7, 0.7)], nu=16, n=4, thick=0.05)

def thigh_metal():
    lathe('Plate', [(-0.46, 0.61, 0.63), (0.2, 0.63, 0.66), (0.5, 0.64, 0.67)], az=(-15, 195), nu=14, n=4, thick=0.05)
    lathe('Trim', [(0.44, 0.66, 0.69), (0.56, 0.66, 0.69)], az=(-15, 195), nu=14, n=4, thick=0.04)
    rivets('Trim', 0.5, 0.67, 0.7, 4, 5, az=(10, 170))
    gem('Plate', 0.3, (0, 0.6, -0.56), squash=(1.1, 0.55, 1), sub=1)
    gem('Trim', 0.05, (0, 0.77, -0.56))
    for z in (0.25, -0.3):
        lathe('Strap', [(z - 0.05, 0.6, 0.6), (z + 0.05, 0.6, 0.6)], az=(195, 345), nu=6, n=4, thick=0.035)

def thigh_crystal():
    lathe('Plate', [(-0.48, 0.62, 0.64), (0.5, 0.66, 0.68)], az=(-15, 195), nu=4, n=2.4, thick=0.06)
    lathe('Trim', [(0.42, 0.7, 0.72), (0.56, 0.7, 0.72)], az=(-15, 195), nu=4, n=2.4, thick=0.05)
    shard('Accent', (0, 0.58, -0.5), (0, 1, 0.15), 0.32, 0.1, seed=4)

# ---- boot (on LowerLeg, 1 x 1.193 x 1; the foot sits below it) ----

def boot_base(role_shoe, toe_role=None, sole='Strap'):
    box(role_shoe, (1.1, 1.26, 0.36), (0, 0.1, -0.6), bevel=0.08, taper=(1, 0.96), segs=2)
    box(sole, (1.14, 1.32, 0.1), (0, 0.1, -0.78), bevel=0.03)
    if toe_role:
        box(toe_role, (1.04, 0.42, 0.3), (0, 0.6, -0.6), bevel=0.06, segs=2)

def boot_wood():
    lathe('Strap', [(-0.55, 0.6, 0.6), (0.2, 0.61, 0.61), (0.42, 0.65, 0.65)], nu=16, n=4, thick=0.05)
    boot_base('Strap')
    lathe('Plate', [(-0.4, 0.66, 0.67), (0.36, 0.67, 0.69)], az=(45, 135), nu=4, n=4, thick=0.08, jitter=0.03, seed=81)
    for z in (0.3, -0.05, -0.38):
        lathe('Trim', [(z - 0.045, 0.7, 0.72), (z + 0.045, 0.7, 0.72)], nu=16, n=4, thick=0.04)
    box('Plate', (0.9, 0.3, 0.12), (0, 0.6, -0.4), bevel=0.03, jitter=0.05, seed=82)

def boot_stone():
    lathe('Strap', [(-0.55, 0.6, 0.6), (0.3, 0.61, 0.61), (0.46, 0.67, 0.67)], nu=16, n=4, thick=0.05)
    boot_base('Strap', toe_role='Plate')
    box('Plate', (0.74, 0.16, 0.8), (0, 0.66, 0.0), (math.radians(-5), 0, 0), bevel=0.05, jitter=0.06, seed=91)
    for z in (0.28, -0.25):
        lathe('Trim', [(z - 0.05, 0.7, 0.72), (z + 0.05, 0.7, 0.72)], nu=16, n=4, thick=0.04)

def boot_metal():
    lathe('Plate', [(-0.5, 0.6, 0.62), (0.15, 0.62, 0.65), (0.44, 0.65, 0.68)], nu=24, n=4, thick=0.05)
    lathe('Trim', [(0.4, 0.68, 0.7), (0.54, 0.68, 0.7)], nu=24, n=4, thick=0.045)
    lathe('Trim', [(-0.52, 0.64, 0.66), (-0.4, 0.64, 0.66)], nu=24, n=4, thick=0.04)
    boot_base('Plate', toe_role='Trim')
    rivets('Trim', 0.47, 0.69, 0.71, 4, 8)

def boot_crystal():
    lathe('Plate', [(-0.5, 0.62, 0.64), (0.46, 0.68, 0.7)], nu=8, n=2.4, thick=0.06)
    lathe('Trim', [(0.4, 0.72, 0.74), (0.56, 0.72, 0.74)], nu=8, n=2.4, thick=0.05)
    boot_base('Trim', toe_role='Plate')
    shard('Accent', (0, 0.66, 0.1), (0, 0.35, 1), 0.42, 0.09, seed=6)

# ---------------------------------------------------------------- tools (grip at origin, along +Z)

def grip(role, r=0.12, z0=-0.1, z1=0.88):
    tube(role, [((0, 0, z0), r), ((0, 0, z1), r)], sides=8)

def sword_wood():
    grip('Handle', 0.13, -0.18, 0.9)
    for z in (0.12, 0.45, 0.78):
        lathe('Trim', [(z - 0.06, 0.15, 0.15), (z + 0.06, 0.15, 0.15)], nu=8, thick=0.03)
    gem('Handle', 0.17, (0, 0, -0.24), squash=(1, 1, 0.8))
    box('Handle', (0.86, 0.22, 0.18), (0, 0, 0.98), bevel=0.04, jitter=0.06, seed=3)
    lathe('Trim', [(0.9, 0.17, 0.17), (1.06, 0.17, 0.17)], nu=8, thick=0.03)
    tube('Plate', [((0, 0, 1.0), 0.27), ((0.02, 0, 1.8), 0.28), ((-0.01, 0, 2.8), 0.25), ((0, 0, 3.4), 0.2), ((0, 0, 3.8), 0)],
         sides=6, flat=0.42, roll=math.pi / 2, jitter=0.04, seed=4)

def sword_stone():
    grip('Handle', 0.12, -0.12, 0.92)
    for z in (0.15, 0.5):
        lathe('Strap', [(z - 0.1, 0.145, 0.145), (z + 0.1, 0.145, 0.145)], nu=8, thick=0.03)
    gem('Plate', 0.16, (0, 0, -0.2), squash=(1, 0.9, 0.9))
    tube('Strap', [((-0.25, 0, 0.92), 0.08), ((0, 0, 1.02), 0.1), ((0.25, 0, 0.92), 0.08)], sides=5)
    tube('Accent', [((-0.5, 0, 0.82), 0.04), ((-0.25, 0, 0.98), 0.08), ((0.25, 0, 0.98), 0.08), ((0.5, 0, 0.82), 0.04)], sides=6)
    tube('Plate', [((0, 0, 0.95), 0.24), ((0, 0, 1.35), 0.31), ((0.02, 0, 2.0), 0.3), ((-0.02, 0, 2.7), 0.27),
                   ((0, 0, 3.3), 0.2), ((0, 0, 3.75), 0)], sides=4, flat=0.3, jitter=0.1, seed=7)

def sword_metal():
    grip('Strap', 0.12, -0.08, 0.86)
    for z in (0.1, 0.4, 0.7):
        lathe('Trim', [(z - 0.02, 0.135, 0.135), (z + 0.02, 0.135, 0.135)], nu=8, thick=0.02)
    gem('Trim', 0.17, (0, 0, -0.22), squash=(1, 0.8, 1), sub=1)
    gem('Accent', 0.08, (0, 0, -0.38), squash=(1, 1, 1.3))
    box('Trim', (0.32, 0.24, 0.2), (0, 0, 0.95), bevel=0.04)
    for sx in (-1, 1):
        tube('Trim', [((sx * 0.12, 0, 0.95), 0.09), ((sx * 0.38, 0, 0.98), 0.075), ((sx * 0.56, 0, 1.08), 0.06),
                      ((sx * 0.64, 0, 1.2), 0)], sides=6)
        gem('Accent', 0.07, (0, sx * 0.12, 0.95), squash=(1, 0.5, 1))
    tube('Plate', [((0, 0, 1.0), 0.24), ((0, 0, 1.22), 0.23), ((0, 0, 3.25), 0.19), ((0, 0, 3.95), 0)], sides=4, flat=0.22)

def sword_crystal():
    grip('Trim', 0.12, -0.1, 0.86)
    shard('Accent', (0, 0, -0.08), (0, 0, -1), 0.42, 0.13, seed=1)
    box('Trim', (0.36, 0.26, 0.22), (0, 0, 0.95), rot=(0, 0, math.radians(45)), bevel=0.03)
    for sx in (-1, 1):
        shard('Plate', (sx * 0.14, 0, 0.95), (sx, 0, 0.55), 0.55, 0.08, seed=2)
    tube('Plate', [((0, 0, 0.98), 0.2), ((0, 0, 1.6), 0.3), ((0, 0, 2.6), 0.27), ((0, 0, 3.35), 0.18), ((0, 0, 3.95), 0)],
         sides=6, flat=0.36, roll=math.pi / 2)
    shard('Accent', (0, 0, 1.0), (0, 0, 1), 1.4, 0.09, sides=4, seed=3)

AXE = [(-0.18, 2.82), (-0.5, 2.92), (-0.86, 3.12), (-0.98, 2.95), (-1.04, 2.62), (-0.96, 2.26), (-0.84, 2.1), (-0.5, 2.36), (-0.18, 2.44)]
AXE_EDGE = {2, 3, 4, 5, 6}

def harvester_base(head_role):
    tube('Handle', [((0, 0, -0.28), 0.13), ((0, 0, 1.6), 0.125), ((0, 0, 3.0), 0.12)], sides=7)
    lathe('Strap', [(-0.15, 0.15, 0.15), (0.85, 0.15, 0.15)], nu=8, thick=0.03)
    if head_role:
        box(head_role, (0.36, 0.48, 0.5), (0, 0, 2.64), bevel=0.05)

def pick(role, r0=0.12, jitter=0.0, sides=4):
    tube(role, [((0, 0.18, 2.7), r0), ((0, 0.6, 2.68), r0 * 0.85), ((0, 0.95, 2.52), r0 * 0.55), ((0, 1.16, 2.28), 0)],
         sides=sides, flat=0.75, jitter=jitter, seed=5)

def harvester_wood():
    harvester_base(None)
    box('Plate', (0.42, 0.62, 0.52), (0, 0, 2.64), bevel=0.06, jitter=0.05, seed=2)
    prism('Plate', AXE, 0.22, edge=AXE_EDGE, jitter=0.03, seed=3)
    pick('Plate', 0.14, jitter=0.06, sides=5)
    for z in (2.32, 2.96):
        lathe('Trim', [(z - 0.06, 0.17, 0.17), (z + 0.06, 0.17, 0.17)], nu=8, thick=0.03)
    tube('Trim', [((0.24, 0.3, 2.3), 0.04), ((0.24, 0, 2.64), 0.05), ((0.24, -0.3, 2.98), 0.04)], sides=4)
    tube('Trim', [((-0.24, 0.3, 2.98), 0.04), ((-0.24, 0, 2.64), 0.05), ((-0.24, -0.3, 2.3), 0.04)], sides=4)

def harvester_stone():
    harvester_base(None)
    prism('Plate', AXE, 0.26, edge=AXE_EDGE, jitter=0.06, seed=4)
    pick('Plate', 0.15, jitter=0.12, sides=5)
    lathe('Strap', [(2.3, 0.2, 0.26), (2.98, 0.2, 0.26)], nu=8, thick=0.04, jitter=0.06, seed=6)
    for sx in (-1, 1):
        tube('Strap', [((sx * 0.22, 0.3, 2.34), 0.04), ((sx * 0.22, -0.3, 2.94), 0.04)], sides=4)
    tube('Accent', [((0, -0.1, 3.0), 0.06), ((0, -0.12, 3.22), 0.05), ((0, -0.08, 3.4), 0)], sides=5)

def harvester_metal():
    harvester_base('Trim')
    lathe('Trim', [(2.36, 0.17, 0.17), (2.42, 0.17, 0.17)], nu=8, thick=0.03)
    prism('Plate', AXE, 0.14, edge=AXE_EDGE)
    pick('Plate', 0.11)
    tube('Plate', [((0, 0, 2.88), 0.09), ((0, 0, 3.2), 0)], sides=4)
    for sx in (-1, 1):
        gem('Accent', 0.07, (sx * 0.19, 0, 2.64), squash=(0.5, 1, 1))

def harvester_crystal():
    harvester_base('Trim')
    prism('Plate', [(-0.18, 2.86), (-0.62, 3.05), (-1.0, 3.2), (-1.06, 2.64), (-0.9, 2.06), (-0.5, 2.32), (-0.18, 2.42)],
          0.16, edge={2, 3, 4})
    shard('Plate', (0, 0.15, 2.66), (0, 1, -0.3), 1.0, 0.13, seed=6)
    shard('Accent', (0, 0, 2.86), (0, 0, 1), 0.45, 0.08, sides=4, seed=7)
    for sx in (-1, 1):
        gem('Accent', 0.07, (sx * 0.19, 0, 2.64), squash=(0.5, 1, 1))

# ---------------------------------------------------------------- bags (centred; outer side is -Y, the wearer's back)

def bag_satchel():
    box('Pouch', (1.5, 0.66, 1.4), (0, 0, -0.08), bevel=0.16, segs=2)
    box('Flap', (1.56, 0.1, 0.78), (0, -0.36, 0.26), (math.radians(4), 0, 0), bevel=0.04, segs=2)
    lathe('Flap', dome(0.78, 0.36, 0, 0.12, nv=3), nu=12, thick=0.05, cap_top=True, loc=(0, 0, 0.6), rot=(0, 0, 0))
    box('Strap', (0.16, 0.06, 0.9), (0, -0.42, 0.1), bevel=0.02)
    box('Buckle', (0.24, 0.07, 0.2), (0, -0.45, -0.06), bevel=0.02)
    for sx in (-1, 1):
        box('Strap', (0.12, 0.7, 0.08), (sx * 0.55, 0, 0.66), bevel=0.02)

def bag_hide():
    box('Pouch', (1.66, 0.8, 1.6), (0, 0, -0.2), bevel=0.2, segs=2, jitter=0.03, seed=2)
    box('Fur', (1.3, 0.12, 1.0), (0, -0.42, -0.26), bevel=0.06, jitter=0.08, seed=3)
    for i in range(7):
        a = 2 * math.pi * i / 7
        gem('Fur', 0.14, (math.cos(a) * 0.62, -0.46, -0.26 + math.sin(a) * 0.48), squash=(1, 0.5, 1))
    tube('Roll', [((-0.95, 0, 0.84), 0.3), ((0.95, 0, 0.84), 0.3)], sides=10)
    for x in (-0.55, 0.55):
        lathe('Strap', [(-0.06, 0.33, 0.33), (0.06, 0.33, 0.33)], nu=10, thick=0.03, loc=(x, 0, 0.84), rot=(0, math.radians(90), 0))
    box('Buckle', (0.2, 0.07, 0.18), (0, -0.44, 0.3), bevel=0.02)
    box('Strap', (0.12, 0.06, 0.6), (0, -0.43, 0.48), bevel=0.02)

def bag_explorer():
    box('Canvas', (1.6, 0.8, 1.7), (0, 0, -0.1), bevel=0.18, segs=2)
    box('Flap', (1.64, 0.86, 0.36), (0, 0, 0.72), bevel=0.1, segs=2)
    box('Pouch', (1.0, 0.24, 0.7), (0, -0.48, -0.34), bevel=0.08, segs=2)
    for sx in (-1, 1):
        box('Pouch', (0.3, 0.56, 0.74), (sx * 0.92, 0, -0.3), bevel=0.08, segs=2)
        tube('Frame', [((sx * 0.86, 0.3, -1.12), 0.06), ((sx * 0.86, 0.3, 1.32), 0.06)], sides=6)
    for z in (-1.0, 1.2):
        tube('Frame', [((-0.86, 0.3, z), 0.05), ((0.86, 0.3, z), 0.05)], sides=6)
    tube('Roll', [((-0.92, -0.05, 1.18), 0.27), ((0.92, -0.05, 1.18), 0.27)], sides=10)
    for x in (-0.5, 0.5):
        lathe('Strap', [(-0.05, 0.3, 0.3), (0.05, 0.3, 0.3)], nu=10, thick=0.03, loc=(x, -0.05, 1.18), rot=(0, math.radians(90), 0))
        box('Strap', (0.1, 0.06, 1.1), (x, -0.43, 0.1), bevel=0.02)
    box('Buckle', (0.2, 0.07, 0.18), (0, -0.62, -0.2), bevel=0.02)
    # A small lantern on the side.
    box('Frame', (0.24, 0.24, 0.06), (1.12, 0, 0.3), bevel=0.02)
    box('Buckle', (0.18, 0.18, 0.26), (1.12, 0, 0.14), bevel=0.02)
    box('Frame', (0.24, 0.24, 0.06), (1.12, 0, -0.02), bevel=0.02)

# ---------------------------------------------------------------- build everything

STYLES = ('wood', 'stone', 'metal', 'crystal')
PIECES = ('helmet', 'chest', 'pauldron', 'hip', 'thigh', 'boot')
G = globals()
for fam in STYLES:
    use(fam)
    for piece in PIECES:
        G[f'{piece}_{fam}']()
        finish(f'armour_{fam}_{piece}', fam, 'armour', PIECE_PART[piece])
    G[f'sword_{fam}'](); finish(f'sword_{fam}', fam, 'tool')
    G[f'harvester_{fam}'](); finish(f'harvester_{fam}', fam, 'tool')
use('bag')
for b in ('satchel', 'hide', 'explorer'):
    G[f'bag_{b}'](); finish(f'bag_{b}', 'bag', 'bag')

json.dump(BOUNDS, open(OUT + 'bounds.json', 'w'), indent=1)
print('BUILT', len(LIB), 'models')
for k, v in BOUNDS.items(): print(f'  {k}: {v}')

if PREVIEW:
    exec(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'preview3.py')).read())
