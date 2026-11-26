# Clover Island height and material field, in Roblox coordinates relative to the
# island centre (x east, z south; north is -z). Mirrored exactly in CloverIsland.lua.
import math
LOBE_R, CORE_R = 46.0, 52.0
LOBES = [(-1,-1,'pines'),(1,-1,'rocks'),(-1,1,'palms'),(1,1,'meadow')]  # NW NE SW SE
LOBE_C = 58.0
def smooth(a): a=max(0.0,min(1.0,a)); return a*a*(3-2*a)
def noise(x,z):
    return (math.sin(x*0.071+1.3)*math.cos(z*0.063-0.4)*1.4 + math.sin(x*0.153-z*0.121+2.1)*0.7
            + math.cos(x*0.031+z*0.047)*1.2)
def stem(x,z):
    # sandy spit to the south, from z=60 to z=150, 22 wide tapering to 12
    if z < 30 or z > 132: return -9
    t=(z-30)/102.0; w=22-9*t
    tip = smooth((132-z)/14)                 # rounded tip
    v = 1-abs(x)/w
    return v*tip - (1-tip) if v > 0 else v
def land(x,z):
    """>0 inside the island (roughly studs from the shore / 20), <0 in the sea."""
    best = 1 - math.hypot(x,z)/CORE_R
    for sx,sz,_ in LOBES:
        cx,cz = sx*LOBE_C/math.sqrt(2)*1.0, sz*LOBE_C/math.sqrt(2)*1.0
        best = max(best, 1 - math.hypot(x-cx*1.0, z-cz*1.0)/LOBE_R)
    best = max(best, stem(x,z)*0.35)
    return best + noise(x*1.7,z*1.7)*0.025
def lobe_of(x,z):
    if z > 44 and abs(x) < 24: return 'stem'
    if math.hypot(x,z) < 30: return 'centre'
    return LOBES[(0 if x<0 else 1) + (0 if z<0 else 2)][2]
def path_dist(x,z):
    # dirt paths: spawn spit -> centre, and centre -> each lobe
    # winding trails: spawn spit -> pond, and pond -> into each lobe
    d = abs(x - 4*math.sin(z*0.07)) if 14 < z < 122 else 1e9
    for sx,sz,_ in LOBES:
        ex,ez = sx*38,sz*38; L=math.hypot(ex,ez)
        t=(x*ex+z*ez)/(L*L)
        if 0.38 < t < 1:
            px,pz = ex*t, ez*t                    # nearest point on the straight line
            wob = 4*math.sin(t*7 + sx*1.7 + sz*0.6)  # sideways wobble
            nx,nz = -ez/L, ex/L
            d=min(d, math.hypot(x-(px+nx*wob), z-(pz+nz*wob)))
    return d
def lobe_w(x,z,i):
    sx,sz,_=LOBES[i]; c=LOBE_C/math.sqrt(2)
    d=math.hypot(x-sx*c, z-sz*c)
    return smooth((1-d/LOBE_R)/0.45) * smooth((math.hypot(x,z)-20)/16)
def stem_w(x,z):
    return smooth((z-38)/16)*smooth((24-abs(x))/8)
def height(x,z):
    l = land(x,z)
    if l <= 0:
        return max(-26.0, 1.0 + l*60)       # shelf down into the sea
    lobe = lobe_of(x,z)
    h = 1.5 + smooth(l/0.18)*2.5             # beach rising to the grass
    inland = smooth((l-0.12)/0.5)
    h += inland*(2.5 + noise(x,z)*1.6)       # rolling ground
    h += 9*math.exp(-(math.hypot(x,z)/34)**2) # central hill
    wr = lobe_w(x,z,1)                       # NE: terraced rock cliffs
    if wr > 0:
        k = smooth((l-0.1+noise(x*2.3,z*2.3)*0.06)/0.35); hr = h + k*14 + noise(x*1.3,z*1.3)*3
        hr = 1.5 + math.floor((hr-1.5)/4.5)*4.5 + (hr-1.5)%4.5*0.25
        h += (hr-h)*wr
    h += inland*5*lobe_w(x,z,0)              # NW: higher wooded ground
    ws = stem_w(x,z)                         # south spit stays low
    h += (min(h, 2.6 + l*4) - h)*ws
    # pond on the central hill
    pd = math.hypot(x+6, z-4)
    if pd < 11: h = min(h, 10.5 - (11-pd)*0.5)
    return h
def material(x,z,h,slope):
    l = land(x,z); lobe = lobe_of(x,z)
    if l <= 0.07 or (h < 2.6 and lobe != 'stem'): return 'Sand'
    if math.hypot(x+6, z-4) < 11 and h < 10.6: return 'Water'
    if lobe_w(x,z,1) > 0.5 and slope > 0.35: return 'Rock'
    if slope > 0.9: return 'Rock'
    if path_dist(x,z) < 3.2 and lobe != 'rocks': return 'Ground'
    if lobe == 'palms' and l < 0.3: return 'Sand'
    if lobe == 'meadow': return 'LeafyGrass'
    return 'Grass'
