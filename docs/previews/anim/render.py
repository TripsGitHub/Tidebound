import bpy, math, os, sys
from mathutils import Matrix, Vector
sys.path.insert(0,'/tmp/animprev')
from keys import parse, sample
ANIMS,HOLD=parse('/home/user/tidebound/src/client/Anim.lua')
TRAIL={'slash':((0.43,0.93,1.0),0.08,0.26,0.85),'swing':((1,1,1),0.08,0.20,0.5)}
bpy.ops.wm.read_factory_settings(use_empty=True)
sc=bpy.context.scene
def mat(name,rgb):
    m=bpy.data.materials.new(name); m.use_nodes=True
    b=m.node_tree.nodes['Principled BSDF']; b.inputs['Base Color'].default_value=(*[(c/255)**2.2 for c in rgb],1); b.inputs['Roughness'].default_value=0.8; return m
SK,SH,PA,WD,WDD,BER,GR,ST,EYE=[mat(n,c) for n,c in [('eye',(30,26,24)),('sk',(238,196,160)),('sh',(60,110,170)),('pa',(50,50,60)),('wd',(141,101,64)),('wdd',(104,72,45)),('ber',(190,38,64)),('gr',(106,158,70)),('st',(128,128,133))]][1:]+[mat('eye2',(30,26,24))]
C4=Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)))
def R(v):
    x,y,z=[math.radians(a) for a in v]
    return Matrix.Rotation(x,4,'X')@Matrix.Rotation(y,4,'Y')@Matrix.Rotation(z,4,'Z')
T=lambda p:Matrix.Translation(Vector(p))
def S(s): return Matrix.Diagonal((*s,1))
def joint(pos,rot): return T(pos)@R(rot)@T([-c for c in pos])
def cube(name,m):
    bpy.ops.mesh.primitive_cube_add(size=1); o=bpy.context.object; o.name=name; o.data.materials.append(m); return o
# blocky R15 body, Roblox coords, feet at y=0
PARTS=[('LowerTorso',(0,2.2,0),(2,0.4,1),SH,'root'),('UpperTorso',(0,3.2,0),(2,1.6,1),SH,'waist'),('Head',(0,4.6,0),(1.2,1.2,1.2),SK,'neck'),
 ('LUA',(-1.5,3.4,0),(1,1.2,1),SH,'waist'),('LLA',(-1.5,2.4,0),(1,0.9,1),SK,'waist'),('LH',(-1.5,1.8,0),(0.9,0.3,0.9),SK,'waist'),
 ('RUA',(1.5,3.4,0),(1,1.2,1),SH,'shoulder'),('RLA',(1.5,2.4,0),(1,0.9,1),SK,'elbow'),('RH',(1.5,1.8,0),(0.9,0.3,0.9),SK,'elbow'),
 ('LL',(-0.5,1.0,0),(1,2.0,1),PA,'root'),('RL',(0.5,1.0,0),(1,2.0,1),PA,'root')]
WAIST,NECK,SHO,ELB=(0,2.4,0),(0,4.0,0),(1.5,3.9,0),(1.5,2.85,0)
GRIP=(1.5,1.75,0)
def tool_parts(kind):
    # built along +Y from the grip, then turned -90 about X (points forward), like Appearance.setTool
    if kind=='harvester': return [((0,1.4,0),(0.25,2.8,0.25),WD),((0,2.7,-0.35),(0.35,0.4,1.1),ST)]
    if kind=='club': return [((0,0.7,0),(0.3,1.4,0.3),WDD),((0,2.0,0),(0.55,1.4,0.55),WD)]
    if kind=='berries': return [((0,0.35,0),(0.5,0.5,0.5),BER)]
    return []
class Char:
    def __init__(s,ox,oz,anim,tool,trail):
        s.o=T((ox,0,oz)); s.anim=anim; s.tool=tool; s.trail=trail
        s.objs=[(cube(n,m),c,sz,g) for n,c,sz,m,g in PARTS]
        s.tobjs=[(cube('tool',m),c,sz) for c,sz,m in tool_parts(tool)]
        s.objs+=[(cube('eye',EYE),(ex,4.75,-0.61),(0.16,0.26,0.04),'neck') for ex in (-0.25,0.25)]
        s.hist=[]
        if trail:
            s.tr=bpy.data.objects.new('trail',bpy.data.meshes.new('trail')); sc.collection.objects.link(s.tr)
            tm=bpy.data.materials.new('trailm'); tm.use_nodes=True; nt=tm.node_tree; nt.nodes.clear()
            out=nt.nodes.new('ShaderNodeOutputMaterial'); mix=nt.nodes.new('ShaderNodeMixShader'); tr=nt.nodes.new('ShaderNodeBsdfTransparent'); em=nt.nodes.new('ShaderNodeEmission'); at=nt.nodes.new('ShaderNodeAttribute'); at.attribute_name='a'
            col=TRAIL[anim][0]; em.inputs[0].default_value=(*col,1); em.inputs[1].default_value=1.6
            nt.links.new(at.outputs['Fac'],mix.inputs[0]); nt.links.new(tr.outputs[0],mix.inputs[1]); nt.links.new(em.outputs[0],mix.inputs[2]); nt.links.new(mix.outputs[0],out.inputs[0])
            tm.blend_method='BLEND' if hasattr(tm,'blend_method') else None
            s.tr.data.materials.append(tm)
    def mats(s,t):
        rest=HOLD if s.tool in ('harvester','club') else {}
        p=sample(ANIMS[s.anim],rest,t) if s.anim else rest
        z=(0,0,0)
        W=joint(WAIST,p.get('Waist',z)); N=W@joint(NECK,p.get('Neck',z)); SHm=W@joint(SHO,p.get('RightShoulder',z)); EL=SHm@joint(ELB,p.get('RightElbow',z))
        return {'root':Matrix.Identity(4),'waist':W,'neck':N,'shoulder':SHm,'elbow':EL}
    def tip(s,t):
        G=s.mats(t)['elbow']@T(GRIP)@Matrix.Rotation(math.radians(-90),4,'X')
        L=3.0 if s.tool=='harvester' else 2.7
        return C4@s.o@G@Vector((0,L*0.45,0)), C4@s.o@G@Vector((0,L,0))
    def pose(s,t):
        M=s.mats(t)
        for o,c,sz,g in s.objs: o.matrix_world=C4@s.o@M[g]@T(c)@S(sz)
        G=M['elbow']@T(GRIP)@Matrix.Rotation(math.radians(-90),4,'X')
        for o,c,sz in s.tobjs: o.matrix_world=C4@s.o@G@T(c)@S(sz)
        if s.trail:
            col,a,b,alpha=TRAIL[s.anim]
            # history at 240 Hz over the trail lifetime (0.16 s), only while enabled
            pts=[]
            for k in range(0,40):
                tt=t-k/240
                if tt<0 or tt<a or tt>b: continue
                age=(t-tt)/0.16
                if age>1: continue
                base,tp=s.tip(tt); pts.append((base,tp,(1-age)*alpha, 1-0.8*age))
            me=s.tr.data; me.clear_geometry()
            if len(pts)>=2:
                vs=[];fs=[];al=[]
                for i,(bs,tp,aa,w) in enumerate(pts):
                    mid=(bs+tp)/2; half=(tp-bs)/2*w
                    vs+= [tuple(mid-half),tuple(mid+half)]; al+=[aa,aa]
                for i in range(len(pts)-1): fs.append((2*i,2*i+1,2*i+3,2*i+2))
                me.from_pydata(vs,[],fs)
                attr=me.attributes.new('a','FLOAT','POINT')
                for i,v in enumerate(al): attr.data[i].value=v
            me.update()
# ground + lighting
def ground(x,z):
    bpy.ops.mesh.primitive_cylinder_add(radius=4,depth=0.2,location=(x,-z,-0.1),vertices=48); bpy.context.object.data.materials.append(GR)
sun=bpy.data.objects.new('S',bpy.data.lights.new('S','SUN')); sun.data.energy=3.2; sun.rotation_euler=(math.radians(45),math.radians(10),math.radians(150)); sc.collection.objects.link(sun)
sc.world=bpy.data.worlds.new('W'); sc.world.use_nodes=True; sc.world.node_tree.nodes['Background'].inputs[0].default_value=(0.62,0.78,0.92,1); sc.world.node_tree.nodes['Background'].inputs[1].default_value=1.0
sc.render.engine='CYCLES'; sc.cycles.samples=int(os.environ.get('SAMPLES','10')); sc.cycles.device='CPU'; sc.view_settings.view_transform='Standard'
sc.render.resolution_x=sc.render.resolution_y=360
PANELS=[('swing','harvester',True,'Chop (tools)'),('slash','club',True,'Slash (club, sword)'),('eat','berries',False,'Eat'),('pickup',None,False,'Pick up'),('place',None,False,'Place'),('slash','club',True,'Slash, from the front')]
chars=[]
for i,(an,tool,tr,_) in enumerate(PANELS):
    x=i*30; chars.append(Char(x,0,an,tool,tr)); ground(x,0)
cam=bpy.data.objects.new('C',bpy.data.cameras.new('C')); sc.collection.objects.link(cam); sc.camera=cam
cam.data.type='ORTHO'; cam.data.ortho_scale=8.5
def aim(x,view):
    tgt=Vector((x,0,2.6))
    if view=='front': pos=tgt+Vector((0,12,3))
    else: pos=tgt+Vector((9,7,4.5))
    cam.location=pos; cam.rotation_euler=(tgt-pos).to_track_quat('-Z','Y').to_euler()
FPS=30; CYCLE=1.3; N=int(FPS*CYCLE)
out='/tmp/animprev/frames'; os.makedirs(out,exist_ok=True)
for f in range(N):
    t=f/FPS
    for c in chars: c.pose(t)
    for i,c in enumerate(chars):
        aim(i*30,'front' if i==5 else 'side')
        sc.render.filepath=f'{out}/p{i}_{f:03d}.png'; bpy.ops.render.render(write_still=True)
print('DONE')
