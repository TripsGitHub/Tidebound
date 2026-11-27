import sys,math; sys.path.insert(0,'/tmp/arch'); sys.path.insert(0,'/tmp/clover')
from fields import *
import field as CL
from PIL import Image
class Clover:
    name='Clover Island'; bounds=(-152,152,-152,176)
    def height(s,x,z): return CL.height(x,z)
    def material(s,x,z,h,sl): return CL.material(x,z,h,sl)
    def land(s,x,z): return CL.land(x,z)
ISL=[(Clover(),0,320),(PineHills(),-300,90),(StoneShelf(),300,90),(FrostIsle(),-190,-265),(SlimeMarsh(),195,-265),(EmberIsle(),0,0)]
COL={'Sand':(226,204,150),'Grass':(108,162,72),'LeafyGrass':(90,140,62),'Rock':(120,116,112),'Slate':(92,92,98),'Ground':(150,118,82),'Snow':(236,240,244),'Glacier':(170,210,230),'Mud':(96,80,60),'Basalt':(58,56,62),'CrackedLava':(236,96,36),'Seabed':(0,0,0)}
def render(scale, x0,x1,z0,z1, path):
    W,H=int((x1-x0)/scale),int((z1-z0)/scale)
    img=Image.new('RGB',(W,H)); px=img.load()
    for j in range(H):
        z=z0+(j+.5)*scale
        for i in range(W):
            x=x0+(i+.5)*scale
            hit=None
            for isl,cx,cz in ISL:
                b=isl.bounds
                if b[0]<=x-cx<=b[1] and b[2]<=z-cz<=b[3]: hit=(isl,x-cx,z-cz); break
            if hit:
                isl,lx,lz=hit; e=1.5
                h=isl.height(lx,lz); hx=isl.height(lx+e,lz); hz=isl.height(lx,lz+e)
            else: h=-26; hx=hz=h
            if h<0:
                t=max(0,min(1,-h/22)); c=(int(120-80*t),int(205-80*t),int(210-40*t))
            else:
                sl=abs(hx-h)/e+abs(hz-h)/e
                m=isl.material(lx,lz,h,sl/2)
                if isinstance(isl,(PineHills,)):
                    for p in isl.pools:
                        if math.hypot(lx-p[0],lz-p[1])<p[2] and h<p[3]: m='Water'
                if isinstance(isl,Clover) and math.hypot(lx+6,lz-4)<11 and h<10.5: m='Water'
                c=COL.get(m,(70,150,190)) if m!='Water' else (70,160,200)
                shade=1+((h-hx)-(h-hz))*0.09+h*0.004
                shade=max(0.55,min(1.35,shade))
                c=tuple(max(0,min(255,int(v*shade))) for v in c)
            px[i,j]=c
    img.save(path); return img
if __name__=='__main__':
    render(float(sys.argv[1]) if len(sys.argv)>1 else 3, -440,440,-400,500,'/tmp/arch/map.png')
