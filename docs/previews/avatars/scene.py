import sys,os,math,bpy
sys.path.insert(0,'/tmp/avatar')
exec(open('/tmp/avatar/render.py').read())
LOOKS=[
 dict(skin=1,hair=0,hairColor=1,outfit=0,dye=0,paint=0),
 dict(skin=4,hair=2,hairColor=0,outfit=1,dye=2,paint=1),
 dict(skin=0,hair=1,hairColor=3,outfit=2,dye=4,paint=0),
 dict(skin=5,hair=3,hairColor=0,outfit=0,dye=5,paint=2),
 dict(skin=2,hair=0,hairColor=2,outfit=1,dye=1,paint=3),
 dict(skin=3,hair=4,hairColor=4,outfit=2,dye=0,paint=1),
]
for i,l in enumerate(LOOKS):
    x=(i-2.5)*4.2; yaw=[18,8,-4,4,-8,-18][i]
    Char(T((x,0,abs(i-2.5)*0.9))@A(y=yaw),l)  # +180: Roblox front is -Z; turn to face camera at -Z... see below
# ground
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,0)); g=bpy.context.object; g.data.materials.append(mat((104,156,70)))
sun=bpy.data.objects.new('Sun',bpy.data.lights.new('Sun','SUN')); sun.data.energy=3.4; sun.data.color=(1,0.95,0.86); sun.data.angle=0.2
sun.rotation_euler=(math.radians(-45),math.radians(-20),math.radians(25)); sc.collection.objects.link(sun)
sc.world=bpy.data.worlds.new('W'); sc.world.use_nodes=True; bg=sc.world.node_tree.nodes['Background']; bg.inputs[0].default_value=(0.62,0.78,0.92,1); bg.inputs[1].default_value=0.6
sc.render.engine='CYCLES'; sc.cycles.device='CPU'; sc.cycles.samples=int(os.environ.get('SAMPLES','32')); sc.view_settings.view_transform='Standard'
def shot(path,loc,target,lens,res):
    cam=bpy.data.objects.new('Cam',bpy.data.cameras.new('Cam')); sc.collection.objects.link(cam); cam.data.lens=lens; cam.location=loc
    t=bpy.data.objects.new('T',None); t.location=target; sc.collection.objects.link(t)
    c=cam.constraints.new('TRACK_TO'); c.target=t; c.track_axis='TRACK_NEGATIVE_Z'; c.up_axis='UP_Y'
    sc.camera=cam; sc.render.resolution_x,sc.render.resolution_y=res; sc.render.filepath=path; bpy.ops.render.render(write_still=True)
# camera stands on Roblox -Z (in front of the faces) -> Blender +Y
shot("/tmp/avatar/lineup.png",(0,30,6),(0,0,2.4),40,(1600,800))
shot('/tmp/avatar/heads.png',(-4.2*0.5,8,5.0),(-4.2*0.5,0,4.4),50,(1600,900))
