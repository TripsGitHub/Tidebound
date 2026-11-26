import re
def parse(path):
    s=open(path).read()
    body=s[s.index('local ANIMS'):s.index('local JOINTS')]
    anims={}
    for m in re.finditer(r'\n\t(\w+) = \{\n(.*?)\n\t\},',body,re.S):
        keys=[]
        for line in m.group(2).split('\n'):
            tm=re.search(r't = ([\d.]+)',line)
            if not tm: continue
            pose=None
            if 'pose' in line:
                pose={j:tuple(float(x) for x in v.split(',')) for j,v in re.findall(r'(\w+) = Vector3\.new\(([^)]*)\)',line)}
            keys.append((float(tm.group(1)),pose))
        anims[m.group(1)]=keys
    hold={j:tuple(float(x) for x in v.split(',')) for j,v in re.findall(r'(\w+) = Vector3\.new\(([^)]*)\)',s[s.index('local HOLD'):s.index('local ANIMS')])}
    return anims,hold
def smooth(a): return a*a*(3-2*a)
J=['RightShoulder','RightElbow','Waist','Neck']
def sample(keys,rest,t):
    if t>=keys[-1][0]: return rest
    for (ta,pa),(tb,pb) in zip(keys,keys[1:]):
        if ta<=t<tb:
            f=smooth((t-ta)/(tb-ta)); pa=pa or rest; pb=pb or rest
            return {j:tuple(a+(b-a)*f for a,b in zip(pa.get(j,(0,0,0)),pb.get(j,(0,0,0)))) for j in J}
    return rest
if __name__=='__main__':
    a,h=parse('/home/user/tidebound/src/client/Anim.lua'); print(list(a), h); print(a['slash'])
