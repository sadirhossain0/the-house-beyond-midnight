class_name RoomBuilder
extends RefCounted
## Builds a room: static geometry is collected per (state, material) and merged into a few large
## meshes at the end; colliders go into one StaticBody3D per state; floors carry a footstep
## surface; lights, flames and halos are registered for the LightManager and MultiMesh systems.

const LAYER_WORLD := 1
const LAYER_FLOOR := 2

var world: Node3D
var room: Room
var target: Node3D
var tag := "common"
var _batches := {}

func _init(w: Node3D, r: Room) -> void:
	world = w; room = r; target = r

func into(t: Node3D, p_tag: String) -> RoomBuilder:
	target = t; tag = p_tag; return self
func common() -> RoomBuilder: return into(room, "common")
func now() -> RoomBuilder: return into(room.state_now, "now")
func then() -> RoomBuilder: return into(room.state_then, "then")

static func mat(m: Variant) -> Material:
	if m is Material: return m
	return MaterialLib.get_mat(String(m))

static func euler(rot: Vector3) -> Basis:
	return Basis.from_euler(rot, EULER_ORDER_XYZ)

# ------------------------------------------------------------------------------- geometry
func add_static(mesh: Mesh, m: Variant, xform: Transform3D, shadow := true) -> void:
	var material := mat(m)
	var key := "%d:%d:%s" % [target.get_instance_id(), material.get_instance_id(), shadow]
	if not _batches.has(key):
		_batches[key] = {"target": target, "mat": material, "shadow": shadow, "parts": []}
	_batches[key].parts.append([mesh, xform])

func add_node(mesh: Mesh, m: Variant, xform: Transform3D, parent: Node3D = null, shadow := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat(m)
	mi.transform = xform
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent else target).add_child(mi)
	return mi

func _place(mesh: Mesh, m: Variant, pos: Vector3, rot: Vector3, scl: Vector3, opts: Dictionary) -> Variant:
	var xf := Transform3D(euler(rot).scaled(scl), pos)
	if opts.get("dynamic", false) or opts.has("parent"):
		return add_node(mesh, m, xf, opts.get("parent", null), opts.get("shadow", true))
	add_static(mesh, m, xf, opts.get("shadow", true))
	return null

func box(size: Vector3, m: Variant, pos: Vector3, rot := Vector3.ZERO, opts := {}) -> Variant:
	var r: Variant = _place(MeshKit.box(size), m, pos, rot, Vector3.ONE, opts)
	if opts.get("collide", false):
		collider(pos, size, euler(rot))
	return r

func cyl(rt: float, rb: float, h: float, m: Variant, pos: Vector3, rot := Vector3.ZERO, opts := {}) -> Variant:
	var r: Variant = _place(MeshKit.cyl(rt, rb, h, opts.get("seg", 16), opts.get("open", false)), m, pos, rot, Vector3.ONE, opts)
	if opts.get("collide", false):
		var rr := maxf(rt, rb); collider(pos, Vector3(rr * 2, h, rr * 2))
	return r

func sphere(r: float, m: Variant, pos: Vector3, scl := Vector3.ONE, opts := {}) -> Variant:
	return _place(MeshKit.sphere(r, opts.get("seg", 16), opts.get("rings", 10)), m, pos, opts.get("rot", Vector3.ZERO), scl, opts)

func lathe(points: Array, m: Variant, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE, opts := {}) -> Variant:
	var pts: Array = []
	for p in points: pts.append(Vector2(p[0], p[1]) if p is Array else p)
	return _place(MeshKit.lathe(pts, opts.get("seg", 20)), m, pos, rot, scl, opts)

func quad(w: float, h: float, m: Variant, pos: Vector3, rot := Vector3.ZERO, opts := {}) -> Variant:
	return _place(MeshKit.quad(w, h), m, pos, rot, Vector3.ONE, opts)

# ------------------------------------------------------------------------------- physics
func _body(floor_surface := "") -> StaticBody3D:
	var key := tag if floor_surface == "" else "%s:%s" % [tag, floor_surface]
	var dict: Dictionary = room.bodies if floor_surface == "" else room.floor_bodies
	if dict.has(key): return dict[key]
	var b := StaticBody3D.new()
	b.name = "Body_" + key.replace(":", "_")
	b.collision_layer = LAYER_FLOOR if floor_surface != "" else LAYER_WORLD
	b.collision_mask = 0
	if floor_surface != "": b.set_meta("surface", floor_surface)
	room.add_child(b)
	dict[key] = b
	return b

## Box collider centred at `center` with `size`, optional rotation basis.
func collider(center: Vector3, size: Vector3, basis := Basis(), floor_surface := "") -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new(); shape.size = Vector3(maxf(size.x, 0.02), maxf(size.y, 0.02), maxf(size.z, 0.02))
	cs.shape = shape
	cs.transform = Transform3D(basis, center)
	_body(floor_surface).add_child(cs)
	if tag != "common" and ((tag == "then") != (room.state == "then")): cs.disabled = true
	return cs

## AABB collider from min/max corners.
func collider_box(x0: float, z0: float, x1: float, z1: float, y0 := -1.0, y1 := 6.0) -> CollisionShape3D:
	return collider(Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, (z0 + z1) * 0.5), Vector3(absf(x1 - x0), absf(y1 - y0), absf(z1 - z0)))

## Visible floor plus a walkable slab carrying a footstep surface type.
func floor_rect(x0: float, z0: float, x1: float, z1: float, y: float, m: Variant, surface := "", visual := true) -> void:
	var w := x1 - x0; var d := z1 - z0
	if visual: add_static(MeshKit.box(Vector3(w, 0.1, d)), m, Transform3D(Basis(), Vector3((x0 + x1) * 0.5, y - 0.05, (z0 + z1) * 0.5)))
	collider(Vector3((x0 + x1) * 0.5, y - 0.25, (z0 + z1) * 0.5), Vector3(w, 0.5, d), Basis(), surface if surface != "" else room.surface)

func ceiling(x0: float, z0: float, x1: float, z1: float, y: float, m: Variant) -> void:
	add_static(MeshKit.box(Vector3(x1 - x0, 0.12, z1 - z0)), m, Transform3D(Basis(), Vector3((x0 + x1) * 0.5, y + 0.06, (z0 + z1) * 0.5)), true)
	collider(Vector3((x0 + x1) * 0.5, y + 0.3, (z0 + z1) * 0.5), Vector3(x1 - x0, 0.5, z1 - z0))

## Sloped walkable slab for stairs, rising from y0 at (axis start) to y1.
func ramp(x0: float, z0: float, x1: float, z1: float, y0: float, y1: float, axis := "z", surface := "carpet") -> void:
	var run := absf(z1 - z0) if axis == "z" else absf(x1 - x0)
	var rise := y1 - y0
	var len := sqrt(run * run + rise * rise)
	var ang := atan2(rise, run)
	var center := Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5 - 0.12, (z0 + z1) * 0.5)
	var basis := Basis()
	if axis == "z":
		var dir := signf(z1 - z0)
		basis = Basis(Vector3.RIGHT, -ang * dir)
		collider(center, Vector3(absf(x1 - x0), 0.24, len), basis, surface)
	else:
		var dirx := signf(x1 - x0)
		basis = Basis(Vector3.BACK, ang * dirx)
		collider(center, Vector3(len, 0.24, absf(z1 - z0)), basis, surface)

## Axis-aligned wall from (ax,az) to (bx,bz). n = side the room is on (+1/-1 along the normal).
## openings: [{at, w, h, y, door}] measured along the wall from its min coordinate.
func wall(ax: float, az: float, bx: float, bz: float, o := {}) -> void:
	var along_x := is_equal_approx(az, bz)
	var length := absf(bx - ax) if along_x else absf(bz - az)
	var y0: float = o.get("y0", 0.0)
	var H: float = o.get("h", 4.0)
	var T: float = o.get("t", 0.3)
	var n: float = o.get("n", 1.0)
	var m: Variant = o.get("mat", "plaster")
	var start := minf(ax, bx) if along_x else minf(az, bz)
	var fixed := az if along_x else ax
	var off := fixed - n * T * 0.5
	var openings: Array = o.get("openings", []).duplicate()
	openings.sort_custom(func(a, b): return a.at < b.at)
	var seg := func(s0: float, s1: float, yy0: float, yy1: float, collide: bool) -> void:
		if s1 - s0 < 0.001 or yy1 - yy0 < 0.001: return
		var c := start + (s0 + s1) * 0.5; var l := s1 - s0; var hh := yy1 - yy0
		var size := Vector3(l, hh, T) if along_x else Vector3(T, hh, l)
		var pos := Vector3(c, (yy0 + yy1) * 0.5, off) if along_x else Vector3(off, (yy0 + yy1) * 0.5, c)
		add_static(MeshKit.box(size), m, Transform3D(Basis(), pos))
		if collide: collider(pos, size)
	var cur := 0.0
	for p in openings:
		var a: float = p.at - p.w * 0.5; var b: float = p.at + p.w * 0.5
		var py: float = p.get("y", 0.0)
		seg.call(cur, a, y0, y0 + H, true)
		seg.call(a, b, y0 + py + p.h, y0 + H, true)
		if py > 0.0: seg.call(a, b, y0, y0 + py, true)
		if not p.get("door", false):
			var size2 := Vector3(b - a, H, T) if along_x else Vector3(T, H, b - a)
			var pos2 := Vector3(start + p.at, y0 + H * 0.5, off) if along_x else Vector3(off, y0 + H * 0.5, start + p.at)
			collider(pos2, size2)
		cur = b
	seg.call(cur, length, y0, y0 + H, true)
	# interior trim: skirting, wainscot + dado rail, picture rail, cornice
	var inner := fixed + n * 0.001
	var trim := func(yy: float, hh: float, depth: float, tm: Variant, skip_openings: bool) -> void:
		var pieces: Array = []
		var c0 := 0.0
		if skip_openings:
			for p in openings:
				var py: float = p.get("y", 0.0)
				if yy < y0 + py + p.h and yy + hh > y0 + py:
					pieces.append([c0, p.at - p.w * 0.5]); c0 = p.at + p.w * 0.5
		pieces.append([c0, length])
		for pc in pieces:
			if pc[1] - pc[0] < 0.01: continue
			var l: float = pc[1] - pc[0]; var c: float = start + (pc[0] + pc[1]) * 0.5
			var size := Vector3(l, hh, depth) if along_x else Vector3(depth, hh, l)
			var pos := Vector3(c, yy + hh * 0.5, inner + n * depth * 0.5) if along_x else Vector3(inner + n * depth * 0.5, yy + hh * 0.5, c)
			add_static(MeshKit.box(size), tm, Transform3D(Basis(), pos), false)
	if o.has("wainscot"):
		var wh: float = o.wainscot.get("h", 1.2)
		trim.call(y0, wh, 0.035, o.wainscot.get("mat", "wainscot"), true)
		trim.call(y0 + wh - 0.03, 0.07, 0.07, o.get("rail_mat", "walnut"), true)
	if o.get("skirting", true): trim.call(y0, 0.2, 0.045, o.get("skirt_mat", "walnut"), true)
	if o.has("picture"): trim.call(y0 + o.picture, 0.05, 0.035, o.get("picture_mat", "gilt_dull"), true)
	if o.get("cornice", true):
		trim.call(y0 + H - 0.24, 0.24, 0.13, o.get("cornice_mat", "plaster_moulding"), false)
		trim.call(y0 + H - 0.32, 0.07, 0.2, o.get("cornice_mat", "plaster_moulding"), false)
		trim.call(y0 + H - 0.08, 0.08, 0.26, o.get("cornice_mat", "plaster_moulding"), false)

# ------------------------------------------------------------------------------- lighting
## A pooled-style light: OmniLight3D managed by the LightManager, plus halo and optional flame.
func light(pos: Vector3, o := {}) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = o.get("color", Color(1.0, 0.66, 0.36))
	l.light_energy = o.get("energy", 1.2)
	l.omni_range = o.get("range", 6.0)
	l.omni_attenuation = o.get("attenuation", 1.4)
	l.light_volumetric_fog_energy = o.get("fog", 0.6)
	l.light_specular = o.get("specular", 0.6)
	l.shadow_enabled = false
	l.shadow_bias = 0.08
	l.shadow_normal_bias = 1.2
	l.distance_fade_enabled = true
	l.distance_fade_begin = o.get("fade", 22.0)
	l.distance_fade_length = 6.0
	l.set_meta("base_energy", l.light_energy)
	l.set_meta("flicker", o.get("flicker", 0.0))
	l.set_meta("priority", o.get("priority", 1.0))
	l.set_meta("can_shadow", o.get("shadow", true))
	l.set_meta("seed", randf() * 100.0)
	if o.has("id"): l.set_meta("id", o.id)
	l.visible = o.get("on", true)
	target.add_child(l)
	room.lights.append(l)
	if o.get("glow", true):
		glow(pos, o.get("glow_color", l.light_color), o.get("glow_size", 0.5), o.get("glow_intensity", 0.6), o.get("on", true))
	if o.get("flame", false):
		flame(pos - Vector3(0, 0.03, 0), o.get("on", true), o.get("flame_scale", 1.0))
	return l

func flame(pos: Vector3, lit := true, s := 1.0) -> int:
	room.flames[tag].append({"pos": pos, "lit": lit, "s": s})
	return room.flames[tag].size() - 1

func glow(pos: Vector3, c: Color, size := 0.5, intensity := 0.6, on := true) -> int:
	room.glows[tag].append({"pos": pos, "color": c * intensity, "size": size, "on": on})
	return room.glows[tag].size() - 1

# ------------------------------------------------------------------------------- finalize
func finalize() -> void:
	finalize_batches()
	for t in ["common", "now", "then"]:
		var parent: Node3D = room if t == "common" else (room.state_now if t == "now" else room.state_then)
		if parent == null: continue
		if room.flames[t].size() > 0:
			room.flame_mm[t] = _flame_multimesh(room.flames[t], parent)
		if room.glows[t].size() > 0:
			room.glow_mm[t] = _glow_multimesh(room.glows[t], parent)

## Merge the static geometry added through this builder (safe to call for late additions).
func finalize_batches() -> void:
	for b in _batches.values():
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for part in b.parts:
			var mesh: Mesh = part[0]
			for s in mesh.get_surface_count():
				st.append_from(mesh, s, part[1])
		var material: Material = b.mat
		if material is BaseMaterial3D and material.normal_enabled and not material.uv1_triplanar:
			st.generate_tangents()
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = material
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if b.shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.gi_mode = GeometryInstance3D.GI_MODE_STATIC
		b.target.add_child(mi)
	_batches.clear()

func _flame_multimesh(list: Array, parent: Node3D) -> MultiMeshInstance3D:
	var q := QuadMesh.new(); q.size = Vector2(0.06, 0.15); q.center_offset = Vector3(0, 0.06, 0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = q
	mm.instance_count = list.size()
	for i in list.size():
		var f: Dictionary = list[i]
		mm.set_instance_transform(i, Transform3D(Basis(), f.pos))
		mm.set_instance_custom_data(i, Color(randf(), 1.0 if f.lit else 0.0, f.s, 0))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var sm := ShaderMaterial.new(); sm.shader = load("res://src/fx/flame.gdshader")
	mmi.material_override = sm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-200, -50, -200), Vector3(400, 100, 400))
	parent.add_child(mmi)
	return mmi

func _glow_multimesh(list: Array, parent: Node3D) -> MultiMeshInstance3D:
	var q := QuadMesh.new(); q.size = Vector2(1, 1)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.use_colors = true
	mm.mesh = q
	mm.instance_count = list.size()
	for i in list.size():
		var g: Dictionary = list[i]
		mm.set_instance_transform(i, Transform3D(Basis(), g.pos))
		mm.set_instance_color(i, g.color)
		mm.set_instance_custom_data(i, Color(g.size, 1.0 if g.on else 0.0, randf(), 0))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var sm := ShaderMaterial.new(); sm.shader = load("res://src/fx/glow.gdshader")
	mmi.material_override = sm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-200, -50, -200), Vector3(400, 100, 400))
	parent.add_child(mmi)
	return mmi

## Turn an instanced flame/glow on or off after finalize.
static func set_flame(room_: Room, t: String, index: int, lit: bool) -> void:
	var mmi: MultiMeshInstance3D = room_.flame_mm.get(t)
	if mmi == null or index < 0: return
	var c := mmi.multimesh.get_instance_custom_data(index); c.g = 1.0 if lit else 0.0
	mmi.multimesh.set_instance_custom_data(index, c)

static func set_glow(room_: Room, t: String, index: int, on: bool) -> void:
	var mmi: MultiMeshInstance3D = room_.glow_mm.get(t)
	if mmi == null or index < 0: return
	var c := mmi.multimesh.get_instance_custom_data(index); c.g = 1.0 if on else 0.0
	mmi.multimesh.set_instance_custom_data(index, c)
