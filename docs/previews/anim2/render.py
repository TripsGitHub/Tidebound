# Renders the body animations in src/client/Anim.lua on R15 dummies wearing the set 3
# armour. The poses are a straight Python port of Anim.lua (walkPose, idlePose,
# airPose, sample), and the one-off animations are read from the Lua file itself.
# Run: python3 render.py   (needs pip bpy, and set3's OBJs in /tmp/models/out3/)
import bpy, math, os, re, sys
from mathutils import Matrix, Vector

LUA = os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../../src/client/Anim.lua')
OUT = os.environ.get('OUT', '/tmp/anim2/')
MODELS = '/tmp/models/out3/'
FPS, LOOP = 24, 1.75
os.makedirs(OUT, exist_ok=True)

# ---------------------------------------------------------------- read Anim.lua

src = open(LUA).read()
def parse_block(start, end):
    body = src[src.index(start):src.index(end)]
    anims = {}
    for m in re.finditer(r'\n\t(\w+) = \{\n(.*?)\n\t\},', body, re.S):
        keys = []
        for chunk in m.group(2).split('{ t = ')[1:]:
            t = float(re.match(r'[\d.]+', chunk).group(0))
            pose = {j: tuple(float(x) for x in v.split(',')) for j, v in re.findall(r'(\w+) = V\(([^)]*)\)', chunk)} or None
            keys.append((t, pose))
        anims[m.group(1)] = keys
    return anims
ANIMS = parse_block('local ANIMS', 'local REACTS')
REACTS = parse_block('local REACTS', 'local DRESS_ORDER')
HOLD = {j: tuple(float(x) for x in v.split(',')) for j, v in re.findall(r'(\w+) = V\(([^)]*)\)', src[src.index('local HOLD'):src.index('local ANIMS')])}
ABSOLUTE = {'RightShoulder', 'RightElbow', 'RightWrist', 'LeftShoulder', 'LeftElbow', 'LeftWrist'}

# ---------------------------------------------------------------- port of the pose code

def add(a, b, k=1.0): return tuple(x + y * k for x, y in zip(a, b))
def lerp(a, b, f): return tuple(x + (y - x) * f for x, y in zip(a, b))
Z = (0.0, 0.0, 0.0)
def smooth(a): return a * a * (3 - 2 * a)
def mix(a, b, f):
    out = {k: lerp(v, b.get(k, Z), f) for k, v in a.items()}
    for k, v in b.items():
        if k not in a: out[k] = lerp(Z, v, f)
    return out

def idle(t):
    b = math.sin(t * 1.7)
    return {'Waist': (1.5 * b, 0, 0), 'Neck': (-1.2 * b, 0, 0), 'RightShoulder': (0, 0, 3 + b), 'LeftShoulder': (0, 0, -3 - b),
            'RightElbow': (6 + b, 0, 0), 'LeftElbow': (6 + b, 0, 0), 'RootPos': (0, -0.02 * (b + 1), 0)}

def walk(ph, run):
    s, c = math.sin(ph), math.cos(ph)
    amp = 32 + 18 * run; arm = amp * (0.55 + 0.15 * run); bob = 0.12 + 0.12 * run
    sr, sl = max(0, c), max(0, -c)
    return {'RightHip': (amp * s, 0, 0), 'LeftHip': (-amp * s, 0, 0),
            'RightKnee': (-6 - amp * (1.1 + 0.5 * run) * sr, 0, 0), 'LeftKnee': (-6 - amp * (1.1 + 0.5 * run) * sl, 0, 0),
            'RightAnkle': (0.4 * amp * s, 0, 0), 'LeftAnkle': (-0.4 * amp * s, 0, 0),
            'RightShoulder': (-arm * s, 0, 4), 'LeftShoulder': (arm * s, 0, -4),
            'RightElbow': (12 + 50 * run + 0.4 * arm * max(0, -s), 0, 0), 'LeftElbow': (12 + 50 * run + 0.4 * arm * max(0, s), 0, 0),
            'Root': (-3 - 8 * run, 6 * s, 0), 'Waist': (-1 - 3 * run, -9 * s, 0), 'Neck': (1 + 3 * run, 3 * s, 0),
            'RootPos': (0, bob * (abs(c) - 0.6), 0)}

def air(rising):
    if rising:
        return {'RightHip': (34, 0, 0), 'RightKnee': (-56, 0, 0), 'LeftHip': (-8, 0, 0), 'LeftKnee': (-24, 0, 0),
                'RightAnkle': (-10, 0, 0), 'LeftAnkle': (-14, 0, 0), 'RightShoulder': (30, 0, 26), 'LeftShoulder': (-10, 0, -30),
                'RightElbow': (30, 0, 0), 'LeftElbow': (24, 0, 0), 'Waist': (-4, 0, 0), 'Neck': (4, 0, 0)}
    return {'RightHip': (14, 0, 0), 'RightKnee': (-22, 0, 0), 'LeftHip': (6, 0, 0), 'LeftKnee': (-12, 0, 0),
            'RightAnkle': (8, 0, 0), 'LeftAnkle': (8, 0, 0), 'RightShoulder': (14, 0, 58), 'LeftShoulder': (14, 0, -58),
            'RightElbow': (18, 0, 0), 'LeftElbow': (18, 0, 0), 'Waist': (4, 0, 0), 'Neck': (6, 0, 0)}

def sample(keys, under, t, scale=1.0, additive=False):
    if t >= keys[-1][0] or t < 0: return under
    a, b = keys[0], keys[-1]
    for i in range(len(keys) - 1):
        if keys[i][0] <= t < keys[i + 1][0]: a, b = keys[i], keys[i + 1]; break
    f = smooth((t - a[0]) / (b[0] - a[0]))
    out = dict(under)
    for j in set((a[1] or {}).keys()) | set((b[1] or {}).keys()):
        if j in ABSOLUTE and not additive:
            out[j] = lerp((a[1] or {}).get(j, under.get(j, Z)), (b[1] or {}).get(j, under.get(j, Z)), f)
        else:
            out[j] = add(under.get(j, Z), lerp((a[1] or {}).get(j, Z), (b[1] or {}).get(j, Z), f), scale)
    return out

def pose_for(spec, t):
    """spec: dict(speed, held, action, action_at, jump)"""
    speed = spec.get('speed', 0)
    run = min(1, max(0, (speed - 17) / 8)); wk = min(1, speed / 10)
    stride = 7 + 3 * run
    ph = (t * max(speed, 2) / stride * 2 * math.pi) % (2 * math.pi)
    p = mix(idle(t), walk(ph, run), smooth(wk))
    jump = spec.get('jump')
    react = None
    if jump:
        t0, t1, t2 = jump  # leave ground, start falling, land
        if t0 <= t < t2:
            w = smooth(min(1, (t - t0) / 0.12))
            p = mix(p, air(t < t1), w)
        elif t2 <= t < t2 + 0.12:
            p = mix(p, air(False), 1 - smooth((t - t2) / 0.12))
        react = ('land', t - t2)
    if spec.get('held'):
        for j, v in HOLD.items(): p[j] = add(v, p.get(j, Z), 0.25)
    if spec.get('action'):
        p = sample(ANIMS[spec['action']], p, t - spec.get('action_at', 0.2))
    if react and 0 <= react[1]:
        p = sample(REACTS[react[0]], p, react[1], 0.8, True)
    if spec.get('hurt_at') is not None:
        p = sample(REACTS['hurt'], p, t - spec['hurt_at'], 1, True)
    return p

# ---------------------------------------------------------------- scene

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
def lin(rgb): return tuple(((c / 255 + 0.055) / 1.055) ** 2.4 for c in rgb)
MATS = {}
def mat(name, rgb, metal=0.0, rough=0.8, emit=0.0):
    if name in MATS: return MATS[name]
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = (*lin(rgb), 1); b.inputs['Metallic'].default_value = metal; b.inputs['Roughness'].default_value = rough
    if emit: b.inputs['Emission Color'].default_value = (*lin(rgb), 1); b.inputs['Emission Strength'].default_value = emit
    m.diffuse_color = (*lin(rgb), 1)
    MATS[name] = m; return m

TIERS = {
    'wood': ('wood', (150, 108, 66), (196, 170, 118), (96, 132, 58), (92, 62, 40), False),
    'stone': ('stone', (128, 126, 122), (110, 72, 44), (232, 222, 196), (96, 62, 40), False),
    'gold': ('metal', (236, 192, 72), (150, 104, 40), (200, 40, 48), (88, 58, 38), False),
    'silver': ('metal', (206, 210, 218), (120, 124, 134), (70, 120, 210), (88, 58, 38), False),
    'amethyst': ('crystal', (150, 80, 220), (50, 34, 70), (230, 180, 255), (44, 36, 52), True),
    'fractite': ('crystal', (70, 220, 230), (30, 60, 70), (170, 255, 255), (40, 40, 48), True),
}
def tier_mats(t):
    style, plate, trim, accent, strap, glow = TIERS[t]
    pm = {'wood': (0, 0.8), 'stone': (0, 0.9), 'metal': (0.85, 0.32), 'crystal': (0, 0.15)}[style]
    return style, {'Plate': mat(t + 'P', plate, *pm), 'Trim': mat(t + 'T', trim, 0.85 if style == 'metal' else 0, 0.45),
                   'Accent': mat(t + 'A', accent, 0, 0.3, 3 if glow else 0), 'Strap': mat(t + 'S', strap), 'Handle': mat('handle', (110, 76, 48))}

# Roblox space -> Blender space ((x, y, z) -> (x, -z, y)).
C4 = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
def T(p): return Matrix.Translation(Vector(p))
def R(v):
    x, y, z = (math.radians(a) for a in v)
    return Matrix.Rotation(x, 4, 'X') @ Matrix.Rotation(y, 4, 'Y') @ Matrix.Rotation(z, 4, 'Z')

# R15 dummy in Roblox space (feet at y = 0): part -> (parent, joint, pivot, centre, size)
RIG = {
    'LowerTorso': (None, 'Root', (0, 2.1, 0), (0, 2.1, 0), (2, 0.4, 1)),
    'UpperTorso': ('LowerTorso', 'Waist', (0, 2.3, 0), (0, 3.1, 0), (2, 1.6, 1)),
    'Head': ('UpperTorso', 'Neck', (0, 3.9, 0), (0, 4.5, 0), (1.2, 1.2, 1.2)),
    'RightUpperArm': ('UpperTorso', 'RightShoulder', (1.5, 3.75, 0), (1.5, 3.3, 0), (1, 1.169, 1)),
    'RightLowerArm': ('RightUpperArm', 'RightElbow', (1.5, 2.8, 0), (1.5, 2.3, 0), (1, 1.05, 1)),
    'RightHand': ('RightLowerArm', 'RightWrist', (1.5, 1.85, 0), (1.5, 1.7, 0), (1, 0.3, 1)),
    'LeftUpperArm': ('UpperTorso', 'LeftShoulder', (-1.5, 3.75, 0), (-1.5, 3.3, 0), (1, 1.169, 1)),
    'LeftLowerArm': ('LeftUpperArm', 'LeftElbow', (-1.5, 2.8, 0), (-1.5, 2.3, 0), (1, 1.05, 1)),
    'LeftHand': ('LeftLowerArm', 'LeftWrist', (-1.5, 1.85, 0), (-1.5, 1.7, 0), (1, 0.3, 1)),
    'RightUpperLeg': ('LowerTorso', 'RightHip', (0.5, 2.0, 0), (0.5, 1.55, 0), (1, 1.217, 1)),
    'RightLowerLeg': ('RightUpperLeg', 'RightKnee', (0.5, 1.2, 0), (0.5, 0.75, 0), (1, 1.193, 1)),
    'RightFoot': ('RightLowerLeg', 'RightAnkle', (0.5, 0.3, 0), (0.5, 0.15, -0.05), (1, 0.3, 1.1)),
    'LeftUpperLeg': ('LowerTorso', 'LeftHip', (-0.5, 2.0, 0), (-0.5, 1.55, 0), (1, 1.217, 1)),
    'LeftLowerLeg': ('LeftUpperLeg', 'LeftKnee', (-0.5, 1.2, 0), (-0.5, 0.75, 0), (1, 1.193, 1)),
    'LeftFoot': ('LeftLowerLeg', 'LeftAnkle', (-0.5, 0.3, 0), (-0.5, 0.15, -0.05), (1, 0.3, 1.1)),
}
WEAR = {'helmet': [('Head', 0)], 'chest': [('UpperTorso', 0)], 'pauldron': [('RightUpperArm', 0), ('LeftUpperArm', 180)],
        'hip': [('LowerTorso', 0)], 'thigh': [('RightUpperLeg', 0), ('LeftUpperLeg', 0)], 'boot': [('RightLowerLeg', 0), ('LeftLowerLeg', 0)]}

def world(pose):
    """Roblox-space matrix of each part's joint chain."""
    out = {}
    for name, (parent, joint, pivot, centre, size) in RIG.items():
        base = out[parent] if parent else T(pose.get('RootPos', Z))
        out[name] = base @ T(pivot) @ R(pose.get(joint, Z)) @ T(tuple(-c for c in pivot))
    return out

def import_obj(path):
    before = set(bpy.data.objects)
    bpy.ops.wm.obj_import(filepath=path, up_axis='Y', forward_axis='NEGATIVE_Z')
    objs = [o for o in bpy.data.objects if o not in before]
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs: o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for o in list(objs):
        if o.name.startswith('Bounds'):
            bpy.data.objects.remove(o); objs.remove(o)
    return objs

SKIN = mat('skin', (226, 186, 150)); SHIRT = mat('shirt', (74, 92, 120)); PANTS = mat('pants', (60, 56, 52))
class Dummy:
    def __init__(self, x, tier, spec, tool=None, hide_until=None):
        self.o = T((x, 0, 0)); self.spec = spec; self.parts = []; self.armour = []; self.tool = []
        for name, (_, _, _, centre, size) in RIG.items():
            bpy.ops.mesh.primitive_cube_add(size=1); c = bpy.context.object
            c.data.materials.append(SKIN if name in ('Head', 'RightHand', 'LeftHand') else PANTS if 'Leg' in name or 'Foot' in name else SHIRT)
            self.parts.append((c, name, centre, size))
        style, mats = tier_mats(tier)
        for piece, spots in WEAR.items():
            for part, turn in spots:
                objs = import_obj(f'{MODELS}armour_{style}_{piece}.obj')
                for o in objs:
                    role = re.sub(r'\.\d+$', '', o.name).split('_')[0]
                    if role in mats: o.data.materials.clear(); o.data.materials.append(mats[role])
                    hide = (hide_until or {}).get(piece)
                    self.armour.append((o, part, turn, hide))
        if tool:
            for o in import_obj(f'{MODELS}{tool}_{style}.obj'):
                role = re.sub(r'\.\d+$', '', o.name).split('_')[0]
                if role in mats: o.data.materials.clear(); o.data.materials.append(mats[role])
                self.tool.append(o)

    def frame(self, t):
        pose = pose_for(self.spec, t)
        W = world(pose)
        lift = 0
        jump = self.spec.get('jump')
        if jump and jump[0] <= t < jump[2]:
            u = (t - jump[0]) / (jump[2] - jump[0]); lift = 4 * 2.2 * u * (1 - u)
        base = self.o @ C4 @ T((0, lift, 0))
        for c, name, centre, size in self.parts:
            c.matrix_world = base @ W[name] @ T(centre) @ Matrix.Diagonal((*size, 1))
        for o, part, turn, hide in self.armour:
            centre = RIG[part][3]
            o.matrix_world = base @ W[part] @ T(centre) @ R((0, turn, 0)) @ C4.inverted()
            o.hide_render = hide is not None and t < hide
        for o in self.tool:
            # Grip at the bottom of the fist, tool pointing forward (Appearance.setTool).
            o.matrix_world = base @ W['RightHand'] @ T((1.5, 1.7 - 0.15 + 0.1, 0)) @ R((-90, 0, 0)) @ C4.inverted()
            o.hide_render = self.spec.get('tool_from') is not None and t < self.spec['tool_from']

# Six dummies, left to right as seen by the camera (camera looks at their fronts).
CAST = [
    Dummy(13.75, 'gold', {'speed': 16, 'held': True}, tool='sword'),
    Dummy(8.25, 'wood', {'speed': 22.86}),
    Dummy(2.75, 'stone', {'action': 'draw', 'action_at': 0.45, 'tool_from': 0.55}, tool='harvester'),
    Dummy(-2.75, 'silver', {'action': 'dress_head', 'action_at': 0.3}, hide_until={'helmet': 0.6}),
    Dummy(-8.25, 'amethyst', {'action': 'dress_feet', 'action_at': 0.3}),
    Dummy(-13.75, 'fractite', {'jump': (0.25, 0.6, 1.05)}),
]
# Walkers walk on the spot: the ground scrolls instead (set per frame below).
bpy.ops.mesh.primitive_plane_add(size=80); ground = bpy.context.object; ground.data.materials.append(mat('ground', (88, 78, 60), 0, 0.95))

cam = bpy.data.objects.new('Cam', bpy.data.cameras.new('Cam')); sc.collection.objects.link(cam)
cam.data.lens = 30; cam.location = (0, 30, 6)
cam.rotation_euler = (Vector((0, 0, 3.0)) - cam.location).to_track_quat('-Z', 'Y').to_euler()
sc.camera = cam
sun = bpy.data.objects.new('Sun', bpy.data.lights.new('Sun', 'SUN')); sc.collection.objects.link(sun)
sun.data.energy = 3.4; sun.data.angle = math.radians(5); sun.data.color = (1, 0.93, 0.82)
sun.rotation_euler = Vector((0.35, 0.6, 0.72)).normalized().to_track_quat('Z', 'Y').to_euler()
sc.world = bpy.data.worlds.new('W'); sc.world.use_nodes = True
bg = sc.world.node_tree.nodes['Background']; bg.inputs[0].default_value = (0.32, 0.36, 0.42, 1); bg.inputs[1].default_value = 0.8
sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'; sc.cycles.samples = int(os.environ.get('SAMPLES', '10'))
sc.cycles.use_denoising = True
try: sc.view_settings.view_transform = 'AgX'; sc.view_settings.look = 'AgX - Medium High Contrast'
except Exception: pass
sc.render.resolution_x, sc.render.resolution_y = 960, 540
sc.render.image_settings.file_format = 'PNG'

frames = int(os.environ.get('FRAMES', str(int(LOOP * FPS))))
for f in range(frames):
    t = f / FPS
    for d in CAST: d.frame(t)
    sc.render.filepath = f'{OUT}f{f:03d}.png'
    bpy.ops.render.render(write_still=True)
print('DONE', frames)
