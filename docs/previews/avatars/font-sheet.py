from PIL import Image, ImageDraw, ImageFont
F='/tmp/fonts/'
def font(name,size,var=None):
    f=ImageFont.truetype(F+name,size)
    if var:
        try: f.set_variation_by_name(var)
        except Exception as e: print(name,e)
    return f
OPTS=[
 ('A  Oswald','Oswald.ttf','Bold','Oswald.ttf','SemiBold'),
 ('B  Denk One (picked)','DenkOne-Regular.ttf',None,'DenkOne-Regular.ttf',None),
 ('C  Kalam','Kalam-Bold.ttf',None,'Kalam-Bold.ttf',None),
 ('D  Sarpanch','Sarpanch-Bold.ttf',None,'Sarpanch-Bold.ttf',None),
 ('Now  Source Sans','SourceSans3.ttf','Bold','SourceSans3.ttf','Bold'),
 ('Typical sim game (avoid)','Bangers-Regular.ttf',None,'Bangers-Regular.ttf',None),
]
W,RH=1080,300
img=Image.new('RGB',(W,RH*len(OPTS)),(70,110,60))
d=ImageDraw.Draw(img)
lab=font('SourceSans3.ttf',26,'Bold')
TAN=(196,176,130); DARK=(150,130,92); RIM=(236,224,190)
def ot(xy,t,f,fill=(255,255,255),anchor='la',sw=3):
    d.text(xy,t,font=f,fill=fill,anchor=anchor,stroke_width=sw,stroke_fill=(30,24,18))
for k,(name,hf,hv,bf,bv) in enumerate(OPTS):
    y=k*RH
    # backdrop stripe
    d.rectangle((0,y,W,y+RH),fill=(86,128,70) if k%2 else (78,118,64))
    d.text((24,y+12),name,font=lab,fill=(255,240,200))
    H=font(hf,46,hv); B=font(bf,24,bv); S=font(bf,30,bv)
    # panel
    d.rounded_rectangle((24,y+52,520,y+282),12,fill=TAN,outline=RIM,width=3)
    ot((44,y+60),'Bag',H)
    for i,(nm,b1) in enumerate([('Stone Axe (x1)','Equip'),('Baked Potato (x6)','Eat')]):
        x=44+i*236
        d.rounded_rectangle((x,y+124,x+220,y+270),10,fill=DARK)
        ot((x+110,y+190),nm,B,anchor='mm',sw=2)
        ot((x+60,y+246),b1,S,anchor='mm',sw=2); ot((x+160,y+246),'Drop',S,anchor='mm',sw=2)
    # HUD bits
    ot((560,y+60),'Lv. 12',H)
    d.rounded_rectangle((720,y+72,1000,y+102),12,fill=TAN,outline=RIM,width=2)
    d.rounded_rectangle((723,y+75,860,y+99),10,fill=(240,210,90))
    ot((860,y+87),'340 XP',B,anchor='mm',sw=2)
    ot((800,y+170),'Baked Potato',font(hf,40,hv),anchor='mm')
    d.ellipse((760,y+200,840,y+280),fill=TAN,outline=RIM,width=3)
    ot((800,y+268),'6',B,anchor='mm',sw=2)
    ot((560,y+128),'[E] Pickup',B,sw=2)
img.save('/tmp/fontprev/fonts.png')
