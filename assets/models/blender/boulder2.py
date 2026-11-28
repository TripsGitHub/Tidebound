import sys; sys.path.insert(0, '/tmp/models')
import bpy, bmesh, math, random
from mathutils import Vector
from lib import *
reset()
def mossify(ob, threshold=0.86):
    ob.data.materials.append(mat("Moss", (128, 124, 116)))
    for p in ob.data.polygons:
        n = ob.matrix_world.to_3x3() @ p.normal
        if n.z > threshold:
            p.material_index = 1
def chunk(r, name, seed, squash):
    # A chunky, blunt rock: a low icosphere, gently pushed about, flat-bottomed.
    rng = random.Random(seed)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=2, radius=r)
    lumps = [(Vector((rng.uniform(-1,1), rng.uniform(-1,1), rng.uniform(-0.3,1))).normalized(), rng.uniform(0.08, 0.18)) for _ in range(5)]
    for v in bm.verts:
        d = 1 + rng.uniform(-0.03, 0.03) + sum(a*max(0, v.co.normalized().dot(n))**3 for n, a in lumps) - 0.1
        v.co = Vector((v.co.x*squash[0]*d, v.co.y*squash[1]*d, v.co.z*squash[2]*d))
        if v.co.z < -r*squash[2]*0.25:
            v.co.z = -r*squash[2]*0.25
        if v.co.z > r*squash[2]*0.8:   # blunt top
            v.co.z = r*squash[2]*0.8 + (v.co.z - r*squash[2]*0.8)*0.3
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.05)
    return obj_from_bm(bm, name, mat("Basalt", (128, 124, 116)))
main = chunk(3.3, "Rock", 11, (1.2, 1.0, 0.88)); main.location.z = 3.3*0.88*0.25
side = chunk(1.8, "Rock2", 4, (1.1, 1.0, 0.85)); side.location = (3.6, -1.6, 1.8*0.7*0.25)
small = chunk(1.0, "Rock3", 9, (1.1, 1.0, 0.75)); small.location = (-3.4, 2.0, 0.2)
ob = join([main, side, small], "Rock"); mossify(ob)
k = 1.25
ob.scale = (k, k, k); ob.location = ob.location * k
bpy.ops.object.select_all(action='DESELECT'); ob.select_set(True); bpy.context.view_layer.objects.active = ob
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
export('/tmp/models/out/boulder.obj', [ob])
ground(80)
setup_render((0, 0, 1.5), 22, '/tmp/models/prev/boulder2.png', res=900, height=500, elev=0.3)
bpy.ops.render.render(write_still=True)
print("DONE")
