import bpy, bmesh, math, random, sys, os
sys.path.insert(0,'/tmp/models'); sys.path.insert(0,'/tmp/arch'); sys.path.insert(0,'/tmp/clover')
from lib import mat, reset
from fields import *
import field as CL
reset()
MATS={'Sand':(226,204,150),'Grass':(108,162,72),'LeafyGrass':(92,142,62),'Rock':(120,116,112),'Slate':(90,90,96),'Ground':(150,118,82),'Snow':(238,242,246),'Glacier':(176,214,232),'Mud':(96,80,60),'Basalt':(60,58,64),'CrackedLava':(240,100,36),'Seabed':(200,184,140),'Water':(70,160,200)}
M={k:mat('T'+k,v) for k,v in MATS.items()}
lava=M['CrackedLava']; b=lava.node_tree.nodes['Principled BSDF']; b.inputs['Emission Color'].default_value=(1,0.3,0.05,1); b.inputs['Emission Strength'].default_value=2.0
class Clover:
    name='Clover Island'; bounds=(-152,152,-152,176)
    def height(s,x,z): return CL.height(x,z)
    def material(s,x,z,h,sl): return CL.material(x,z,h,sl)
    def land(s,x,z): return CL.land(x,z)
    def zone(s,x,z): return CL.lobe_of(x,z)
    def can_grow(s,x,z): return CL.land(x,z)>0.1 and CL.path_dist(x,z)>5 and math.hypot(x+6,z-4)>14
ISL=[(Clover(),0,320),(PineHills(),-300,90),(StoneShelf(),300,90),(FrostIsle(),-190,-265),(SlimeMarsh(),195,-265),(EmberIsle(),0,0)]
STEP=float(os.environ.get('STEP','3'))
names=list(M.keys())
for isl,cx,cz in ISL:
    x0,x1,z0,z1=isl.bounds
    nx,nz=int((x1-x0)/STEP)+1,int((z1-z0)/STEP)+1
    H=[[isl.height(x0+i*STEP,z0+j*STEP) for i in range(nx)] for j in range(nz)]
    bm=bmesh.new(); V=[[bm.verts.new((cx+x0+i*STEP,-(cz+z0+j*STEP),H[j][i])) for i in range(nx)] for j in range(nz)]
    me=bpy.data.meshes.new(isl.name); ob=bpy.data.objects.new(isl.name,me); bpy.context.collection.objects.link(ob)
    for k in names: me.materials.append(M[k])
    for j in range(nz-1):
        for i in range(nx-1):
            f=bm.faces.new((V[j][i],V[j][i+1],V[j+1][i+1],V[j+1][i]))
            hs=[H[j][i],H[j][i+1],H[j+1][i],H[j+1][i+1]]; h=sum(hs)/4
            x,z=x0+(i+.5)*STEP,z0+(j+.5)*STEP
            m='Seabed' if h<0 else isl.material(x,z,h,(max(hs)-min(hs))/STEP)
            f.material_index=names.index(m)
    bm.to_mesh(me); bm.free()
# sea + pools
bpy.ops.mesh.primitive_plane_add(size=3000,location=(0,0,-27)); bpy.context.object.data.materials.append(M['Seabed'])
bpy.ops.mesh.primitive_plane_add(size=3000,location=(0,0,0.2)); sea=bpy.context.object
sm=bpy.data.materials.new('Sea'); sm.use_nodes=True; bb=sm.node_tree.nodes['Principled BSDF']
bb.inputs['Base Color'].default_value=(0.06,0.32,0.42,1); bb.inputs['Alpha'].default_value=0.72; bb.inputs['Roughness'].default_value=0.15
sea.data.materials.append(sm)
def disc(x,z,r,y,m):
    bpy.ops.mesh.primitive_cylinder_add(radius=r,depth=0.2,location=(x,-z,y),vertices=48); bpy.context.object.data.materials.append(m)
disc(-6,324,11,10.4,sm)
ph=ISL[1][0]
for p in ph.pools: disc(-300+p[0],90+p[1],p[2],p[3]-0.1,sm)
# props
def load(name):
    for d in ('out','out2'):
        f=f'/tmp/models/{d}/{name}.obj'
        if os.path.exists(f):
            before=set(bpy.data.objects); bpy.ops.wm.obj_import(filepath=f,up_axis='Y',forward_axis='NEGATIVE_Z')
            return [o for o in bpy.data.objects if o not in before]
for n in ['pine','palm','boulder','bush','boar','slimepool']:
    objs=load(n); col=bpy.data.collections.new(n)
    for o in objs:
        for c in o.users_collection: c.objects.unlink(o)
        col.objects.link(o)
snowpine=bpy.data.collections.new('snowpine')
for o in bpy.data.collections['pine'].objects:
    c=o.copy(); c.data=o.data.copy(); snowpine.objects.link(c)
    for i,ms in enumerate(c.data.materials):
        if ms and 'runk' not in ms.name.lower() and 'wood' not in ms.name.lower(): c.data.materials[i]=mat('snowy'+str(i),(214,228,232))
dark=bpy.data.collections.new('obsidian')
for o in bpy.data.collections['boulder'].objects:
    c=o.copy(); c.data=o.data.copy(); dark.objects.link(c)
    for i in range(len(c.data.materials)): c.data.materials[i]=mat('obs'+str(i),(44,36,58))
rng=random.Random(5)
def place(kind,isl,cx,cz,x,z,s):
    e=bpy.data.objects.new(kind,None); bpy.context.collection.objects.link(e)
    e.instance_type='COLLECTION'; e.instance_collection=bpy.data.collections[kind]
    e.location=(cx+x,-(cz+z),isl.height(x,z)-0.3); e.scale=(s,s,s); e.rotation_euler=(0,0,rng.uniform(0,6.28))
PLANS={
 'Clover Island':[('pine','pines',9,(2,4)),('bush','pines',3,None),('boulder','rocks',13,None),('palm','palms',8,(1,3)),('bush','meadow',8,None),('pine','meadow',2,(1,2)),('pine','centre',2,(1,2))],
 'Pine Hills':[('pine','forest',11,(2,4)),('bush','forest',3,None),('boulder','forest',3,None),('pine','meadow',3,(1,2)),('bush','meadow',8,None),('palm','shore',4,(1,2))],
 'Stone Shelf':[('boulder','cliffs',16,None),('boulder','slope',3,None),('pine','slope',4,(1,2)),('bush','slope',4,None)],
 'Frost Isle':[('snowpine','slopes',8,(1,3)),('boulder','peak',6,None),('boulder','shore',2,None)],
 'Slime Marsh':[('slimepool','*',8,None),('bush','*',10,None),('pine','heart',2,(1,1))],
 'Ember Isle':[('obsidian','slopes',9,None),('boulder','camp',3,None)],
}
for isl,cx,cz in ISL:
    taken=[]
    x0,x1,z0,z1=isl.bounds
    def spot(zone,sp,lst,near=None,nr=None):
        for _ in range(80):
            if near: a=rng.uniform(0,6.28); d=rng.uniform(sp,nr); x,z=near[0]+math.cos(a)*d,near[1]+math.sin(a)*d
            else: x,z=rng.uniform(x0,x1),rng.uniform(z0,z1)
            if isl.can_grow(x,z) and isl.height(x,z)>2.5 and (zone=='*' or isl.zone(x,z)==zone) and all(math.hypot(x-a,z-b)>=sp for a,b in lst): return (x,z)
    for kind,zone,n,clump in PLANS[isl.name]:
        for _ in range(n):
            c=spot(zone,30 if clump else 16,taken)
            if not c: continue
            mem=[c]; place(kind,isl,cx,cz,*c,rng.uniform(0.9,1.2))
            if clump:
                for _ in range(rng.randint(*clump)-1):
                    p=spot(zone,7,mem,c,11)
                    if p: mem.append(p); place(kind,isl,cx,cz,*p,rng.uniform(0.9,1.2))
            taken+=mem
# cave fang rocks at Stone Shelf, and the dark cave mouth
bpy.ops.mesh.primitive_uv_sphere_add(radius=6,location=(300+12,-(90-84),7)); o=bpy.context.object; o.scale=(1.2,0.5,0.9); o.data.materials.append(mat('cave',(16,14,12)))
ss=ISL[2][0]; mx,mz=ss.cave_mouth
white=mat('fang',(232,228,214))
for k in range(9):
    a=math.radians(-150+k*37.5); r=9.5
    fx,fz=mx+math.cos(a)*r, mz+math.sin(a)*r*0.6-3
    bpy.ops.mesh.primitive_cone_add(vertices=5,radius1=1.6,radius2=0.2,depth=7+3*(k%2),location=(300+fx,-(90+fz),ss.height(fx,fz)+2.5))
    o=bpy.context.object; o.data.materials.append(white); o.rotation_euler=(math.radians(-15),0,a)
sc=bpy.context.scene
sun=bpy.data.objects.new('Sun',bpy.data.lights.new('Sun','SUN')); sun.data.energy=3.4; sun.data.angle=0.15
sun.rotation_euler=(math.radians(50),math.radians(8),math.radians(30)); sc.collection.objects.link(sun)
sc.world=bpy.data.worlds.new('W'); sc.world.use_nodes=True
bg=sc.world.node_tree.nodes['Background']; bg.inputs[0].default_value=(0.55,0.7,0.88,1); bg.inputs[1].default_value=0.9
sc.render.engine='CYCLES'; sc.cycles.device='CPU'; sc.cycles.samples=int(os.environ.get('SAMPLES','16'))
sc.view_settings.view_transform='Standard'
def shot(path,loc,target,lens=32,res=(1600,1000),ortho=0):
    cam=bpy.data.objects.new('Cam',bpy.data.cameras.new('Cam')); sc.collection.objects.link(cam); cam.data.lens=lens; cam.data.clip_end=5000
    cam.location=loc
    if ortho: cam.data.type='ORTHO'; cam.data.ortho_scale=ortho; cam.rotation_euler=(0,0,0)
    else:
        t=bpy.data.objects.new('T',None); t.location=target; sc.collection.objects.link(t)
        c=cam.constraints.new('TRACK_TO'); c.target=t; c.track_axis='TRACK_NEGATIVE_Z'; c.up_axis='UP_Y'
    sc.camera=cam; sc.render.resolution_x,sc.render.resolution_y=res; sc.render.filepath=path
    bpy.ops.render.render(write_still=True)
for spec in os.environ.get('SHOTS','overview').split(','):
    if spec=='overview': shot('/tmp/arch/overview.png',(0,-700,520),(0,-40,0),lens=34,res=(1600,1100))
    if spec=='top': shot('/tmp/arch/top.png',(0,-40,800),None,res=(1200,1300),ortho=900)
    if spec=='pine': shot('/tmp/arch/pine3d.png',(-170,-10,95),(-305,-90,8),lens=30)
    if spec=='stone': shot('/tmp/arch/stone3d.png',(330,90,60),(305,-5,14),lens=30)
    if spec=='frost': shot('/tmp/arch/frost3d.png',(-110,365,80),(-190,265,22),lens=30)
    if spec=='marsh': shot('/tmp/arch/marsh3d.png',(110,170,85),(195,265,2),lens=30)
    if spec=='ember': shot('/tmp/arch/ember3d.png',(10,-170,70),(0,0,22),lens=28)
print('DONE')
