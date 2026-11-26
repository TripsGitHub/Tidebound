# Height/material fields for the five non-spawn islands, in Roblox studs relative to
# each island's centre (x east, z south). Mirrored line for line in IslandFields.lua.
import math
hyp=math.hypot
def smooth(a): a=max(0.0,min(1.0,a)); return a*a*(3-2*a)
def noise(x,z):
    return (math.sin(x*0.071+1.3)*math.cos(z*0.063-0.4)*1.4 + math.sin(x*0.153-z*0.121+2.1)*0.7
            + math.cos(x*0.031+z*0.047)*1.2)
def beach(l):
    # sea shelf below 0, then sand rising to the grass line
    if l<=0: return max(-26.0, 1+l*60)
    return 1.5+smooth(l/0.18)*2.5
def bump(x,z,cx,cz,r,h): return h*math.exp(-((x-cx)**2+(z-cz)**2)/(r*r))
def grain(x,z):
    # fine noise that breaks up straight material edges (-1..1)
    return math.sin(x*0.41+z*0.17)*0.5+math.sin(z*0.37-x*0.23+1.7)*0.5
def detail(x,z):
    # small bumps on the ground so slopes are not perfectly smooth (about -0.75..0.75)
    return (math.sin(x*0.29+z*0.11)*math.cos(z*0.31-x*0.07)+math.sin(x*0.53-z*0.47)*0.5)*0.5
def grassy(x,z,base='Grass'):
    # patches of the darker grass inside light grass and the other way round
    n=noise(x*0.6+90,z*0.6)
    if base=='Grass': return 'LeafyGrass' if n>1.3 else 'Grass'
    return 'Grass' if n<-1.3 else 'LeafyGrass'
def pool_cut(h,x,z,p):
    cx,cz,r,level=p; d=hyp(x-cx,z-cz)
    return min(h,level-(r-d)*0.5) if d<r else h

# ---------------------------------------------------------------- Pine Hills (west)
# A crescent of rolling wooded hills wrapped round a sheltered lagoon that opens east,
# towards the middle. Two hill lakes. Wood island.
class PineHills:
    name='Pine Hills'; bounds=(-128,128,-128,128); ytop=40
    def land(s,x,z):
        base=1-hyp(x,z)/100+noise(x*1.5,z*1.5)*0.03
        lag=1-hyp(x-64,z+4)/54
        l=base-max(0.0,lag)*1.25
        return max(l,1-hyp(x-60,z-6)/11)          # little islet in the lagoon
    def ground(s,x,z):
        l=s.land(x,z); h=beach(l)
        if l<=0: return h
        inland=smooth((l-0.12)/0.45)
        h+=inland*(2.5+noise(x,z)*1.6)
        for cx,cz,r,hh in ((-48,-30,34,13),(-20,40,30,10),(-60,30,26,9),(5,-62,26,8)):
            h+=inland*bump(x,z,cx,cz,r,hh)
        return h+smooth(l/0.2)*detail(x,z)*0.7
    pools=[(-36,-4,12,None),(-30,62,9,None)]
    def __init__(s):
        s.pools=[(cx,cz,r,s.ground(cx,cz)-0.6) for cx,cz,r,_ in PineHills.pools]
    def height(s,x,z):
        h=s.ground(x,z)
        for p in s.pools: h=pool_cut(h,x,z,p)
        return h
    def zone(s,x,z):
        if x>15 and s.land(x,z)<0.35: return 'shore'
        if z+noise(x*0.9,z*0.9)*6>18: return 'meadow'
        return 'forest'
    def material(s,x,z,h,slope):
        l=s.land(x,z); g=grain(x,z)
        if l<=0.07+g*0.03 or h<2.6+g*0.5: return 'Sand'
        if slope>0.9+g*0.15: return 'Rock'
        if s.zone(x,z)=='meadow': return grassy(x,z,'LeafyGrass')
        return grassy(x,z)
    def can_grow(s,x,z):
        return s.land(x,z)>0.1 and all(hyp(x-p[0],z-p[1])>p[2]+3 for p in s.pools)

# ---------------------------------------------------------------- Stone Shelf (east)
# A long ridge: stepped grey cliffs drop to the sea on the east, a grassy slope faces
# the middle on the west, and a cave runs into the ridge from a fang-rock mouth at
# the north end. Stone island.
ROT=math.radians(12)
class StoneShelf:
    name='Stone Shelf'; bounds=(-110,110,-132,132); ytop=44
    cave_mouth=(12,-86); cave_end=(10,-40); cave_floor=3.0; cave_h=9.0; cave_w=6.0; chamber=(10,-38,15)
    def uv(s,x,z): return x*math.cos(ROT)-z*math.sin(ROT), x*math.sin(ROT)+z*math.cos(ROT)
    def land(s,x,z):
        u,v=s.uv(x,z)
        return 1-math.sqrt((u/64)**2+(v/108)**2)+noise(x*1.4,z*1.4)*0.03
    def ridge(s,x,z):
        u,v=s.uv(x,z)
        return smooth((u+18)/34)*smooth((1-abs(v)/100)/0.25)
    def height(s,x,z):
        l=s.land(x,z); h=beach(l)
        if l<=0: return h
        inland=smooth((l-0.1)/0.4)
        h+=inland*(2+noise(x,z)*1.3)
        w=s.ridge(x,z)*smooth((l-0.06)/0.3)
        if w>0:
            hr=h+w*30+noise(x*1.2,z*1.2)*2.5
            hr=1.5+math.floor((hr-1.5+grain(x,z)*1.5)/6)*6+((hr-1.5)%6)*0.45   # rough ledges
            h=h+(hr-h)*min(1.0,w*1.6)
        return h+smooth(l/0.2)*detail(x,z)*0.7
    def in_cave(s,x,y,z):
        (ax,az),(bx,bz)=s.cave_mouth,s.cave_end
        t=max(0.0,min(1.0,((x-ax)*(bx-ax)+(z-az)*(bz-az))/((bx-ax)**2+(bz-az)**2)))
        px,pz=ax+(bx-ax)*t,az+(bz-az)*t
        d=hyp(x-px,z-pz); cx,cz,cr=s.chamber; dc=hyp(x-cx,z-cz)
        w=s.cave_w+math.sin(t*9)*1.2
        top=s.cave_floor+s.cave_h*(1-(d/w)**2) if d<w else -1
        ctop=s.cave_floor+14*(1-(dc/cr)**2) if dc<cr else -1
        return s.cave_floor<=y<max(top,ctop)
    def zone(s,x,z):
        if hyp(x-s.chamber[0],z-s.chamber[1])<s.chamber[2]: return 'cave'
        return 'cliffs' if s.ridge(x,z)>0.45 else 'slope'
    def material(s,x,z,h,slope):
        l=s.land(x,z); g=grain(x,z)
        if l<=0.06+g*0.03 or h<2.6+g*0.5: return 'Sand'
        if s.ridge(x,z)>0.45+g*0.08: return 'Slate' if slope>0.7+g*0.15 else 'Rock'
        if slope>0.9+g*0.15: return 'Rock'
        return grassy(x,z)
    def can_grow(s,x,z): return s.land(x,z)>0.1 and hyp(x-s.cave_mouth[0],z-s.cave_mouth[1])>18

# ---------------------------------------------------------------- Frost Isle (north-west)
# One snowy mountain with rocky shoulders, snow pines round its foot, a frozen pond in
# a hollow on the south side and a low peninsula pointing south-east.
class FrostIsle:
    name='Frost Isle'; bounds=(-120,124,-120,124); ytop=60
    pond=(-30,42,13)
    def land(s,x,z):
        l=1-hyp(x,z)/82+noise(x*1.1,z*1.1)*0.06
        return max(l,(1-hyp(x-62,z-52)/30)*0.6)
    def ground(s,x,z):
        l=s.land(x,z); h=beach(l)
        if l<=0: return h
        inland=smooth((l-0.12)/0.4)
        d=hyp(x+6,z+10)
        h+=inland*(2+noise(x,z)*2)
        h+=inland*40*smooth(1-d/80)**1.4
        h+=inland*smooth(1-d/72)*abs(noise(x*0.8,z*0.8))*5
        return h+smooth(l/0.2)*detail(x,z)*0.7
    def height(s,x,z):
        h=s.ground(x,z); cx,cz,r=s.pond; d=hyp(x-cx,z-cz)
        if d<r+6:
            level=s.ground(cx,cz)
            h=h+(level-h)*smooth((r+6-d)/6)   # flatten a shelf round the pond
        return h
    def pond_level(s): return s.ground(*s.pond[:2])
    def zone(s,x,z):
        h=s.ground(x,z)
        if h>24: return 'peak'
        if s.land(x,z)<0.18: return 'shore'
        return 'slopes'
    def material(s,x,z,h,slope):
        l=s.land(x,z)
        if hyp(x-s.pond[0],z-s.pond[1])<s.pond[2]: return 'Glacier'
        g=grain(x,z)
        if l<=0.05+g*0.03 or h<2.2+g*0.5: return 'Sand'
        if slope>1.5+g*0.2 and h>8: return 'Rock'
        return 'Snow'
    def can_grow(s,x,z): return s.land(x,z)>0.1 and hyp(x-s.pond[0],z-s.pond[1])>s.pond[2]+4

# ---------------------------------------------------------------- Slime Marsh (north-east)
# Five low, boggy islets on shallow flats you can wade between. Mud patches, reeds,
# slime pools. Slime island.
ISLETS=[(4,6,38,'heart'),(-60,24,26,'west'),(52,50,24,'east'),(42,-56,23,'north'),(-44,-56,19,'northwest')]
class SlimeMarsh:
    name='Slime Marsh'; bounds=(-112,112,-112,112); ytop=24
    def land(s,x,z):
        return max(1-hyp(x-cx,z-cz)/r for cx,cz,r,_ in ISLETS)+noise(x*1.9,z*1.9)*0.04
    def height(s,x,z):
        l=s.land(x,z)
        if l<=0:
            flats=smooth((92+noise(x*0.8,z*0.8)*6-hyp(x,z))/22)     # shallow flats inside the marsh
            return max(-26.0,1+l*60)*(1-flats)+max(-2.5,1+l*14)*flats
        h=1.2+smooth(l/0.25)*1.8+smooth((l-0.2)/0.5)*(1.2+noise(x*1.6,z*1.6)*0.9)
        return h+smooth(l/0.2)*detail(x,z)*0.35
    def zone(s,x,z):
        best,name=-9,'heart'
        for cx,cz,r,n in ISLETS:
            v=1-hyp(x-cx,z-cz)/r
            if v>best: best,name=v,n
        return name
    def material(s,x,z,h,slope):
        l=s.land(x,z)
        if l<=0.05+grain(x,z)*0.03: return 'Mud'
        if noise(x*2.7+40,z*2.7)>1.1: return 'Mud'
        if l<0.14: return 'Ground'
        return 'LeafyGrass'
    def can_grow(s,x,z): return s.land(x,z)>0.12

# ---------------------------------------------------------------- Ember Isle (middle)
# The late-game middle: a black volcano with a lava-filled crater, two lava streams
# down its north and west flanks, basalt cliffs, and one landing on the south side
# (facing Clover Island) with a flat ash terrace to camp on.
class EmberIsle:
    name='Ember Isle'; bounds=(-150,150,-150,150); ytop=64
    def land(s,x,z):
        return 1-hyp(x,z)/112+noise(x*1.2,z*1.2)*0.04
    def landing(s,x,z):
        a=math.atan2(x,z)+noise(x*0.5,z*0.5)*0.07   # 0 = due south
        return smooth((0.55-abs(a))/0.3)
    def height(s,x,z):
        l=s.land(x,z); h=beach(l)
        if l<=0: return h
        d=hyp(x,z); inland=smooth((l-0.06)/0.25)
        cone=smooth(1-d/96)**1.5*52
        h+=inland*(cone+3+noise(x*1.5,z*1.5)*1.5)
        h+=(1-s.landing(x,z))*smooth((l-0.02)/0.08)*8     # sea cliffs except at the landing
        h+=smooth(l/0.2)*detail(x,z)*0.9
        if d<22: h=min(h,40+(d/22)**2*12)  # crater
        t=s.landing(x,z)*smooth((d-58)/8)*smooth((92-d)/8)       # ash terrace
        h=h+(6.5-h)*t if l>0.1 else h
        return h
    def stream(s,x,z):
        best=0.0
        for a0,wob in ((math.pi,0.25),(-math.pi/2,0.2)):   # north, west
            a=math.atan2(x,z); d=hyp(x,z)
            da=abs((a-a0-math.sin(d*0.06)*wob+math.pi)%(2*math.pi)-math.pi)*d
            if 18<d<88: best=max(best,1-da/(5+d*0.04))
        return best
    def zone(s,x,z):
        d=hyp(x,z)
        if d<24: return 'crater'
        if s.landing(x,z)>0.5 and 60<d<90: return 'camp'
        return 'slopes'
    def material(s,x,z,h,slope):
        d=hyp(x,z); l=s.land(x,z)
        if d<16: return 'CrackedLava'
        if s.stream(x,z)>0: return 'CrackedLava'
        g=grain(x,z)
        if l<=0.05+g*0.03 or h<2.4+g*0.5: return 'Basalt' if s.landing(x,z)<0.5 else 'Sand'
        if s.zone(x,z)=='camp' and noise(x*1.8,z*1.8)>0.2: return 'Ground'
        if slope>0.8+g*0.15: return 'Slate'
        return 'Basalt'
    def can_grow(s,x,z): return s.land(x,z)>0.1 and s.stream(x,z)<=0 and hyp(x,z)>26
