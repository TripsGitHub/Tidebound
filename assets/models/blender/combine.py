import bpy, glob, os, math
bpy.ops.wm.read_factory_settings(use_empty=True)
files = sorted(glob.glob('/tmp/models/out/*.obj') + glob.glob('/tmp/models/out2/*.obj'))
seen = set(); i = 0
for f in files:
    name = os.path.splitext(os.path.basename(f))[0]
    if name in seen: continue
    seen.add(name)
    before = set(bpy.data.objects)
    bpy.ops.wm.obj_import(filepath=f, up_axis='Y', forward_axis='NEGATIVE_Z')
    new = [o for o in bpy.data.objects if o not in before]
    gx, gy = (i % 6) * 30, (i // 6) * 30
    for o in new:
        o.name = f"{name}__{o.name.split('.')[0]}"
        o.location.x += gx; o.location.y += gy
    i += 1
# Roblox gives each MeshPart one colour, so split any object that uses several materials.
for o in list(bpy.data.objects):
    if len(o.data.materials) > 1:
        bpy.ops.object.select_all(action='DESELECT'); o.select_set(True); bpy.context.view_layer.objects.active = o
        base = o.name
        bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.separate(type='MATERIAL'); bpy.ops.object.mode_set(mode='OBJECT')
        for p in [x for x in bpy.data.objects if x.name == base or x.name.startswith(base + '.')]:
            used = {p.data.materials[poly.material_index].name for poly in p.data.polygons} if p.data.polygons else set()
            mname = sorted(used)[0] if used else 'x'
            import re; p.name = base + '_' + re.sub(r'\.\d+$', '', mname)
for o in bpy.data.objects:
    # drop unused material slots so each part carries exactly one colour
    used = {poly.material_index for poly in o.data.polygons}
    for idx in reversed(range(len(o.data.materials))):
        if idx not in used:
            o.active_material_index = idx
            bpy.context.view_layer.objects.active = o
            bpy.ops.object.material_slot_remove()
bpy.ops.object.select_all(action='SELECT')
for o in bpy.data.objects:
    if o.type=='MESH': o.data.name = o.name
bpy.ops.wm.obj_export(filepath='/tmp/models/tidebound_models.obj', export_materials=True, up_axis='Y', forward_axis='NEGATIVE_Z', export_object_groups=True)
print("MODELS", i, sorted(o.name for o in bpy.data.objects))
