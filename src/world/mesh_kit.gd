class_name MeshKit
extends RefCounted
## Procedural meshes Godot has no primitive for: lathes, tori with arcs, swept tubes, extruded
## shapes, discs and arcs. All produce smooth normals and UVs; most surfaces in the estate use
## world-space triplanar materials, so UVs only matter for decals.

static var _cache := {}

static func cached(key: String, maker: Callable) -> Mesh:
	if not _cache.has(key): _cache[key] = maker.call()
	return _cache[key]

static func box(size: Vector3) -> Mesh:
	return cached("box%s" % size, func():
		var m := BoxMesh.new(); m.size = size; return m)

static func cyl(rt: float, rb: float, h: float, seg := 16, open := false) -> Mesh:
	return cached("cyl%.4f:%.4f:%.4f:%d:%s" % [rt, rb, h, seg, open], func():
		var m := CylinderMesh.new(); m.top_radius = rt; m.bottom_radius = rb; m.height = h; m.radial_segments = seg; m.rings = 1
		m.cap_top = not open; m.cap_bottom = not open; return m)

static func sphere(r: float, seg := 16, rings := 10, hemi := false) -> Mesh:
	return cached("sph%.4f:%d:%d:%s" % [r, seg, rings, hemi], func():
		var m := SphereMesh.new(); m.radius = r; m.height = r * (1.0 if hemi else 2.0); m.radial_segments = seg; m.rings = rings; m.is_hemisphere = hemi; return m)

static func capsule(r: float, h: float, seg := 12) -> Mesh:
	return cached("cap%.4f:%.4f:%d" % [r, h, seg], func():
		var m := CapsuleMesh.new(); m.radius = r; m.height = h + 2.0 * r; m.radial_segments = seg; m.rings = 4; return m)

static func quad(w: float, h: float) -> Mesh:
	return cached("quad%.4f:%.4f" % [w, h], func():
		var m := QuadMesh.new(); m.size = Vector2(w, h); return m)

## Lathe around +Y. points: Array of Vector2(radius, y).
static func lathe(points: Array, seg := 20, phi_start := 0.0, phi_len := TAU) -> Mesh:
	var key := "lathe%s:%d:%.3f:%.3f" % [str(points).md5_text(), seg, phi_start, phi_len]
	return cached(key, func():
		var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var n := points.size()
		var lens := [0.0]
		for i in range(1, n): lens.append(lens[i - 1] + (points[i] - points[i - 1]).length())
		var total := maxf(lens[n - 1], 0.0001)
		for s in seg + 1:
			var a: float = phi_start + phi_len * float(s) / seg
			var ca := cos(a); var sa := sin(a)
			for i in n:
				var p: Vector2 = points[i]
				st.set_uv(Vector2(float(s) / seg, lens[i] / total))
				st.add_vertex(Vector3(p.x * sa, p.y, p.x * ca))
		for s in seg:
			for i in n - 1:
				var a0 := s * n + i; var a1 := a0 + n
				st.add_index(a0); st.add_index(a1); st.add_index(a0 + 1)
				st.add_index(a0 + 1); st.add_index(a1); st.add_index(a1 + 1)
		st.generate_normals(); st.generate_tangents()
		return st.commit())

## Torus in the XY plane (facing +Z), with optional arc, like a ring hung on a wall.
static func torus(r: float, t: float, arc := TAU, radial := 8, tubular := 24) -> Mesh:
	return cached("torus%.4f:%.4f:%.3f:%d:%d" % [r, t, arc, radial, tubular], func():
		var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for j in radial + 1:
			for i in tubular + 1:
				var u := float(i) / tubular * arc
				var v := float(j) / radial * TAU
				var center := Vector3(r * cos(u), r * sin(u), 0)
				var p := Vector3((r + t * cos(v)) * cos(u), (r + t * cos(v)) * sin(u), t * sin(v))
				st.set_normal((p - center).normalized())
				st.set_uv(Vector2(float(i) / tubular, float(j) / radial))
				st.add_vertex(p)
		for j in range(1, radial + 1):
			for i in range(1, tubular + 1):
				var a := (tubular + 1) * j + i - 1; var b := (tubular + 1) * (j - 1) + i - 1
				var c := (tubular + 1) * (j - 1) + i; var d := (tubular + 1) * j + i
				st.add_index(a); st.add_index(d); st.add_index(b)
				st.add_index(b); st.add_index(d); st.add_index(c)
		st.generate_tangents()
		return st.commit())

## Tube swept along a Catmull-Rom curve through `pts`. taper: end radius multiplier.
static func tube(pts: Array, radius: float, seg := 24, radial := 6, taper := 1.0) -> Mesh:
	var key := "tube%s:%.4f:%d:%d:%.2f" % [str(pts).md5_text(), radius, seg, radial, taper]
	return cached(key, func():
		var curve := Curve3D.new()
		for i in pts.size():
			var p: Vector3 = pts[i]
			var prev: Vector3 = pts[maxi(i - 1, 0)]
			var nxt: Vector3 = pts[mini(i + 1, pts.size() - 1)]
			var tan := (nxt - prev) * 0.25
			curve.add_point(p, -tan, tan)
		var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var length := curve.get_baked_length()
		var up := Vector3.UP
		var prev_n := Vector3.ZERO
		for s in seg + 1:
			var t := float(s) / seg
			var p := curve.sample_baked(t * length, true)
			var p2 := curve.sample_baked(minf(t * length + 0.01, length), true)
			if s == seg: p2 = p + (p - curve.sample_baked(maxf(length - 0.01, 0.0), true))
			var tangent := (p2 - p).normalized()
			if tangent.length() < 0.5: tangent = Vector3.FORWARD
			var nrm := prev_n if prev_n != Vector3.ZERO else (up.cross(tangent).normalized() if absf(up.dot(tangent)) < 0.99 else Vector3.RIGHT)
			nrm = (nrm - tangent * nrm.dot(tangent)).normalized()
			prev_n = nrm
			var bin := tangent.cross(nrm).normalized()
			var rr := radius * lerpf(1.0, taper, t)
			for k in radial + 1:
				var a := float(k) / radial * TAU
				var dir := nrm * cos(a) + bin * sin(a)
				st.set_normal(dir); st.set_uv(Vector2(float(k) / radial, t))
				st.add_vertex(p + dir * rr)
		for s in seg:
			for k in radial:
				var a0 := s * (radial + 1) + k; var a1 := a0 + radial + 1
				st.add_index(a0); st.add_index(a0 + 1); st.add_index(a1)
				st.add_index(a0 + 1); st.add_index(a1 + 1); st.add_index(a1)
		return st.commit())

## Extrude a 2D polygon (XY) along +Z by depth. holes: Array of polygons.
static func extrude(poly: PackedVector2Array, depth: float, key := "") -> Mesh:
	var k := "ext%s:%.4f" % [key if key != "" else str(poly).md5_text(), depth]
	return cached(k, func():
		var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var idx := Geometry2D.triangulate_polygon(poly)
		var cw := Geometry2D.is_polygon_clockwise(poly)
		for face in [0, 1]:
			var z := depth if face == 1 else 0.0
			var nz := 1.0 if face == 1 else -1.0
			for i in range(0, idx.size(), 3):
				var tri := [idx[i], idx[i + 1], idx[i + 2]]
				if (face == 0) != cw: tri.reverse()
				for v in tri:
					st.set_normal(Vector3(0, 0, nz)); st.set_uv(poly[v]); st.add_vertex(Vector3(poly[v].x, poly[v].y, z))
		var n := poly.size()
		for i in n:
			var a := poly[i]; var b := poly[(i + 1) % n]
			var e := (b - a).normalized()
			var nrm := Vector3(e.y, -e.x, 0) * (-1.0 if cw else 1.0)
			var quad_v := [Vector3(a.x, a.y, 0), Vector3(b.x, b.y, 0), Vector3(b.x, b.y, depth), Vector3(a.x, a.y, depth)]
			for t in [[0, 1, 2], [0, 2, 3]]:
				var tt: Array = t if not cw else [t[0], t[2], t[1]]
				for v in tt:
					st.set_normal(nrm); st.set_uv(Vector2(float(i) / n, quad_v[v].z)); st.add_vertex(quad_v[v])
		return st.commit())

## Flat disc (or sector) in the XY plane facing +Z with radial UVs (for clock faces, windows).
static func disc(r: float, seg := 32, start := 0.0, length := TAU) -> Mesh:
	return cached("disc%.4f:%d:%.3f:%.3f" % [r, seg, start, length], func():
		var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in seg:
			var a0 := start + length * float(i) / seg; var a1 := start + length * float(i + 1) / seg
			for p in [Vector2.ZERO, Vector2(cos(a0), sin(a0)), Vector2(cos(a1), sin(a1))]:
				st.set_normal(Vector3(0, 0, 1)); st.set_uv(Vector2(0.5 + p.x * 0.5, 0.5 - p.y * 0.5)); st.add_vertex(Vector3(p.x * r, p.y * r, 0))
		return st.commit())

## A box whose vertices are displaced by a function (for dust sheets, drapes, quilts).
static func displaced_box(size: Vector3, subdiv: Vector3i, fn: Callable, key: String) -> Mesh:
	return cached("dbox" + key, func():
		var b := BoxMesh.new(); b.size = size; b.subdivide_width = subdiv.x; b.subdivide_height = subdiv.y; b.subdivide_depth = subdiv.z
		var arrays := b.get_mesh_arrays()
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i in verts.size(): verts[i] = fn.call(verts[i])
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = null
		arrays[Mesh.ARRAY_TANGENT] = null
		var am := ArrayMesh.new(); am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var st := SurfaceTool.new(); st.create_from(am, 0); st.generate_normals(); st.generate_tangents()
		return st.commit())

## A plane (facing +Z) displaced by fn(Vector3)->Vector3, for curtains and drapes.
static func displaced_plane(w: float, h: float, sx: int, sy: int, fn: Callable, key: String) -> Mesh:
	return cached("dplane" + key, func():
		var q := PlaneMesh.new(); q.size = Vector2(w, h); q.subdivide_width = sx; q.subdivide_depth = sy; q.orientation = PlaneMesh.FACE_Z
		var arrays := q.get_mesh_arrays()
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i in verts.size(): verts[i] = fn.call(verts[i])
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = null; arrays[Mesh.ARRAY_TANGENT] = null
		var am := ArrayMesh.new(); am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var st := SurfaceTool.new(); st.create_from(am, 0); st.generate_normals(); st.generate_tangents()
		return st.commit())
