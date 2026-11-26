from PIL import Image, ImageDraw, ImageFont, ImageFilter
K=2
bg=Image.open('/tmp/arch/clover-ground.png').convert('RGB').resize((1280*K//2*1,800*K//2*1)) if False else Image.open('/tmp/arch/clover-ground.png').convert('RGB').resize((1280,800))
img=bg.copy(); d=ImageDraw.Draw(img,'RGBA')
F=lambda s: ImageFont.truetype('/tmp/fonts/DenkOne-Regular.ttf',s)
TAN=(196,176,130,225); CARD=(178,158,114,255); DARK=(150,131,92,255); RIM=(236,224,190,255); EDGE=(46,34,20); GOOD=(88,186,74)
def ot(xy,t,s,anchor='la',fill=(255,255,255),sw=2): d.text(xy,t,font=F(s),fill=fill,anchor=anchor,stroke_width=sw,stroke_fill=EDGE)
W,H=560*1.2,400*1.2; x0=(1280-W)/2; y0=(800-H)/2; s=1.2
def R(x,y,w,h): return (x0+x*s,y0+y*s,x0+(x+w)*s,y0+(y+h)*s)
d.rounded_rectangle((x0,y0,x0+W,y0+H),10,fill=TAN,outline=RIM,width=3)
ot((640,y0+8*s+15*s),'Your Castaway',int(30*s),anchor='mm')
d.rounded_rectangle(R(16,50,210,280),7,fill=DARK)
p=Image.open('/tmp/avatar/portrait.png').convert('RGBA'); bx=R(16,50,210,280); pw=int(bx[2]-bx[0]); ph=int(bx[3]-bx[1])
p=p.resize((pw, int(p.height*pw/p.width))); img.paste(p,(int(bx[0]),int(bx[1]+(ph-p.height)/2)),p)
rows=[('Skin','Tone 3'),('Hair','Topknot'),('Hair colour','Rust'),('Outfit','Voyager'),('Dye','Dusk'),('Face paint','Cheek stripes')]
for i,(a,b) in enumerate(rows):
    y=54+i*46
    d.rounded_rectangle(R(240,y,304,40),7,fill=CARD)
    ot((x0+250*s,y0+(y+20)*s),a,int(19*s),anchor='lm')
    ot((x0+(240+136)*s,y0+(y+20)*s),'<',int(26*s),anchor='mm')
    ot((x0+(240+150+(304-184)/2)*s,y0+(y+20)*s),b,int(19*s),anchor='mm')
    ot((x0+(240+304-20)*s,y0+(y+20)*s),'>',int(26*s),anchor='mm')
d.rounded_rectangle((640-75*s,y0+H-14*s-38*s,640+75*s,y0+H-14*s),7,fill=GOOD)
ot((640,y0+H-14*s-19*s),'Done',int(24*s),anchor='mm')
# top-left menu
for i,(lab,key) in enumerate([('Inventory','C'),('Look','L')]):
    x=10+i*72
    ot((x+33,16),lab,16,anchor='mm')
    d.rounded_rectangle((x+7,26,x+59,78),8,fill=TAN,outline=RIM,width=2)
    if lab=='Look':
        d.rounded_rectangle((x+18,40,x+48,70),3,fill=(214,160,118),outline=EDGE,width=2)
        d.rounded_rectangle((x+16,35,x+50,45),3,fill=(92,60,36))
        for ex in (8,18): d.rectangle((x+18+ex,52,x+22+ex,59),fill=(30,26,24))
    else:
        d.rounded_rectangle((x+18,40,x+48,72),6,fill=(150,100,60)); d.rectangle((x+24,36,x+42,44),outline=(110,70,40),width=3)
    d.rounded_rectangle((x+51,70,x+67,86),4,fill=DARK,outline=RIM,width=1); ot((x+59,78),key,13,anchor='mm',sw=1)
ot((10+2*72+33,16),'Shells',16,anchor='mm'); d.ellipse((10+144+17,30,10+144+49,62),fill=(246,200,72),outline=EDGE,width=2); ot((10+144+33,46),'S',20,anchor='mm'); ot((10+144+33,74),'120',19,anchor='mm')
# XP bar
ot((440,20),'Lv. 12',22,anchor='lm'); d.rounded_rectangle((510,10,770,30),6,fill=TAN,outline=RIM,width=2); d.rounded_rectangle((512,12,660,28),5,fill=(122,214,92)); ot((640,20),'340 / 520 XP',15,anchor='mm',sw=1); ot((780,20),'Lv. 13',22,anchor='lm')
img.save('/tmp/avatar/look-screen.png')
