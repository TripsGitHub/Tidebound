import bpy, bmesh, math, random, sys, os
sys.path.insert(0,'/tmp/models'); sys.path.insert(0,'/tmp/clover')
from lib import mat, reset
from field import *
reset()
MATS = {'Sand':(226,204,150),'Grass':(108,162,72),'LeafyGrass':(96,146,64),'Rock':(112,108,104),'Ground':(150,118,82),'Water':(60,150,175),'Seabed':(200,184,140)}
M = {k:mat('T'+k,v) for k,v in MATS.items()}
# terrain mesh: Blender (X, Y, Z) = Roblox (x, -z, y)
S=2.0; X0,X1,Z0,Z1=-150,150,-150,175
nx,nz=int((X1-X0)/S)+1,int((Z1-Z0)/S)+1
H=[[height(X0+i*S,Z0+j*S) for i in range(nx)] for j in range(nz)]
bm=bmesh.new(); V=[[bm.verts.new((X0+i*S,-(Z0+j*S),H[j][i])) for i in range(nx)] for j in range(nz)]
me=bpy.data.meshes.new('Island'); ob=bpy.data.objects.new('Island',me); bpy.context.collection.objects.link(ob)
names=list(M.keys())
for k in names: me.materials.append(M[k])
for j in range(nz-1):
    for i in range(nx-1):
        f=bm.faces.new((V[j][i],V[j][i+1],V[j+1][i+1],V[j+1][i]))
        x,z=X0+(i+.5)*S,Z0+(j+.5)*S; hs=[H[j][i],H[j][i+1],H[j+1][i],H[j+1][i+1]]
        h=sum(hs)/4; slope=(max(hs)-min(hs))/S
        m = 'Seabed' if h < 0 else material(x,z,h,slope)
        f.material_index=names.index(m)
bm.to_mesh(me); bm.free()
# sea
bpy.ops.mesh.primitive_plane_add(size=1400,location=(0,-20,-27)); bpy.context.object.data.materials.append(M['Seabed'])
bpy.ops.mesh.primitive_plane_add(size=1400,location=(0,-20,0.2)); sea=bpy.context.object
sm=bpy.data.materials.new('Sea'); sm.use_nodes=True; b=sm.node_tree.nodes['Principled BSDF']
b.inputs['Base Color'].default_value=(0.06,0.32,0.42,1); b.inputs['Alpha'].default_value=0.72; b.inputs['Roughness'].default_value=0.15
sea.data.materials.append(sm)
# pond
bpy.ops.mesh.primitive_cylinder_add(radius=11,depth=0.2,location=(-6,-4,10.4),vertices=64); bpy.context.object.data.materials.append(sm)
# props
def load(name):
    for d in ('out','out2'):
        f=f'/tmp/models/{d}/{name}.obj'
        if os.path.exists(f):
            before=set(bpy.data.objects)
            bpy.ops.wm.obj_import(filepath=f,up_axis='Y',forward_axis='NEGATIVE_Z')
            return [o for o in bpy.data.objects if o not in before]
proto={}
for n in ['pine','palm','boulder','bush','boar','log']:
    objs=load(n); e=bpy.data.objects.new('P_'+n,None); bpy.context.collection.objects.link(e)
    for o in objs: o.parent=e
    e.location=(0,0,-500); proto[n]=e
def place(n,x,z,s=1.0):
    src=proto[n]; e=bpy.data.objects.new(n,None); bpy.context.collection.objects.link(e)
    e.instance_type='COLLECTION'
    if n not in bpy.data.collections:
        col=bpy.data.collections.new(n)
        for o in src.children: col.objects.link(o)
        col.instance_offset=(0,0,-500)
    e.instance_collection=bpy.data.collections[n]
    e.location=(x,-z,height(x,z)-0.3); e.scale=(s,s,s); e.rotation_euler=(0,0,rng.uniform(0,6.28))
rng=random.Random(7)
taken=[(0,108)]+[(-12,92),(12,92)]
def ok(x,z,sp,lst):
    return all(math.hypot(x-a,z-b)>=sp for a,b in lst)
def zone_spot(zone,sp,lst,near=None,nr=None):
    for _ in range(60):
        if near: a=rng.uniform(0,6.28); d=rng.uniform(sp,nr); x,z=near[0]+math.cos(a)*d,near[1]+math.sin(a)*d
        else: x,z=rng.uniform(-125,125),rng.uniform(-125,135)
        l=land(x,z)
        if l>0.1 and lobe_of(x,z)==zone and path_dist(x,z)>5 and math.hypot(x+6,z-4)>14 and ok(x,z,sp,lst): return (x,z)
def trees(zone,kind,clumps,size,sc):
    for _ in range(clumps):
        c=zone_spot(zone,22,taken)
        if not c: continue
        mem=[c]; place(kind,*c,s=rng.uniform(*sc))
        for _ in range(rng.randint(*size)-1):
            p=zone_spot(zone,7,mem,c,11)
            if p: mem.append(p); place(kind,*p,s=rng.uniform(*sc))
        taken.extend(mem)
def singles(zone,kind,n,sp,sc):
    for _ in range(n):
        p=zone_spot(zone,sp,taken)
        if p: taken.append(p); place(kind,*p,s=rng.uniform(*sc))
trees('pines','pine',9,(2,4),(0.9,1.25)); singles('pines','bush',3,14,(0.9,1.1)); singles('pines','boulder',2,16,(0.7,0.9))
singles('rocks','boulder',13,11,(0.8,1.3)); trees('rocks','pine',2,(1,1),(0.9,1.1))
trees('palms','palm',8,(1,3),(0.9,1.15)); singles('palms','bush',3,14,(0.9,1.1))
singles('meadow','bush',8,13,(0.9,1.15)); trees('meadow','pine',2,(1,2),(0.9,1.1)); singles('meadow','boulder',2,16,(0.7,0.9))
trees('centre','pine',2,(1,2),(1.0,1.2)); singles('centre','bush',2,12,(0.9,1.1))
for (x,z,r) in [(40,40,0.6),(46,52,2.4),(33,55,4.1)]: place('boar',x,z); 
# spawn stuff: player, board, trader
skin=mat('Skin',(238,196,160)); shirt=mat('Shirt',(60,110,170)); pants=mat('Pants',(50,50,60)); wood=mat('Wd',(130,90,58)); cloth=mat('Cl',(196,92,62))
def cube(loc,sc,m):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc); c=bpy.context.object; c.scale=sc; c.data.materials.append(m)
gx,gz=0,108; gy=height(gx,gz)
for (px,py,pz),(sx,sy,sz),m in [((0,0,4.9),(1.1,1.1,1.1),skin),((0,0,3.4),(2,1,1.9),shirt),((-1.5,0,3.4),(0.95,1,1.9),shirt),((1.5,0,3.4),(0.95,1,1.9),shirt),((-0.5,0,1.2),(0.95,1,2.4),pants),((0.5,0,1.2),(0.95,1,2.4),pants)]:
    cube((gx+px,-gz+py,gy+pz),(sx,sy,sz),m)
bx,bz=-12,92; by=height(bx,bz)
cube((bx-2.8,-bz,by+3.7),(0.7,0.7,7.5),wood); cube((bx+2.8,-bz,by+3.7),(0.7,0.7,7.5),wood); cube((bx,-bz,by+4.8),(6.4,0.4,3.8),wood)
tx,tz=12,92; ty=height(tx,tz)
cube((tx,-tz,ty+1.4),(7,1.6,2.8),wood); cube((tx,-tz,ty+7.2),(7.6,4.2,0.3),cloth)
for x in (-3.4,3.4): cube((tx+x,-tz+1.2,ty+3.6),(0.45,0.45,7.3),wood)
# camera + light
sc=bpy.context.scene
sun=bpy.data.objects.new('Sun',bpy.data.lights.new('Sun','SUN')); sun.data.energy=3.4; sun.data.angle=0.15
sun.rotation_euler=(math.radians(50),math.radians(8),math.radians(30)); sc.collection.objects.link(sun)
sc.world=bpy.data.worlds.new('W'); sc.world.use_nodes=True
bg=sc.world.node_tree.nodes['Background']; bg.inputs[0].default_value=(0.55,0.7,0.88,1); bg.inputs[1].default_value=0.9
sc.render.engine='CYCLES'; sc.cycles.device='CPU'; sc.cycles.samples=int(os.environ.get('SAMPLES','20'))
sc.view_settings.view_transform='Standard'
def shot(path,loc,target,lens=32,res=(1600,1000),ortho=0):
    cam=bpy.data.objects.new('Cam',bpy.data.cameras.new('Cam')); sc.collection.objects.link(cam); cam.data.lens=lens; cam.data.clip_end=3000
    cam.location=loc
    if ortho:
        cam.data.type='ORTHO'; cam.data.ortho_scale=ortho; cam.rotation_euler=(0,0,0)
    else:
        t=bpy.data.objects.new('T',None); t.location=target; sc.collection.objects.link(t)
        c=cam.constraints.new('TRACK_TO'); c.target=t; c.track_axis='TRACK_NEGATIVE_Z'; c.up_axis='UP_Y'
    sc.camera=cam; sc.render.resolution_x,sc.render.resolution_y=res; sc.render.filepath=path
    bpy.ops.render.render(write_still=True)
which=os.environ.get('SHOT','aerial')
if which in ('aerial','all'): shot('/tmp/clover/aerial.png',(105,-190,105),(0,-20,0),lens=30)
if which in ('top','all'): shot('/tmp/clover/top.png',(0,-15,300),None,res=(1100,1200),ortho=330)
if which in ('ground','all'): shot('/tmp/clover/ground.png',(6,-122,8),(-4,-40,9),lens=24)
print('DONE')
