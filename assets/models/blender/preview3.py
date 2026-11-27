# Preview sheets for set3 (run through set3.py with PREVIEW=1).
# Writes armour-tiers-1/2.jpg and tools.jpg to $SHOTS (default /tmp/models/shots3/).
SHOTS = os.environ.get('SHOTS', '/tmp/models/shots3/')
os.makedirs(SHOTS, exist_ok=True)

# Same palette as src/shared/Tiers.lua: plate, trim, accent, strap, style, glow.
TIERS = [
    ('wood', (150, 108, 66), (196, 170, 118), (96, 132, 58), (92, 62, 40), 'wood', False),
    ('stone', (128, 126, 122), (110, 72, 44), (232, 222, 196), (96, 62, 40), 'stone', False),
    ('silver', (206, 210, 218), (120, 124, 134), (70, 120, 210), (88, 58, 38), 'metal', False),
    ('gold', (236, 192, 72), (150, 104, 40), (200, 40, 48), (88, 58, 38), 'metal', False),
    ('sunsteel', (186, 44, 40), (240, 180, 60), (255, 150, 40), (60, 36, 30), 'metal', True),
    ('diamond', (170, 236, 240), (60, 70, 86), (230, 252, 255), (52, 44, 52), 'crystal', False),
    ('fractite', (70, 220, 230), (30, 60, 70), (170, 255, 255), (40, 40, 48), 'crystal', True),
    ('amethyst', (150, 80, 220), (50, 34, 70), (230, 180, 255), (44, 36, 52), 'crystal', True),
    ('obsidian', (34, 30, 42), (90, 40, 110), (200, 90, 255), (30, 26, 34), 'crystal', True),
    ('lunar', (214, 222, 250), (110, 120, 170), (160, 200, 255), (60, 60, 80), 'metal', True),
]

def lin(rgb):
    return tuple(((x / 255 + 0.055) / 1.055) ** 2.4 if x / 255 > 0.04045 else x / 255 / 12.92 for x in rgb)

PMATS = {}
def pmat(key, rgb, metal=0.0, rough=0.8, emit=0.0):
    if key in PMATS: return PMATS[key]
    m = bpy.data.materials.new(key); m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = (*lin(rgb), 1)
    b.inputs['Metallic'].default_value = metal
    b.inputs['Roughness'].default_value = rough
    if emit:
        b.inputs['Emission Color'].default_value = (*lin(rgb), 1)
        b.inputs['Emission Strength'].default_value = emit
    PMATS[key] = m
    return m

def tier_mats(t):
    name, plate, trim, accent, strap, style, glow = t
    pm = {'wood': (0, 0.8), 'stone': (0, 0.9), 'metal': (0.85, 0.32), 'crystal': (0.0, 0.12)}[style]
    tm = (0.85, 0.4) if style in ('metal',) else (0.0, 0.7)
    return {
        'Plate': pmat(f'{name}_P', plate, *pm),
        'Trim': pmat(f'{name}_T', trim, *tm),
        'Accent': pmat(f'{name}_A', accent, 0.0, 0.3, 3.0 if glow else 0.0),
        'Strap': pmat(f'{name}_S', strap, 0.0, 0.8),
        'Handle': pmat('handle', (110, 76, 48), 0.0, 0.8),
    }

def place(model, loc, rotz=0.0, mats=None):
    fam, objs = LIB[model]
    for o in objs:
        if o.name.startswith('Bounds'): continue
        c = bpy.data.objects.new(o.name + '_c', o.data)
        bpy.context.scene.collection.objects.link(c)
        c.location = loc; c.rotation_euler = (0, 0, rotz)
        role = o.name.split('.')[0]
        m = (mats or {}).get(role)
        if m is None and fam == 'bag':
            m = pmat('bag_' + role, BAGS.get(role, (200, 200, 200)), 0.6 if role == 'Buckle' else 0.0, 0.7)
        if m is not None:
            c.material_slots[0].link = 'OBJECT'; c.material_slots[0].material = m

SKIN = pmat('dummy', (150, 140, 128), 0, 0.9)
# Part centres of a blocky R15 dummy (Blender: z up, front +Y) and sizes (x, y, z).
RIG = {
    'Head': ((0, 0, 4.5), (1.2, 1.2, 1.2)), 'UpperTorso': ((0, 0, 3.1), (2, 1, 1.6)),
    'LowerTorso': ((0, 0, 2.1), (2, 1, 0.4)),
    'RightUpperArm': ((1.5, 0, 3.3), (1, 1, 1.169)), 'LeftUpperArm': ((-1.5, 0, 3.3), (1, 1, 1.169)),
    'RightLowerArm': ((1.5, 0, 2.3), (1, 1, 1.05)), 'LeftLowerArm': ((-1.5, 0, 2.3), (1, 1, 1.05)),
    'RightHand': ((1.5, 0, 1.7), (1, 1, 0.3)), 'LeftHand': ((-1.5, 0, 1.7), (1, 1, 0.3)),
    'RightUpperLeg': ((0.5, 0, 1.55), (1, 1, 1.217)), 'LeftUpperLeg': ((-0.5, 0, 1.55), (1, 1, 1.217)),
    'RightLowerLeg': ((0.5, 0, 0.75), (1, 1, 1.193)), 'LeftLowerLeg': ((-0.5, 0, 0.75), (1, 1, 1.193)),
    'RightFoot': ((0.5, 0.05, 0.15), (1, 1.1, 0.3)), 'LeftFoot': ((-0.5, 0.05, 0.15), (1, 1.1, 0.3)),
}
WEAR = [('helmet', 'Head', 0), ('chest', 'UpperTorso', 0), ('pauldron', 'RightUpperArm', 0),
        ('pauldron', 'LeftUpperArm', math.pi), ('hip', 'LowerTorso', 0), ('thigh', 'RightUpperLeg', 0),
        ('thigh', 'LeftUpperLeg', 0), ('boot', 'RightLowerLeg', 0), ('boot', 'LeftLowerLeg', 0)]

def dummy(x, y=0.0):
    for name, (c, s) in RIG.items():
        bm = bmesh.new()
        if name == 'Head':  # classic Roblox head: a rounded cylinder
            bmesh.ops.create_cone(bm, cap_ends=True, segments=20, radius1=0.6, radius2=0.6, depth=1.2)
            bmesh.ops.bevel(bm, geom=[e for e in bm.edges if abs(e.verts[0].co.z) > 0.5 and abs(e.verts[1].co.z) > 0.5],
                            offset=0.2, segments=3, affect='EDGES', profile=0.5)
        else:
            bmesh.ops.create_cube(bm, size=1); xform(bm, scale=s)
            bmesh.ops.bevel(bm, geom=bm.edges[:], offset=0.06, segments=2, affect='EDGES', profile=0.5)
        me = bpy.data.meshes.new('d'); bm.to_mesh(me); bm.free()
        o = bpy.data.objects.new('dummy', me); bpy.context.scene.collection.objects.link(o)
        o.location = (c[0] + x, c[1] + y, c[2]); me.materials.append(SKIN)

def scene_setup(target, cam_loc, res=(1600, 900), lens=50):
    sc = bpy.context.scene
    for o in list(sc.objects):
        if o.users_collection and o.users_collection[0] == sc.collection: bpy.data.objects.remove(o)
    cam = bpy.data.objects.new('Cam', bpy.data.cameras.new('Cam')); sc.collection.objects.link(cam)
    cam.data.lens = lens; cam.location = cam_loc
    d = V(target) - V(cam_loc)
    cam.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
    sc.camera = cam
    sun = bpy.data.objects.new('Sun', bpy.data.lights.new('Sun', 'SUN')); sc.collection.objects.link(sun)
    sun.data.energy = 3.4; sun.data.angle = math.radians(4); sun.data.color = (1.0, 0.93, 0.82)
    sun.rotation_euler = V((0.35, 0.6, 0.72)).normalized().to_track_quat('Z', 'Y').to_euler()
    fill = bpy.data.objects.new('Fill', bpy.data.lights.new('Fill', 'SUN')); sc.collection.objects.link(fill)
    fill.data.energy = 0.6; fill.data.color = (0.7, 0.8, 1.0)
    fill.rotation_euler = V((-0.6, -0.3, 0.4)).normalized().to_track_quat('Z', 'Y').to_euler()
    sc.world = bpy.data.worlds.new('W'); sc.world.use_nodes = True
    bg = sc.world.node_tree.nodes['Background']; bg.inputs[0].default_value = (0.32, 0.36, 0.42, 1); bg.inputs[1].default_value = 0.8
    bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, 0))
    g = bpy.context.object; g.data.materials.append(pmat('ground', (88, 78, 60), 0, 0.95))
    sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'; sc.cycles.samples = SAMPLES
    try: sc.cycles.use_denoising = True
    except Exception: pass
    try: sc.view_settings.view_transform = 'AgX'; sc.view_settings.look = 'AgX - Medium High Contrast'
    except Exception: sc.view_settings.view_transform = 'Filmic'
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.image_settings.file_format = 'JPEG'; sc.render.image_settings.quality = 88

def render(path):
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print('RENDERED', path)

def armour_sheet(tiers, path, back=False):
    gap = 4.6
    x0 = gap * (len(tiers) - 1) / 2 * (-1 if back else 1)
    gap = -gap if not back else gap
    cy = -17 if back else 17
    scene_setup((0, 0, 2.4), (2.5 if not back else -2.5, cy * 1.25, 5.6), lens=(30 if len(tiers) > 4 else 36))
    for i, t in enumerate(tiers):
        x = x0 + gap * i
        dummy(x)
        mats = tier_mats(t)
        for piece, part, rz in WEAR:
            c = RIG[part][0]
            place(f'armour_{t[5]}_{piece}', (c[0] + x, c[1], c[2]), rz, mats)
        h = RIG['RightHand'][0]
        place(f'sword_{t[5]}', (h[0] + x + 0.55, 0.3, 0.02), 0, mats)
    render(path)

def tools_sheet(path):
    scene_setup((0, 0, 1.9), (0, 15, 4.2), res=(1600, 900), lens=40)
    for i, t in enumerate(TIERS):
        place(f'sword_{t[5]}', (6.3 - 1.4 * i, 0.0, 0.45), 0, tier_mats(t))
    render(path)

def gear_sheet(path):
    scene_setup((-1.6, 0, 1.6), (-1.6, 16, 4.4), res=(1600, 900), lens=32)
    for i, t in enumerate([TIERS[0], TIERS[1], TIERS[3], TIERS[7]]):
        place(f'harvester_{t[5]}', (5.4 - 2.3 * i, 0, 0.3), math.radians(90), tier_mats(t))
    for i, b in enumerate(('satchel', 'hide', 'explorer')):
        h = BOUNDS[f'bag_{b}'][1]
        place(f'bag_{b}', (-3.4 - 2.7 * i, 0, h / 2), math.pi + math.radians(20))
    render(path)

which = os.environ.get('SHEETS', 'tiers1,tiers2,tools,gear')
if 'tiers1' in which: armour_sheet(TIERS[:5], SHOTS + 'armour-tiers-1.jpg')
if 'tiers2' in which: armour_sheet(TIERS[5:], SHOTS + 'armour-tiers-2.jpg')
if 'styles' in which: armour_sheet([TIERS[0], TIERS[1], TIERS[3], TIERS[7]], SHOTS + 'armour-styles.jpg')
if 'back' in which: armour_sheet([TIERS[0], TIERS[1], TIERS[3], TIERS[7]], SHOTS + 'armour-back.jpg', back=True)
if 'tools' in which: tools_sheet(SHOTS + 'tools.jpg')
if 'gear' in which: gear_sheet(SHOTS + 'gear.jpg')
