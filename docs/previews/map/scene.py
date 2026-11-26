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
STEP=float(os.environ.get('STEP','2'))
GRASS=os.environ.get('GRASS','').split(',')
def lin(c): return tuple((((v/255)+0.055)/1.055)**2.4 for v in c)
# One terrain material driven by blended vertex colours, like Roblox blends
# materials between voxels; a little noise breaks up flat colour.
tm=bpy.data.materials.new('Terrain'); tm.use_nodes=True; nt=tm.node_tree
bs=nt.nodes['Principled BSDF']; bs.inputs['Roughness'].default_value=0.9
ca=nt.nodes.new('ShaderNodeVertexColor'); ca.layer_name='Col'
nz=nt.nodes.new('ShaderNodeTexNoise'); nz.inputs['Scale'].default_value=0.35; nz.inputs['Detail'].default_value=6
tc=nt.nodes.new('ShaderNodeTexCoord'); nt.links.new(tc.outputs['Object'],nz.inputs['Vector'])
mr=nt.nodes.new('ShaderNodeMapRange'); mr.inputs['To Min'].default_value=0.82; mr.inputs['To Max'].default_value=1.12
nt.links.new(nz.outputs['Fac'],mr.inputs['Value'])
mx=nt.nodes.new('ShaderNodeMix'); mx.data_type='RGBA'; mx.blend_type='MULTIPLY'; mx.inputs['Factor'].default_value=1
nt.links.new(ca.outputs['Color'],mx.inputs['A'])
cm=nt.nodes.new('ShaderNodeCombineColor'); nt.links.new(mr.outputs['Result'],cm.inputs[0]); nt.links.new(mr.outputs['Result'],cm.inputs[1]); nt.links.new(mr.outputs['Result'],cm.inputs[2])
nt.links.new(cm.outputs['Color'],mx.inputs['B']); nt.links.new(mx.outputs['Result'],bs.inputs['Base Color'])
bp=nt.nodes.new('ShaderNodeBump'); bp.inputs['Strength'].default_value=0.25
n2=nt.nodes.new('ShaderNodeTexNoise'); n2.inputs['Scale'].default_value=2.5; n2.inputs['Detail'].default_value=8
nt.links.new(tc.outputs['Object'],n2.inputs['Vector']); nt.links.new(n2.outputs['Fac'],bp.inputs['Height']); nt.links.new(bp.outputs['Normal'],bs.inputs['Normal'])
grassmat=bpy.data.materials.new('GrassHair'); grassmat.use_nodes=True
gb=grassmat.node_tree.nodes['Principled BSDF']; gb.inputs['Base Color'].default_value=(*lin((92,150,58)),1); gb.inputs['Roughness'].default_value=0.8
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
    for _ in range(2):
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
    bm.to_mesh(me); bm.free()
    if isl.name in GRASS:
        vg=ob.vertex_groups.new(name='grass')
        for j in range(nz_):
            for i in range(nx):
                w=G[j][i] if H[j][i]>1.5 else 0
                if w>0.05: vg.add([j*nx+i],w,'REPLACE')
        me.materials.append(grassmat)
        mod=ob.modifiers.new('hair','PARTICLE_SYSTEM'); ps=mod.particle_system; st=ps.settings
        st.type='HAIR'; st.count=int(float(os.environ.get('GRASSN','120000'))); st.hair_length=1.5; st.material=2
        st.use_advanced_hair=True; st.use_rotations=True; st.rotation_mode='NOR'; st.child_type='SIMPLE'; st.rendered_child_count=10; st.child_radius=0.9; st.child_length_threshold=0; st.roughness_endpoint=0.25; st.roughness_1=0.15; st.display_step=2; st.render_step=2
        st.brownian_factor=0.2; st.length_random=0.6
        ps.vertex_group_density='grass'; ps.vertex_group_length='grass'
        st.root_radius=0.2; st.tip_radius=0.0; st.radius_scale=1
# sea + pools
bpy.ops.mesh.primitive_plane_add(size=3000,location=(0,0,-26.02)); fl=bpy.context.object.data; fl.materials.append(tm)
fa=fl.color_attributes.new('Col','FLOAT_COLOR','CORNER')
for d in fa.data: d.color=(*lin(MATS['Seabed']),1)
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
    if spec=='cloverground':
        gx,gz=54,58; gh=CL.height(gx,gz)
        shot('/tmp/arch/clover-ground.png',(gx,-(320+gz),gh+12),(-6,-(320+4),CL.height(-6,4)+2),lens=24,res=(1600,1000))
    if spec=='pineground':
        gx,gz=-20,60; gh=ISL[1][0].height(gx,gz)
        shot('/tmp/arch/pine-ground.png',(-300+gx,-(90+gz),gh+14),(-300+gx+10,-(90+gz-70),gh+3),lens=24,res=(1600,1000))
print('DONE')
