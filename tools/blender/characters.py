"""Character generator for The House Beyond Midnight (Blender 5.x, bpy).

Builds every character as a skinned glTF: a Skin-modifier body subdivided into smooth organic
forms, a sculpted head, articulated hands, metaball hair, layered clothing, accessories, and a
face rig (eye, lid and brow bones plus swappable mouth meshes). Weights are smooth distance-based
weights against bone segments, so the result deforms cleanly under procedural animation.

Character space: Blender Z-up, the character faces -Y (exported to glTF/Godot as facing +Z).
Arms are modelled in a relaxed A-pose; the in-game animator lowers them.

Run: python3 tools/blender/characters.py [out_dir] [--preview] [--only name,name]
"""
import bpy, bmesh, math, os, random, sys
from mathutils import Vector, Matrix, Euler

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..')
OUT = os.path.join(ROOT, 'assets', 'models', 'chars')
A_POSE = 0.55  # arm angle out from the body (radians)
# Cartoon proportions: a compact body, a big round head sitting low on the shoulders, short legs,
# oversized hands and boots, big eyes and a round nose.
BODY_K = 0.6; HEAD_K = 2.0; LEG_K = 0.62; HAND_K = 1.45; BOOT_K = 1.35; EYE_K = 1.32; NOSE_K = 1.55; BUILD_K = 1.08

# ===================================================================================== specs
def V(*a): return Vector(a)

CAST = {
    # ---------------------------------------------------------------- Avery Wren (the surveyor): teal field coat, copper mop, mustard scarf
    'avery_fieldcoat': dict(height=1.0, build='normal', skin=(0.95, 0.76, 0.62), iris='avery', brow=(0.5, 0.2, 0.08),
        hair=dict(style='bob', color=(0.8, 0.36, 0.13)), face=dict(freckles=True, nose=1.0, blush=True, shape='round', brow_w=1.7), lip=(0.72, 0.32, 0.28),
        outfit=dict(type='coat', main=(0.1, 0.46, 0.47), second=(0.06, 0.3, 0.32), shirt=(0.96, 0.92, 0.82), trousers=(0.13, 0.15, 0.28), boots=(0.5, 0.24, 0.1), belt=(0.25, 0.13, 0.06), skirt_len=0.58, fabric='wool'),
        acc=['satchel', 'bigscarf', 'notebook', 'glasses', 'pencil', 'folding_rule', 'tape', 'wristwatch', 'cuffs'], scarf=(0.99, 0.74, 0.1)),
    'avery_shirtsleeves': dict(base='avery_fieldcoat', outfit=dict(type='waistcoat', main=(0.97, 0.94, 0.86), second=(0.5, 0.16, 0.45), shirt=(0.97, 0.94, 0.86), trousers=(0.13, 0.15, 0.28), boots=(0.5, 0.24, 0.1), trim=(0.95, 0.72, 0.25))),
    'avery_raincoat': dict(base='avery_fieldcoat', outfit=dict(type='coat', main=(1.0, 0.8, 0.08), second=(0.9, 0.6, 0.04), shirt=(0.96, 0.92, 0.82), trousers=(0.13, 0.15, 0.28), boots=(0.8, 0.12, 0.1), belt=(0.85, 0.55, 0.05), skirt_len=0.6, fabric='rubber', hood=True), acc=['satchel', 'notebook', 'glasses', 'pencil', 'tape', 'wristwatch']),
    'avery_lanternkeeper': dict(base='avery_fieldcoat', outfit=dict(type='coat', main=(0.1, 0.15, 0.42), second=(0.95, 0.72, 0.25), shirt=(0.96, 0.92, 0.82), trousers=(0.08, 0.09, 0.2), boots=(0.15, 0.08, 0.06), belt=(0.35, 0.22, 0.06), trim=(0.95, 0.72, 0.25), skirt_len=0.62, fabric='wool'), acc=['satchel', 'bigscarf', 'notebook', 'cap', 'glasses', 'pencil', 'wristwatch', 'cuffs'], scarf=(0.3, 0.72, 0.95), cap=(0.1, 0.15, 0.42)),
    'avery_masquerade': dict(base='avery_fieldcoat', outfit=dict(type='tailcoat', main=(0.04, 0.42, 0.3), second=(0.02, 0.24, 0.17), lapel=(0.02, 0.14, 0.1), vest=(0.98, 0.76, 0.28), shirt=(0.98, 0.96, 0.92), trousers=(0.06, 0.08, 0.1), boots=(0.05, 0.04, 0.04), fabric='wool'), acc=['mask', 'bowtie', 'flower', 'notebook', 'wristwatch'], bowtie=(0.98, 0.76, 0.28)),
    'avery_nightcap': dict(base='avery_fieldcoat', outfit=dict(type='pajamas', main=(0.72, 0.84, 1.0), second=(0.32, 0.42, 0.9), shirt=(0.72, 0.84, 1.0), trousers=(0.72, 0.84, 1.0), boots=(0.95, 0.4, 0.55), socks=(1.0, 0.85, 0.2), fabric='linen'), acc=['nightcap', 'notebook', 'glasses', 'wristwatch'], nightcap=(1.0, 0.42, 0.58)),
    'avery_phantom': dict(base='avery_fieldcoat', outfit=dict(type='coat', main=(0.78, 0.98, 0.92), second=(0.5, 0.85, 0.85), shirt=(0.92, 0.98, 1.0), trousers=(0.32, 0.5, 0.62), boots=(0.22, 0.32, 0.45), belt=(0.55, 0.8, 0.85), skirt_len=0.75, fabric='linen', hood=True), acc=['notebook', 'glasses', 'wristwatch']),
    # ---------------------------------------------------------------- Mara Bell (the singer): magenta jacket, big curls, teal band
    'mara_performer': dict(height=0.98, build='normal', skin=(0.56, 0.36, 0.24), iris='mara', brow=(0.08, 0.05, 0.03), hair=dict(style='curls', color=(0.1, 0.06, 0.05), band=(0.1, 0.78, 0.74)), sequin_sleeve=True, sequin=(1.0, 0.55, 0.82),
        face=dict(lashes=True, nose=0.95, blush=True, shape='heart', mole=True, brow_w=1.25), lip=(0.6, 0.18, 0.25),
        outfit=dict(type='jacket', main=(0.82, 0.13, 0.5), second=(0.48, 0.05, 0.3), trim=(1.0, 0.78, 0.25), shirt=(0.98, 0.93, 0.86), trousers=(0.22, 0.1, 0.34), boots=(0.25, 0.05, 0.12), gloves=(0.98, 0.96, 0.92), fabric='wool'),
        acc=['brooch', 'gloves', 'feather', 'earrings', 'bangles', 'stage_shoulders']),
    'mara_gown': dict(base='mara_performer', outfit=dict(type='gown', main=(0.03, 0.58, 0.42), second=(0.02, 0.38, 0.28), trim=(1.0, 0.78, 0.25), gloves=(0.98, 0.96, 0.92), fabric='velvet'), acc=['brooch', 'gloves', 'feather', 'earrings', 'bangles'], feather=(1.0, 0.85, 0.35), sequin_sleeve=False),
    'mara_masquerade': dict(base='mara_performer', outfit=dict(type='jacket', main=(0.32, 0.12, 0.62), second=(0.18, 0.06, 0.38), trim=(1.0, 0.82, 0.35), shirt=(0.98, 0.93, 0.86), trousers=(0.1, 0.06, 0.2), boots=(0.06, 0.04, 0.08), gloves=(0.15, 0.08, 0.2), fabric='wool'), acc=['brooch', 'gloves', 'mask', 'earrings', 'bangles'], sequin_sleeve=False),
    'theo': dict(height=1.03, build='slim', skin=(0.94, 0.8, 0.68), iris='theo', hair=dict(style='short', color=(0.3, 0.18, 0.1)), face=dict(nose=1.1),
        outfit=dict(type='waistcoat', main=(0.96, 0.93, 0.86), second=(0.42, 0.62, 0.32), shirt=(0.96, 0.93, 0.86), trousers=(0.3, 0.26, 0.4), boots=(0.32, 0.18, 0.1), trim=(0.9, 0.75, 0.35)), acc=['scarf', 'notebook', 'glasses', 'pencil'], scarf=(0.9, 0.2, 0.22)),
    'june': dict(height=0.96, build='normal', skin=(0.8, 0.6, 0.45), iris='june', hair=dict(style='ponytail', color=(0.1, 0.06, 0.05)), face=dict(freckles=True),
        outfit=dict(type='waistcoat', main=(0.95, 0.9, 0.8), second=(0.95, 0.48, 0.12), shirt=(0.95, 0.9, 0.8), trousers=(0.2, 0.36, 0.62), boots=(0.22, 0.12, 0.08), trim=(0.6, 0.6, 0.62)), acc=['goggles']),
    # ---------------------------------------------------------------- ghosts and echoes (re-coloured in game by the ghost / echo shaders)
    'porter': dict(height=1.32, build='slim', head_scale=0.92, skin=(0.84, 0.8, 0.74), iris='porter', brow=(0.62, 0.64, 0.68), hair=dict(style='fringe', color=(0.7, 0.72, 0.75)),
        face=dict(nose=1.45, moustache='droopy', eye_size=1.0, ears=1.25, shape='long', brow_w=1.35, brow_tilt=1.0), tail=True,
        outfit=dict(type='uniform', main=(0.16, 0.22, 0.62), trim=(1.0, 0.78, 0.3), gloves=(0.98, 0.97, 0.94), fabric='wool'), acc=['cap', 'gloves', 'epaulettes', 'hanger', 'ticket', 'keyring'], cap=(0.16, 0.22, 0.62)),
    'pip': dict(height=0.72, child=True, head_scale=1.12, skin=(0.95, 0.84, 0.76), iris='pip', hair=dict(style='boy', color=(0.75, 0.52, 0.25)), face=dict(eye_size=1.25, nose=0.85, blush=True, freckles=True, ears=1.7, shape='bean'), tail=True, cap_scale=1.22,
        outfit=dict(type='pageboy', main=(0.95, 0.36, 0.15), trim=(1.0, 0.82, 0.35), fabric='wool'), acc=['cap', 'buttons', 'snuffer'], cap=(0.95, 0.36, 0.15)),
    'host': dict(height=0.95, build='round', head_scale=1.08, skin=(0.95, 0.76, 0.66), iris='host', brow=(0.85, 0.85, 0.88), hair=dict(style='slick', color=(0.86, 0.86, 0.9)),
        face=dict(moustache='curl', sideburns=True, nose=0.95, blush=True, shape='egg', brow_w=2.0), crooked_bow=True,
        outfit=dict(type='tailcoat', main=(0.62, 0.07, 0.17), second=(0.38, 0.03, 0.1), lapel=(0.22, 0.02, 0.06), vest=(0.08, 0.5, 0.46), shirt=(0.98, 0.96, 0.92), trousers=(0.1, 0.05, 0.07), boots=(0.05, 0.04, 0.05), trim=(1.0, 0.8, 0.3), fabric='wool'),
        acc=['bowtie', 'monocle', 'watchchain', 'cane', 'tophat', 'dance_card', 'wilted_flower'], bowtie=(1.0, 0.8, 0.3)),
    'dancer_lady': dict(height=0.98, skin=(0.94, 0.82, 0.78), iris='dancer', hair=dict(style='updo', color=(0.6, 0.25, 0.12)), face=dict(lashes=True, blush=True, shape='heart'),
        outfit=dict(type='gown', main=(0.95, 0.45, 0.62), second=(0.75, 0.25, 0.45), trim=(1.0, 0.92, 0.85), fabric='velvet'), acc=['mask_fox']),
    'dancer_gent': dict(height=1.03, skin=(0.92, 0.8, 0.74), iris='dancer', hair=dict(style='slick', color=(0.12, 0.1, 0.1)),
        outfit=dict(type='tailcoat', main=(0.06, 0.4, 0.5), second=(0.03, 0.25, 0.32), lapel=(0.02, 0.16, 0.2), vest=(0.98, 0.98, 1.0), shirt=(0.98, 0.96, 0.92), trousers=(0.05, 0.08, 0.1), boots=(0.03, 0.03, 0.03), fabric='wool'), acc=['mask_owl', 'bowtie'], bowtie=(0.98, 0.98, 1.0)),
    'king': dict(height=1.2, skin=(0.92, 0.82, 0.72), iris='king', hair=dict(style='slick', color=(0.35, 0.26, 0.22)),
        outfit=dict(type='robe', main=(0.72, 0.06, 0.14), second=(0.45, 0.03, 0.08), trim=(1.0, 0.8, 0.3), fabric='velvet'), acc=['crown', 'mask_full']),
    'musician': dict(height=1.0, skin=(0.92, 0.82, 0.72), iris='host', hair=dict(style='short', color=(0.2, 0.16, 0.14)),
        outfit=dict(type='tailcoat', main=(0.1, 0.1, 0.14), second=(0.06, 0.06, 0.08), lapel=(0.04, 0.04, 0.05), vest=(0.95, 0.95, 0.96), shirt=(0.98, 0.96, 0.92), trousers=(0.06, 0.06, 0.08), boots=(0.03, 0.03, 0.03), fabric='wool'), acc=['bowtie'], bowtie=(0.85, 0.1, 0.18)),
    # the family, for painted portraits
    'edmund': dict(height=1.04, skin=(0.88, 0.72, 0.6), iris='king', brow=(0.2, 0.15, 0.13), hair=dict(style='slick', color=(0.22, 0.15, 0.12)), face=dict(moustache='big', nose=1.15, shape='long'),
        outfit=dict(type='tailcoat', main=(0.06, 0.26, 0.18), second=(0.04, 0.16, 0.11), lapel=(0.03, 0.1, 0.07), vest=(0.7, 0.08, 0.15), shirt=(0.98, 0.96, 0.92), trousers=(0.06, 0.06, 0.08), boots=(0.03, 0.03, 0.03), fabric='wool'), acc=['bowtie', 'watchchain'], bowtie=(0.05, 0.05, 0.05)),
    'margaret': dict(height=0.97, skin=(0.93, 0.78, 0.68), iris='mara', hair=dict(style='updo', color=(0.55, 0.28, 0.1)), face=dict(lashes=True, blush=True, shape='heart'),
        outfit=dict(type='gown', main=(0.62, 0.06, 0.22), second=(0.42, 0.04, 0.15), trim=(1.0, 0.85, 0.5), fabric='velvet'), acc=['brooch']),
    'celeste': dict(height=0.99, build='slim', skin=(0.9, 0.78, 0.7), iris='theo', hair=dict(style='updo', color=(0.08, 0.06, 0.1)), face=dict(lashes=True),
        outfit=dict(type='gown', main=(0.1, 0.2, 0.55), second=(0.06, 0.12, 0.38), trim=(0.75, 0.88, 1.0), fabric='velvet'), acc=[]),
    'youngest': dict(height=0.7, child=True, head_scale=1.1, skin=(0.95, 0.8, 0.7), iris='pip', hair=dict(style='boy', color=(0.6, 0.34, 0.15)), face=dict(eye_size=1.2, blush=True, freckles=True, shape='bean'),
        outfit=dict(type='pageboy', main=(0.1, 0.45, 0.3), trim=(1.0, 0.85, 0.5), fabric='wool'), acc=[]),
}

def resolve(name):
    s = dict(CAST[name])
    if 'base' in s:
        b = resolve(s.pop('base'))
        b.update(s)
        s = b
    return s

# ===================================================================================== helpers
def clean():
    bpy.ops.wm.read_factory_settings(use_empty=True)

def link(obj):
    bpy.context.scene.collection.objects.link(obj)
    return obj

def new_obj(name, mesh):
    return link(bpy.data.objects.new(name, mesh))

def to_linear(c):
    return tuple(((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c)

def mat(name, color, rough=0.8, metal=0.0, emit=None, image=None):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = (*to_linear(color), 1.0)
    if image and os.path.exists(image):
        tex = m.node_tree.nodes.new('ShaderNodeTexImage'); tex.image = bpy.data.images.load(image)
        m.node_tree.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
    bsdf.inputs['Roughness'].default_value = rough
    bsdf.inputs['Metallic'].default_value = metal
    if emit:
        bsdf.inputs['Emission Color'].default_value = (*emit, 1.0); bsdf.inputs['Emission Strength'].default_value = 1.0
    return m

def apply_mods(obj):
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    for m in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=m.name)
    obj.select_set(False)

def subsurf(obj, levels=2):
    m = obj.modifiers.new('sub', 'SUBSURF'); m.levels = levels; m.render_levels = levels
    return m

def smooth(obj):
    for p in obj.data.polygons: p.use_smooth = True

def prim(kind, name, loc=(0, 0, 0), scale=(1, 1, 1), rot=(0, 0, 0), material=None, **kw):
    bm = bmesh.new()
    if kind == 'sphere': bmesh.ops.create_uvsphere(bm, u_segments=kw.get('u', 24), v_segments=kw.get('v', 16), radius=kw.get('r', 1.0))
    elif kind == 'cyl': bmesh.ops.create_cone(bm, cap_ends=kw.get('caps', True), segments=kw.get('seg', 24), radius1=kw.get('r1', 1.0), radius2=kw.get('r2', 1.0), depth=kw.get('depth', 1.0))
    elif kind == 'cube': bmesh.ops.create_cube(bm, size=1.0)
    elif kind == 'torus':
        R, rr = kw.get('R', 1.0), kw.get('rr', 0.1); seg, rs = kw.get('seg', 32), kw.get('rs', 10); arc = kw.get('arc', math.tau)
        verts = []
        for i in range(seg + (0 if arc >= math.tau else 1)):
            u = arc * i / seg
            ring = []
            for j in range(rs):
                v = math.tau * j / rs
                ring.append(bm.verts.new(((R + rr * math.cos(v)) * math.cos(u), (R + rr * math.cos(v)) * math.sin(u), rr * math.sin(v))))
            verts.append(ring)
        n = len(verts)
        for i in range(n if arc >= math.tau else n - 1):
            a, b = verts[i], verts[(i + 1) % n]
            for j in range(rs):
                bm.faces.new((a[j], b[j], b[(j + 1) % rs], a[(j + 1) % rs]))
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    o = new_obj(name, me)
    o.location = loc; o.scale = scale; o.rotation_euler = rot
    if material: o.data.materials.append(material)
    smooth(o)
    return o

def bake_xform(o):
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    o.select_set(False)

def tube(name, pts, r, material, r_end=None, seg=12):
    """A tube along a polyline (Catmull-Rom smoothed by a bezier curve), converted to mesh."""
    cu = bpy.data.curves.new(name, 'CURVE'); cu.dimensions = '3D'; cu.bevel_depth = r; cu.bevel_resolution = 3; cu.resolution_u = seg
    sp = cu.splines.new('NURBS'); sp.points.add(len(pts) - 1)
    for i, p in enumerate(pts): sp.points[i].co = (*p, 1.0)
    sp.use_endpoint_u = True; sp.order_u = min(4, len(pts))
    if r_end is not None:
        sp.points[-1].radius = r_end / r
    cu.use_fill_caps = True
    o = new_obj(name, cu)
    bpy.ops.object.select_all(action='DESELECT')
    bpy.context.view_layer.objects.active = o; o.select_set(True)
    bpy.ops.object.convert(target='MESH')
    o = bpy.context.view_layer.objects.active; o.select_set(False)
    o.data.materials.clear(); o.data.materials.append(material)
    smooth(o)
    return o

def lathe(name, profile, material, segs=32, loc=(0, 0, 0), open_front=0.0, scale=(1, 1, 1)):
    """Revolve (radius, z) points around Z. open_front leaves a gap (radians) centred on -Y."""
    bm = bmesh.new()
    rings = []
    span = math.tau - open_front
    closed = open_front == 0.0
    count = segs if closed else segs + 1
    for i in range(count):
        a = -math.pi / 2 + open_front / 2 + span * i / segs  # start beside the front gap
        ring = [bm.verts.new((r * math.cos(a), r * math.sin(a), z)) for r, z in profile]
        rings.append(ring)
    for i in range(segs if closed else segs):
        a, b = rings[i], rings[(i + 1) % len(rings)]
        for j in range(len(profile) - 1):
            bm.faces.new((a[j], b[j], b[j + 1], a[j + 1]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    o = new_obj(name, me); o.location = loc; o.scale = scale
    o.data.materials.append(material)
    smooth(o)
    return o

# ===================================================================================== skeleton
class Rig:
    """Joint positions for a character (in metres, Z-up, facing -Y)."""
    def __init__(self, s):
        self.s = s
        H0 = s.get('height', 1.0)
        H = H0 * BODY_K
        child = s.get('child', False)
        bw = {'slim': 0.9, 'round': 1.25}.get(s.get('build', 'normal'), 1.0) * BUILD_K
        self.bw = bw
        leg = (0.3 if child else 0.42) * H * LEG_K
        self.leg = leg
        hips = leg * 2 + 0.08 * H * BOOT_K
        spine = 0.1 * H; chest = (0.14 if child else 0.2) * H; neck = (0.12 if child else 0.15) * H
        self.j = j = {}
        j['root'] = V(0, 0, 0)
        j['hips'] = V(0, 0, hips)
        j['spine'] = V(0, 0, hips + spine)
        j['chest'] = V(0, 0, hips + spine + chest)
        j['neck'] = V(0, 0, hips + spine + chest + neck)
        j['head'] = V(0, 0, j['neck'].z + 0.06 * H)
        self.head_r = 0.135 * s.get('head_scale', 1.0) * (1.05 if child else 1.0) * (H0 ** 0.25) * HEAD_K
        j['head_c'] = V(0, 0.0, j['head'].z + self.head_r * 0.95)
        j['head_top'] = V(0, 0, j['head_c'].z + self.head_r * 1.1)
        shw = (0.15 if child else 0.19) * bw * H
        up = (0.15 if child else 0.21) * H; fo = (0.13 if child else 0.19) * H; hand = 0.17 * H * (0.8 if child else 1) * HAND_K
        sh_z = j['chest'].z + 0.12 * H
        for side, sx in (('L', 1), ('R', -1)):
            j['shoulder.' + side] = V(sx * shw, 0, sh_z)
            d = V(sx * math.sin(A_POSE), 0, -math.cos(A_POSE))
            j['elbow.' + side] = j['shoulder.' + side] + d * up
            j['wrist.' + side] = j['elbow.' + side] + d * fo
            j['hand_end.' + side] = j['wrist.' + side] + d * hand * 0.6
            hx = 0.095 * bw * H
            j['hip.' + side] = V(sx * hx, 0, hips - 0.03 * H)
            j['knee.' + side] = j['hip.' + side] + V(0, -0.01, -leg)
            j['ankle.' + side] = j['knee.' + side] + V(0, 0.01, -leg)
            j['toe.' + side] = j['ankle.' + side] + V(0, -0.13 * H * BOOT_K, -0.07 * H * BOOT_K)
        self.H = H

    # bones: name -> (head, tail, parent)
    def bones(self):
        j = self.j; H = self.H
        b = {
            'root': (j['root'], j['root'] + V(0, 0, 0.1), None),
            'hips': (j['hips'], j['spine'], 'root'),
            'spine': (j['spine'], j['chest'], 'hips'),
            'chest': (j['chest'], j['neck'] - V(0, 0, 0.04 * H), 'spine'),
            'neck': (j['neck'] - V(0, 0, 0.04 * H), j['head'], 'chest'),
            'head': (j['head'], j['head_top'], 'neck'),
        }
        for side in ('L', 'R'):
            sx = 1 if side == 'L' else -1
            b['shoulder.' + side] = (j['chest'] + V(sx * 0.05 * H, 0, 0.1 * H), j['shoulder.' + side], 'chest')
            b['upper_arm.' + side] = (j['shoulder.' + side], j['elbow.' + side], 'shoulder.' + side)
            b['forearm.' + side] = (j['elbow.' + side], j['wrist.' + side], 'upper_arm.' + side)
            b['hand.' + side] = (j['wrist.' + side], j['hand_end.' + side], 'forearm.' + side)
            b['thigh.' + side] = (j['hip.' + side], j['knee.' + side], 'hips')
            b['shin.' + side] = (j['knee.' + side], j['ankle.' + side], 'thigh.' + side)
            b['foot.' + side] = (j['ankle.' + side], j['toe.' + side], 'shin.' + side)
        return b

# ===================================================================================== body
def body_mesh(rig, s, mats):
    """Skin-modifier body: torso, arms, legs as one smooth mesh, coloured by zone."""
    j = rig.j; H = rig.H; bw = rig.bw
    child = s.get('child', False); round_ = s.get('build') == 'round'
    has_legs = not s.get('tail') and s['outfit']['type'] not in ('gown', 'robe')
    verts, edges, radii = [], [], []
    def add(p, rx, ry=None):
        verts.append(tuple(p)); radii.append((rx, ry if ry is not None else rx)); return len(verts) - 1
    pel = add(j['hips'] + V(0, 0, -0.02 * H), 0.15 * bw * H, 0.11 * bw * H)
    waist = add(j['spine'], 0.13 * bw * H * (1.18 if round_ else 1.0), 0.095 * bw * H * (1.3 if round_ else 1.0))
    chest = add(j['chest'] + V(0, 0, 0.05 * H), 0.165 * bw * H * (1.1 if round_ else 1.0), 0.11 * bw * H * (1.2 if round_ else 1.0))
    upch = add(j['chest'] + V(0, 0, 0.13 * H), 0.15 * bw * H, 0.095 * bw * H)
    neck = add(j['neck'], 0.05 * H, 0.05 * H)
    edges += [(pel, waist), (waist, chest), (chest, upch), (upch, neck)]
    arm_r = (0.042 if child else 0.052) * H * (1.15 if round_ else 1.0)
    for side in ('L', 'R'):
        sh = add(j['shoulder.' + side], arm_r * 1.15)
        el = add(j['elbow.' + side], arm_r * 0.85)
        mid = add((j['elbow.' + side] + j['wrist.' + side]) * 0.5, arm_r * 0.82)
        wr = add(j['wrist.' + side] + (j['elbow.' + side] - j['wrist.' + side]).normalized() * 0.03, arm_r * 0.72)
        edges += [(upch, sh), (sh, el), (el, mid), (mid, wr)]
        if has_legs:
            leg_r = (0.055 if child else 0.068) * H * (1.12 if round_ else 1.0)
            hp = add(j['hip.' + side], leg_r * 1.15)
            kn = add(j['knee.' + side], leg_r * 0.85)
            calf = add(j['knee.' + side] + (j['ankle.' + side] - j['knee.' + side]) * 0.35, leg_r * 0.88)
            an = add(j['ankle.' + side] + V(0, 0, 0.05 * H), leg_r * 0.66)
            edges += [(pel, hp), (hp, kn), (kn, calf), (calf, an)]
    me = bpy.data.meshes.new('Body'); me.from_pydata(verts, edges, []); me.update()
    o = new_obj('Body', me)
    sk = o.modifiers.new('skin', 'SKIN'); sk.use_smooth_shade = True; sk.branch_smoothing = 0.6
    for i, (rx, ry) in enumerate(radii): o.data.skin_vertices[0].data[i].radius = (rx, ry)
    o.data.skin_vertices[0].data[pel].use_root = True
    subsurf(o, 2)
    apply_mods(o)
    # flatten the back a little and push the chest forward (less cylindrical torsos)
    for v in o.data.vertices:
        z = v.co.z
        if j['hips'].z - 0.1 < z < j['neck'].z:
            if v.co.y > 0: v.co.y *= 0.82
            else: v.co.y *= 1.05
    # zone materials
    o.data.materials.clear()
    for k in ('torso', 'sleeve', 'legs', 'skin', 'sequin'): o.data.materials.append(mats[k])
    for p in o.data.polygons:
        c = p.center
        if abs(c.x) > 0.13 * bw * H and c.z > j['hips'].z + 0.08 * H: idx = 4 if (s.get('sequin_sleeve') and c.x < 0) else 1   # arms
        elif c.z < j['hips'].z - 0.05 * H: idx = 2                                     # legs
        elif c.z > j['neck'].z - 0.03 * H: idx = 3                                     # neck
        else: idx = 0
        p.material_index = idx
    smooth(o)
    return o

# ===================================================================================== head & face
def head_mesh(rig, s, mats):
    j = rig.j; r = rig.head_r; c = j['head_c']
    o = prim('sphere', 'Head', r=1.0, u=40, v=28, material=mats['skin'])
    me = o.data
    for v in me.vertices:
        x, y, z = v.co
        # base proportions: a touch taller than wide, deeper at the back of the skull
        x *= 0.97; z *= 1.06
        if y > 0: y *= 1.05
        # jaw: narrow and pull forward below the cheekbones, round chin
        if z < -0.15:
            t = min(1.0, (-z - 0.15) / 0.85)
            x *= 1.0 - 0.2 * t
            if y < 0: y *= 1.0 - 0.12 * t
            z -= 0.08 * t
        # cheeks
        if -0.55 < z < 0.0 and y < -0.2: x *= 1.04
        # signature head shapes
        shape = s.get('face', {}).get('shape', 'round')
        if shape == 'egg':        # narrow crown, big round jowls (the Host)
            x *= 1.0 + 0.22 * max(0.0, -z) - 0.12 * max(0.0, z); y *= 1.0 + 0.1 * max(0.0, -z)
        elif shape == 'long':     # a long, lantern-jawed face (the Porter)
            z *= 1.22; x *= 0.86
        elif shape == 'heart':    # wide cheekbones, pointed chin (Mara)
            x *= 1.07 - 0.25 * max(0.0, -z - 0.3)
        elif shape == 'bean':     # wide and squashed (Pip)
            x *= 1.12; z *= 0.92
        elif shape == 'round':    # apple-round with full cheeks (Avery)
            x *= 1.04 + 0.06 * max(0.0, -z) * (1.0 - max(0.0, -z))
        # brow ridge and a flatter face plane
        if y < -0.55 and -0.1 < z < 0.45: y *= 0.94
        if y < -0.6 and 0.12 < z < 0.3: y -= 0.03
        # eye sockets
        for sx in (-1, 1):
            d = math.dist((x, z), (sx * 0.38, 0.12))
            if y < -0.6 and d < 0.22: y += 0.06 * (1 - d / 0.22)
        v.co = Vector((x, y, z)) * r + c
    subsurf(o, 1); apply_mods(o); smooth(o)
    parts = [o]
    face = s.get('face', {})
    # nose
    ns = face.get('nose', 1.0) * NOSE_K
    n = prim('sphere', 'Nose', r=1.0, u=16, v=12, material=mats['skin'])
    for v in n.data.vertices:
        x, y, z = v.co
        y *= 1.2 if y < 0 else 0.6
        if z < 0 and y < 0: y *= 1.1
        v.co = Vector((x * 0.85, y, z * 1.05)) * 0.022 * r / 0.135 * ns + c + V(0, -r * 0.99, -r * 0.12)
    parts.append(n)
    # ears
    es = face.get('ears', 1.0)
    for sx in (-1, 1):
        e = prim('sphere', 'Ear', r=1.0, u=14, v=10, material=mats['skin'])
        for v in e.data.vertices:
            x, y, z = v.co
            v.co = Vector((x * 0.38, y * 0.62, z * 0.9)) * 0.034 * es * r / 0.135 + c + V(sx * r * 0.98, r * 0.05, -r * 0.02)
        parts.append(e)
    # eyes: white ball + iris disc (UV-mapped) ; lids are separate (bones)
    eye_s = face.get('eye_size', 1.0) * EYE_K
    eye_r = 0.03 * r / 0.135 * eye_s
    eyes = []
    for sx, side in ((1, 'L'), (-1, 'R')):
        ec = c + V(sx * r * 0.37, -r * 0.8, r * 0.13)
        ball = prim('sphere', 'Eye.' + side, r=eye_r, u=20, v=14, material=mats['eye'], loc=ec)
        ball.scale = (1.0, 0.62, 1.15); bake_xform(ball)
        iris = iris_disc('Iris.' + side, eye_r * 0.58, mats['iris'], ec + V(0, -eye_r * 0.62 - 0.0008, 0))
        lid = prim('sphere', 'Lid.' + side, r=eye_r * 1.12, u=20, v=10, material=mats['skin'], loc=ec)
        # keep the upper hemisphere only (a shell that rotates down to blink)
        bm = bmesh.new(); bm.from_mesh(lid.data)
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < -0.0001], context='VERTS')
        bm.to_mesh(lid.data); bm.free()
        lid.scale = (1.05, 0.7, 1.2); bake_xform(lid)
        R = Matrix.Translation(ec) @ Matrix.Rotation(-0.75, 4, 'X') @ Matrix.Translation(-ec)
        lid.data.transform(R)
        rim = []
        for k in range(9):
            a = math.pi + math.pi * k / 8.0
            pnt = V(math.cos(a) * eye_r * 1.12 * 1.05, math.sin(a) * eye_r * 1.12 * 0.7, 0.0) + ec
            rim.append(R @ pnt)
        liner = tube('Liner.' + side, rim, eye_r * 0.085, mats['brow'], r_end=eye_r * 0.05)
        eyes.append((side, ec, ball, iris, lid, liner))
        if face.get('lashes'):
            lash = tube('Lash.' + side, [ec + V(-sx * eye_r * 0.9, -eye_r * 0.6, eye_r * 0.7), ec + V(0, -eye_r * 0.75, eye_r * 1.05), ec + V(sx * eye_r * 1.2, -eye_r * 0.5, eye_r * 0.9)], eye_r * 0.09, mats['brow'])
            eyes[-1] = eyes[-1] + (lash,)   # weighted to the lid with the liner
    # brows
    brows = []
    for sx, side in ((1, 'L'), (-1, 'R')):
        bc = c + V(sx * r * 0.39, -r * 0.84, r * 0.56)
        bw_ = face.get('brow_w', 1.0)
        tilt = face.get('brow_tilt', 0.0)   # + = permanently worried (inner ends up)
        b = tube('Brow.' + side, [bc + V(-sx * r * 0.16, 0.0, -r * 0.02 + tilt * r * 0.12), bc + V(0, -r * 0.03, r * 0.02), bc + V(sx * r * 0.18, r * 0.02, -r * 0.03 - tilt * r * 0.1)], r * 0.035 * bw_, mats['brow'], r_end=r * 0.02 * bw_)
        brows.append((side, bc, b))
    # mouths (one visible at a time, toggled in-game)
    mc = c + V(0, -r * 0.92, -r * 0.42)
    mouths = {}
    mouths['neutral'] = tube('Mouth_neutral', [mc + V(-r * 0.2, 0.004, 0.0), mc + V(0, -0.003, -0.004), mc + V(r * 0.2, 0.004, 0.0)], r * 0.028, mats['lip'])
    mouths['smile'] = tube('Mouth_smile', [mc + V(-r * 0.24, 0.01, r * 0.07), mc + V(-r * 0.1, -0.004, -r * 0.03), mc + V(0, -0.006, -r * 0.05), mc + V(r * 0.1, -0.004, -r * 0.03), mc + V(r * 0.24, 0.01, r * 0.07)], r * 0.03, mats['lip'])
    mouths['frown'] = tube('Mouth_frown', [mc + V(-r * 0.2, 0.01, -r * 0.06), mc + V(0, -0.004, r * 0.03), mc + V(r * 0.2, 0.01, -r * 0.06)], r * 0.028, mats['lip'])
    op = prim('sphere', 'Mouth_open', r=r * 0.11, u=16, v=10, material=mats['mouth'], loc=mc + V(0, 0.0, -r * 0.03)); op.scale = (1.0, 0.4, 0.85); bake_xform(op); mouths['open'] = op
    oo = prim('sphere', 'Mouth_o', r=r * 0.07, u=14, v=10, material=mats['mouth'], loc=mc + V(0, 0.0, -r * 0.02)); oo.scale = (1.0, 0.4, 1.15); bake_xform(oo); mouths['o'] = oo
    gr = prim('sphere', 'Mouth_grin', r=r * 0.15, u=16, v=10, material=mats['mouth'], loc=mc + V(0, 0.0, -r * 0.02)); gr.scale = (1.2, 0.35, 0.55)
    bm = bmesh.new(); bm.from_mesh(gr.data); bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z > 0.02 * r], context='VERTS'); bm.to_mesh(gr.data); bm.free(); bake_xform(gr)
    teeth = prim('cube', 'Mouth_grin_teeth', material=mats['teeth'], loc=mc + V(0, -r * 0.045, -r * 0.035)); teeth.scale = (r * 0.13, r * 0.01, r * 0.025); bake_xform(teeth)
    mouths['grin'] = gr; mouths['grin_teeth'] = teeth
    if face.get('freckles'):
        for i in range(12):
            sx = 1 if i % 2 else -1
            f = prim('sphere', 'Freckle', r=r * 0.018, u=6, v=4, material=mats['freckle'], loc=c + V(sx * r * (0.22 + (i % 5) * 0.06), -r * 0.92 + (i % 5) * 0.012, -r * 0.05 - (i % 3) * r * 0.06))
            f.scale = (1, 0.3, 1); bake_xform(f); parts.append(f)
    if face.get('blush'):
        for sx in (-1, 1):
            bl = prim('sphere', 'Blush', r=r * 0.12, u=12, v=8, material=mats['blush'], loc=c + V(sx * r * 0.55, -r * 0.78, -r * 0.22)); bl.scale = (1, 0.25, 0.7); bake_xform(bl); parts.append(bl)
    if face.get('moustache'):
        style = face['moustache']
        for sx in (-1, 1):
            if style == 'curl':      # a magnificent handlebar that curls back on itself
                pts = [mc + V(0, -r * 0.05, r * 0.14), mc + V(sx * r * 0.22, -r * 0.04, r * 0.08), mc + V(sx * r * 0.46, -r * 0.0, r * 0.1), mc + V(sx * r * 0.62, r * 0.04, r * 0.3), mc + V(sx * r * 0.55, r * 0.05, r * 0.45), mc + V(sx * r * 0.44, r * 0.04, r * 0.36)]
                m = tube('Moustache', pts, r * 0.075, mats['hair'], r_end=r * 0.018)
            elif style == 'droopy':  # long and mournful, past the chin
                pts = [mc + V(0, -r * 0.05, r * 0.13), mc + V(sx * r * 0.2, -r * 0.04, r * 0.07), mc + V(sx * r * 0.3, -r * 0.02, -r * 0.18), mc + V(sx * r * 0.33, r * 0.0, -r * 0.5)]
                m = tube('Moustache', pts, r * 0.045, mats['hair'], r_end=r * 0.015)
            else:
                big = style == 'big'
                m = tube('Moustache', [mc + V(0, -0.006, r * 0.13), mc + V(sx * r * 0.22, -0.004, r * 0.08), mc + V(sx * r * 0.42, 0.01, r * 0.14), mc + V(sx * r * 0.48, 0.02, r * 0.28)], r * (0.08 if big else 0.045), mats['hair'], r_end=r * 0.02)
            parts.append(m)
    if face.get('mole'):
        mo = prim('sphere', 'BeautyMark', r=r * 0.035, u=8, v=6, material=mats['mouth'], loc=c + V(r * 0.33, -r * 0.9, -r * 0.3)); mo.scale = (1, 0.4, 1); bake_xform(mo); parts.append(mo)
    if face.get('sideburns'):
        for sx in (-1, 1):
            sb = prim('sphere', 'Sideburn', r=r * 0.2, u=12, v=10, material=mats['hair'], loc=c + V(sx * r * 0.92, -r * 0.25, -r * 0.2)); sb.scale = (0.35, 0.8, 1.4); bake_xform(sb); parts.append(sb)
    return parts, eyes, brows, mouths

def iris_disc(name, radius, material, center):
    bm = bmesh.new()
    ring = []
    cverts = bm.verts.new(center)
    for i in range(24):
        a = math.tau * i / 24
        ring.append(bm.verts.new(center + V(math.cos(a) * radius, 0, math.sin(a) * radius)))
    for i in range(24): bm.faces.new((cverts, ring[(i + 1) % 24], ring[i]))
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    o = new_obj(name, me); o.data.materials.append(material)
    uv = o.data.uv_layers.new()
    for loop in o.data.loops:
        co = o.data.vertices[loop.vertex_index].co - center
        uv.data[loop.index].uv = (0.5 + co.x / radius * 0.5, 0.5 + co.z / radius * 0.5)
    return o

# ===================================================================================== hands & feet
def hand_mesh(rig, side, s, material):
    j = rig.j; H = rig.H; sx = 1 if side == 'L' else -1
    w = j['wrist.' + side]; d = (j['hand_end.' + side] - w).normalized()
    side_v = V(0, 1, 0).cross(d).normalized() * sx  # across the palm
    fwd = d.cross(side_v).normalized()
    sc = H * (0.8 if s.get('child') else 1.0) * HAND_K
    verts, edges, radii = [], [], []
    def add(p, r): verts.append(tuple(p)); radii.append((r, r * 0.7)); return len(verts) - 1
    wi = add(w, 0.028 * sc)
    palm = add(w + d * 0.05 * sc, 0.036 * sc)
    edges.append((wi, palm))
    for f in range(4):
        base = w + d * 0.085 * sc + side_v * (f - 1.5) * 0.017 * sc
        l = (0.052 - abs(f - 1.5) * 0.006) * sc
        k1 = add(base, 0.0095 * sc); k2 = add(base + d * l * 0.55, 0.0085 * sc); tip = add(base + d * l, 0.007 * sc)
        edges += [(palm, k1), (k1, k2), (k2, tip)]
    tb = w + d * 0.035 * sc - side_v * 0.03 * sc + fwd * 0.012 * sc
    t1 = add(tb, 0.011 * sc); t2 = add(tb + (d * 0.5 - side_v * 0.6 + fwd * 0.4).normalized() * 0.04 * sc, 0.009 * sc)
    edges += [(palm, t1), (t1, t2)]
    me = bpy.data.meshes.new('Hand.' + side); me.from_pydata(verts, edges, []); me.update()
    o = new_obj('Hand.' + side, me)
    sk = o.modifiers.new('skin', 'SKIN'); sk.use_smooth_shade = True
    for i, (rx, ry) in enumerate(radii): o.data.skin_vertices[0].data[i].radius = (rx, ry)
    o.data.skin_vertices[0].data[wi].use_root = True
    subsurf(o, 2); apply_mods(o)
    o.data.materials.append(material); smooth(o)
    return o

def boot_mesh(rig, side, s, material, sole):
    j = rig.j; H = rig.H * BOOT_K
    a = j['ankle.' + side]
    b = prim('sphere', 'Boot.' + side, r=1.0, u=24, v=16, material=material)
    for v in b.data.vertices:
        x, y, z = v.co
        if y < 0: y = (y * 0.14 - 0.03) * BOOT_K   # long, round toe box
        else: y = y * 0.07 * BOOT_K
        if z < 0: z *= 0.55                    # flat underside
        x *= 0.058 * BOOT_K * (1.0 - 0.25 * max(0.0, -y / 0.17))  # toe tapers
        v.co = Vector((x, y, z * 0.06 * BOOT_K)) + a + V(0, -0.015 * H, -0.045 * H)
    shaft = prim('cyl', 'BootShaft.' + side, r1=0.056 * H, r2=0.05 * H, depth=0.16 * H, seg=24, material=material, loc=a + V(0, 0.005, 0.035 * H))
    so = prim('cube', 'Sole.' + side, material=sole, loc=a + V(0, -0.055 * H, -0.08 * H)); so.scale = (0.1 * H, 0.215 * H, 0.016 * H); bake_xform(so)
    bv = so.modifiers.new('bev', 'BEVEL'); bv.width = 0.006; bv.segments = 2; apply_mods(so)
    heel = prim('cube', 'Heel.' + side, material=sole, loc=a + V(0, 0.03 * H, -0.075 * H)); heel.scale = (0.07 * H, 0.06 * H, 0.03 * H); bake_xform(heel)
    return [b, shaft, so, heel]

# ===================================================================================== hair (metaballs)
def hair_mesh(rig, s, material):
    style = s.get('hair', {}).get('style', 'none')
    if style == 'none': return []
    c = rig.j['head_c']; r = rig.head_r
    mb = bpy.data.metaballs.new('HairBalls'); mb.resolution = 0.006 * (r / 0.135); mb.render_resolution = mb.resolution
    o = new_obj('Hair', mb)
    def ball(x, y, z, rad, sx=1.0, sy=1.0, sz=1.0, kind='ELLIPSOID'):
        e = mb.elements.new(); e.type = kind; e.co = (c + V(x, y, z) * r); e.radius = rad * r * 1.74
        e.size_x, e.size_y, e.size_z = sx, sy, sz
        e.stiffness = 2.0
    cap = lambda: [ball(0, 0.12, 0.3, 0.9, 1.05, 1.05, 0.92), ball(0, 0.38, 0.0, 0.86, 1.05, 0.9, 1.0)]
    if style == 'tousled':
        cap()
        for x, y, z, rad in [(0.42, -0.6, 0.72, 0.3), (0.05, -0.66, 0.8, 0.32), (-0.38, -0.58, 0.7, 0.28), (0.78, -0.2, 0.05, 0.36), (-0.8, -0.2, 0.05, 0.36), (0.62, 0.15, -0.38, 0.34), (-0.62, 0.15, -0.38, 0.34), (0.0, 0.58, -0.45, 0.48), (0.3, 0.0, 0.98, 0.26)]:
            ball(x, y, z, rad)
        ball(0.15, -0.5, 0.85, 0.22, 1.0, 1.0, 1.6)  # cowlick
    elif style == 'puff':
        ball(0, 0.15, 0.3, 0.92, 1.05, 1.0, 0.85)
        for i in range(14):
            a = i / 14 * math.tau
            ball(math.cos(a) * 0.62, 0.22 + math.sin(a) * 0.55, 1.0 + math.sin(i * 1.7) * 0.12, 0.42)
        ball(0, 0.22, 1.25, 0.58)
        for sx in (-1, 1): ball(sx * 0.86, -0.42, 0.05, 0.1, 1, 1, 2.0)
    elif style == 'slick':
        ball(0, 0.1, 0.32, 0.95, 1.05, 1.08, 0.82); ball(0, 0.4, -0.05, 0.85, 1.05, 0.85, 1.0)
        ball(0.25, -0.5, 0.72, 0.4, 1.6, 0.8, 0.5)
    elif style == 'short':
        cap(); ball(0.3, -0.55, 0.65, 0.4, 1.4, 1.0, 0.6); ball(-0.25, -0.55, 0.7, 0.36, 1.3, 1.0, 0.6)
    elif style == 'ponytail':
        cap(); ball(0, -0.6, 0.65, 0.42, 1.6, 1.0, 0.6)
        for i, t in enumerate([0.0, 0.25, 0.5, 0.75]): ball(0, 1.05 + t * 0.15, 0.1 - t * 0.9, 0.38 - i * 0.05)
    elif style == 'fringe':
        for sx in (-1, 1): ball(sx * 0.85, 0.15, -0.05, 0.42, 0.6, 1.0, 1.1)
        ball(0, 0.75, -0.1, 0.6, 1.2, 0.8, 0.9)
    elif style == 'boy':
        cap(); ball(0.2, -0.6, 0.72, 0.38, 1.4, 1.0, 0.6)
    elif style == 'bob':      # cut at home with kitchen scissors: blunt fringe, straight sides
        cap()
        ball(0, -0.62, 0.52, 0.5, 1.7, 0.42, 0.48)                     # the fringe, cut dead straight above the glasses
        for sx in (-1, 1):
            ball(sx * 0.84, -0.05, -0.18, 0.44, 0.48, 1.05, 1.45)      # side curtains to the jaw
            ball(sx * 0.72, 0.42, -0.3, 0.42, 0.6, 0.9, 1.3)
        ball(0, 0.62, -0.32, 0.5, 1.2, 0.7, 1.2)
        ball(0.3, -0.05, 0.98, 0.09, 1.0, 1.3, 1.3)                     # one curl that will not lie down
    elif style == 'curls':    # big stage curls, three ringlets over the forehead (she counts in threes)
        ball(0, 0.15, 0.3, 0.95, 1.08, 1.05, 0.92)
        for i in range(22):
            a = i / 22 * math.tau; h = (i % 3) * 0.28
            ball(math.cos(a) * 0.92, 0.18 + math.sin(a) * 0.85, 0.2 + h + 0.25 * math.sin(i * 2.3), 0.3)
        for k in range(9):
            a = k / 9 * math.tau
            ball(math.cos(a) * 0.45, 0.2 + math.sin(a) * 0.42, 0.95, 0.32)
        for k, x in enumerate((-0.3, 0.0, 0.3)):
            ball(x, -0.78, 0.62 - k * 0.04 * (k - 1), 0.13, 1.0, 1.0, 1.7)
    elif style == 'updo':
        cap(); ball(0, 0.55, 1.0, 0.55); ball(0, 0.65, 0.85, 0.45)
        for sx in (-1, 1): ball(sx * 0.82, -0.3, -0.2, 0.16, 1, 1, 2.0)
    bpy.ops.object.select_all(action='DESELECT')
    bpy.context.view_layer.objects.active = o; o.select_set(True)
    bpy.ops.object.convert(target='MESH')
    o = bpy.context.view_layer.objects.active
    o.select_set(False)
    o.name = 'Hair'
    tex = bpy.data.textures.new('HairGrooves', 'MARBLE'); tex.marble_type = 'SHARPER'; tex.noise_basis_2 = 'SAW'
    tex.noise_scale = 0.35 * r; tex.turbulence = 3.0; tex.noise_depth = 2
    disp = o.modifiers.new('grooves', 'DISPLACE'); disp.texture = tex; disp.texture_coords = 'OBJECT'; disp.strength = 0.035 * r; disp.mid_level = 0.6
    apply_mods(o)
    dec = o.modifiers.new('dec', 'DECIMATE'); dec.ratio = 0.5
    apply_mods(o)
    o.data.materials.clear(); o.data.materials.append(material); smooth(o)
    out = [o]
    if style == 'puff':
        band = prim('torus', 'HairBand', R=r * 0.55, rr=r * 0.08, material=s['_mats']['band'], loc=c + V(0, r * 0.2, r * 1.08)); bake_xform(band); out.append(band)
    if style == 'ponytail':
        tie = prim('torus', 'HairTie', R=r * 0.2, rr=r * 0.06, material=s['_mats']['band'], loc=c + V(0, r * 1.08, r * 0.15), rot=(math.pi / 2, 0, 0)); bake_xform(tie); out.append(tie)
    return out

# ===================================================================================== clothing
def clothing(rig, s, mats):
    j = rig.j; H = rig.H; bw = rig.bw
    o = s['outfit']; t = o['type']
    parts = []
    waist_r = 0.135 * bw * H * (1.18 if s.get('build') == 'round' else 1.0)
    chest_r = 0.165 * bw * H
    front_y = -0.11 * bw * H
    if t in ('coat',):
        L = o.get('skirt_len', 0.52) * H
        prof = [(waist_r * 1.02, 0), (waist_r * 1.14, -0.12 * H), (waist_r * 1.38, -L * 0.6), (waist_r * 1.62, -L)]
        sk = lathe('Skirt', prof, mats['torso'], 40, loc=j['spine'] + V(0, 0, -0.02 * H), open_front=0.55)
        sk.scale = (1.0, 0.85, 1.0); bake_xform(sk)
        so = sk.modifiers.new('solid', 'SOLIDIFY'); so.thickness = 0.012 * H; so.offset = 1.0
        subsurf(sk, 1); apply_mods(sk); parts.append(('skirt', sk))
        col = lathe('Collar', [(0.075 * H, -0.02 * H), (0.088 * H, 0.03 * H), (0.11 * H, 0.08 * H), (0.12 * H, 0.085 * H)], mats['torso'], 32, loc=j['neck'] + V(0, 0.005, -0.06 * H), open_front=0.9)
        so = col.modifiers.new('solid', 'SOLIDIFY'); so.thickness = 0.008 * H; apply_mods(col); parts.append(('chest', col))
        for sx in (-1, 1):
            lp = prim('cube', 'Lapel', material=mats['second'], loc=j['chest'] + V(sx * 0.07 * H, front_y * 1.02, 0.12 * H), rot=(0.15, sx * 0.3, sx * 0.32)); lp.scale = (0.07 * H, 0.012 * H, 0.2 * H); bake_xform(lp); parts.append(('chest', lp))
            pk = prim('cube', 'Pocket', material=mats['torso'], loc=j['spine'] + V(sx * 0.15 * H, -waist_r * 1.18, -0.2 * H), rot=(-0.12, 0, sx * 0.05)); pk.scale = (0.1 * H, 0.012 * H, 0.11 * H); bake_xform(pk); parts.append(('skirt', pk))
        belt = prim('cyl', 'Belt', r1=waist_r * 1.06, r2=waist_r * 1.06, depth=0.05 * H, seg=36, material=mats['belt'], loc=j['spine'] + V(0, 0, -0.04 * H)); belt.scale = (1, 0.78, 1); bake_xform(belt); parts.append(('spine', belt))
        bu = prim('cube', 'Buckle', material=mats['trim'], loc=j['spine'] + V(0, -waist_r * 0.82, -0.04 * H)); bu.scale = (0.05 * H, 0.01 * H, 0.045 * H); bake_xform(bu); parts.append(('spine', bu))
        for i in range(3):
            b = prim('cyl', 'Button', r1=0.011 * H, r2=0.011 * H, depth=0.008 * H, seg=12, material=mats['button'], loc=j['chest'] + V(-0.075 * H, front_y * 1.05, 0.12 * H - i * 0.07 * H), rot=(math.pi / 2, 0, 0)); bake_xform(b); parts.append(('chest', b))
        for side in ('L', 'R'):
            cu = prim('torus', 'Cuff', R=0.046 * H, rr=0.016 * H, material=mats['second'], loc=j['wrist.' + side] + (j['elbow.' + side] - j['wrist.' + side]).normalized() * 0.04 * H)
            cu.rotation_euler = (0, (1 if side == 'L' else -1) * A_POSE, 0); bake_xform(cu); parts.append(('forearm.' + side, cu))
        if o.get('hood'):
            hd = prim('sphere', 'HoodDown', r=0.12 * H, u=16, v=12, material=mats['torso'], loc=j['chest'] + V(0, 0.15 * H, 0.28 * H)); hd.scale = (1.2, 0.6, 0.7); bake_xform(hd); parts.append(('chest', hd))
    elif t == 'tailcoat':
        col = lathe('Collar', [(0.07 * H, -0.01 * H), (0.085 * H, 0.05 * H), (0.1 * H, 0.07 * H)], mats['torso'], 32, loc=j['neck'] + V(0, 0.01, -0.06 * H), open_front=1.1)
        so = col.modifiers.new('solid', 'SOLIDIFY'); so.thickness = 0.008 * H; apply_mods(col); parts.append(('chest', col))
        for sx in (-1, 1):
            lp = prim('cube', 'Lapel', material=mats['lapel'], loc=j['chest'] + V(sx * 0.07 * H, front_y * 1.03, 0.12 * H), rot=(0.12, sx * 0.38, sx * 0.28)); lp.scale = (0.075 * H, 0.014 * H, 0.24 * H); bake_xform(lp); parts.append(('chest', lp))
            # tails: tapered panels hanging behind
            tl = prim('cube', 'Tail', material=mats['torso'], loc=j['hips'] + V(sx * 0.075 * H, 0.1 * H, -0.24 * H), rot=(-0.12, 0, sx * 0.06))
            tl.scale = (0.13 * H, 0.025 * H, 0.55 * H)
            bm = bmesh.new(); bm.from_mesh(tl.data)
            for v in bm.verts:
                if v.co.z < 0: v.co.x *= 0.45
            bm.to_mesh(tl.data); bm.free(); bake_xform(tl)
            subsurf(tl, 1); apply_mods(tl); parts.append(('tails', tl))
        vest = lathe('Vest', [(waist_r * 1.03, -0.12 * H), (waist_r * 1.05, 0.0), (chest_r * 1.01, 0.16 * H), (chest_r * 0.95, 0.24 * H)], mats['vest'], 32, loc=j['spine'], open_front=math.pi * 1.1, scale=(1, 0.74, 1))
        vest.rotation_euler = (0, 0, math.pi); bake_xform(vest)
        bm = bmesh.new(); bm.from_mesh(vest.data)
        cut = [v for v in bm.verts if v.co.y < 0 and abs(v.co.x) < (v.co.z - (j['spine'].z + 0.04 * H)) * 0.55]
        bmesh.ops.delete(bm, geom=cut, context='VERTS'); bm.to_mesh(vest.data); bm.free()
        so = vest.modifiers.new('solid', 'SOLIDIFY'); so.thickness = 0.008 * H; so.offset = 1.0; apply_mods(vest); parts.append(('spine', vest))
        for i in range(3):
            b = prim('cyl', 'Button', r1=0.008 * H, r2=0.008 * H, depth=0.006 * H, seg=10, material=mats['trim'], loc=j['spine'] + V(0, front_y * 1.06, 0.13 * H - i * 0.05 * H), rot=(math.pi / 2, 0, 0)); bake_xform(b); parts.append(('spine', b))
        shirt = prim('cube', 'ShirtFront', material=mats['shirt'], loc=j['chest'] + V(0, front_y * 0.98, 0.12 * H), rot=(0.12, 0, 0)); shirt.scale = (0.075 * H, 0.01 * H, 0.13 * H); bake_xform(shirt); parts.append(('chest', shirt))
        for side in ('L', 'R'):
            cu = prim('torus', 'Cuff', R=0.044 * H, rr=0.01 * H, material=mats['shirt'], loc=j['wrist.' + side] + (j['elbow.' + side] - j['wrist.' + side]).normalized() * 0.02 * H)
            cu.rotation_euler = (0, (1 if side == 'L' else -1) * A_POSE, 0); bake_xform(cu); parts.append(('forearm.' + side, cu))
    elif t == 'uniform':
        col = prim('cyl', 'HighCollar', r1=0.072 * H, r2=0.078 * H, depth=0.07 * H, seg=28, material=mats['torso'], loc=j['neck'] + V(0, 0, -0.005 * H)); parts.append(('neck', col))
        gb = prim('torus', 'CollarBand', R=0.076 * H, rr=0.006 * H, material=mats['trim'], loc=j['neck'] + V(0, 0, 0.03 * H)); parts.append(('neck', gb))
        for sx in (-1, 1):
            for i in range(4):
                b = prim('sphere', 'Button', r=0.012 * H, u=10, v=6, material=mats['trim'], loc=j['chest'] + V(sx * 0.06 * H, front_y * 1.06, 0.2 * H - i * 0.065 * H)); parts.append(('chest', b))
        sk = lathe('Skirt', [(waist_r * 1.02, 0), (waist_r * 1.1, -0.1 * H), (waist_r * 1.22, -0.22 * H)], mats['torso'], 36, loc=j['spine'] + V(0, 0, -0.02 * H))
        sk.scale = (1, 0.82, 1); bake_xform(sk); so = sk.modifiers.new('solid', 'SOLIDIFY'); so.thickness = 0.01 * H; apply_mods(sk); parts.append(('skirt', sk))
    elif t == 'jacket':
        col = lathe('Collar', [(0.07 * H, -0.01 * H), (0.09 * H, 0.06 * H), (0.115 * H, 0.09 * H)], mats['torso'], 32, loc=j['neck'] + V(0, 0.01, -0.06 * H), open_front=1.0)
        so = col.modifiers.new('solid', 'SOLIDIFY'); so.thickness = 0.008 * H; apply_mods(col); parts.append(('chest', col))
        pep = lathe('Peplum', [(waist_r * 1.02, 0), (waist_r * 1.25, -0.1 * H), (waist_r * 1.45, -0.16 * H)], mats['torso'], 36, loc=j['spine'] + V(0, 0, -0.06 * H), open_front=0.6)
        pep.scale = (1, 0.82, 1); bake_xform(pep); so = pep.modifiers.new('solid', 'SOLIDIFY'); so.thickness = 0.01 * H; apply_mods(pep); parts.append(('skirt', pep))
        for sx in (-1, 1):
            tr = tube('Trim', [j['chest'] + V(sx * 0.03 * H, front_y * 1.05, 0.26 * H), j['chest'] + V(sx * 0.06 * H, front_y * 1.08, 0.08 * H), j['spine'] + V(sx * 0.07 * H, front_y * 1.0, -0.08 * H)], 0.006 * H, mats['trim'])
            parts.append(('chest', tr))
        band = prim('torus', 'WaistTrim', R=waist_r * 1.03, rr=0.007 * H, material=mats['trim'], loc=j['spine'] + V(0, 0, -0.1 * H)); band.scale = (1, 0.78, 1); bake_xform(band); parts.append(('spine', band))
    elif t == 'waistcoat':
        for i in range(4):
            b = prim('cyl', 'Button', r1=0.009 * H, r2=0.009 * H, depth=0.006 * H, seg=10, material=mats['trim'], loc=j['spine'] + V(0, front_y * 1.06, 0.27 * H - i * 0.055 * H), rot=(math.pi / 2, 0, 0)); bake_xform(b); parts.append(('spine', b))
        vee = prim('cube', 'ShirtVee', material=mats['shirt'], loc=j['chest'] + V(0, front_y * 1.02, 0.2 * H), rot=(0.1, 0, 0)); vee.scale = (0.08 * H, 0.01 * H, 0.12 * H); bake_xform(vee); parts.append(('chest', vee))
        for side in ('L', 'R'):
            cu = prim('torus', 'RolledSleeve', R=0.05 * H, rr=0.016 * H, material=mats['shirt'], loc=(j['elbow.' + side] * 0.7 + j['wrist.' + side] * 0.3))
            cu.rotation_euler = (0, (1 if side == 'L' else -1) * A_POSE, 0); bake_xform(cu); parts.append(('forearm.' + side, cu))
    elif t in ('gown', 'robe'):
        L = j['hips'].z + 0.02 * H
        if t == 'gown':
            prof = [(waist_r * 0.92, 0.0), (waist_r * 1.5, -0.12 * H), (0.3 * H, -L * 0.45), (0.42 * H, -L * 0.85), (0.45 * H, -L), (0.001, -L)]
        else:
            prof = [(0.2 * H, 0.32 * H), (0.24 * H, 0.0), (0.32 * H, -L * 0.5), (0.42 * H, -L), (0.001, -L)]
        g = lathe('Skirt', prof, mats['torso'] if t == 'robe' else mats['legs'], 48, loc=j['spine'] + V(0, 0, 0.02 * H))
        subsurf(g, 1); apply_mods(g); parts.append(('skirt', g))
        hem = prim('torus', 'Hem', R=0.44 * H, rr=0.018 * H, material=mats['trim'], loc=j['spine'] + V(0, 0, -L + 0.06 * H)); parts.append(('skirt', hem))
        if t == 'robe':
            cape = lathe('Cape', [(0.12 * H, 0.42 * H), (0.28 * H, 0.26 * H), (0.33 * H, -0.05 * H)], mats['second'], 40, loc=j['chest'], open_front=1.6)
            so = cape.modifiers.new('solid', 'SOLIDIFY'); so.thickness = 0.01 * H; apply_mods(cape); parts.append(('chest', cape))
    elif t == 'pajamas':
        for i in range(6):
            st = prim('torus', 'Stripe', R=chest_r * 1.0 - i * 0.004, rr=0.006 * H, material=mats['second'], loc=j['spine'] + V(0, 0, -0.02 * H + i * 0.07 * H)); st.scale = (1, 0.72, 1); bake_xform(st); parts.append(('spine', st))
        for i in range(3):
            b = prim('cyl', 'Button', r1=0.01 * H, r2=0.01 * H, depth=0.006 * H, seg=10, material=mats['shirt'], loc=j['chest'] + V(0, front_y * 1.06, 0.18 * H - i * 0.07 * H), rot=(math.pi / 2, 0, 0)); bake_xform(b); parts.append(('chest', b))
    elif t == 'pageboy':
        for sx in (-1, 1):
            for i in range(3):
                b = prim('sphere', 'Button', r=0.01 * H, u=8, v=6, material=mats['trim'], loc=j['chest'] + V(sx * 0.04 * H, front_y * 1.05, 0.18 * H - i * 0.05 * H)); parts.append(('chest', b))
    return parts

def ghost_tail(rig, s, material):
    j = rig.j; H = rig.H
    L = j['hips'].z * 0.92
    wr = 0.135 * rig.bw * H
    t = lathe('Tail', [(wr * 1.18, 0.05 * H), (wr * 1.25, -0.1 * H), (wr * 1.0, -L * 0.45), (wr * 0.45, -L * 0.8), (0.02, -L), (0.001, -L * 1.02)], material, 32, loc=j['hips'])
    subsurf(t, 1); apply_mods(t)
    return t

# ===================================================================================== accessories
def accessories(rig, s, mats):
    j = rig.j; H = rig.H; c = j['head_c']; r = rig.head_r
    acc = s.get('acc', [])
    parts = []
    waist_r = 0.135 * rig.bw * H
    front_y = -0.11 * rig.bw * H
    if 'satchel' in acc:
        bag = prim('cube', 'Satchel', material=mats['leather'], loc=j['hips'] + V(0.2 * H, -0.02 * H, 0.0)); bag.scale = (0.2 * H, 0.07 * H, 0.16 * H); bag.rotation_euler = (0, 0.1, 0.2); bake_xform(bag)
        bv = bag.modifiers.new('bev', 'BEVEL'); bv.width = 0.012 * H; bv.segments = 3; apply_mods(bag); smooth(bag); parts.append(('hips', bag))
        flap = prim('cube', 'SatchelFlap', material=mats['leather_dark'], loc=j['hips'] + V(0.2 * H, -0.058 * H, 0.05 * H)); flap.scale = (0.205 * H, 0.012 * H, 0.08 * H); flap.rotation_euler = (0, 0.1, 0.2); bake_xform(flap); parts.append(('hips', flap))
        strap = tube('Strap', [j['hips'] + V(0.2 * H, -0.06 * H, 0.06 * H), j['spine'] + V(0.1 * H, -0.12 * H, 0.06 * H), j['chest'] + V(-0.06 * H, -0.13 * H, 0.15 * H), j['chest'] + V(-0.15 * H, -0.02 * H, 0.29 * H), j['chest'] + V(-0.1 * H, 0.1 * H, 0.27 * H), j['spine'] + V(0.08 * H, 0.12 * H, 0.0), j['hips'] + V(0.2 * H, 0.04 * H, 0.04 * H)], 0.011 * H, mats['leather'])
        parts.append(('chest', strap))
    if 'scarf' in acc:
        sc = prim('torus', 'Scarf', R=0.075 * H, rr=0.03 * H, material=mats['scarf'], loc=j['neck'] + V(0, -0.005, -0.01 * H), rot=(0.15, 0, 0)); bake_xform(sc); parts.append(('neck', sc))
        tl = prim('cube', 'ScarfTail', material=mats['scarf'], loc=j['chest'] + V(0.055 * H, front_y * 1.18, 0.06 * H), rot=(0.1, 0, 0.08)); tl.scale = (0.065 * H, 0.022 * H, 0.26 * H); bake_xform(tl)
        subsurf(tl, 1); apply_mods(tl); parts.append(('scarf', tl))
    if 'cap' in acc:
        capm = mats['cap']
        rb = rig.head_r; r = rb * s.get('cap_scale', 1.0)
        z0 = rb * 0.78   # the cap sits on the crown whatever its size
        top = prim('cyl', 'Cap', r1=r * 0.9, r2=r * 0.95, depth=r * 0.62, seg=32, material=capm, loc=c + V(0.01, 0.0, z0 + r * 0.31), rot=(0.06, -0.06, 0)); parts.append(('head', top))
        band = prim('cyl', 'CapBand', r1=r * 0.97, r2=r * 0.97, depth=r * 0.14, seg=32, caps=False, material=mats['trim'], loc=c + V(0.01, 0.0, z0 + r * 0.07), rot=(0.06, -0.06, 0)); parts.append(('head', band))
        peak = prim('cube', 'CapPeak', material=mats['black'], loc=c + V(0.01, -r * 0.82, z0), rot=(-0.25, 0, 0)); peak.scale = (r * 0.95, r * 0.5, r * 0.05); bake_xform(peak); parts.append(('head', peak))
        r = rig.head_r
    if 'tophat' in acc:   # tall, slightly tipped, with a band and a curled brim
        tilt = (0.12, -0.18, 0)
        th = prim('cyl', 'TopHat', r1=r * 0.6, r2=r * 0.66, depth=r * 1.25, seg=36, material=mats['black'], loc=c + V(r * 0.12, 0.0, r * 1.55), rot=tilt); parts.append(('head', th))
        hb = prim('cyl', 'HatBand', r1=r * 0.615, r2=r * 0.625, depth=r * 0.22, seg=36, caps=False, material=mats['trim'], loc=c + V(r * 0.08, 0.0, r * 1.08), rot=tilt); parts.append(('head', hb))
        br = prim('torus', 'HatBrim', R=r * 0.78, rr=r * 0.07, material=mats['black'], loc=c + V(r * 0.06, 0.0, r * 0.94), rot=tilt); br.scale = (1.0, 0.92, 0.6); bake_xform(br); parts.append(('head', br))
        bd = prim('cyl', 'HatBrimDisc', r1=r * 0.8, r2=r * 0.8, depth=r * 0.04, seg=36, material=mats['black'], loc=c + V(r * 0.06, 0.0, r * 0.94), rot=tilt); parts.append(('head', bd))
    if 'glasses' in acc:  # big round brass spectacles: you can't miss them
        ec_z = r * 0.13; ey = -r * 1.04
        for sx in (-1, 1):
            rim = prim('torus', 'Spectacle', R=r * 0.24, rr=r * 0.028, material=mats['brass'], loc=c + V(sx * r * 0.37, ey, ec_z), rot=(math.pi / 2, 0, 0)); bake_xform(rim); parts.append(('head', rim))
            arm = tube('SpecArm', [c + V(sx * r * 0.61, ey + r * 0.04, ec_z), c + V(sx * r * 0.92, -r * 0.5, ec_z + r * 0.02), c + V(sx * r * 0.98, r * 0.05, ec_z - r * 0.05)], r * 0.018, mats['brass']); parts.append(('head', arm))
        bridge = tube('SpecBridge', [c + V(-r * 0.14, ey, ec_z + r * 0.03), c + V(0, ey - r * 0.03, ec_z + r * 0.08), c + V(r * 0.14, ey, ec_z + r * 0.03)], r * 0.022, mats['brass']); parts.append(('head', bridge))
    if 'bigscarf' in acc:  # an enormous hand-knitted scarf, wound twice, tails flapping
        nz = j['neck'] + V(0, 0, 0.0)
        for k, (R_, dz) in enumerate(((r * 0.5, -r * 0.05), (r * 0.46, r * 0.1))):
            sc = prim('torus', 'BigScarf', R=R_, rr=r * 0.15, material=mats['scarf'], loc=nz + V(0, r * 0.02, dz), rot=(0.12 - k * 0.1, 0, 0)); sc.scale = (1.0, 0.9, 0.7); bake_xform(sc); parts.append(('neck', sc))
        for k, sx in enumerate((0.16, -0.05)):
            tail_c = j['chest'] + V(sx * r, -r * 0.42 - k * 0.02, -r * 0.05 - k * r * 0.12)
            tail_len = r * 0.95 - k * r * 0.2
            tl = prim('cube', 'BigScarfTail', material=mats['scarf'], loc=tail_c, rot=(0.18, 0, 0.12 - k * 0.2)); tl.scale = (r * 0.3, r * 0.08, tail_len); bake_xform(tl)
            subsurf(tl, 1); apply_mods(tl); parts.append(('scarf', tl))
            for f in range(5):
                fr = prim('cyl', 'Fringe', r1=r * 0.014, r2=r * 0.014, depth=r * 0.14, seg=6, material=mats['scarf'], loc=tail_c + V((f - 2) * r * 0.06 + (0.12 - k * 0.2) * tail_len * 0.5, -r * 0.08, -tail_len * 0.5 - r * 0.08)); parts.append(('scarf', fr))
    if 'feather' in acc:  # an ostrich plume tucked into the curls, nodding forward
        base = c + V(r * 0.55, r * 0.05, r * 1.05)
        pts = [base, base + V(r * 0.18, r * 0.1, r * 0.45), base + V(r * 0.1, r * 0.35, r * 0.85), base + V(-r * 0.2, r * 0.7, r * 1.0)]
        fe = tube('Feather', pts, r * 0.13, mats['feather'], r_end=r * 0.04, seg=18)
        bm = bmesh.new(); bm.from_mesh(fe.data)
        for v in bm.verts: v.co.y = base.y + (v.co.y - base.y) * 0.4    # flatten it into a plume, not a pipe
        bm.to_mesh(fe.data); bm.free(); parts.append(('head', fe))
        gem = prim('sphere', 'FeatherGem', r=r * 0.08, u=12, v=8, material=mats['gem'], loc=base); parts.append(('head', gem))
    if 'earrings' in acc:
        for sx in (-1, 1):
            hoop = prim('torus', 'Earring', R=r * 0.11, rr=r * 0.018, material=mats['gold'], loc=c + V(sx * r * 0.98, r * 0.02, -r * 0.32), rot=(0, math.pi / 2, 0)); bake_xform(hoop); parts.append(('head', hoop))
    if 'crown' in acc:
        cr = prim('cyl', 'CrownBand', r1=r * 0.82, r2=r * 0.78, depth=r * 0.36, seg=32, caps=False, material=mats['gold'], loc=c + V(0, 0, r * 1.0)); parts.append(('head', cr))
        for i in range(7):
            a = i / 7 * math.tau
            sp = prim('cyl', 'CrownSpike', r1=r * 0.13, r2=0.0, depth=r * 0.5, seg=8, material=mats['gold'], loc=c + V(math.cos(a) * r * 0.8, math.sin(a) * r * 0.8, r * 1.38)); parts.append(('head', sp))
            gem = prim('sphere', 'Gem', r=r * 0.07, u=10, v=6, material=mats['gem'], loc=c + V(math.cos(a) * r * 0.8, math.sin(a) * r * 0.8, r * 1.65)); parts.append(('head', gem))
    if 'mask' in acc or 'mask_full' in acc:
        full = 'mask_full' in acc
        mk = prim('sphere', 'Mask', r=r * 1.02, u=32, v=20, material=mats['mask_full' if full else 'mask'], loc=c)
        bm = bmesh.new(); bm.from_mesh(mk.data)
        kill = []
        for v in bm.verts:
            x, y, z = v.co            # mesh is local to the sphere's centre
            if y > -r * 0.45: kill.append(v); continue
            if not full and (z < -r * 0.05 or z > r * 0.48): kill.append(v); continue
            for sx in (-1, 1):
                if math.dist((x, z), (sx * r * 0.37, r * 0.13)) < r * 0.13: kill.append(v)
        bmesh.ops.delete(bm, geom=list(set(kill)), context='VERTS'); bm.to_mesh(mk.data); bm.free()
        so = mk.modifiers.new('solid', 'SOLIDIFY'); so.thickness = 0.006 * H; apply_mods(mk); parts.append(('head', mk))
        if not full:
            for sx in (-1, 1):
                pl = prim('cyl', 'Plume', r1=r * 0.06, r2=0.0, depth=r * 0.9, seg=8, material=mats['trim'], loc=c + V(sx * r * 0.75, -r * 0.6, r * 0.65), rot=(0, sx * -0.6, 0)); parts.append(('head', pl))
    if 'brooch' in acc:
        br = prim('cyl', 'Brooch', r1=0.022 * H, r2=0.022 * H, depth=0.008 * H, seg=10, material=mats['gold'], loc=j['chest'] + V(0.08 * H, front_y * 1.1, 0.22 * H), rot=(math.pi / 2, 0, 0)); bake_xform(br); parts.append(('chest', br))
    hand_l = j['hand_end.L']; hand_r = j['hand_end.R']
    if 'pencil' in acc:          # behind the right ear, where surveyors keep them
        pc = prim('cyl', 'Pencil', r1=r * 0.032, r2=r * 0.032, depth=r * 0.62, seg=6, material=mats['rule'], loc=c + V(-r * 1.0, r * 0.08, r * 0.18), rot=(math.pi / 2, 0.25, 0)); parts.append(('head', pc))
        tip = prim('cyl', 'PencilTip', r1=r * 0.032, r2=0.0, depth=r * 0.1, seg=6, material=mats['paper'], loc=c + V(-r * 1.0, -r * 0.27, r * 0.27), rot=(math.pi / 2, 0.25, 0)); parts.append(('head', tip))
        er = prim('cyl', 'Eraser', r1=r * 0.034, r2=r * 0.034, depth=r * 0.06, seg=8, material=mats['pink'], loc=c + V(-r * 1.0, r * 0.41, r * 0.1), rot=(math.pi / 2, 0.25, 0)); parts.append(('head', er))
    if 'folding_rule' in acc:    # a yellow carpenter's rule sticking out of the breast pocket
        for k in range(3):
            seg_ = prim('cube', 'Rule', material=mats['rule'], loc=j['chest'] + V(0.075 * H + k * 0.004, front_y * 1.2, 0.1 * H + k * 0.03 * H), rot=(0, 0.25 - k * 0.12, 0)); seg_.scale = (0.022 * H, 0.008 * H, 0.17 * H); bake_xform(seg_); parts.append(('chest', seg_))
    if 'tape' in acc:            # tape measure clipped to the belt
        tp = prim('cyl', 'TapeMeasure', r1=0.05 * H, r2=0.05 * H, depth=0.032 * H, seg=20, material=mats['rule'], loc=j['hips'] + V(-0.16 * H * rig.bw, -0.03 * H, 0.02 * H), rot=(0, math.pi / 2, 0)); bake_xform(tp); parts.append(('hips', tp))
        tc = prim('cyl', 'TapeCap', r1=0.02 * H, r2=0.02 * H, depth=0.035 * H, seg=12, material=mats['black'], loc=j['hips'] + V(-0.16 * H * rig.bw, -0.03 * H, 0.02 * H), rot=(0, math.pi / 2, 0)); bake_xform(tc); parts.append(('hips', tc))
    if 'wristwatch' in acc:      # worn over the coat cuff: never once late
        w = j['wrist.L'] + (j['elbow.L'] - j['wrist.L']).normalized() * 0.05 * H
        d = (j['wrist.L'] - j['elbow.L']).normalized()
        bd = prim('torus', 'WatchBand', R=0.045 * H, rr=0.012 * H, material=mats['leather_dark'], loc=w); bd.rotation_euler = d.to_track_quat('Z', 'Y').to_euler(); bake_xform(bd); parts.append(('forearm.L', bd))
        fc = prim('cyl', 'WatchFace', r1=0.04 * H, r2=0.04 * H, depth=0.016 * H, seg=20, material=mats['brass'], loc=w + V(0, -0.05 * H, 0)); fc.rotation_euler = (math.pi / 2, 0, 0); bake_xform(fc); parts.append(('forearm.L', fc))
        gl = prim('cyl', 'WatchGlass', r1=0.032 * H, r2=0.032 * H, depth=0.004 * H, seg=20, material=mats['cream'], loc=w + V(0, -0.059 * H, 0)); gl.rotation_euler = (math.pi / 2, 0, 0); bake_xform(gl); parts.append(('forearm.L', gl))
    if 'cuffs' in acc:           # sleeves rolled back twice
        for side in ('L', 'R'):
            mid = j['elbow.' + side] * 0.35 + j['wrist.' + side] * 0.65; d = (j['wrist.' + side] - j['elbow.' + side]).normalized()
            cf = prim('torus', 'Cuff', R=0.06 * H, rr=0.024 * H, material=mats['torso'], loc=mid); cf.rotation_euler = d.to_track_quat('Z', 'Y').to_euler(); bake_xform(cf); parts.append(('forearm.' + side, cf))
    if 'bangles' in acc:         # three, always three
        for k in range(3):
            pnt = j['wrist.R'] + (j['elbow.R'] - j['wrist.R']).normalized() * (0.02 + k * 0.022) * H; d = (j['wrist.R'] - j['elbow.R']).normalized()
            bg = prim('torus', 'Bangle', R=0.05 * H, rr=0.008 * H, material=mats['gold'], loc=pnt); bg.rotation_euler = d.to_track_quat('Z', 'Y').to_euler(); bake_xform(bg); parts.append(('forearm.R', bg))
    if 'stage_shoulders' in acc: # puffed theatrical shoulders
        for side in ('L', 'R'):
            sp_ = prim('sphere', 'PuffShoulder', r=0.085 * H, u=16, v=10, material=mats['sequin'] if side == 'R' else mats['torso'], loc=j['shoulder.' + side] + V(0, 0, 0.02 * H)); sp_.scale = (1.15, 1.0, 0.85); bake_xform(sp_); parts.append(('shoulder.' + side, sp_))
    if 'hanger' in acc:          # the empty coat hanger he never puts down
        a0 = j['elbow.L'] + V(0, -0.02 * H, 0.0)
        hk = tube('Hanger', [a0 + V(-0.16 * H, -0.02, -0.1 * H), a0 + V(0, -0.02, 0.0), a0 + V(0.16 * H, -0.02, -0.1 * H), a0 + V(-0.16 * H, -0.02, -0.1 * H)], 0.008 * H, mats['leather'])
        parts.append(('upper_arm.L', hk))
        hh = tube('HangerHook', [a0, a0 + V(0, -0.02, 0.06 * H), a0 + V(0.03 * H, -0.02, 0.08 * H), a0 + V(0.05 * H, -0.02, 0.05 * H)], 0.006 * H, mats['brass']); parts.append(('upper_arm.L', hh))
    if 'ticket' in acc:          # coat-check ticket tucked into the cap band
        tk = prim('cube', 'Ticket', material=mats['cream'], loc=c + V(r * 0.55, -r * 0.65, r * 0.95), rot=(0.1, 0.0, -0.35)); tk.scale = (r * 0.2, r * 0.02, r * 0.32); bake_xform(tk); parts.append(('head', tk))
        st_ = prim('cube', 'TicketStripe', material=mats['red'], loc=c + V(r * 0.55, -r * 0.67, r * 1.02), rot=(0.1, 0.0, -0.35)); st_.scale = (r * 0.2, r * 0.022, r * 0.06); bake_xform(st_); parts.append(('head', st_))
    if 'keyring' in acc:         # a ring of brass tags for every room in the house
        kp = j['hips'] + V(0.15 * H * rig.bw, -0.05 * H, -0.02 * H)
        kr = prim('torus', 'KeyRing', R=0.04 * H, rr=0.006 * H, material=mats['brass'], loc=kp, rot=(0, math.pi / 2, 0)); bake_xform(kr); parts.append(('hips', kr))
        for k in range(6):
            a = k / 6 * math.pi + 0.2
            tg = prim('cube', 'KeyTag', material=mats['brass'], loc=kp + V(0.006 * H, math.cos(a) * 0.05 * H, -math.sin(a) * 0.05 * H - 0.03 * H), rot=(a, 0, 0)); tg.scale = (0.004 * H, 0.025 * H, 0.05 * H); bake_xform(tg); parts.append(('hips', tg))
    if 'buttons' in acc:         # every lost button in the house, sewn on wherever there was room
        br_ = random.Random(7)
        cols = [mats['gold'], mats['red'], mats['brass'], mats['cream'], mats['black'], mats['gem'], mats['silver']]
        for k in range(16):
            bp = j['spine'] + V((br_.random() - 0.5) * 0.24 * H, front_y * 1.18, br_.random() * 0.3 * H - 0.02 * H)
            bt = prim('cyl', 'Button', r1=(0.014 + br_.random() * 0.012) * H, r2=(0.014 + br_.random() * 0.012) * H, depth=0.008 * H, seg=10, material=cols[k % len(cols)], loc=bp, rot=(math.pi / 2, 0, br_.random())); bake_xform(bt); parts.append(('chest', bt))
    if 'snuffer' in acc:         # a candle snuffer, carried like a sword
        rod = tube('SnufferRod', [hand_r + V(0, 0, 0.02 * H), hand_r + V(0.02 * H, -0.08 * H, 0.32 * H)], 0.007 * H, mats['brass']); parts.append(('hand.R', rod))
        cone = prim('cyl', 'SnufferCone', r1=0.045 * H, r2=0.012 * H, depth=0.07 * H, seg=14, material=mats['brass'], loc=hand_r + V(0.025 * H, -0.09 * H, 0.33 * H), rot=(math.pi, 0, 0)); parts.append(('hand.R', cone))
    if 'dance_card' in acc:      # tied to his wrist; not one name written on it
        string = tube('CardString', [j['wrist.L'], j['wrist.L'] + V(0.01, -0.02, -0.08 * H)], 0.003 * H, mats['red']); parts.append(('hand.L', string))
        cd = prim('cube', 'DanceCard', material=mats['cream'], loc=j['wrist.L'] + V(0.01, -0.02, -0.14 * H), rot=(0.1, 0, 0.2)); cd.scale = (0.07 * H, 0.004 * H, 0.1 * H); bake_xform(cd); parts.append(('hand.L', cd))
    if 'wilted_flower' in acc:   # a carnation that gave up around 1891
        base = j['chest'] + V(0.1 * H, front_y * 1.15, 0.22 * H)
        stem = tube('Stem', [base, base + V(0.02 * H, -0.03 * H, 0.06 * H), base + V(0.06 * H, -0.05 * H, 0.03 * H)], 0.005 * H, mats['leather_dark']); parts.append(('chest', stem))
        hd = prim('sphere', 'Carnation', r=0.035 * H, u=12, v=8, material=mats['flower'], loc=base + V(0.07 * H, -0.06 * H, 0.0)); hd.scale = (1, 1, 0.7); bake_xform(hd); parts.append(('chest', hd))
    def half_mask(material):
        mk = prim('sphere', 'Mask', r=r * 1.02, u=32, v=20, material=material, loc=c)
        bm = bmesh.new(); bm.from_mesh(mk.data); kill = []
        for v in bm.verts:
            x, y, z = v.co            # mesh is local to the sphere's centre
            if y > -r * 0.45 or z < -r * 0.05 or z > r * 0.5: kill.append(v); continue
            for sx in (-1, 1):
                if math.dist((x, z), (sx * r * 0.37, r * 0.13)) < r * 0.15: kill.append(v)
        bmesh.ops.delete(bm, geom=list(set(kill)), context='VERTS'); bm.to_mesh(mk.data); bm.free()
        so = mk.modifiers.new('solid', 'SOLIDIFY'); so.thickness = 0.01 * r; apply_mods(mk); parts.append(('head', mk))
    if 'mask_fox' in acc:
        half_mask(mats['fox'])
        for sx in (-1, 1):
            ear = prim('cyl', 'FoxEar', r1=r * 0.2, r2=0.0, depth=r * 0.5, seg=4, material=mats['fox'], loc=c + V(sx * r * 0.55, -r * 0.55, r * 0.75), rot=(-0.3, sx * 0.35, math.pi / 4)); parts.append(('head', ear))
        sn = prim('cyl', 'FoxSnout', r1=r * 0.16, r2=r * 0.02, depth=r * 0.4, seg=12, material=mats['fox'], loc=c + V(0, -r * 1.12, r * 0.02), rot=(math.pi / 2, 0, 0)); parts.append(('head', sn))
        nt = prim('sphere', 'FoxNose', r=r * 0.04, u=8, v=6, material=mats['black'], loc=c + V(0, -r * 1.32, r * 0.02)); parts.append(('head', nt))
    if 'mask_owl' in acc:
        half_mask(mats['owl'])
        for sx in (-1, 1):
            tuft = prim('cyl', 'OwlTuft', r1=r * 0.12, r2=0.0, depth=r * 0.45, seg=6, material=mats['owl'], loc=c + V(sx * r * 0.62, -r * 0.5, r * 0.78), rot=(-0.2, sx * 0.6, 0)); parts.append(('head', tuft))
            ring = prim('torus', 'OwlEyeRing', R=r * 0.2, rr=r * 0.04, material=mats['cream'], loc=c + V(sx * r * 0.37, -r * 1.0, r * 0.13), rot=(math.pi / 2, 0, 0)); bake_xform(ring); parts.append(('head', ring))
        bk = prim('cyl', 'OwlBeak', r1=r * 0.08, r2=0.0, depth=r * 0.22, seg=8, material=mats['gold'], loc=c + V(0, -r * 1.08, -r * 0.05), rot=(math.pi * 0.62, 0, 0)); parts.append(('head', bk))
    if 'bowtie' in acc:
        crooked = 0.35 if s.get('crooked_bow') else 0.0
        for sx in (-1, 1):
            w = prim('cyl', 'BowWing', r1=0.026 * H, r2=0.002, depth=0.05 * H, seg=4, material=mats['bowtie'], loc=j['neck'] + V(sx * 0.024 * H * math.cos(crooked), -0.068 * H, -0.025 * H + sx * 0.024 * H * math.sin(crooked)), rot=(0, sx * math.pi / 2 + crooked, 0)); bake_xform(w); parts.append(('neck', w))
        k = prim('sphere', 'BowKnot', r=0.012 * H, u=8, v=6, material=mats['bowtie'], loc=j['neck'] + V(0, -0.07 * H, -0.025 * H)); parts.append(('neck', k))
    if 'monocle' in acc:
        mo = prim('torus', 'Monocle', R=r * 0.2, rr=r * 0.022, material=mats['gold'], loc=c + V(-r * 0.37, -r * 0.92, r * 0.13), rot=(math.pi / 2, 0, 0)); bake_xform(mo); parts.append(('head', mo))
    if 'watchchain' in acc:
        ch = tube('WatchChain', [j['spine'] + V(-0.08 * H, front_y * 1.25, 0.1 * H), j['spine'] + V(-0.01 * H, front_y * 1.3, 0.06 * H), j['spine'] + V(0.06 * H, front_y * 1.25, 0.1 * H)], 0.003 * H, mats['gold']); parts.append(('spine', ch))
        fob = prim('cyl', 'Fob', r1=0.02 * H, r2=0.02 * H, depth=0.008 * H, seg=14, material=mats['gold'], loc=j['spine'] + V(0.07 * H, front_y * 1.28, 0.1 * H), rot=(math.pi / 2, 0, 0)); bake_xform(fob); parts.append(('spine', fob))
    if 'nightcap' in acc:
        pts = [c + V(0, 0, r * 1.0), c + V(0, r * 0.1, r * 1.5), c + V(r * 0.7, r * 0.4, r * 2.1), c + V(r * 1.6, r * 0.5, r * 1.9), c + V(r * 2.1, r * 0.5, r * 1.2)]
        nc = tube('Nightcap', pts, r * 0.95, mats['cap'], r_end=r * 0.12, seg=16); parts.append(('head', nc))
        pom = prim('sphere', 'Pompom', r=r * 0.25, u=12, v=8, material=mats['shirt'], loc=pts[-1]); parts.append(('head', pom))
        brim = prim('torus', 'NightcapBrim', R=r * 0.95, rr=r * 0.12, material=mats['shirt'], loc=c + V(0, 0, r * 0.82)); parts.append(('head', brim))
    if 'goggles' in acc:
        st = prim('torus', 'GoggleStrap', R=r * 1.02, rr=r * 0.07, material=mats['leather_dark'], loc=c + V(0, 0, r * 0.45), rot=(0.25, 0, 0)); bake_xform(st); parts.append(('head', st))
        for sx in (-1, 1):
            g = prim('cyl', 'Goggle', r1=r * 0.24, r2=r * 0.24, depth=r * 0.2, seg=20, material=mats['brass'], loc=c + V(sx * r * 0.36, -r * 0.8, r * 0.75), rot=(math.pi / 2 - 0.5, 0, 0)); bake_xform(g); parts.append(('head', g))
    if 'epaulettes' in acc:
        for side in ('L', 'R'):
            ep = prim('cube', 'Epaulette', material=mats['trim'], loc=j['shoulder.' + side] + V(0, 0, 0.055 * H)); ep.scale = (0.1 * H, 0.08 * H, 0.02 * H); bake_xform(ep); parts.append(('shoulder.' + side, ep))
    if 'flower' in acc:
        fl = prim('sphere', 'Buttonhole', r=0.022 * H, u=10, v=8, material=mats['flower'], loc=j['chest'] + V(0.09 * H, front_y * 1.1, 0.27 * H)); parts.append(('chest', fl))
    if s['outfit'].get('hood') and s['outfit']['main'][0] > 0.7 and s['outfit']['main'][2] > 0.85:
        hood = prim('sphere', 'Hood', r=r * 1.3, u=32, v=20, material=mats['torso'], loc=c + V(0, r * 0.05, r * 0.05))
        bm = bmesh.new(); bm.from_mesh(hood.data)
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if (v.co - c).y < -r * 0.55 and (v.co - c).z < r * 0.6], context='VERTS'); bm.to_mesh(hood.data); bm.free()
        so = hood.modifiers.new('solid', 'SOLIDIFY'); so.thickness = 0.01 * H; apply_mods(hood); parts.append(('head', hood))
    if 'notebook' in acc:
        nb = prim('cube', 'Notebook', material=mats['leather_dark'], loc=j['wrist.L'] + V(0.0, -0.06 * H, -0.05 * H)); nb.scale = (0.1 * H, 0.015 * H, 0.13 * H); bake_xform(nb); parts.append(('prop_notebook', nb))
    if 'cane' in acc:
        cn = prim('cyl', 'Cane', r1=0.011 * H, r2=0.011 * H, depth=0.9 * H, seg=10, material=mats['black'], loc=j['wrist.R'] + V(0, -0.03 * H, -0.45 * H)); parts.append(('prop_cane', cn))
        kn = prim('sphere', 'CaneKnob', r=0.025 * H, u=12, v=8, material=mats['silver'], loc=j['wrist.R'] + V(0, -0.03 * H, 0.0)); parts.append(('prop_cane', kn))
    return parts

# ===================================================================================== rig & weights
def build_armature(rig, extra):
    arm = bpy.data.armatures.new('Rig')
    o = new_obj('Rig', arm)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.mode_set(mode='EDIT')
    eb = arm.edit_bones
    bones = rig.bones()
    bones.update(extra)
    for name, (h, t, parent) in bones.items():
        b = eb.new(name); b.head = h; b.tail = t
        b.roll = 0.0
    for name, (h, t, parent) in bones.items():
        if parent: eb[name].parent = eb[parent]; eb[name].use_connect = False
    bpy.ops.object.mode_set(mode='OBJECT')
    return o, bones

def seg_dist(p, a, b):
    ab = b - a; t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
    return (p - (a + ab * t)).length

def weight_smooth(obj, bones, allowed, power=4.0, top=3):
    """Distance-to-segment weights, limited to the `allowed` bones."""
    groups = {n: obj.vertex_groups.get(n) or obj.vertex_groups.new(name=n) for n in allowed}
    for v in obj.data.vertices:
        p = obj.matrix_world @ v.co
        ds = []
        for n in allowed:
            h, t, _ = bones[n]
            d = seg_dist(p, Vector(h), Vector(t)) + 0.002
            ds.append((1.0 / d ** power, n))
        ds.sort(reverse=True)
        ds = ds[:top]
        tot = sum(w for w, _ in ds)
        for w, n in ds: groups[n].add([v.index], w / tot, 'REPLACE')

def weight_rigid(obj, bone):
    g = obj.vertex_groups.get(bone) or obj.vertex_groups.new(name=bone)
    g.add([v.index for v in obj.data.vertices], 1.0, 'REPLACE')

def weight_skirt(obj, bones, rig, extra_bone='skirt'):
    """Coat skirts follow the hips at the waist and the thighs toward the hem."""
    j = rig.j
    top = j['spine'].z; bottom = j['knee.L'].z
    groups = {n: obj.vertex_groups.get(n) or obj.vertex_groups.new(name=n) for n in ('hips', 'thigh.L', 'thigh.R', extra_bone)}
    for v in obj.data.vertices:
        p = obj.matrix_world @ v.co
        t = max(0.0, min(1.0, (top - p.z) / max(top - bottom, 0.01)))
        side = 'thigh.L' if p.x > 0 else 'thigh.R'
        front = 1.0 if p.y < 0 else 0.5
        w_leg = 0.55 * t * front * min(1.0, abs(p.x) / 0.08)
        w_sk = 0.35 * t
        w_hip = max(0.0, 1.0 - w_leg - w_sk)
        groups['hips'].add([v.index], w_hip, 'REPLACE'); groups[side].add([v.index], w_leg, 'REPLACE'); groups[extra_bone].add([v.index], w_sk, 'REPLACE')

# ===================================================================================== build one
def build_character(name, preview=False):
    clean()
    s = resolve(name)
    o = s['outfit']
    fab = {'tweed': 0.95, 'wool': 0.92, 'linen': 0.9, 'velvet': 0.75, 'rubber': 0.35}.get(o.get('fabric', 'wool'), 0.9)
    trousers = o.get('trousers', o['main'])
    mats = {
        'skin': mat('skin', s['skin'], 0.55), 'eye': mat('eye_white', (0.95, 0.94, 0.9), 0.15), 'iris': mat('iris_' + s.get('iris', 'avery'), (0.5, 0.5, 0.5), 0.08, image=os.path.join(ROOT, 'assets', 'textures', 'generated', 'iris_%s.png' % s.get('iris', 'avery'))),
        'brow': mat('brow', s.get('brow', s.get('hair', {}).get('color', (0.2, 0.12, 0.08))), 0.9), 'lip': mat('lip', s.get('lip', (0.55, 0.28, 0.24)), 0.5),
        'mouth': mat('mouth_dark', (0.12, 0.03, 0.03), 0.9), 'teeth': mat('teeth', (0.95, 0.93, 0.86), 0.3), 'freckle': mat('freckle', (0.5, 0.3, 0.2), 0.8), 'blush': mat('blush', (0.95, 0.55, 0.55), 0.8),
        'hair': mat('hair', s.get('hair', {}).get('color', (0.2, 0.12, 0.08)), 0.55), 'band': mat('band', s.get('hair', {}).get('band', (0.8, 0.3, 0.2)), 0.35, 0.7),
        'torso': mat('cloth_main', o['main'], fab), 'second': mat('cloth_second', o.get('second', o['main']), fab), 'lapel': mat('cloth_lapel', o.get('lapel', o.get('second', o['main'])), 0.4),
        'vest': mat('cloth_vest', o.get('vest', o.get('second', o['main'])), 0.6), 'shirt': mat('cloth_shirt', o.get('shirt', (0.9, 0.88, 0.82)), 0.9),
        'legs': mat('cloth_legs', trousers if o['type'] not in ('gown', 'robe') else o['main'], fab), 'boots': mat('leather_boots', o.get('boots', (0.2, 0.12, 0.08)), 0.45),
        'sole': mat('sole', (0.08, 0.06, 0.05), 0.8), 'belt': mat('leather_belt', o.get('belt', (0.17, 0.1, 0.06)), 0.5), 'trim': mat('trim_gold', o.get('trim', (0.79, 0.64, 0.33)), 0.3, 1.0),
        'button': mat('button', (0.16, 0.1, 0.06), 0.4), 'leather': mat('leather', (0.42, 0.25, 0.14), 0.55), 'leather_dark': mat('leather_dark', (0.25, 0.15, 0.09), 0.5),
        'scarf': mat('cloth_scarf', s.get('scarf', (0.77, 0.54, 0.16)), 1.0), 'cap': mat('cloth_cap', s.get('cap', s.get('nightcap', (0.2, 0.2, 0.3))), 0.9),
        'black': mat('black', (0.03, 0.03, 0.035), 0.4), 'gold': mat('gold', (0.88, 0.7, 0.36), 0.25, 1.0), 'silver': mat('silver', (0.85, 0.85, 0.88), 0.2, 1.0), 'brass': mat('brass', (0.8, 0.62, 0.32), 0.3, 1.0),
        'gem': mat('gem', (0.75, 0.1, 0.18), 0.1), 'mask': mat('mask', (0.1, 0.06, 0.08), 0.35), 'mask_full': mat('mask_white', (0.95, 0.93, 0.9), 0.3),
        'bowtie': mat('bowtie', s.get('bowtie', (0.06, 0.06, 0.06)), 0.5), 'flower': mat('flower', (0.75, 0.1, 0.2), 0.7),
        'gloves': mat('gloves', o.get('gloves', s['skin']), 0.7),
        'lens': mat('lens', (0.75, 0.85, 0.9), 0.05, 0.3), 'sequin': mat('sequin', s.get('sequin', (1.0, 0.45, 0.75)), 0.18, 0.85),
        'rule': mat('rule_yellow', (0.98, 0.78, 0.12), 0.45), 'paper': mat('paper', (0.97, 0.95, 0.88), 0.85), 'pink': mat('eraser', (0.95, 0.5, 0.55), 0.7),
        'red': mat('red', (0.85, 0.1, 0.12), 0.5), 'fox': mat('fox_mask', (0.95, 0.42, 0.1), 0.45), 'owl': mat('owl_mask', (0.55, 0.38, 0.22), 0.6), 'cream': mat('cream', (0.98, 0.93, 0.8), 0.5), 'feather': mat('feather', s.get('feather', (0.1, 0.78, 0.74)), 0.6),
    }
    s['_mats'] = mats
    if 'gloves' not in s.get('acc', []): mats['gloves'] = mats['skin']
    if o['type'] == 'waistcoat': mats['sleeve'] = mats['shirt']; mats['torso'] = mats['second']
    else: mats['sleeve'] = mats['torso'] if o['type'] not in ('gown',) else mats['second']
    if o['type'] == 'gown': mats['torso'] = mats['second']
    if o.get('socks'): pass
    rig = Rig(s)
    H = rig.H
    extra = {
        'eye.L': (rig.j['head_c'] + V(rig.head_r * 0.37, -rig.head_r * 0.8, rig.head_r * 0.13), rig.j['head_c'] + V(rig.head_r * 0.37, -rig.head_r * 1.2, rig.head_r * 0.13), 'head'),
        'eye.R': (rig.j['head_c'] + V(-rig.head_r * 0.37, -rig.head_r * 0.8, rig.head_r * 0.13), rig.j['head_c'] + V(-rig.head_r * 0.37, -rig.head_r * 1.2, rig.head_r * 0.13), 'head'),
        'lid.L': (rig.j['head_c'] + V(rig.head_r * 0.37, -rig.head_r * 0.8, rig.head_r * 0.13), rig.j['head_c'] + V(rig.head_r * 0.37, -rig.head_r * 0.8, rig.head_r * 0.4), 'head'),
        'lid.R': (rig.j['head_c'] + V(-rig.head_r * 0.37, -rig.head_r * 0.8, rig.head_r * 0.13), rig.j['head_c'] + V(-rig.head_r * 0.37, -rig.head_r * 0.8, rig.head_r * 0.4), 'head'),
        'brow.L': (rig.j['head_c'] + V(rig.head_r * 0.39, -rig.head_r * 0.84, rig.head_r * 0.56), rig.j['head_c'] + V(rig.head_r * 0.6, -rig.head_r * 0.81, rig.head_r * 0.56), 'head'),
        'brow.R': (rig.j['head_c'] + V(-rig.head_r * 0.39, -rig.head_r * 0.84, rig.head_r * 0.56), rig.j['head_c'] + V(-rig.head_r * 0.6, -rig.head_r * 0.81, rig.head_r * 0.56), 'head'),
        'skirt': (rig.j['spine'], rig.j['spine'] + V(0, 0, -0.3 * H), 'hips'),
        'tails': (rig.j['hips'] + V(0, 0.1 * H, 0.0), rig.j['hips'] + V(0, 0.12 * H, -0.4 * H), 'hips'),
        'scarf': (rig.j['neck'] + V(0.05 * H, -0.12 * H, -0.06 * H), rig.j['neck'] + V(0.05 * H, -0.13 * H, -0.36 * H), 'chest'),
        'prop_notebook': (rig.j['wrist.L'], rig.j['wrist.L'] + V(0, -0.1, 0), 'hand.L'),
        'prop_cane': (rig.j['wrist.R'], rig.j['wrist.R'] + V(0, 0, -0.1), 'hand.R'),
        'socket.L': (rig.j['hand_end.L'], rig.j['hand_end.L'] + V(0, -0.05, 0), 'hand.L'),
        'socket.R': (rig.j['hand_end.R'], rig.j['hand_end.R'] + V(0, -0.05, 0), 'hand.R'),
    }
    if s.get('tail'):
        z0 = rig.j['hips'].z
        extra['tail.1'] = (rig.j['hips'], rig.j['hips'] - V(0, 0, z0 * 0.35), 'hips')
        extra['tail.2'] = (rig.j['hips'] - V(0, 0, z0 * 0.35), rig.j['hips'] - V(0, 0, z0 * 0.7), 'tail.1')
        extra['tail.3'] = (rig.j['hips'] - V(0, 0, z0 * 0.7), rig.j['hips'] - V(0, 0, z0 * 0.98), 'tail.2')
    arm_obj, bones = build_armature(rig, extra)
    deform_body = ['hips', 'spine', 'chest', 'neck', 'head', 'shoulder.L', 'upper_arm.L', 'forearm.L', 'hand.L', 'shoulder.R', 'upper_arm.R', 'forearm.R', 'hand.R', 'thigh.L', 'shin.L', 'foot.L', 'thigh.R', 'shin.R', 'foot.R']
    meshes = []
    body = body_mesh(rig, s, mats)
    allowed = [b for b in deform_body if not (s.get('tail') or o['type'] in ('gown', 'robe')) or not b.startswith(('thigh', 'shin', 'foot'))]
    weight_smooth(body, bones, allowed); meshes.append(body)
    head_parts, eyes, brows, mouths = head_mesh(rig, s, mats)
    for p in head_parts: weight_rigid(p, 'head'); meshes.append(p)
    for side, ec, ball, iris, lid, *lash in eyes:
        weight_rigid(ball, 'head'); weight_rigid(iris, 'eye.' + side); weight_rigid(lid, 'lid.' + side); meshes += [ball, iris, lid]
        for l in lash: weight_rigid(l, 'lid.' + side); meshes.append(l)
    for side, bc, b in brows: weight_rigid(b, 'brow.' + side); meshes.append(b)
    for k, m in mouths.items(): weight_rigid(m, 'head'); meshes.append(m)
    for side in ('L', 'R'):
        h = hand_mesh(rig, side, s, mats['gloves'])
        weight_smooth(h, bones, ['forearm.' + side, 'hand.' + side], power=6.0, top=2); meshes.append(h)
        if not s.get('tail') and o['type'] not in ('gown', 'robe'):
            for p in boot_mesh(rig, side, s, mats['boots'], mats['sole']):
                weight_smooth(p, bones, ['shin.' + side, 'foot.' + side], power=6.0, top=2); meshes.append(p)
    for p in hair_mesh(rig, s, mats['hair']): weight_rigid(p, 'head'); meshes.append(p)
    for bone, p in clothing(rig, s, mats):
        if bone == 'skirt': weight_skirt(p, bones, rig)
        elif bone == 'tails': weight_smooth(p, bones, ['hips', 'tails'], top=2)
        elif bone.startswith('forearm'): weight_smooth(p, bones, [bone, 'hand.' + bone[-1]], power=6.0, top=2)
        else: weight_smooth(p, bones, [bone] if bone in ('neck', 'head') else ['spine', 'chest', 'neck', 'shoulder.L', 'shoulder.R'] if bone == 'chest' else [bone, 'hips', 'chest'], top=2)
        meshes.append(p)
    if s.get('tail'):
        t = ghost_tail(rig, s, mats['torso'])
        weight_smooth(t, bones, ['hips', 'tail.1', 'tail.2', 'tail.3'], top=2); meshes.append(t)
    for bone, p in accessories(rig, s, mats):
        if bone.startswith('prop_'): weight_rigid(p, bone)
        elif bone == 'scarf': weight_smooth(p, bones, ['chest', 'scarf'], top=2)
        elif bone == 'chest': weight_smooth(p, bones, ['spine', 'chest', 'neck'], top=2)
        else: weight_rigid(p, bone)
        meshes.append(p)
    # every part gets a UV map (box projection at real-world scale) so fabrics tile correctly
    for m in meshes:
        if m.type != 'MESH' or m.data.uv_layers: continue
        uv = m.data.uv_layers.new(name='UVMap')
        tile = 0.25
        for poly in m.data.polygons:
            n = poly.normal; ax = max(range(3), key=lambda i: abs(n[i]))
            for li in poly.loop_indices:
                co = m.matrix_world @ m.data.vertices[m.data.loops[li].vertex_index].co
                uvv = (co.y, co.z) if ax == 0 else ((co.x, co.z) if ax == 1 else (co.x, co.y))
                uv.data[li].uv = (uvv[0] / tile, uvv[1] / tile)
    # join everything except the mouth variants and named props (toggled in-game)
    keep_separate = {'Mouth_neutral', 'Mouth_smile', 'Mouth_frown', 'Mouth_open', 'Mouth_o', 'Mouth_grin', 'Mouth_grin_teeth', 'Notebook', 'Cane', 'CaneKnob'}
    join = [m for m in meshes if m.name.split('.')[0] not in keep_separate]
    separate = [m for m in meshes if m.name.split('.')[0] in keep_separate]
    bpy.ops.object.select_all(action='DESELECT')
    for m in join: m.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.join()
    body.name = 'Body'
    for m in [body] + separate:
        m.parent = arm_obj
        mod = m.modifiers.new('arm', 'ARMATURE'); mod.object = arm_obj
    return arm_obj

def export(name, out_dir):
    path = os.path.join(out_dir, name + '.glb')
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', export_apply=False, export_yup=True, export_skins=True, export_animations=False, export_def_bones=False)
    return path

def preview(name, out_dir):
    scn = bpy.context.scene
    cam = bpy.data.cameras.new('cam'); co = link(bpy.data.objects.new('cam', cam))
    co.location = (0.9, -3.0, 1.15); co.rotation_euler = (math.radians(86), 0, math.radians(17)); cam.lens = 55
    scn.camera = co
    for loc, e in (((2, -3, 3), 900), ((-3, -1, 2), 400), ((0, 3, 3), 600)):
        l = bpy.data.lights.new('l', 'AREA'); l.energy = e; l.size = 2
        lo = link(bpy.data.objects.new('l', l)); lo.location = loc; lo.rotation_euler = (Vector((0, 0, 1)) .rotation_difference(Vector(loc) * -1).to_euler())
    w = bpy.data.worlds.new('w'); w.use_nodes = True; w.node_tree.nodes['Background'].inputs[0].default_value = (0.05, 0.05, 0.06, 1); scn.world = w
    scn.render.engine = 'CYCLES'; scn.cycles.samples = 24; scn.cycles.device = 'CPU'
    scn.render.resolution_x = 640; scn.render.resolution_y = 800
    scn.render.filepath = os.path.join(out_dir, name + '_preview.png')
    bpy.ops.render.render(write_still=True)

if __name__ == '__main__':
    args = sys.argv[1:]
    out = OUT
    os.makedirs(out, exist_ok=True)
    only = None
    if '--only' in args: only = args[args.index('--only') + 1].split(',')
    for name in CAST:
        if only and name not in only: continue
        build_character(name)
        export(name, out)
        if '--preview' in args:
            preview(name, '/tmp/char_previews')
        print('built', name, flush=True)
