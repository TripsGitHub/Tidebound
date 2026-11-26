from PIL import Image, ImageDraw, ImageFont
F='/tmp/fonts/'
OPTS=[('Source Sans Bold','SourceSans3.ttf','Bold'),('Arimo Bold (Arial look)','Arimo.ttf','Bold'),('Roboto Condensed','RobotoCondensed.ttf','Bold'),
('Titillium Web','TitilliumWeb-Bold.ttf',None),('Ubuntu Bold','Ubuntu-Bold.ttf',None),('Oswald','Oswald.ttf','SemiBold'),
('Patrick Hand','PatrickHand-Regular.ttf',None),('Kalam','Kalam-Bold.ttf',None),('Fondamento','Fondamento-Regular.ttf',None),
('Merriweather','Merriweather.ttf','Bold'),('EB Garamond','EBGaramond.ttf','Bold'),('Special Elite','SpecialElite-Regular.ttf',None),
('Josefin Sans','JosefinSans.ttf','Bold'),('Grenze Gotisch','GrenzeGotisch.ttf','Bold'),('Amatic SC','AmaticSC-Bold.ttf',None),('Balthazar','Balthazar-Regular.ttf',None)]
def font(n,s,v):
    f=ImageFont.truetype(F+n,s)
    if v:
        try: f.set_variation_by_name(v)
        except Exception as e: print(n,e,[x for x in f.get_variation_names()])
    return f
TAN=(196,176,130); CARD=(178,158,114); DARK=(150,131,92); RIM=(236,224,190); EDGE=(46,34,20)
CW,CH=540,210
def sheet(opts,start,path):
    img=Image.new('RGB',(CW*2,CH*((len(opts)+1)//2)),(84,130,66)); d=ImageDraw.Draw(img)
    def ot(xy,t,f,anchor='la',fill=(255,255,255),sw=2): d.text(xy,t,font=f,fill=fill,anchor=anchor,stroke_width=sw,stroke_fill=EDGE)
    for k,(name,fn,v) in enumerate(opts):
        x=(k%2)*CW; y=(k//2)*CH
        d.rounded_rectangle((x+12,y+12,x+CW-12,y+CH-12),10,fill=TAN,outline=RIM,width=3)
        lab=font('SourceSans3.ttf',22,'Bold'); d.text((x+26,y+20),f'{start+k}. {name}',font=lab,fill=(60,44,24))
        H=font(fn,40,v); B=font(fn,26,v)
        ot((x+26,y+52),'Wooden Club',H,sw=3)
        d.rounded_rectangle((x+26,y+112,x+250,y+182),8,fill=DARK)
        ot((x+138,y+147),'Equip   Drop',B,anchor='mm')
        ot((x+270,y+120),'Lv. 12   Hunger 72',B)
        ot((x+270,y+156),'Your bag is full',B,fill=(232,86,80))
    img.save(path)
sheet(OPTS[:8],1,'/tmp/fontprev/fonts-1.png'); sheet(OPTS[8:],9,'/tmp/fontprev/fonts-2.png')
