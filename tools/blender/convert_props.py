"""Convert CC0 Poly Haven glTF props into game-ready .glb files.

Heavy models are decimated to a triangle budget so every prop stays real-time friendly.
Run: python3 tools/blender/convert_props.py /opt/cc0/models assets/models/props
"""
import bpy, os, sys, glob

SRC, DST = sys.argv[1], sys.argv[2]
SKIP = {'fir_tree_01', 'pine_tree_01'}
BUDGET = 30000
SPECIAL_BUDGET = {'wooden_candlestick': 12000, 'potted_plant_01': 26000, 'shrub_01': 22000, 'dead_tree_trunk': 26000, 'dead_tree_trunk_02': 26000}

def tri_count(objs):
    n = 0
    for o in objs:
        if o.type == 'MESH':
            n += sum(len(p.vertices) - 2 for p in o.data.polygons)
    return n

os.makedirs(DST, exist_ok=True)
for name in sorted(os.listdir(SRC)):
    if name in SKIP: continue
    files = glob.glob(os.path.join(SRC, name, '*.gltf'))
    if not files: continue
    out = os.path.join(DST, name + '.glb')
    if os.path.exists(out): continue
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=files[0])
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    tris = tri_count(meshes)
    budget = SPECIAL_BUDGET.get(name, BUDGET)
    if tris > budget:
        ratio = max(0.05, budget / tris)
        for o in meshes:
            m = o.modifiers.new('dec', 'DECIMATE'); m.ratio = ratio; m.use_collapse_triangulate = True
            bpy.context.view_layer.objects.active = o
            bpy.ops.object.modifier_apply(modifier='dec')
    bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', export_image_format='AUTO',
                              export_apply=True, export_yup=True)
    print(f'{name}: {tris} -> {tri_count([o for o in bpy.context.scene.objects if o.type == "MESH"])} tris', flush=True)
print('DONE')
