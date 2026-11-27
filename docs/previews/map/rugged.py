# Line-for-line copy of src/server/Rugged.lua: rock outcrops and rocky coast.
import math
from math import sqrt, sin, cos, atan2
def smooth(a):
    a=min(1,max(0,a)); return a*a*(3-2*a)
def grain(x,z): return math.sin(x*0.41+z*0.17)*0.5+math.sin(z*0.37-x*0.23+1.7)*0.5
class Rugged:
    def __init__(s,base,seed,count,rock,coast,size=1,avoid=(),coast_mask=None):
        s.base=base; s.name=base.name; s.bounds=base.bounds; s.o=dict(seed=seed,rock=rock,coast=coast,mask=coast_mask)
        b=base.bounds; s.cx,s.cz=(b[0]+b[1])/2,(b[2]+b[3])/2
        st=[seed]
        def rand():
            st[0]=(st[0]*16807)%2147483647; return st[0]/2147483647
        tors=[]; tries=0
        while len(tors)<count and tries<600:
            tries+=1
            x=b[0]+(b[1]-b[0])*rand(); z=b[2]+(b[3]-b[2])*rand()
            r=(5+rand()*7)*size; h=(3+rand()*6)*size; k=rand()*6.283
            ok=base.land(x,z)>0.22 and base.can_grow(x,z)
            for t in tors:
                if ok and sqrt((x-t[0])**2+(z-t[1])**2)<30: ok=False
            for a in avoid:
                if ok and sqrt((x-a[0])**2+(z-a[1])**2)<a[2]+r: ok=False
            if ok: tors.append((x,z,r,h,k))
        s.tors=tors
    def __getattr__(s,n): return getattr(s.base,n)
    def tor(s,x,z):
        best=0
        for t in s.tors:
            dx,dz=x-t[0],z-t[1]; d=sqrt(dx*dx+dz*dz)
            if d<t[2]*1.5:
                a=atan2(dz,dx); rr=t[2]*(1+0.22*sin(a*3+t[4])+0.12*sin(a*5+2*t[4])); u=1-d/rr
                if u>0:
                    c=t[3]*smooth(u*2.4)+t[3]*0.18*sin(dx*0.9+t[4])*cos(dz*0.8-t[4])*u
                    best=max(best,c)
        return best
    def rocky_coast(s,x,z):
        if not s.o['coast']: return 0
        a=atan2(z-s.cz,x-s.cx); k=sin(a*3+s.o['seed']*0.7)*0.7+sin(a*7+s.o['seed'])*0.3
        r=smooth((k-0.35)/0.25)
        if s.o['mask']: r*=s.o['mask'](x,z)
        return r
    def height(s,x,z):
        h=s.base.height(x,z); l=s.base.land(x,z); rc=s.rocky_coast(x,z)
        if rc>0: h+=rc*5*smooth((l+0.02)/0.04)*(1-smooth((l-0.14)/0.08))
        return h+s.tor(x,z)
    def material(s,x,z,h,sl):
        g=grain(x,z)
        if s.tor(x,z)>0.7+g*0.4: return s.o['rock']
        if s.rocky_coast(x,z)>0.5+g*0.1 and s.base.land(x,z)<0.17+g*0.03: return s.o['rock']
        return s.base.material(x,z,h,sl)
    def can_grow(s,x,z): return s.base.can_grow(x,z) and s.tor(x,z)<0.2
