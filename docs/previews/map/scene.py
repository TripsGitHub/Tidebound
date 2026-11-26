import bpy, bmesh, math, random, sys, os
sys.path.insert(0,'/tmp/models'); sys.path.insert(0,'/tmp/arch'); sys.path.insert(0,'/tmp/clover')
from lib import mat, reset
from fields import *
import field as CL
reset()
MATS={'Sand':(198,178,130),'Grass':(118,126,58),'LeafyGrass':(92,102,50),'Rock':(84,80,74),'Slate':(74,74,78),'Ground':(112,88,60),'Snow':(238,242,246),'Glacier':(176,214,232),'Mud':(74,62,46),'Basalt':(44,42,46),'CrackedLava':(240,100,36),'Seabed':(150,138,104),'Water':(30,98,112)}
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
STEP=float(os.environ.get('STEP','2'))
GRASS=os.environ.get('GRASS','').split(',')
def lin(c): return tuple((((v/255)+0.055)/1.055)**2.4 for v in c)
# One terrain material driven by blended vertex colours, like Roblox blends
# materials between voxels; a little noise breaks up flat colour.
tm=bpy.data.materials.new('Terrain'); tm.use_nodes=True; nt=tm.node_tree
bs=nt.nodes['Principled BSDF']; bs.inputs['Roughness'].default_value=0.9
ca=nt.nodes.new('ShaderNodeVertexColor'); ca.layer_name='Col'
nz=nt.nodes.new('ShaderNodeTexNoise'); nz.inputs['Scale'].default_value=1.6; nz.inputs['Detail'].default_value=4
tc=nt.nodes.new('ShaderNodeTexCoord'); nt.links.new(tc.outputs['Object'],nz.inputs['Vector'])
mr=nt.nodes.new('ShaderNodeMapRange'); mr.inputs['To Min'].default_value=0.9; mr.inputs['To Max'].default_value=1.07
nt.links.new(nz.outputs['Fac'],mr.inputs['Value'])
mx=nt.nodes.new('ShaderNodeMix'); mx.data_type='RGBA'; mx.blend_type='MULTIPLY'; mx.inputs['Factor'].default_value=1
nt.links.new(ca.outputs['Color'],mx.inputs['A'])
cm=nt.nodes.new('ShaderNodeCombineColor'); nt.links.new(mr.outputs['Result'],cm.inputs[0]); nt.links.new(mr.outputs['Result'],cm.inputs[1]); nt.links.new(mr.outputs['Result'],cm.inputs[2])
nt.links.new(cm.outputs['Color'],mx.inputs['B']); nt.links.new(mx.outputs['Result'],bs.inputs['Base Color'])
bp=nt.nodes.new('ShaderNodeBump'); bp.inputs['Strength'].default_value=0.25
n2=nt.nodes.new('ShaderNodeTexNoise'); n2.inputs['Scale'].default_value=2.5; n2.inputs['Detail'].default_value=8
nt.links.new(tc.outputs['Object'],n2.inputs['Vector']); nt.links.new(n2.outputs['Fac'],bp.inputs['Height']); nt.links.new(bp.outputs['Normal'],bs.inputs['Normal'])
grassmat=bpy.data.materials.new('GrassHair'); grassmat.use_nodes=True
gb=grassmat.node_tree.nodes['Principled BSDF']; gb.inputs['Base Color'].default_value=(*lin((150,146,62)),1); gb.inputs['Roughness'].default_value=0.8
import bmesh as _bm
def _clump(seed):
    L=float(os.environ.get('GRASSLEN','2.6')); bm=_bm.new(); r=random.Random(seed)
    for k in range(r.randint(5,9)):
        a=r.uniform(0,6.28); lean=r.uniform(0.05,0.45); w=r.uniform(0.08,0.16); h=L*r.uniform(0.5,1.0)
        ox,oy=r.uniform(-0.5,0.5),r.uniform(-0.5,0.5)
        dx,dy=math.cos(a),math.sin(a)
        v1=bm.verts.new((0,ox-dy*w,oy+dx*w)); v2=bm.verts.new((0,ox+dy*w,oy-dx*w))
        v3=bm.verts.new((h,ox+dx*lean*h,oy+dy*lean*h))
        bm.faces.new((v1,v2,v3))
    me=bpy.data.meshes.new('clump'); bm.to_mesh(me); bm.free()
    o=bpy.data.objects.new('clump',me)
    for p in me.polygons: p.use_smooth=True
    shade=r.uniform(0.75,1.15); m=grassmat.copy(); b=m.node_tree.nodes['Principled BSDF']
    c=b.inputs['Base Color'].default_value; b.inputs['Base Color'].default_value=(c[0]*shade,c[1]*shade*r.uniform(0.95,1.08),c[2]*shade,1)
    me.materials.append(m); return o
CLUMPS=bpy.data.collections.new('clumps')
for k in range(10): CLUMPS.objects.link(_clump(k))
for isl,cx,cz in ISL:
    x0,x1,z0,z1=isl.bounds
    nx,nz_=int((x1-x0)/STEP)+1,int((z1-z0)/STEP)+1
    H=[[isl.height(x0+i*STEP,z0+j*STEP) for i in range(nx)] for j in range(nz_)]
    C=[[None]*nx for _ in range(nz_)]; G=[[0.0]*nx for _ in range(nz_)]
    for j in range(nz_):
        for i in range(nx):
            h=H[j][i]
            sl=max(abs(H[j][min(i+1,nx-1)]-H[j][max(i-1,0)]),abs(H[min(j+1,nz_-1)][i]-H[max(j-1,0)][i]))/(2*STEP)
            m='Seabed' if h<0 else isl.material(x0+i*STEP,z0+j*STEP,h,sl)
            C[j][i]=lin(MATS[m]); G[j][i]=1.0 if m in ('Grass','LeafyGrass') else 0.0
    # blend: two passes of a 3x3 average, roughly the width Roblox blends over
    for _ in range(int(os.environ.get('BLUR','0'))):
        N=[[None]*nx for _ in range(nz_)]; NG=[[0]*nx for _ in range(nz_)]
        for j in range(nz_):
            for i in range(nx):
                acc=[0,0,0]; g=0; n=0
                for dj in (-1,0,1):
                    for di in (-1,0,1):
                        jj,ii=j+dj,i+di
                        if 0<=jj<nz_ and 0<=ii<nx:
                            c=C[jj][ii]; acc[0]+=c[0]; acc[1]+=c[1]; acc[2]+=c[2]; g+=G[jj][ii]; n+=1
                N[j][i]=(acc[0]/n,acc[1]/n,acc[2]/n); NG[j][i]=g/n
        C,G=N,NG
    bm=bmesh.new(); V=[[bm.verts.new((cx+x0+i*STEP,-(cz+z0+j*STEP),H[j][i])) for i in range(nx)] for j in range(nz_)]
    me=bpy.data.meshes.new(isl.name); ob=bpy.data.objects.new(isl.name,me); bpy.context.collection.objects.link(ob)
    me.materials.append(tm)
    col=bm.loops.layers.color.new('Col')
    for j in range(nz_-1):
        for i in range(nx-1):
            if max(H[j][i],H[j][i+1],H[j+1][i],H[j+1][i+1])<-25.5: continue
            f=bm.faces.new((V[j][i],V[j][i+1],V[j+1][i+1],V[j+1][i])); f.smooth=True
            for lp,(jj,ii) in zip(f.loops,((j,i),(j,i+1),(j+1,i+1),(j+1,i))):
                lp[col]=(*C[jj][ii],1)
    uvl=bm.loops.layers.uv.new('UV')
    for f in bm.faces:
        for lp in f.loops:
            co=lp.vert.co; lp[uvl].uv=((co.x-cx-x0)/(x1-x0),((-co.y)-cz-z0)/(z1-z0))
    bm.to_mesh(me); bm.free()
    # Material colour map at sub-voxel resolution, so borders follow the noisy
    # edges in the material function instead of the mesh grid.
    RES=float(os.environ.get('TEXRES','0.6'))
    iw,ih=int((x1-x0)/RES)+1,int((z1-z0)/RES)+1
    px=[0.0]*(iw*ih*4)
    for j in range(ih):
        z=z0+j*RES
        for i in range(iw):
            x=x0+i*RES; h=isl.height(x,z)
            if h<-25.5: c=lin(MATS['Seabed'])
            else:
                sl=max(abs(isl.height(x+1,z)-isl.height(x-1,z)),abs(isl.height(x,z+1)-isl.height(x,z-1)))/2
                c=lin(MATS['Seabed' if h<0 else isl.material(x,z,h,sl)])
            k=(j*iw+i)*4; px[k]=c[0]; px[k+1]=c[1]; px[k+2]=c[2]; px[k+3]=1
    im=bpy.data.images.new(isl.name+'Mat',iw,ih,float_buffer=True); im.colorspace_settings.name='Non-Color'
    im.pixels.foreach_set(px)
    mi=tm.copy(); me.materials[0]=mi
    it=mi.node_tree.nodes.new('ShaderNodeTexImage'); it.image=im; it.interpolation='Linear'; it.extension='EXTEND'
    mix=[n for n in mi.node_tree.nodes if n.type=='MIX'][0]
    mi.node_tree.links.new(it.outputs['Color'],mix.inputs['A'])
    if isl.name in GRASS:
        vg=ob.vertex_groups.new(name='grass')
        for j in range(nz_):
            for i in range(nx):
                w=G[j][i] if H[j][i]>1.5 else 0
                if w>0.05: vg.add([j*nx+i],w,'REPLACE')
        me.materials.append(grassmat)
        mod=ob.modifiers.new('hair','PARTICLE_SYSTEM'); ps=mod.particle_system; st=ps.settings
        st.type='HAIR'; st.count=int(float(os.environ.get('GRASSN','60000'))); st.hair_length=1
        st.render_type='COLLECTION'; st.instance_collection=CLUMPS; st.use_collection_pick_random=True; st.particle_size=1; st.size_random=0.5
        st.use_advanced_hair=True; st.use_rotations=True; st.rotation_mode='VEL'; st.phase_factor_random=2.0; st.rotation_factor_random=0.12
        ps.vertex_group_density='grass'
# sea + pools
bpy.ops.mesh.primitive_plane_add(size=3000,location=(0,0,-26.02)); fl=bpy.context.object.data; fl.materials.append(tm)
fa=fl.color_attributes.new('Col','FLOAT_COLOR','CORNER')
for d in fa.data: d.color=(*lin(MATS['Seabed']),1)
bpy.ops.mesh.primitive_plane_add(size=3000,location=(0,0,0.2)); sea=bpy.context.object
sm=bpy.data.materials.new('Sea'); sm.use_nodes=True; bb=sm.node_tree.nodes['Principled BSDF']
bb.inputs['Base Color'].default_value=(0.02,0.1,0.13,1); bb.inputs['Alpha'].default_value=0.72; bb.inputs['Roughness'].default_value=0.15
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
# darker, olive foliage to sit with the golden grass
for cn in ('pine','palm','bush'):
    for o in bpy.data.collections[cn].objects:
        for ms in o.data.materials:
            if not ms or not ms.use_nodes: continue
            b=ms.node_tree.nodes.get('Principled BSDF')
            if not b: continue
            c=b.inputs['Base Color'].default_value
            if c[1]>c[0]*1.2 and c[1]>c[2]:   # greens only
                b.inputs['Base Color'].default_value=(c[1]*0.42,c[1]*0.5,c[1]*0.16,1)
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
sun=bpy.data.objects.new('Sun',bpy.data.lights.new('Sun','SUN')); sun.data.energy=5.0; sun.data.angle=0.05
sun.data.color=(1.0,0.86,0.66)
from mathutils import Vector as _V
LDIR=_V((0.45,0.75,-0.55)).normalized()   # direction sunlight travels (from behind-left of the cameras)
sun.rotation_euler=LDIR.to_track_quat('-Z','Y').to_euler(); sc.collection.objects.link(sun)
sc.world=bpy.data.worlds.new('W'); sc.world.use_nodes=True; wn=sc.world.node_tree
bg=wn.nodes['Background']; sky=wn.nodes.new('ShaderNodeTexSky'); sky.sky_type='HOSEK_WILKIE'; sky.turbidity=3.0; sky.ground_albedo=0.3
sky.sun_direction=tuple(-LDIR)
wn.links.new(sky.outputs['Color'],bg.inputs['Color']); bg.inputs[1].default_value=float(os.environ.get('SKY','1.0'))
if os.environ.get('HAZE','1')=='1':
    # haze in a big box over the map (a world volume would block the sun entirely)
    bpy.ops.mesh.primitive_cube_add(size=1,location=(0,-40,150)); hb=bpy.context.object; hb.scale=(2400,2400,300)
    vm=bpy.data.materials.new('Haze'); vm.use_nodes=True; vn=vm.node_tree; vn.nodes.remove(vn.nodes['Principled BSDF'])
    vol=vn.nodes.new('ShaderNodeVolumePrincipled'); vol.inputs['Density'].default_value=float(os.environ.get('HAZED','0.00025'))
    vol.inputs['Color'].default_value=(0.95,0.85,0.68,1); vol.inputs['Anisotropy'].default_value=0.6
    vn.links.new(vol.outputs['Volume'],vn.nodes['Material Output'].inputs['Volume']); hb.data.materials.append(vm)
sc.render.engine='CYCLES'; sc.cycles.device='CPU'; sc.cycles.samples=int(os.environ.get('SAMPLES','16'))
sc.cycles.volume_step_rate=8; sc.cycles.volume_max_steps=64
try: sc.view_settings.view_transform='AgX'; sc.view_settings.look='AgX - Punchy'; sc.view_settings.exposure=0.1
except Exception: sc.view_settings.view_transform='Filmic'; sc.view_settings.look='Medium High Contrast'
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
    if spec=='cloverground':
        gx,gz=54,58; gh=CL.height(gx,gz)
        shot('/tmp/arch/clover-ground.png',(gx,-(320+gz),gh+7),(-6,-(320+4),CL.height(-6,4)+2),lens=24,res=(1600,1000))
    if spec=='pineground':
        gx,gz=-20,60; gh=ISL[1][0].height(gx,gz)
        shot('/tmp/arch/pine-ground.png',(-300+gx,-(90+gz),gh+10),(-300+gx+10,-(90+gz-70),gh+3),lens=24,res=(1600,1000))
print('DONE')
