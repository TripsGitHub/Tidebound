# Top-down preview of the new layout: same islands, spacing rules and counts as
# WorldBuilder.lua. Land/height is approximated (no hills or lakes), so positions are
# indicative, not exact.
import math, random
from PIL import Image, ImageDraw, ImageFont
rng = random.Random(1911)
ISL = [("Palm Beach",0,320,85,"beach"),("Pine Hills",-300,90,100,"hills"),("Stone Shelf",300,90,90,"rock"),
       ("Frost Isle",-190,-265,85,"snow"),("Slime Marsh",195,-265,78,"marsh"),("Ember Isle",0,0,115,"ember")]
NODES = {"beach":[("Palm",13,(1,2)),("Bush",7,None),("Boulder",3,None)],
 "hills":[("Pine",20,(1,3)),("Bush",9,None),("Boulder",6,None)],
 "rock":[("Boulder",14,None),("Pine",5,(1,2)),("Bush",3,None)],
 "snow":[("Pine",13,(1,3)),("Boulder",6,None)],
 "marsh":[("SlimePool",7,None),("Bush",8,None),("Pine",5,(1,2))],
 "ember":[("Boulder",7,None)]}
CORE = {"beach":(112,160,78),"hills":(106,158,70),"rock":(110,106,102),"snow":(236,240,246),"marsh":(84,124,68),"ember":(58,56,62)}
CLUMP, INCLUMP, NODE = 30, 7, 16
def land(x,z):
    for n,ix,iz,r,b in ISL:
        if math.hypot(x-ix,z-iz) <= r+12: return True
    return False
def spot(isl, taken, spacing, near=None, nr=None):
    n,ix,iz,r,b = isl
    for _ in range(30):
        if near:
            a=rng.uniform(0,2*math.pi); d=rng.uniform(spacing, nr or spacing*1.4); x,z=near[0]+math.cos(a)*d, near[1]+math.sin(a)*d
        else:
            a=rng.uniform(0,2*math.pi); d=math.sqrt(rng.random())*(r+10); x,z=ix+math.cos(a)*d, iz+math.sin(a)*d
        if land(x,z) and all(math.hypot(x-t[0],z-t[1])>=spacing for t in taken): return (x,z)
home = ISL[0]; sp=(home[1], home[2]+home[3]*0.75)
taken=[sp]+[(sp[0]+math.cos(i/8*6.283)*10, sp[1]+math.sin(i/8*6.283)*10) for i in range(8)]+[(sp[0]-12,sp[1]-20),(sp[0]+12,sp[1]-20)]
placed=[]
for isl in ISL:
    for kind,count,clump in NODES[isl[4]]:
        made=0
        for _ in range(count*3):
            if made>=count: break
            if clump:
                c=spot(isl,taken,CLUMP)
                if c:
                    ct=[c]; placed.append((kind,c)); made+=1
                    for _ in range(rng.randint(*clump)-1):
                        if made>=count: break
                        s=spot(isl,ct,INCLUMP,c,INCLUMP*1.6)
                        if s: ct.append(s); placed.append((kind,s)); made+=1
                    taken+=ct
            else:
                s=spot(isl,taken,NODE)
                if s: taken.append(s); placed.append((kind,s)); made+=1
W=1400; S=1.0  # 1 px per stud... scale to 1000 px
img=Image.new("RGB",(1000,1000),(46,140,170)); d=ImageDraw.Draw(img)
k=1000/880; off=440
P=lambda x,z:((x+off)*k,(z+off)*k)
for n,ix,iz,r,b in ISL:
    for rr,col in [(r+40,(70,160,185)),(r+16,(218,196,140))]:
        cx,cy=P(ix,iz); d.ellipse([cx-rr*k,cy-rr*k,cx+rr*k,cy+rr*k],fill=col)
    cr=r*0.5 if b=="beach" else r
    cx,cy=P(ix,iz); d.ellipse([cx-cr*k,cy-cr*k,cx+cr*k,cy+cr*k],fill=CORE[b])
    if b=="ember":
        d.ellipse([cx-26*k,cy-26*k,cx+26*k,cy+26*k],fill=(40,38,44)); d.ellipse([cx-9*k,cy-9*k,cx+9*k,cy+9*k],fill=(230,90,30))
STY={"Pine":((30,84,46),6),"Palm":((60,140,50),6),"Boulder":((150,150,156),4.5),"Bush":((70,120,50),2.6),"SlimePool":((120,220,80),3.5)}
for kind,(x,z) in placed:
    col,rad=STY[kind]; cx,cy=P(x,z); d.ellipse([cx-rad*k,cy-rad*k,cx+rad*k,cy+rad*k],fill=col,outline=(20,20,20))
cx,cy=P(*sp); d.polygon([(cx,cy-9),(cx-7,cy+6),(cx+7,cy+6)],fill=(255,80,60),outline=(0,0,0))
try: f=ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",18); fs=ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",14)
except: f=fs=ImageFont.load_default()
for n,ix,iz,r,b in ISL:
    cx,cy=P(ix,iz-r-24); tw=d.textlength(n,font=f); d.text((cx-tw/2,cy-10),n,fill=(255,255,255),font=f,stroke_width=3,stroke_fill=(0,0,0))
d.text((cx-10,0),"",font=fs)
# legend + scale
lx,ly=18,860
d.rectangle([10,850,330,990],fill=(245,236,214),outline=(90,60,40),width=3)
for i,(kind,lab) in enumerate([("Pine","Pine"),("Palm","Palm"),("Boulder","Boulder"),("Bush","Bush"),("SlimePool","Slime pool")]):
    col,rad=STY[kind]; y=ly+10+i*22; d.ellipse([lx+6-6,y-6,lx+6+6,y+6],fill=col,outline=(0,0,0)); d.text((lx+20,y-9),lab,fill=(40,30,20),font=fs)
d.polygon([(190,868),(183,882),(197,882)],fill=(255,80,60),outline=(0,0,0)); d.text((205,866),"Spawn",fill=(40,30,20),font=fs)
d.line([(190,920),(190+50*k,920)],fill=(40,30,20),width=4); d.text((190,928),"50 studs (9 players)",fill=(40,30,20),font=fs)
from collections import Counter
c=Counter(k for k,_ in placed); print(c, sum(c.values()))
img.save('/tmp/map/map-preview.png')
