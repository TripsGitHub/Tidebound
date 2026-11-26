import bpy, bmesh, math, random
from mathutils import Vector, Matrix

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)

MATS = {}
def mat(name, rgb):
    if name in MATS: return MATS[name]
    m = bpy.data.materials.new(name); m.use_nodes = True
    c = tuple(x/255 for x in rgb)
    # sRGB -> linear for the shader
    lin = tuple(((x+0.055)/1.055)**2.4 if x > 0.04045 else x/12.92 for x in c)
    m.node_tree.nodes["Principled BSDF"].inputs[0].default_value = (*lin, 1)
    m.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.85
    m.diffuse_color = (*lin, 1)
    MATS[name] = m
    return m

def obj_from_bm(bm, name, material, parent=None):
    me = bpy.data.meshes.new(name); bm.normal_update(); bm.to_mesh(me); bm.free()
    for p in me.polygons: p.use_smooth = False
    ob = bpy.data.objects.new(name, me); bpy.context.collection.objects.link(ob)
    me.materials.append(material)
    return ob

def loft(rings, sides, name, material, cap_bottom=True, cap_top=True, jitter=0.0, seed=1, twist=0.0):
    """rings: list of (center Vector, radius, scaleY). Builds a faceted tube."""
    rng = random.Random(seed)
    bm = bmesh.new(); rows = []
    for i, (c, r, sy) in enumerate(rings):
        row = []
        for s in range(sides):
            a = 2*math.pi*s/sides + i*twist
            j = 1 + rng.uniform(-jitter, jitter)
            row.append(bm.verts.new((c.x + math.cos(a)*r*j, c.y + math.sin(a)*r*j*sy, c.z)))
        rows.append(row)
    for i in range(len(rows)-1):
        for s in range(sides):
            bm.faces.new((rows[i][s], rows[i][(s+1)%sides], rows[i+1][(s+1)%sides], rows[i+1][s]))
    if cap_bottom: bm.faces.new(list(reversed(rows[0])))
    if cap_top: bm.faces.new(rows[-1])
    return obj_from_bm(bm, name, material)

def cone(base_z, height, radius, sides, name, material, seed=1, tip_offset=(0,0), jitter=0.08, base_center=(0,0), star=0.0, droop=0.0):
    rng = random.Random(seed)
    bm = bmesh.new(); ring = []
    for s in range(sides):
        a = 2*math.pi*s/sides + rng.uniform(-0.12, 0.12)
        tipv = (s % 2 == 0)
        r = radius*(1+rng.uniform(-jitter, jitter))*(1.0 if tipv else 1.0-star)
        z = base_z + rng.uniform(-0.06, 0.06)*height - (droop*height if tipv else 0)
        ring.append(bm.verts.new((base_center[0]+math.cos(a)*r, base_center[1]+math.sin(a)*r, z)))
    tip = bm.verts.new((base_center[0]+tip_offset[0], base_center[1]+tip_offset[1], base_z+height))
    for s in range(sides):
        bm.faces.new((ring[s], ring[(s+1)%sides], tip))
    bm.faces.new(list(reversed(ring)))
    return obj_from_bm(bm, name, material)

def rock(radius, name, material, seed=1, squash=(1,1,0.7), subdiv=1, noise=0.22, flat_bottom=True):
    rng = random.Random(seed)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=radius)
    for v in bm.verts:
        d = 1 + rng.uniform(-noise, noise)
        v.co = Vector((v.co.x*squash[0]*d, v.co.y*squash[1]*d, v.co.z*squash[2]*d))
        if flat_bottom and v.co.z < -radius*squash[2]*0.35:
            v.co.z = -radius*squash[2]*0.35
    # merge flattened bottom into one face-ish
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.001)
    return obj_from_bm(bm, name, material)

def join(objs, name):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs: o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join(); objs[0].name = name; objs[0].data.name = name
    return objs[0]

def setup_render(target, dist, path, res=600, height=None, elev=0.55):
    sc = bpy.context.scene
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam")); bpy.context.collection.objects.link(cam)
    cam.data.lens = 50
    cam.location = (target[0]+dist*0.25, target[1]-dist*0.97, target[2]+dist*elev)
    tgt = bpy.data.objects.new("T", None); tgt.location = target; bpy.context.collection.objects.link(tgt)
    c = cam.constraints.new('TRACK_TO'); c.target = tgt; c.track_axis = 'TRACK_NEGATIVE_Z'; c.up_axis = 'UP_Y'
    sc.camera = cam
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", 'SUN')); sun.data.energy = 3.2; sun.data.angle = 0.2
    sun.rotation_euler = (math.radians(45), math.radians(10), math.radians(35)); bpy.context.collection.objects.link(sun)
    sc.world = bpy.data.worlds.new("W"); sc.world.use_nodes = True
    bg = sc.world.node_tree.nodes['Background']; bg.inputs[0].default_value = (0.55, 0.68, 0.85, 1); bg.inputs[1].default_value = 0.9
    sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'; sc.cycles.samples = 32
    sc.view_settings.view_transform = 'Standard'
    sc.render.resolution_x = res; sc.render.resolution_y = height or res
    sc.render.filepath = path

def ground(size=40, rgb=(222, 206, 160)):
    bpy.ops.mesh.primitive_plane_add(size=size, location=(0, 0, 0))
    g = bpy.context.object; g.name = "Ground"; g.data.materials.append(mat("Sand", rgb))
    return g

def export(path, objs):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs: o.select_set(True)
    bpy.ops.wm.obj_export(filepath=path, export_selected_objects=True, export_materials=True,
                          up_axis='Y', forward_axis='NEGATIVE_Z', apply_modifiers=True)
