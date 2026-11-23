"""Avery's car: a tired old estate, lofted from cross-sections, with booleaned wheel arches, a glass
greenhouse with pillars, chrome bumpers and round lamps. Exports assets/models/props/car_estate.glb.

    python3 tools/blender/car.py
"""
import math, os, sys
import bpy, bmesh
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
OUT = os.path.join(ROOT, 'assets', 'models', 'props', 'car_estate.glb')


def clean():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def mat(name, color, rough=0.5, metal=0.0, emit=None, coat=0.0):
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = (*color, 1)
    b.inputs['Roughness'].default_value = rough
    b.inputs['Metallic'].default_value = metal
    if coat and 'Coat Weight' in b.inputs: b.inputs['Coat Weight'].default_value = coat
    if emit:
        b.inputs['Emission Color'].default_value = (*emit, 1); b.inputs['Emission Strength'].default_value = 3.0
    return m


def link(o):
    bpy.context.collection.objects.link(o); return o


def section(y, w, z0, z1, wt, n=24, power=4.0):
    """Superellipse cross-section: wide at the sill, tumbling home toward the roof."""
    pts = []
    for i in range(n):
        a = 2 * math.pi * i / n
        c, s = math.cos(a), math.sin(a)
        x = math.copysign(abs(c) ** (2 / power), c)
        z = math.copysign(abs(s) ** (2 / power), s)
        zz = z0 + (z + 1) * 0.5 * (z1 - z0)
        t = (zz - z0) / max(z1 - z0, 1e-3)
        half = w + (wt - w) * max(0.0, t - 0.45) / 0.55
        pts.append(Vector((x * half, y, zz)))
    return pts


def loft(name, sections, material):
    bm = bmesh.new()
    rings = []
    for sec in sections:
        rings.append([bm.verts.new(p) for p in section(*sec)])
    n = len(rings[0])
    for a, b in zip(rings[:-1], rings[1:]):
        for i in range(n):
            bm.faces.new((a[i], a[(i + 1) % n], b[(i + 1) % n], b[i]))
    for ring in (rings[0], rings[-1]):
        f = bm.faces.new(ring if ring is rings[-1] else list(reversed(ring)))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    o = link(bpy.data.objects.new(name, me))
    o.data.materials.append(material)
    return o


def apply_mods(o):
    bpy.context.view_layer.objects.active = o
    for m in list(o.modifiers):
        bpy.ops.object.modifier_apply(modifier=m.name)


def prim(kind, name, material, loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1), **kw):
    if kind == 'cyl': bpy.ops.mesh.primitive_cylinder_add(vertices=kw.get('v', 32), radius=kw.get('r', 1), depth=kw.get('d', 1), location=loc, rotation=rot)
    elif kind == 'cube': bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    elif kind == 'sphere': bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, radius=kw.get('r', 1), location=loc, rotation=rot)
    elif kind == 'torus': bpy.ops.mesh.primitive_torus_add(major_radius=kw.get('R', 1), minor_radius=kw.get('r', 0.2), major_segments=40, minor_segments=14, location=loc, rotation=rot)
    o = bpy.context.active_object; o.name = name; o.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    o.data.materials.append(material)
    return o


def bevel(o, w=0.01, seg=2):
    m = o.modifiers.new('bevel', 'BEVEL'); m.width = w; m.segments = seg; m.limit_method = 'ANGLE'
    apply_mods(o)


def build():
    clean()
    paint = mat('car_paint', (0.06, 0.16, 0.12), 0.32, 0.55, coat=1.0)
    chrome = mat('chrome', (0.9, 0.9, 0.92), 0.08, 1.0)
    glass = mat('glass', (0.015, 0.02, 0.025), 0.04, 0.2)
    tyre = mat('tyre', (0.02, 0.02, 0.02), 0.85)
    trim = mat('trim', (0.03, 0.03, 0.03), 0.5)
    head = mat('headlamp', (1.0, 0.95, 0.8), 0.1, 0.0, emit=(1.0, 0.92, 0.75))
    tail = mat('taillamp', (0.6, 0.02, 0.02), 0.2, 0.0, emit=(1.0, 0.05, 0.03))
    plate = mat('plate', (0.92, 0.9, 0.82), 0.6)
    # front is -Y (glTF +Z)
    secs = [(-2.22, 0.76, 0.34, 0.72, 0.62), (-2.05, 0.85, 0.28, 0.84, 0.76), (-1.3, 0.875, 0.27, 0.9, 0.8), (-0.78, 0.875, 0.27, 0.96, 0.8),
            (-0.22, 0.875, 0.27, 1.38, 0.63), (0.4, 0.875, 0.27, 1.43, 0.63), (1.25, 0.87, 0.27, 1.42, 0.64), (1.85, 0.86, 0.28, 1.32, 0.66),
            (2.1, 0.84, 0.3, 1.12, 0.68), (2.24, 0.76, 0.36, 0.88, 0.6)]
    body = loft('Body', secs, paint)
    sub = body.modifiers.new('sub', 'SUBSURF'); sub.levels = 2; sub.render_levels = 2
    apply_mods(body)
    # wheel arches
    for y in (-1.38, 1.36):
        cut = prim('cyl', 'cut', paint, loc=(0, y, 0.33), rot=(0, math.pi / 2, 0), r=0.42, d=2.2, v=40)
        b = body.modifiers.new('arch', 'BOOLEAN'); b.object = cut; b.operation = 'DIFFERENCE'; b.solver = 'EXACT'
        apply_mods(body)
        bpy.data.objects.remove(cut)
    # glass greenhouse: faces above the beltline that aren't roof or pillars
    body.data.materials.append(glass); body.data.materials.append(trim)
    bm = bmesh.new(); bm.from_mesh(body.data); bm.faces.ensure_lookup_table()
    for f in bm.faces:
        c = f.calc_center_median(); n = f.normal
        windscreen = -0.74 < c.y < -0.26 and c.z > 1.0 and abs(c.x) < 0.6
        rear_window = c.y > 1.9 and c.z > 0.98 and abs(c.x) < 0.62
        if windscreen or rear_window:
            f.material_index = 1
        elif c.z > 1.0 and n.z < 0.72:
            pillar = abs(c.y - 0.42) < 0.07 or abs(c.y - 1.55) < 0.06 or (c.y < -0.62 and abs(n.x) > 0.25)
            f.material_index = 0 if pillar else 1
        elif 0.95 < c.z <= 1.0 and n.z < 0.6:
            f.material_index = 2   # rubber window seal line
    bm.to_mesh(body.data); bm.free()
    for p in body.data.polygons: p.use_smooth = True
    parts = [body]
    # bumpers, grille, lamps, plates, mirrors, handles
    for y, s in ((-2.3, -1), (2.32, 1)):
        bb = prim('cube', 'Bumper', chrome, loc=(0, y, 0.42), scale=(1.72, 0.1, 0.12)); bevel(bb, 0.03, 3); parts.append(bb)
    g = prim('cube', 'Grille', trim, loc=(0, -2.2, 0.62), scale=(0.9, 0.06, 0.2)); bevel(g, 0.02); parts.append(g)
    gs = prim('cube', 'GrilleSurround', chrome, loc=(0, -2.21, 0.62), scale=(0.96, 0.04, 0.25)); bevel(gs, 0.02); parts.append(gs)
    for i in range(9):
        parts.append(prim('cube', 'GrilleBar', chrome, loc=(-0.4 + i * 0.1, -2.235, 0.62), scale=(0.012, 0.02, 0.18)))
    for sx in (-1, 1):
        r = prim('cyl', 'LampRing', chrome, loc=(sx * 0.62, -2.15, 0.7), rot=(math.pi / 2, 0, 0), r=0.13, d=0.08); parts.append(r)
        parts.append(prim('sphere', 'Headlamp', head, loc=(sx * 0.62, -2.18, 0.7), scale=(0.115, 0.04, 0.115)))
        parts.append(prim('cube', 'Taillamp', tail, loc=(sx * 0.68, 2.2, 0.82), scale=(0.16, 0.05, 0.22)))
        m = prim('cube', 'Mirror', chrome, loc=(sx * 0.9, -0.6, 1.0), scale=(0.09, 0.04, 0.07)); bevel(m, 0.015); parts.append(m)
        for y in (-0.2, 0.75):
            parts.append(prim('cube', 'Handle', chrome, loc=(sx * 0.885, y, 0.9), scale=(0.02, 0.14, 0.025)))
        parts.append(prim('cube', 'Trim', chrome, loc=(sx * 0.878, 0.0, 0.62), scale=(0.01, 3.4, 0.02)))
    parts.append(prim('cube', 'PlateF', plate, loc=(0, -2.36, 0.42), scale=(0.5, 0.01, 0.12)))
    parts.append(prim('cube', 'PlateR', plate, loc=(0, 2.38, 0.42), scale=(0.5, 0.01, 0.12)))
    for sx in (-1, 1):
        parts.append(prim('cube', 'RoofRail', trim, loc=(sx * 0.42, 0.55, 1.425), scale=(0.03, 1.8, 0.03)))
        for y in (-0.3, 1.4): parts.append(prim('cube', 'RailFoot', trim, loc=(sx * 0.42, y, 1.405), scale=(0.04, 0.06, 0.04)))
    # wheels
    for y in (-1.38, 1.36):
        for sx in (-1, 1):
            t = prim('torus', 'Tyre', tyre, loc=(sx * 0.78, y, 0.33), rot=(0, math.pi / 2, 0), R=0.25, r=0.085)
            t.scale = (1, 1, 1.25); bpy.ops.object.transform_apply(scale=True); parts.append(t)
            parts.append(prim('cyl', 'Rim', chrome, loc=(sx * 0.8, y, 0.33), rot=(0, math.pi / 2, 0), r=0.2, d=0.12))
            parts.append(prim('sphere', 'Hubcap', chrome, loc=(sx * 0.86, y, 0.33), scale=(0.05, 0.12, 0.12)))
    for o in parts:
        for p in o.data.polygons: p.use_smooth = True
    bpy.ops.object.select_all(action='DESELECT')
    for o in parts: o.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.join()
    body.name = 'CarEstate'
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', export_yup=True, export_apply=True)
    print('exported', OUT, len(body.data.polygons), 'faces')


if __name__ == '__main__':
    build()
