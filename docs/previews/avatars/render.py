# Mirrors src/server/Avatar.lua on a blocky R15 body (Roblox coords, feet at y=0).
import bpy, math, os, sys
from mathutils import Matrix, Vector
bpy.ops.wm.read_factory_settings(use_empty=True)
sc=bpy.context.scene
def lin(c): return tuple(((v/255+0.055)/1.055)**2.4 if v/255>0.04045 else v/255/12.92 for v in c)
MC={}
def mat(rgb,metal=False):
    k=(rgb,metal)
    if k in MC: return MC[k]
    m=bpy.data.materials.new(str(k)); m.use_nodes=True; b=m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value=(*lin(rgb),1); b.inputs['Roughness'].default_value=0.55 if metal else 0.75
    if metal: b.inputs['Metallic'].default_value=0.8
    MC[k]=m; return m
C4=Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)))
def T(p): return Matrix.Translation(Vector(p))
def A(x=0,y=0,z=0): return Matrix.Rotation(math.radians(x),4,'X')@Matrix.Rotation(math.radians(y),4,'Y')@Matrix.Rotation(math.radians(z),4,'Z')
def S(s): return Matrix.Diagonal((*s,1))
O=dict(
 skin=[(255,224,189),(241,194,150),(214,160,118),(176,120,82),(130,86,58),(92,60,42)],
 hair=['Shaggy','Topknot','Braids','Buzz','Bald'],
 hairColor=[(34,28,26),(92,60,36),(214,180,110),(150,64,34),(170,166,160)],
 outfit=['Castaway','Islander','Voyager'],
 dye=[(52,120,150),(84,120,60),(210,96,80),(210,180,120),(110,80,140),(200,120,40)],
 paint=['None','Cheek stripes','Eye band','Chin dots'])
CANVAS=(222,208,170);ROPE=(150,112,70);LEATHER=(96,64,40);TROUSERS=(78,62,48);SHELL=(246,238,220);EYES=(30,26,24);MOUTH=(110,56,44);OCHRE=(176,62,40);CLAY=(240,236,226)
PARTS={'Head':((0,4.6,0),(1.2,1.2,1.2)),'UpperTorso':((0,3.2,0),(2,1.6,1)),'LowerTorso':((0,2.2,0),(2,0.4,1)),
 'LeftUpperArm':((-1.5,3.4,0),(1,1.2,1)),'LeftLowerArm':((-1.5,2.4,0),(1,0.9,1)),'LeftHand':((-1.5,1.8,0),(0.9,0.3,0.9)),
 'RightUpperArm':((1.5,3.4,0),(1,1.2,1)),'RightLowerArm':((1.5,2.4,0),(1,0.9,1)),'RightHand':((1.5,1.8,0),(0.9,0.3,0.9)),
 'LeftUpperLeg':((-0.5,1.55,0),(1,0.9,1)),'LeftLowerLeg':((-0.5,0.75,0),(1,0.8,1)),'LeftFoot':((-0.5,0.15,0),(1,0.3,1)),
 'RightUpperLeg':((0.5,1.55,0),(1,0.9,1)),'RightLowerLeg':((0.5,0.75,0),(1,0.8,1)),'RightFoot':((0.5,0.15,0),(1,0.3,1))}
BODY={'Castaway':{'UpperTorso':'dye','UpperArm':'dye','LowerTorso':'canvas','UpperLeg':'canvas'},
 'Islander':{'LowerTorso':'dye','UpperLeg':'dye'},
 'Voyager':{'UpperTorso':'canvas','UpperArm':'canvas','LowerTorso':'trousers','UpperLeg':'trousers','LowerLeg':'trousers'}}
def cube(M,size,rgb,metal=False):
    bpy.ops.mesh.primitive_cube_add(size=1); o=bpy.context.object; o.data.materials.append(mat(rgb,metal))
    o.matrix_world=C4@M@S(size); return o
class Char:
    def __init__(s,root,look):
        s.root=root; s.L=look; s.cf={}
        sk=O['skin'][look['skin']]; dye=O['dye'][look['dye']]
        cols={'skin':sk,'dye':dye,'canvas':CANVAS,'trousers':TROUSERS}
        bm=BODY[O['outfit'][look['outfit']]]
        for n,(c,sz) in PARTS.items():
            s.cf[n]=(root@T(c),Vector(sz))
            if n=='Head': continue
            key=n.replace('Left','').replace('Right','')
            cube(s.cf[n][0],sz,cols[bm.get(key,'skin')])
        hb=s.cf['Head'][0]@T((0,0.05,0)); s.cf['HeadBlock']=(hb,Vector((1.2,1.2,1.2)))
        cube(hb,(1.2,1.2,1.2),sk)
        s.face(); s.hair(); s.outfit()
    def p(s,to,size,off,rgb,metal=False): cube(s.cf[to][0]@off,size,rgb,metal)
    def face(s):
        L=s.L; hc=O['hairColor'][L['hairColor']]; f=-0.6
        for x in (-0.24,0.24):
            s.p('HeadBlock',(0.16,0.26,0.05),T((x,0.08,f-0.02)),EYES)
            s.p('HeadBlock',(0.3,0.07,0.05),T((x,0.3,f-0.02))@A(z=2 if x>0 else -2),hc)
        s.p('HeadBlock',(0.3,0.06,0.04),T((0,-0.28,f-0.015)),MOUTH)
        paint=O['paint'][L['paint']]; pc=OCHRE if L['skin']<=2 else CLAY
        if paint=='Cheek stripes':
            for x in (-0.3,0.3):
                for k in (0,1): s.p('HeadBlock',(0.26,0.05,0.03),T((x,-0.12-k*0.1,f-0.01)),pc)
        elif paint=='Eye band': s.p('HeadBlock',(1.22,0.36,0.03),T((0,0.08,f-0.008)),pc)
        elif paint=='Chin dots':
            for x in (-0.14,0,0.14): s.p('HeadBlock',(0.07,0.07,0.03),T((x,-0.44,f-0.01)),pc)
    def hair(s):
        L=s.L; st=O['hair'][L['hair']]; c=O['hairColor'][L['hairColor']]; top=0.6; back=0.6; H=1.2
        if st=='Bald': return
        if st=='Buzz':
            s.p('HeadBlock',(H+0.04,0.12,H+0.04),T((0,top+0.02,0)),c); s.p('HeadBlock',(H+0.04,H*0.45,0.06),T((0,top-H*0.22,back+0.02)),c); return
        th=0.16 if st=='Topknot' else 0.3
        s.p('HeadBlock',(H+0.12,th,H+0.12),T((0,top+th/2-0.08,0)),c)
        sl=H*0.4 if st=='Topknot' else H*0.6
        for sx in (-1,1): s.p('HeadBlock',(0.1,sl,H*0.7),T((sx*(H/2+0.04),top-sl/2,H*0.15)),c)
        bl=H*0.85 if st=='Shaggy' else H*0.6
        s.p('HeadBlock',(H+0.12,bl,0.12),T((0,top-bl/2,back+0.05)),c)
        if st=='Shaggy':
            for x,t in zip((-0.36,0,0.36),(10,-4,-12)): s.p('HeadBlock',(0.38,0.24,0.1),T((x,top-0.12,-back-0.04))@A(z=t),c)
            for x in (-0.4,0,0.4): s.p('HeadBlock',(0.3,0.2,0.1),T((x,top-bl-0.05,back+0.05)),c)
        elif st=='Topknot':
            s.p('HeadBlock',(0.34,0.34,0.34),T((0,top+0.12,0.32))@A(x=45,y=45),c)
            s.p('HeadBlock',(0.3,0.08,0.3),T((0,top+0.02,0.32))@A(x=-20,y=45),O['dye'][L['dye']])
        elif st=='Braids':
            for sx in (-1,1):
                x=sx*(H/2+0.05)
                for k in range(3): s.p('HeadBlock',(0.24,0.3,0.24),T((x,-H*0.1-k*0.28,0.05))@A(y=45),c)
                s.p('HeadBlock',(0.16,0.14,0.16),T((x,-H*0.1-0.86,0.05)),O['dye'][L['dye']])
    def outfit(s):
        L=s.L; n=O['outfit'][L['outfit']]; dye=O['dye'][L['dye']]; us=s.cf['UpperTorso'][1]; ls=s.cf['LowerTorso'][1]
        if n=='Castaway':
            s.p('LowerTorso',(ls.x+0.08,0.22,ls.z+0.08),T((0,0.05,0)),ROPE)
            s.p('LowerTorso',(0.22,0.32,0.06),T((-0.55,-0.12,-ls.z/2-0.05)),ROPE)
            s.p('UpperTorso',(0.42,0.38,0.04),T((0.5,-0.25,-us.z/2-0.02))@A(z=8),CANVAS)
            for side in ('Left','Right'):
                a=s.cf[side+'UpperArm'][1]
                for x in (-0.25,0.22): s.p(side+'UpperArm',(0.5,0.16,a.z+0.06),T((x,-a.y/2+0.04,0))@A(z=math.degrees(x*30*math.pi/180)*1),dye)
                g=s.cf[side+'UpperLeg'][1]
                s.p(side+'UpperLeg',(g.x+0.06,0.18,g.z+0.06),T((0,-g.y/2+0.05,0))@A(z=5 if side=='Left' else -5),CANVAS)
        elif n=='Islander':
            s.p('UpperTorso',(0.34,us.y*1.25,us.z+0.06),A(z=38),dye)
            for i in range(-2,3): s.p('UpperTorso',(0.14,0.14,0.1),T((i*0.22,us.y/2-0.18-(2-abs(i))*0.06,-us.z/2-0.05)),SHELL)
            for i in range(8):
                a=i/8*math.pi*2; pos=(math.sin(a)*(ls.x/2+0.06),-0.45,math.cos(a)*(ls.z/2+0.06))
                d=tuple(int(v*(1-0.15*(i%2))) for v in dye)
                s.p('LowerTorso',(0.6,0.9,0.08),T(pos)@A(y=math.degrees(a))@A(x=-6),d)
            s.p('LowerTorso',(ls.x+0.14,0.16,ls.z+0.14),T((0,0.1,0)),ROPE)
        elif n=='Voyager':
            for sx in (-1,1): s.p('UpperTorso',(us.x*0.32,us.y+0.02,0.06),T((sx*us.x*0.33,0,-us.z/2-0.03)),dye)
            s.p('UpperTorso',(us.x+0.04,us.y+0.02,0.06),T((0,0,us.z/2+0.03)),dye)
            s.p('LowerTorso',(ls.x+0.06,0.2,ls.z+0.06),T((0,0.08,0)),LEATHER)
            s.p('LowerTorso',(0.24,0.2,0.06),T((0,0.08,-ls.z/2-0.05)),(214,178,90),True)
            for side in ('Left','Right'):
                a=s.cf[side+'UpperArm'][1]; s.p(side+'UpperArm',(a.x+0.08,0.2,a.z+0.08),T((0,-a.y/2+0.1,0)),CANVAS)
