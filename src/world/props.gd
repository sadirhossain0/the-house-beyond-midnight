class_name Props
extends RefCounted
## Props for the estate. CC0 Poly Haven models are placed with fitted colliders; bespoke pieces
## (the Grand Clock, chandeliers, staircases, windows, doors, piano...) are built here.

const MODELS := "res://assets/models/props/"
const GEN := "res://assets/textures/generated/"

## Local-space builder for one prop. Static parts are batched by the room builder unless the
## prop is dynamic, in which case they become children of `node`.
class P:
	var B: RoomBuilder
	var xf: Transform3D
	var node: Node3D = null
	func _init(b: RoomBuilder, at := {}, dynamic := false) -> void:
		B = b
		var basis := Basis(Vector3.UP, at.get("ry", 0.0)).scaled(Vector3.ONE * at.get("scale", 1.0))
		xf = Transform3D(basis, at.get("pos", Vector3.ZERO))
		if dynamic:
			node = Node3D.new(); node.transform = xf; B.target.add_child(node)
	func t(pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE) -> Transform3D:
		return Transform3D(RoomBuilder.euler(rot).scaled(scl), pos)
	func put(mesh: Mesh, m: Variant, local: Transform3D, opts := {}) -> MeshInstance3D:
		if node:
			return B.add_node(mesh, m, local, node, opts.get("shadow", true))
		if opts.get("dynamic", false):
			return B.add_node(mesh, m, xf * local, B.target, opts.get("shadow", true))
		B.add_static(mesh, m, xf * local, opts.get("shadow", true))
		return null
	func box(size: Vector3, m: Variant, pos: Vector3, rot := Vector3.ZERO, opts := {}) -> MeshInstance3D:
		return put(MeshKit.box(size), m, t(pos, rot), opts)
	func cyl(rt: float, rb: float, h: float, m: Variant, pos: Vector3, rot := Vector3.ZERO, opts := {}) -> MeshInstance3D:
		return put(MeshKit.cyl(rt, rb, h, opts.get("seg", 16), opts.get("open", false)), m, t(pos, rot), opts)
	func sph(r: float, m: Variant, pos: Vector3, scl := Vector3.ONE, opts := {}) -> MeshInstance3D:
		return put(MeshKit.sphere(r, opts.get("seg", 14), opts.get("rings", 8)), m, t(pos, opts.get("rot", Vector3.ZERO), scl), opts)
	func lathe(points: Array, m: Variant, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE, opts := {}) -> MeshInstance3D:
		var pts: Array = []
		for p in points: pts.append(Vector2(p[0], p[1]))
		return put(MeshKit.lathe(pts, opts.get("seg", 18)), m, t(pos, rot, scl), opts)
	func torus(r: float, th: float, m: Variant, pos: Vector3, rot := Vector3.ZERO, opts := {}) -> MeshInstance3D:
		return put(MeshKit.torus(r, th, opts.get("arc", TAU), opts.get("radial", 8), opts.get("tubular", 24)), m, t(pos, rot, opts.get("scl", Vector3.ONE)), opts)
	func tube(points: Array, r: float, m: Variant, opts := {}) -> MeshInstance3D:
		return put(MeshKit.tube(points, r, opts.get("seg", 20), opts.get("radial", 6), opts.get("taper", 1.0)), m, Transform3D(), opts)
	func quad(w: float, h: float, m: Variant, pos: Vector3, rot := Vector3.ZERO, opts := {}) -> MeshInstance3D:
		return put(MeshKit.quad(w, h), m, t(pos, rot), opts)
	func disc(r: float, m: Variant, pos: Vector3, rot := Vector3.ZERO, opts := {}) -> MeshInstance3D:
		return put(MeshKit.disc(r, opts.get("seg", 32), opts.get("start", 0.0), opts.get("len", TAU)), m, t(pos, rot), opts)
	func world(p: Vector3) -> Vector3: return xf * p
	func light(p: Vector3, o := {}) -> OmniLight3D: return B.light(world(p), o)
	func flame(p: Vector3, lit := true, s := 1.0) -> int: return B.flame(world(p), lit, s)
	func glow(p: Vector3, c: Color, size := 0.5, intensity := 0.6) -> int: return B.glow(world(p), c, size, intensity)
	func collide(x0: float, z0: float, x1: float, z1: float, y0 := 0.0, y1 := 2.0) -> void:
		var c := Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, (z0 + z1) * 0.5)
		B.collider(xf * c, Vector3(absf(x1 - x0), absf(y1 - y0), absf(z1 - z0)) * xf.basis.get_scale(), xf.basis.orthonormalized())

static func decal_mat(tex_name: String, rough := 0.6, emissive := 0.0, alpha := false) -> StandardMaterial3D:
	var key := "decal:%s:%.2f:%.2f:%s" % [tex_name, rough, emissive, alpha]
	if MaterialLib._cache.has(key): return MaterialLib._cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(GEN + tex_name + ".png")
	m.roughness = rough
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if alpha: m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR; m.alpha_scissor_threshold = 0.4
	if emissive > 0.0:
		m.emission_enabled = true; m.emission_texture = m.albedo_texture; m.emission = Color.WHITE; m.emission_energy_multiplier = emissive
	MaterialLib._cache[key] = m
	return m

# ===================================================================================== models
## Place a CC0 model. at: {pos, ry, scale}. opts: collide (bool), size (Vector3 for collider), dynamic.
static func model(B: RoomBuilder, name: String, at := {}, opts := {}) -> Node3D:
	var path := MODELS + name + ".glb"
	if not ResourceLoader.exists(path):
		push_warning("missing model " + name); return null
	var scene: PackedScene = load(path)
	var inst: Node3D = scene.instantiate()
	var s: float = at.get("scale", 1.0)
	inst.transform = Transform3D(Basis(Vector3.UP, at.get("ry", 0.0)).scaled(Vector3.ONE * s), at.get("pos", Vector3.ZERO))
	(opts.get("parent", B.target) as Node3D).add_child(inst)
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if opts.get("shadow", true) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if opts.has("vis_range"): (mi as MeshInstance3D).visibility_range_end = opts.vis_range
	if opts.get("collide", true):
		var aabb := _scene_aabb(inst)
		if aabb.size.length() > 0.01:
			var size: Vector3 = opts.get("col_size", aabb.size)
			B.collider(inst.transform * aabb.get_center(), size * s, inst.transform.basis.orthonormalized())
	return inst

static func _scene_aabb(root: Node3D) -> AABB:
	var out := AABB(); var first := true
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null: continue
		var rel := root.global_transform.affine_inverse() * m.global_transform if root.is_inside_tree() else _rel_xform(root, m)
		var a: AABB = rel * m.mesh.get_aabb()
		if first: out = a; first = false
		else: out = out.merge(a)
	return out

static func _rel_xform(root: Node3D, n: Node3D) -> Transform3D:
	var t := Transform3D(); var cur: Node = n
	while cur and cur != root:
		if cur is Node3D: t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t

# ===================================================================================== clocks
## The Grand Clock: seven metres of walnut and gilt, twelve chime lamps round the face.
static func grand_clock(B: RoomBuilder, at: Dictionary) -> Dictionary:
	var p := P.new(B, at)
	var wal := "walnut"; var gilt := "gilt"
	p.box(Vector3(2.6, 0.5, 1.3), wal, Vector3(0, 0.25, 0)); p.box(Vector3(2.8, 0.08, 1.4), gilt, Vector3(0, 0.52, 0))
	p.box(Vector3(2.3, 3.3, 1.05), wal, Vector3(0, 2.2, 0))
	for s in [-1, 1]:
		p.cyl(0.12, 0.12, 3.2, wal, Vector3(s * 1.05, 2.2, 0.48), Vector3.ZERO, {"seg": 14})
		p.cyl(0.16, 0.16, 0.12, gilt, Vector3(s * 1.05, 3.85, 0.48)); p.cyl(0.16, 0.16, 0.12, gilt, Vector3(s * 1.05, 0.6, 0.48))
	p.box(Vector3(1.4, 2.5, 0.04), "glass", Vector3(0, 2.2, 0.53), Vector3.ZERO, {"shadow": false})
	p.box(Vector3(1.55, 0.08, 0.08), gilt, Vector3(0, 3.47, 0.55)); p.box(Vector3(1.55, 0.08, 0.08), gilt, Vector3(0, 0.93, 0.55))
	# the stopped pendulum (trembles, as if it wants to swing)
	var pend := Node3D.new(); pend.transform = p.xf * Transform3D(Basis(), Vector3(0, 3.3, 0.3)); B.target.add_child(pend)
	B.add_node(MeshKit.cyl(0.02, 0.02, 2.0, 6), "brass", Transform3D(Basis(), Vector3(0, -1.0, 0)), pend)
	B.add_node(MeshKit.cyl(0.28, 0.28, 0.05, 28), "brass", Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, -2.05, 0)), pend)
	for s in [-1, 1]: B.add_node(MeshKit.cyl(0.07, 0.07, 1.3, 10), "brass_dark", Transform3D(Basis(), Vector3(s * 0.45, -1.2, -0.15)), pend)
	# hood and face
	p.box(Vector3(2.7, 2.4, 1.3), wal, Vector3(0, 5.05, 0))
	var face := StandardMaterial3D.new()
	face.albedo_texture = load(GEN + "clock_grand.png"); face.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	face.emission_enabled = true; face.emission_texture = face.albedo_texture; face.emission = Color(0.55, 1.0, 0.78); face.emission_energy_multiplier = 0.25; face.roughness = 0.5
	p.quad(1.78, 1.78, face, Vector3(0, 5.1, 0.661), Vector3.ZERO, {"shadow": false})
	p.torus(0.9, 0.06, gilt, Vector3(0, 5.1, 0.66), Vector3.ZERO, {"tubular": 48})
	p.torus(0.98, 0.03, gilt, Vector3(0, 5.1, 0.66), Vector3.ZERO, {"tubular": 48})
	var lamps: Array = []
	for i in 12:
		var a := float(i) / 12.0 * TAU
		var lp := Vector3(sin(a) * 1.14, 5.1 + cos(a) * 1.14, 0.66)
		p.cyl(0.07, 0.07, 0.05, "brass_dark", lp, Vector3(PI * 0.5, 0, 0), {"seg": 12})
		var lm := StandardMaterial3D.new(); lm.albedo_color = Color(0.23, 0.19, 0.12); lm.roughness = 0.3
		lm.emission_enabled = true; lm.emission = Color(1.0, 0.8, 0.45); lm.emission_energy_multiplier = 0.0
		lamps.append(B.add_node(MeshKit.sphere(0.055, 14, 8), lm, p.xf * Transform3D(Basis(), lp + Vector3(0, 0, 0.03))))
	for s in [-1, 1]: p.box(Vector3(1.3, 0.25, 1.35), wal, Vector3(s * 0.75, 6.45, 0), Vector3(0, 0, s * -0.42))
	p.box(Vector3(2.9, 0.12, 1.4), gilt, Vector3(0, 6.28, 0))
	p.lathe([[0.0, 0], [0.18, 0.02], [0.22, 0.2], [0.12, 0.38], [0.2, 0.5], [0.05, 0.75], [0.0, 0.85]], gilt, Vector3(0, 6.6, 0.1))
	for s in [-1, 1]:
		p.sph(0.12, gilt, Vector3(s * 1.25, 6.45, 0.4))
		p.cyl(0.1, 0.12, 2.3, wal, Vector3(s * 1.2, 5.05, 0.55), Vector3.ZERO, {"seg": 12})
		p.cyl(0.15, 0.15, 0.1, gilt, Vector3(s * 1.2, 6.2, 0.55))
	for xy in [[-1.0, 4.1], [1.0, 4.1], [-1.0, 6.0], [1.0, 6.0]]: p.sph(0.08, gilt, Vector3(xy[0], xy[1], 0.66), Vector3(1, 1, 0.4))
	p.collide(-1.4, -0.7, 1.4, 0.8, 0, 7)
	return {"lamps": lamps, "pendulum": pend, "face": face, "front": p.world(Vector3(0, 0, 1.9))}

## A gilded ormolu pedestal clock that anchors a room to the sealed night (shift point).
static func anchor_clock(B: RoomBuilder, at: Dictionary) -> Dictionary:
	var p := P.new(B, at)
	p.lathe([[0.0, 0], [0.45, 0], [0.45, 0.1], [0.3, 0.2], [0.22, 0.9], [0.3, 1.0], [0.36, 1.05], [0.0, 1.06]], "stone_trim", Vector3.ZERO, Vector3.ZERO, Vector3.ONE, {"seg": 24})
	p.torus(0.36, 0.03, "gilt", Vector3(0, 1.04, 0), Vector3(PI * 0.5, 0, 0))
	p.box(Vector3(0.62, 0.7, 0.34), "gilt", Vector3(0, 1.42, 0))
	p.box(Vector3(0.54, 0.62, 0.36), "ebony", Vector3(0, 1.42, 0))
	var face := StandardMaterial3D.new(); face.albedo_texture = load(GEN + "clock_dark.png"); face.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	face.emission_enabled = true; face.emission_texture = face.albedo_texture; face.emission = Color(0.4, 1.0, 0.7); face.emission_energy_multiplier = 1.4
	p.quad(0.44, 0.44, face, Vector3(0, 1.44, 0.185), Vector3.ZERO, {"shadow": false})
	p.torus(0.23, 0.02, "gilt", Vector3(0, 1.44, 0.186))
	for s in [-1, 1]: p.lathe([[0.0, 0], [0.05, 0.05], [0.02, 0.2], [0.05, 0.3], [0.0, 0.36]], "gilt", Vector3(s * 0.33, 1.77, 0))
	p.lathe([[0.0, 0], [0.1, 0.05], [0.04, 0.2], [0.12, 0.3], [0.0, 0.45]], "gilt", Vector3(0, 1.77, 0))
	var l := p.light(Vector3(0, 1.45, 0.4), {"color": Color(0.35, 1.0, 0.65), "energy": 1.4, "range": 4.5, "priority": 2.0, "glow_size": 1.1, "glow_intensity": 0.35, "flicker": 0.05, "fog": 1.5})
	p.collide(-0.45, -0.45, 0.45, 0.45, 0, 2.2)
	return {"face": face, "light": l, "front": p.world(Vector3(0, 0, 1.2))}

# ===================================================================================== lighting fixtures
static func chandelier(B: RoomBuilder, at: Dictionary, o := {}) -> Dictionary:
	var p := P.new(B, at)
	var tiers: int = o.get("tiers", 2); var radius: float = o.get("radius", 1.2); var arms: int = o.get("arms", 10)
	var drop: float = o.get("drop", 2.5); var lit: float = o.get("lit", 1.0); var broken: bool = o.get("broken", false)
	var gilt := "gilt_dull" if broken else "gilt"
	var rng := RandomNumberGenerator.new(); rng.seed = int(radius * 100) + tiers
	if not broken: p.cyl(0.015, 0.015, drop, "iron", Vector3(0, -drop * 0.5, 0), Vector3.ZERO, {"seg": 6})
	var cy := 0.0 if broken else -drop
	p.lathe([[0.0, 0.6], [0.12, 0.5], [0.06, 0.25], [0.18, 0.05], [0.12, -0.15], [0.03, -0.35], [0.0, -0.4]], gilt, Vector3(0, cy, 0), Vector3.ZERO, Vector3.ONE, {"seg": 20})
	var flames: Array = []
	var crystals: Array = []
	for tier in tiers:
		var R := radius * (1.0 - tier * 0.42); var y := cy - 0.05 + tier * 0.55
		var n := maxi(5, int(round(arms * (1.0 - tier * 0.35))))
		p.torus(R, 0.025, gilt, Vector3(0, y, 0), Vector3(PI * 0.5, 0, 0), {"tubular": 40})
		for i in n:
			var a := float(i) / n * TAU + tier * 0.3
			var c := Vector3(cos(a) * R, y, sin(a) * R)
			p.tube([Vector3(cos(a) * 0.1, cy + 0.05 + tier * 0.4, sin(a) * 0.1), Vector3(cos(a) * R * 0.5, y - 0.15, sin(a) * R * 0.5), c + Vector3(0, 0.02, 0)], 0.018, gilt, {"seg": 10, "radial": 5})
			p.cyl(0.05, 0.03, 0.05, gilt, c + Vector3(0, 0.05, 0), Vector3.ZERO, {"seg": 10})
			var tilt := (rng.randf() - 0.5) * 0.9 if broken else 0.0
			p.cyl(0.018, 0.018, 0.16, "wax", c + Vector3(0, 0.16, 0), Vector3(0, 0, tilt), {"seg": 8})
			if not broken: flames.append(p.flame(c + Vector3(0, 0.27, 0), rng.randf() < lit, 1.1))
			for k in 3: crystals.append(p.world(Vector3(c.x * 0.92 + (rng.randf() - 0.5) * 0.05, y - 0.08 - k * 0.07, c.z * 0.92)))
		for i in n * 3:
			var a2 := float(i) / (n * 3) * TAU
			crystals.append(p.world(Vector3(cos(a2) * R * 0.98, y - 0.12 - sin(i * 1.1) * 0.06, sin(a2) * R * 0.98)))
	for k in 14: crystals.append(p.world(Vector3((rng.randf() - 0.5) * 0.25, cy - 0.45 - k * 0.04, (rng.randf() - 0.5) * 0.25)))
	# instanced crystal drops
	var drop_mesh := PrismMesh.new(); drop_mesh.size = Vector3(0.04, 0.07, 0.04)
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.mesh = drop_mesh; mm.instance_count = crystals.size()
	var inv := B.target.global_transform.affine_inverse() if B.target.is_inside_tree() else Transform3D()
	for i in crystals.size():
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).rotated(Vector3.RIGHT, PI if not broken else rng.randf() * PI), crystals[i]))
	var mmi := MultiMeshInstance3D.new(); mmi.multimesh = mm; mmi.material_override = MaterialLib.get_mat("crystal")
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	B.target.add_child(mmi)
	var l: OmniLight3D = null
	if not broken:
		l = p.light(Vector3(0, cy - 0.1, 0), {"color": Color(1.0, 0.76, 0.48), "energy": o.get("energy", 3.5) * (0.45 + 0.55 * lit), "range": o.get("range", 16.0), "priority": 4.0, "flicker": 0.04, "glow_size": 3.4 * radius, "glow_intensity": 0.22 * lit + 0.05, "fog": 1.2, "id": o.get("id", "")})
	return {"flames": flames, "light": l, "crystals": mmi, "lit": lit}

static func sconce(B: RoomBuilder, at: Dictionary, o := {}) -> OmniLight3D:
	var p := P.new(B, at)
	var lit: bool = o.get("lit", true); var broken: bool = o.get("broken", false)
	p.lathe([[0.0, 0], [0.09, 0.01], [0.07, 0.1], [0.03, 0.22], [0.0, 0.26]], "brass", Vector3(0, -0.15, 0.02), Vector3.ZERO, Vector3(1, 1, 0.3))
	p.tube([Vector3(0, 0, 0.03), Vector3(0, -0.05, 0.12), Vector3(0, 0.03, 0.2)], 0.012, "brass", {"seg": 8})
	p.cyl(0.04, 0.025, 0.04, "brass", Vector3(0, 0.05, 0.2), Vector3.ZERO, {"seg": 10})
	if broken:
		p.cyl(0.018, 0.018, 0.06, "wax", Vector3(0.02, 0.09, 0.2), Vector3(0, 0, 0.6))
		return null
	p.cyl(0.018, 0.018, 0.14, "wax", Vector3(0, 0.14, 0.2), Vector3.ZERO, {"seg": 8})
	p.sph(0.012, "wax", Vector3(0.015, 0.1, 0.205)); p.sph(0.01, "wax", Vector3(-0.012, 0.12, 0.21))
	return p.light(Vector3(0, 0.25, 0.22), {"color": o.get("color", Color(1.0, 0.64, 0.34)), "energy": o.get("energy", 0.9) if lit else 0.0, "range": 5.0, "flicker": 0.22, "glow_size": 0.45, "on": lit, "flame": true})

static func candelabra(B: RoomBuilder, at: Dictionary, o := {}) -> OmniLight3D:
	var p := P.new(B, at, o.get("dynamic", false))
	var arms: int = o.get("arms", 5); var lit: bool = o.get("lit", true); var h: float = o.get("h", 0.55)
	p.lathe([[0.0, 0], [0.12, 0.0], [0.1, 0.03], [0.03, 0.08], [0.05, h * 0.5], [0.025, h * 0.8], [0.04, h], [0.0, h + 0.01]], "silver", Vector3.ZERO)
	for i in arms:
		var a := (float(i) / (arms - 1) - 0.5) * PI * 0.9
		var mid := i == (arms - 1) / 2
		var x := 0.0 if mid else sin(a) * 0.2
		var y := h + 0.05 if mid else h - 0.02
		if x != 0.0: p.tube([Vector3(0, h * 0.75, 0), Vector3(x * 0.5, h * 0.7, 0), Vector3(x, y, 0)], 0.01, "silver", {"seg": 8})
		p.cyl(0.03, 0.02, 0.03, "silver", Vector3(x, y, 0), Vector3.ZERO, {"seg": 8})
		p.cyl(0.015, 0.015, 0.16, "wax", Vector3(x, y + 0.09, 0), Vector3.ZERO, {"seg": 8})
		if p.node == null: p.flame(Vector3(x, y + 0.2, 0), lit)
	return p.light(Vector3(0, h + 0.25, 0), {"color": Color(1.0, 0.7, 0.4), "energy": 1.1 if lit else 0.0, "range": 5.5, "flicker": 0.28, "glow_size": 0.8, "on": lit})

static func candle(B: RoomBuilder, at: Dictionary, o := {}) -> OmniLight3D:
	var p := P.new(B, at)
	var h: float = o.get("h", 0.18)
	p.cyl(0.05, 0.06, 0.02, "brass", Vector3(0, 0.01, 0), Vector3.ZERO, {"seg": 12})
	p.cyl(0.018, 0.018, h, "wax", Vector3(0, 0.02 + h * 0.5, 0), Vector3.ZERO, {"seg": 8})
	p.sph(0.012, "wax", Vector3(0.015, 0.02 + h * 0.7, 0.01))
	if o.get("lit", true):
		return p.light(Vector3(0, 0.05 + h + 0.03, 0), {"energy": 0.55, "range": 3.5, "flicker": 0.35, "glow_size": 0.35, "flame": true})
	return null

# ===================================================================================== architecture
static func door(B: RoomBuilder, at: Dictionary, o := {}) -> Dictionary:
	var p := P.new(B, at)
	var w: float = o.get("w", 1.2); var h: float = o.get("h", 2.4); var dbl: bool = o.get("double", false)
	var wood: String = o.get("mat", "mahogany"); var frame: String = o.get("frame", "walnut")
	var fw := 0.14
	p.box(Vector3(fw, h + fw, 0.22), frame, Vector3(-w * 0.5 - fw * 0.5, (h + fw) * 0.5, 0))
	p.box(Vector3(fw, h + fw, 0.22), frame, Vector3(w * 0.5 + fw * 0.5, (h + fw) * 0.5, 0))
	p.box(Vector3(w + fw * 2, fw, 0.22), frame, Vector3(0, h + fw * 0.5, 0))
	p.box(Vector3(w + fw * 2 + 0.2, 0.12, 0.28), frame, Vector3(0, h + fw + 0.06, 0))
	var leaves: Array = []
	var nl := 2 if dbl else 1
	var lw := w / nl
	for i in nl:
		var hinge := (-w * 0.5 if i == 0 else w * 0.5) if dbl else -w * 0.5
		var dir := (1.0 if i == 0 else -1.0) if dbl else 1.0
		var pivot := Node3D.new(); pivot.transform = p.xf * Transform3D(Basis(), Vector3(hinge, 0, 0)); B.target.add_child(pivot)
		var cx := dir * lw * 0.5
		B.add_node(MeshKit.box(Vector3(lw - 0.01, h - 0.01, 0.06)), wood, Transform3D(Basis(), Vector3(cx, h * 0.5, 0)), pivot)
		for py_ph in [[h * 0.27, h * 0.38], [h * 0.72, h * 0.38]]:
			if o.get("glass", false) and py_ph[0] > h * 0.5:
				B.add_node(MeshKit.box(Vector3(lw * 0.62, py_ph[1], 0.02)), "window_night", Transform3D(Basis(), Vector3(cx, py_ph[0], 0.03)), pivot)
				continue
			for side in [-1, 1]:
				B.add_node(MeshKit.box(Vector3(lw * 0.66, py_ph[1], 0.03)), wood, Transform3D(Basis(), Vector3(cx, py_ph[0], side * 0.04)), pivot)
				B.add_node(MeshKit.box(Vector3(lw * 0.54, py_ph[1] * 0.85, 0.03)), wood, Transform3D(Basis(), Vector3(cx, py_ph[0], side * 0.055)), pivot)
		var hx := dir * (lw - 0.1)
		for side in [-1, 1]:
			B.add_node(MeshKit.sphere(0.035, 10, 6), "brass", Transform3D(Basis(), Vector3(hx, h * 0.47, side * 0.08)), pivot)
			B.add_node(MeshKit.box(Vector3(0.05, 0.16, 0.012)), "brass", Transform3D(Basis(), Vector3(hx, h * 0.47, side * 0.035)), pivot)
		if o.has("number") and i == 0:
			B.add_node(MeshKit.quad(0.12, 0.12), decal_mat("plate_%d" % o.number, 0.35, 0.0, true), Transform3D(Basis(), Vector3(cx, h * 0.82, 0.075)), pivot)
		pivot.rotation.y = dir * -o.get("open", 0.0)
		leaves.append({"pivot": pivot, "dir": dir})
	return {"leaves": leaves, "w": w, "h": h}

static func arched_window(B: RoomBuilder, at: Dictionary, o := {}) -> void:
	var p := P.new(B, at)
	var w: float = o.get("w", 1.6); var h: float = o.get("h", 3.2); var sill: float = o.get("sill", 0.9)
	var fr := "walnut"
	p.box(Vector3(w + 0.3, 0.1, 0.35), "stone_trim", Vector3(0, sill - 0.05, 0.08))
	var glass: Variant = o.get("glass", "window_night")
	var rect_h := h - w * 0.5
	p.quad(w, rect_h, glass, Vector3(0, sill + rect_h * 0.5, -0.05), Vector3.ZERO, {"shadow": false})
	p.disc(w * 0.5, glass, Vector3(0, sill + rect_h, -0.05), Vector3.ZERO, {"len": PI, "seg": 24, "shadow": false})
	for x in [-w * 0.5, -w / 6.0, w / 6.0, w * 0.5]: p.box(Vector3(0.05, rect_h, 0.06), fr, Vector3(x, sill + rect_h * 0.5, -0.03))
	for k in range(1, 4): p.box(Vector3(w, 0.04, 0.05), fr, Vector3(0, sill + rect_h * k / 4.0, -0.03))
	p.torus(w * 0.5, 0.03, fr, Vector3(0, sill + rect_h, -0.03), Vector3.ZERO, {"arc": PI})
	p.torus(w * 0.5 + 0.1, 0.07, "plaster_moulding", Vector3(0, sill + rect_h, 0.02), Vector3.ZERO, {"arc": PI})
	for s in [-1, 1]: p.box(Vector3(0.14, rect_h, 0.1), "plaster_moulding", Vector3(s * (w * 0.5 + 0.1), sill + rect_h * 0.5, 0.02))
	var cur: Variant = o.get("curtains", "velvet_red")
	if cur != null:
		for s in [-1, 1]: curtain(p, s * (w * 0.5 + 0.25), sill + h + 0.25, 0.25, 0.75, h + sill + 0.2, cur, o.get("tattered", false), s)
		p.box(Vector3(w + 1.3, 0.25, 0.18), "gilt", Vector3(0, sill + h + 0.35, 0.25))
		p.cyl(0.03, 0.03, w + 1.4, "brass", Vector3(0, sill + h + 0.2, 0.22), Vector3(0, 0, PI * 0.5))

static func curtain(p: P, x: float, top: float, z: float, width: float, height: float, m: Variant, tattered: bool, side: int) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = int(x * 100 + top)
	var fn := func(v: Vector3) -> Vector3:
		var u := v.x / width + 0.5; var vv := v.y / height + 0.5
		var gather := 1.0 - exp(-pow((vv - 0.38) / 0.12, 2.0)) * 0.55
		var out := Vector3((v.x + side * width * 0.2 * (1.0 - gather)) * gather, v.y, sin(u * PI * 7.0) * 0.05 + (1.0 - gather) * 0.08)
		if tattered and vv < 0.18: out.y += rng.randf() * 0.25 * (0.18 - vv) * 4.0
		return out
	var key := "curtain%.2f:%.2f:%s:%d" % [width, height, tattered, side]
	var mesh := MeshKit.displaced_plane(width, height, 14, 18, fn, key)
	var mm: Material = RoomBuilder.mat(m)
	if mm is BaseMaterial3D: mm.cull_mode = BaseMaterial3D.CULL_DISABLED
	p.put(mesh, mm, p.t(Vector3(x, top - height * 0.5, z)))
	p.torus(0.1, 0.015, "gilt", Vector3(x + side * 0.05, top - height * 0.62, z + 0.05), Vector3.ZERO, {"tubular": 12})

static func column(B: RoomBuilder, at: Dictionary, o := {}) -> void:
	var p := P.new(B, at)
	var h: float = o.get("h", 6.0); var r: float = o.get("r", 0.32); var m: String = o.get("mat", "stone_trim"); var cap: String = o.get("capital", "gilt")
	p.box(Vector3(r * 2.6, 0.3, r * 2.6), m, Vector3(0, 0.15, 0))
	p.lathe([[r * 1.2, 0], [r * 1.25, 0.1], [r * 1.05, 0.22], [r, 0.3]], m, Vector3(0, 0.3, 0))
	p.cyl(r * 0.92, r, h - 1.1, m, Vector3(0, 0.6 + (h - 1.1) * 0.5, 0), Vector3.ZERO, {"seg": 24})
	for i in 12:
		var a := float(i) / 12 * TAU
		p.box(Vector3(0.035, h - 1.3, 0.035), m, Vector3(cos(a) * r * 0.95, 0.6 + (h - 1.1) * 0.5, sin(a) * r * 0.95))
	p.lathe([[r, 0], [r * 1.3, 0.25], [r * 1.5, 0.42], [r * 1.5, 0.5], [0.0, 0.5]], cap, Vector3(0, h - 0.5, 0))
	p.box(Vector3(r * 3.2, 0.12, r * 3.2), m, Vector3(0, h - 0.06, 0))
	p.collide(-r * 1.2, -r * 1.2, r * 1.2, r * 1.2, 0, h)

static func pilaster(B: RoomBuilder, at: Dictionary, o := {}) -> void:
	var p := P.new(B, at)
	var h: float = o.get("h", 6.0); var w: float = o.get("w", 0.5); var m: String = o.get("mat", "plaster_moulding"); var cap: String = o.get("capital", "gilt")
	p.box(Vector3(w + 0.12, 0.35, 0.16), "walnut", Vector3(0, 0.175, 0.08))
	p.box(Vector3(w, h - 0.8, 0.1), m, Vector3(0, 0.35 + (h - 0.8) * 0.5, 0.05))
	for x in [-w * 0.3, 0.0, w * 0.3]: p.box(Vector3(0.04, h - 1.2, 0.03), "gilt_dull", Vector3(x, 0.55 + (h - 1.2) * 0.5, 0.11))
	p.box(Vector3(w + 0.18, 0.18, 0.2), cap, Vector3(0, h - 0.36, 0.1))
	p.box(Vector3(w + 0.3, 0.12, 0.26), cap, Vector3(0, h - 0.2, 0.13))
	for s in [-1, 1]: p.sph(0.06, cap, Vector3(s * w * 0.5, h - 0.27, 0.2), Vector3(1, 1, 0.5))

static func portrait(B: RoomBuilder, at: Dictionary, tex_name: String, o := {}) -> Dictionary:
	var p := P.new(B, at)
	var w: float = o.get("w", 1.0); var h: float = o.get("h", 1.3)
	var pm := StandardMaterial3D.new(); pm.albedo_texture = load(GEN + tex_name + ".png"); pm.roughness = 0.45
	pm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var pic := p.quad(w, h, pm, Vector3(0, 0, 0.04), Vector3.ZERO, {"shadow": false, "dynamic": o.get("dynamic_pic", false)})
	var fw := 0.12; var frame: String = o.get("frame", "gilt")
	for r in [[0.0, h * 0.5 + fw * 0.5, w + fw * 2, fw], [0.0, -h * 0.5 - fw * 0.5, w + fw * 2, fw], [-w * 0.5 - fw * 0.5, 0.0, fw, h], [w * 0.5 + fw * 0.5, 0.0, fw, h]]:
		p.box(Vector3(r[2], r[3], 0.08), frame, Vector3(r[0], r[1], 0.04))
		p.box(Vector3(r[2] * 0.98 if r[2] > r[3] else r[2] * 0.4, r[3] * 0.4 if r[2] > r[3] else r[3] * 0.98, 0.1), frame, Vector3(r[0], r[1], 0.05))
	for c in [[-1, 1], [1, 1], [-1, -1], [1, -1]]: p.sph(0.06, frame, Vector3(c[0] * (w * 0.5 + fw * 0.5), c[1] * (h * 0.5 + fw * 0.5), 0.09), Vector3(1, 1, 0.5))
	p.sph(0.08, frame, Vector3(0, h * 0.5 + fw, 0.08), Vector3(1.6, 1, 0.5))
	if o.get("light", true):
		p.box(Vector3(0.4, 0.04, 0.04), "brass", Vector3(0, h * 0.5 + 0.25, 0.14))
		p.cyl(0.03, 0.04, 0.38, "brass", Vector3(0, h * 0.5 + 0.25, 0.2), Vector3(0, 0, PI * 0.5))
		p.light(Vector3(0, h * 0.5 + 0.12, 0.35), {"color": Color(1.0, 0.85, 0.6), "energy": 0.35, "range": 2.2, "glow_size": 0.4, "glow_intensity": 0.25, "shadow": false})
	return {"mat": pm, "pic": pic}

static func mirror(B: RoomBuilder, at: Dictionary, o := {}) -> Dictionary:
	var p := P.new(B, at)
	var w: float = o.get("w", 1.6); var h: float = o.get("h", 3.2)
	var m := "mirror_dusty" if o.get("dusty", false) else "mirror"
	var rect_h := h - w * 0.5
	var glass := p.quad(w, rect_h, m, Vector3(0, rect_h * 0.5, 0.03), Vector3.ZERO, {"shadow": false, "dynamic": true})
	var top := p.disc(w * 0.5, m, Vector3(0, rect_h, 0.03), Vector3.ZERO, {"len": PI, "seg": 24, "shadow": false, "dynamic": true})
	var fw := 0.14; var frame: String = o.get("frame", "gilt")
	for s in [-1, 1]: p.box(Vector3(fw, rect_h, 0.12), frame, Vector3(s * (w * 0.5 + fw * 0.5), rect_h * 0.5, 0.05))
	p.box(Vector3(w + fw * 2, fw, 0.12), frame, Vector3(0, -fw * 0.5, 0.05))
	p.torus(w * 0.5 + fw * 0.5, fw * 0.5, frame, Vector3(0, rect_h, 0.05), Vector3.ZERO, {"arc": PI, "tubular": 28})
	p.lathe([[0.0, 0], [0.12, 0.05], [0.05, 0.2], [0.14, 0.3], [0.0, 0.42]], frame, Vector3(0, h, 0.06), Vector3.ZERO, Vector3(1, 1, 0.4))
	return {"glass": glass, "top": top, "center": p.world(Vector3(0, h * 0.45, 0.2)), "w": w, "h": h}

static func rug(B: RoomBuilder, at: Dictionary, o := {}) -> void:
	var p := P.new(B, at)
	var w: float = o.get("w", 4.0); var d: float = o.get("d", 3.0)
	var m := MaterialLib.get_mat(o.get("mat", "rug_hall"))
	p.quad(w, d, m, Vector3(0, 0.012, 0), Vector3(-PI * 0.5, 0, 0), {"shadow": false})
	p.box(Vector3(w, 0.01, d), "black", Vector3(0, 0.005, 0), Vector3.ZERO, {"shadow": false})
	for s in [-1, 1]:
		for i in int(w * 12):
			p.box(Vector3(0.012, 0.005, 0.08), "linen", Vector3(-w * 0.5 + (i + 0.5) / 12.0, 0.006, s * (d * 0.5 + 0.035)), Vector3.ZERO, {"shadow": false})

static func spectral_chains(B: RoomBuilder, at: Dictionary, o := {}) -> Dictionary:
	var w: float = o.get("w", 2.4); var h: float = o.get("h", 2.6)
	var p := P.new(B, at, true)
	var m := StandardMaterial3D.new(); m.albedo_color = Color(0.16, 0.35, 0.29, 0.85); m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true; m.emission = Color(0.29, 1.0, 0.69); m.emission_energy_multiplier = 1.6; m.metallic = 0.6; m.roughness = 0.4
	for dir in [-1, 1]:
		var n := 16
		for i in n:
			var t := float(i) / (n - 1)
			var x: float = (t - 0.5) * w; var y: float = h * 0.5 + dir * (t - 0.5) * h * 0.7 - sin(t * PI) * 0.15
			p.torus(0.07, 0.018, m, Vector3(x, y, 0.12), Vector3(0, PI * 0.5 if i % 2 else 0.0, atan2(dir * h * 0.7, w)), {"radial": 6, "tubular": 12})
	p.box(Vector3(0.3, 0.34, 0.1), m, Vector3(0, h * 0.5, 0.16))
	p.torus(0.1, 0.025, m, Vector3(0, h * 0.5 + 0.2, 0.16), Vector3.ZERO, {"arc": PI})
	var l := OmniLight3D.new(); l.light_color = Color(0.35, 1.0, 0.7); l.light_energy = 0.8; l.omni_range = 4.0; l.position = Vector3(0, h * 0.5, 0.5); p.node.add_child(l)
	return {"node": p.node, "mat": m}

## Straight stair flight along Z from zs (y0) to ze (y1), with runner, nosings, brass rods,
## turned balusters on the chosen sides, a handrail and newel posts.
static func stair_flight(B: RoomBuilder, x0: float, x1: float, zs: float, ze: float, y0: float, y1: float, steps: int, rails := [true, true]) -> void:
	var dz := (ze - zs) / steps; var dy := (y1 - y0) / steps; var w := x1 - x0; var cx := (x0 + x1) * 0.5
	for i in steps:
		var z := zs + dz * (i + 0.5); var y := y0 + dy * (i + 1)
		B.box(Vector3(w, maxf(0.05, y - y0 + 0.02), absf(dz) + 0.01), "walnut", Vector3(cx, (y + y0) * 0.5 - 0.01, z))
		B.box(Vector3(w * 0.62, 0.014, absf(dz) * 0.98), "runner", Vector3(cx, y + 0.007, z), Vector3.ZERO, {"shadow": false})
		B.box(Vector3(w * 0.62, dy, 0.012), "runner", Vector3(cx, y - dy * 0.5, z - dz * 0.5 + signf(dz) * 0.006), Vector3.ZERO, {"shadow": false})
		B.cyl(0.012, 0.012, w * 0.66, "brass", Vector3(cx, y - dy + 0.02, z - dz * 0.5 + signf(dz) * 0.02), Vector3(0, 0, PI * 0.5), {"seg": 6})
		B.box(Vector3(w + 0.04, 0.035, 0.05), "walnut", Vector3(cx, y - 0.015, z + dz * 0.5))
	B.ramp(x0, zs, x1, ze, y0, y1, "z", "carpet")
	var bal_pts: Array = []
	for k in 2:
		if not rails[k]: continue
		var x := x0 + 0.06 if k == 0 else x1 - 0.06
		for i in steps:
			bal_pts.append(Vector3(x, y0 + dy * (i + 1), zs + dz * (i + 0.5)))
		var a := Vector3(x, y0 + 1.0, zs); var b := Vector3(x, y1 + 1.0, ze)
		var rail_len := a.distance_to(b)
		var basis := Basis.looking_at(b - a, Vector3.UP)
		B.add_static(MeshKit.box(Vector3(0.09, 0.07, rail_len)), "mahogany", Transform3D(basis, (a + b) * 0.5))
		B.box(Vector3(0.16, 1.2, 0.16), "walnut", Vector3(x, y0 + 0.6, zs)); B.sphere(0.1, "brass", Vector3(x, y0 + 1.28, zs))
		var length := Vector3(0, y1 - y0, ze - zs).length()
		B.collider((a + b) * 0.5 - Vector3(0, 0.3, 0), Vector3(0.16, 1.6, rail_len), basis)
	balusters(B, bal_pts)

## Instanced turned balusters (one draw call).
static func balusters(B: RoomBuilder, pts: Array, m := "walnut", h := 0.92) -> void:
	if pts.is_empty(): return
	var prof := [Vector2(0, 0), Vector2(0.045, 0), Vector2(0.04, 0.06), Vector2(0.025, 0.12), Vector2(0.05, 0.3), Vector2(0.03, 0.5), Vector2(0.022, 0.62), Vector2(0.035, 0.74), Vector2(0.025, 0.86), Vector2(0.03, h), Vector2(0, h)]
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.mesh = MeshKit.lathe(prof, 10); mm.instance_count = pts.size()
	for i in pts.size(): mm.set_instance_transform(i, Transform3D(Basis(), pts[i]))
	var mmi := MultiMeshInstance3D.new(); mmi.multimesh = mm; mmi.material_override = MaterialLib.get_mat(m)
	B.target.add_child(mmi)

static func balustrade(B: RoomBuilder, a: Vector3, b: Vector3, o := {}) -> void:
	var spacing: float = o.get("spacing", 0.18); var h: float = o.get("h", 0.95)
	var len := a.distance_to(b)
	var n := maxi(2, int(len / spacing))
	var pts: Array = []
	for i in n + 1: pts.append(a.lerp(b, float(i) / n))
	balusters(B, pts, o.get("mat", "walnut"), h - 0.06)
	var basis := Basis.looking_at((b - a).normalized(), Vector3.UP) if len > 0.01 else Basis()
	B.add_static(MeshKit.box(Vector3(0.1, 0.07, len + 0.1)), o.get("rail", "mahogany"), Transform3D(basis, (a + b) * 0.5 + Vector3(0, h, 0)))
	B.add_static(MeshKit.box(Vector3(0.12, 0.05, len + 0.06)), o.get("rail", "mahogany"), Transform3D(basis, (a + b) * 0.5 + Vector3(0, 0.05, 0)))
	if o.get("collide", true): B.collider((a + b) * 0.5 + Vector3(0, 0.6, 0), Vector3(0.16, 1.4, len + 0.14), basis)

# ===================================================================================== furniture
static func fireplace(B: RoomBuilder, at: Dictionary, o := {}) -> Dictionary:
	var p := P.new(B, at)
	var w: float = o.get("w", 2.2); var lit: bool = o.get("lit", false)
	var m := "stone_trim"
	p.box(Vector3(w, 0.12, 0.7), m, Vector3(0, 0.06, 0.15))
	for s in [-1, 1]:
		p.box(Vector3(0.35, 1.3, 0.35), m, Vector3(s * (w * 0.5 - 0.175), 0.77, 0))
		p.box(Vector3(0.4, 0.15, 0.4), m, Vector3(s * (w * 0.5 - 0.175), 0.2, 0.02))
		p.sph(0.08, m, Vector3(s * (w * 0.5 - 0.175), 1.1, 0.18), Vector3(1, 1.5, 0.5))
	p.box(Vector3(w, 0.35, 0.35), m, Vector3(0, 1.5, 0))
	p.box(Vector3(w + 0.3, 0.1, 0.5), m, Vector3(0, 1.72, 0.05))
	p.box(Vector3(w - 0.7, 1.25, 0.3), "black", Vector3(0, 0.75, -0.12), Vector3.ZERO, {"shadow": false})
	for i in 6: p.box(Vector3(0.02, 0.25, 0.02), "iron", Vector3(-0.4 + i * 0.16, 0.3, 0.05))
	p.box(Vector3(0.9, 0.03, 0.3), "iron", Vector3(0, 0.2, -0.05))
	for i in 3: p.cyl(0.07, 0.07, 0.75, "bark", Vector3(0, 0.3 + i * 0.09, -0.05 + (i % 2) * 0.05), Vector3(0, (i - 1) * 0.3, PI * 0.5 + (i - 1) * 0.15))
	var ember := p.box(Vector3(0.7, 0.05, 0.25), "ember", Vector3(0, 0.24, -0.04), Vector3.ZERO, {"dynamic": true, "shadow": false})
	var l := p.light(Vector3(0, 0.6, 0.35), {"color": Color(1.0, 0.45, 0.18), "energy": 2.6 if lit else 0.35, "range": 8.0, "flicker": 0.4, "priority": 2.5, "glow_size": 1.6, "glow_intensity": 0.5 if lit else 0.12, "id": "fire", "fog": 1.0})
	p.box(Vector3(w - 0.4, 1.6, 0.06), "gilt_dull", Vector3(0, 2.6, -0.1))
	p.quad(w - 0.6, 1.4, "mirror_dusty", Vector3(0, 2.6, -0.065))
	p.collide(-w * 0.5, -0.25, w * 0.5, 0.5, 0, 1.8)
	return {"light": l, "ember": ember}

static func reception_desk(B: RoomBuilder, at: Dictionary) -> void:
	var p := P.new(B, at)
	p.box(Vector3(2.6, 1.05, 0.7), "walnut", Vector3(0, 0.525, 0))
	for i in 4: p.box(Vector3(0.5, 0.65, 0.03), "mahogany", Vector3(-0.9 + i * 0.6, 0.5, 0.36))
	p.box(Vector3(2.8, 0.06, 0.85), "stone_trim", Vector3(0, 1.08, 0.02))
	p.box(Vector3(0.6, 0.04, 0.42), "leather", Vector3(-0.3, 1.13, 0.05), Vector3(0, 0.08, 0))
	p.box(Vector3(0.56, 0.035, 0.38), "paper", Vector3(-0.3, 1.152, 0.05), Vector3(0, 0.08, 0))
	p.cyl(0.005, 0.005, 0.18, "black", Vector3(-0.05, 1.16, 0.15), Vector3(0, 0.6, PI * 0.5 - 0.2))
	p.cyl(0.06, 0.06, 0.012, "walnut", Vector3(0.6, 1.12, 0.1))
	p.sph(0.055, "brass", Vector3(0.6, 1.14, 0.1), Vector3(1, 0.7, 1))
	p.cyl(0.008, 0.008, 0.03, "brass", Vector3(0.6, 1.2, 0.1))
	p.cyl(0.07, 0.08, 0.02, "brass", Vector3(1.0, 1.12, -0.1)); p.cyl(0.01, 0.01, 0.3, "brass", Vector3(1.0, 1.27, -0.1))
	p.lathe([[0.0, 0], [0.14, 0.0], [0.12, 0.08], [0.0, 0.1]], "green_glass", Vector3(1.0, 1.36, -0.05), Vector3(-0.3, 0, 0), Vector3(1, 1, 0.55))
	p.light(Vector3(1.0, 1.3, 0.05), {"color": Color(0.78, 1.0, 0.6), "energy": 0.8, "range": 4.0, "priority": 1.5, "glow_size": 0.6, "glow_intensity": 0.25})
	p.collide(-1.35, -0.4, 1.35, 0.45, 0, 1.2)

static func key_rack(B: RoomBuilder, at: Dictionary) -> void:
	var p := P.new(B, at)
	p.box(Vector3(1.6, 0.9, 0.05), "walnut", Vector3.ZERO)
	for i in 12:
		var x := -0.65 + (i % 6) * 0.26; var y := 0.2 - (i / 6) * 0.4
		p.cyl(0.008, 0.008, 0.06, "brass", Vector3(x, y, 0.05), Vector3(PI * 0.5, 0, 0))
		if i != 6:
			p.torus(0.02, 0.004, "brass", Vector3(x, y - 0.03, 0.07))
			p.box(Vector3(0.015, 0.08, 0.004), "brass", Vector3(x, y - 0.09, 0.07))
			p.box(Vector3(0.06, 0.08, 0.004), "paper", Vector3(x, y - 0.16, 0.07))

static func umbrella_stand(B: RoomBuilder, at: Dictionary) -> void:
	var p := P.new(B, at)
	p.cyl(0.16, 0.14, 0.6, "brass_dark", Vector3(0, 0.3, 0), Vector3.ZERO, {"open": true})
	var rng := RandomNumberGenerator.new(); rng.seed = 5
	for i in 4:
		var a := rng.randf() * TAU
		var c := Vector3(cos(a) * 0.06, 0, sin(a) * 0.06)
		p.cyl(0.012, 0.012, 0.9, "black", c + Vector3(0, 0.6, 0), Vector3(0, 0, (rng.randf() - 0.5) * 0.2), {"seg": 6})
		p.torus(0.04, 0.01, "walnut", c + Vector3(0.04, 1.06, 0), Vector3.ZERO, {"arc": PI})
		p.cyl(0.05, 0.015, 0.5, MaterialLib.color(Color(0.08, 0.08, 0.1), 0.9), c + Vector3(0, 0.55, 0), Vector3.ZERO, {"seg": 8})
	p.collide(-0.16, -0.16, 0.16, 0.16, 0, 1)

static func tea_trolley(B: RoomBuilder, at: Dictionary) -> Dictionary:
	var p := P.new(B, at)
	for y in [0.25, 0.75]: p.box(Vector3(0.95, 0.03, 0.55), "mahogany", Vector3(0, y, 0))
	for x in [-1, 1]:
		for z in [-1, 1]:
			p.cyl(0.015, 0.015, 0.8, "brass", Vector3(x * 0.44, 0.42, z * 0.24), Vector3.ZERO, {"seg": 6})
			p.torus(0.04, 0.012, "black", Vector3(x * 0.44, 0.04, z * 0.24), Vector3(0, PI * 0.5, 0))
	p.torus(0.15, 0.012, "brass", Vector3(0.52, 0.85, 0), Vector3(0, PI * 0.5, -PI * 0.5), {"arc": PI})
	model(B, "tea_set_01", {"pos": p.world(Vector3(0, 0.77, 0)), "ry": at.get("ry", 0.0), "scale": 0.95}, {"collide": false})
	p.collide(-0.5, -0.3, 0.5, 0.3, 0, 1.0)
	var g := p.glow(Vector3(-0.1, 1.05, 0), Color(1.0, 0.85, 0.6), 0.8, 0.0)
	return {"glow": g, "pos": p.world(Vector3(0, 0.95, 0))}

static func counter(B: RoomBuilder, at: Dictionary, w := 4.0, d := 0.7) -> void:
	var p := P.new(B, at)
	p.box(Vector3(w, 1.05, d), "walnut", Vector3(0, 0.525, 0))
	for i in int(w / 0.6): p.box(Vector3(0.48, 0.7, 0.03), "mahogany", Vector3(-w * 0.5 + 0.35 + i * 0.6, 0.5, d * 0.5 + 0.01))
	p.box(Vector3(w + 0.1, 0.06, d + 0.12), "mahogany", Vector3(0, 1.08, 0))
	p.cyl(0.06, 0.06, 0.012, "walnut", Vector3(w * 0.5 - 0.4, 1.12, 0)); p.sph(0.055, "brass", Vector3(w * 0.5 - 0.4, 1.14, 0), Vector3(1, 0.7, 1))
	p.box(Vector3(0.25, 0.04, 0.18), "leather", Vector3(-0.4, 1.13, 0.05))
	for i in 5: p.box(Vector3(0.06, 0.003, 0.09), "paper", Vector3(0.2 + i * 0.01, 1.115 + i * 0.003, 0.1), Vector3(0, i * 0.2, 0))
	p.collide(-w * 0.5, -d * 0.5, w * 0.5, d * 0.5, 0, 1.2)

static func coat_on_hook(B: RoomBuilder, pos: Vector3, ry: float, c: Color, length := 1.1, hat := false, mask := false) -> void:
	var p := P.new(B, {"pos": pos, "ry": ry})
	var m := MaterialLib.color(c, 0.95)
	p.sph(0.12, m, Vector3(0, -0.12, 0.05), Vector3(1.7, 0.7, 0.7))
	p.lathe([[0.16, 0], [0.2, -0.2], [0.24, -length * 0.6], [0.27, -length]], m, Vector3(0, -0.12, 0.08), Vector3.ZERO, Vector3(1, 1, 0.45))
	for s in [-1, 1]: p.cyl(0.05, 0.045, length * 0.6, m, Vector3(s * 0.2, -0.45, 0.06), Vector3(0, 0, s * 0.08), {"seg": 8})
	p.box(Vector3(0.08, 0.2, 0.01), MaterialLib.color(c.darkened(0.4), 0.6), Vector3(0, -0.25, 0.16), Vector3(0, 0, 0.1))
	if hat:
		p.cyl(0.1, 0.1, 0.18, "black", Vector3(0.1, 0.12, 0.08)); p.cyl(0.16, 0.16, 0.01, "black", Vector3(0.1, 0.03, 0.08))
	if mask: p.box(Vector3(0.2, 0.08, 0.01), "gilt", Vector3(-0.12, -0.05, 0.2), Vector3(0, 0, 0.4))

static func hook_rail(B: RoomBuilder, at: Dictionary, n := 10, spacing := 0.55, start_no := 1, empty := []) -> Array:
	var p := P.new(B, at)
	p.box(Vector3(n * spacing + 0.2, 0.12, 0.04), "walnut", Vector3(n * spacing * 0.5 - spacing * 0.5, 0, 0))
	var hooks: Array = []
	var palette := [Color(0.16, 0.16, 0.19), Color(0.23, 0.14, 0.13), Color(0.12, 0.17, 0.14), Color(0.17, 0.1, 0.18), Color(0.29, 0.25, 0.19), Color(0.1, 0.1, 0.1)]
	for i in n:
		var x := i * spacing; var no := start_no + i
		p.tube([Vector3(x, 0, 0.02), Vector3(x, -0.02, 0.12), Vector3(x, 0.06, 0.16)], 0.01, "brass", {"seg": 8})
		p.quad(0.09, 0.09, decal_mat("plate_%d" % no, 0.35, 0.0, true), Vector3(x, 0.11, 0.025), Vector3.ZERO, {"shadow": false})
		hooks.append({"no": no, "pos": p.world(Vector3(x, -0.05, 0.25))})
		if not empty.has(no):
			coat_on_hook(B, p.world(Vector3(x, -0.02, 0.12)), at.get("ry", 0.0), palette[(no * 7) % 6], 0.9 + ((no * 13) % 5) * 0.08, no % 4 == 0, no % 5 == 2)
	return hooks

static func music_stand(B: RoomBuilder, at: Dictionary, instrument := "violin") -> Dictionary:
	var p := P.new(B, at)
	for i in 3:
		var a := float(i) / 3 * TAU
		p.cyl(0.008, 0.008, 0.3, "brass", Vector3(cos(a) * 0.12, 0.08, sin(a) * 0.12), Vector3(-sin(a) * 1.1, 0, cos(a) * 1.1), {"seg": 5})
	p.cyl(0.012, 0.012, 1.05, "brass", Vector3(0, 0.6, 0), Vector3.ZERO, {"seg": 6})
	p.box(Vector3(0.5, 0.36, 0.015), "brass", Vector3(0, 1.22, 0), Vector3(-0.35, 0, 0))
	p.box(Vector3(0.5, 0.03, 0.06), "brass", Vector3(0, 1.05, 0.06), Vector3(-0.35, 0, 0))
	# carved instrument on the stand's crest so players can tell them apart without colour
	match instrument:
		"violin": p.lathe([[0.0, 0], [0.035, 0.02], [0.025, 0.06], [0.04, 0.1], [0.0, 0.13]], "brass_dark", Vector3(0, 1.42, -0.06), Vector3(-0.35, 0, 0), Vector3(1, 1, 0.3))
		"cello": p.lathe([[0.0, 0], [0.05, 0.02], [0.035, 0.08], [0.055, 0.14], [0.0, 0.18]], "brass_dark", Vector3(0, 1.42, -0.06), Vector3(-0.35, 0, 0), Vector3(1, 1, 0.3))
		_: p.cyl(0.012, 0.012, 0.2, "brass_dark", Vector3(0, 1.46, -0.06), Vector3(0, 0, PI * 0.5))
	p.collide(-0.2, -0.2, 0.2, 0.2, 0, 1.4)
	return {"sheet_xform": p.xf * p.t(Vector3(0, 1.24, 0.02), Vector3(-0.35, 0, 0)), "pos": p.world(Vector3(0, 1.1, 0.5))}

static func grand_piano(B: RoomBuilder, at: Dictionary, o := {}) -> Dictionary:
	var p := P.new(B, at)
	var m := "lacquer_dusty" if o.get("dusty", false) else "lacquer"
	var mat_l := MaterialLib.color(Color(0.02, 0.02, 0.025), 0.12, 0.0) if m == "lacquer" else MaterialLib.color(Color(0.16, 0.16, 0.17), 0.7)
	var shape := PackedVector2Array()
	shape.append(Vector2(-0.75, 0)); shape.append(Vector2(0.75, 0)); shape.append(Vector2(0.75, -0.6))
	for i in 12:
		var t := float(i + 1) / 12.0
		shape.append(Vector2(0.75 - t * 0.7, -0.6 - t * 0.9 + sin(t * PI) * 0.12))
	for i in 10:
		var t2 := float(i + 1) / 10.0
		shape.append(Vector2(0.05 - t2 * 0.8, -1.5 - sin(t2 * PI) * 0.4))
	shape.append(Vector2(-0.75, -1.9))
	var body := MeshKit.extrude(shape, 0.32, "piano")
	p.put(body, mat_l, p.t(Vector3(0, 0.98, 0), Vector3(PI * 0.5, 0, 0)))
	var lid := MeshKit.extrude(shape, 0.025, "pianolid")
	p.put(lid, mat_l, p.t(Vector3(0.75, 1.0, 0), Vector3(PI * 0.5, 0, 0.1 if o.get("broken", false) else 0.62)))
	if not o.get("broken", false): p.cyl(0.012, 0.012, 0.85, "brass", Vector3(0.62, 1.32, -0.9), Vector3(0, 0, -0.3))
	p.box(Vector3(1.5, 0.08, 0.32), mat_l, Vector3(0, 0.83, 0.16))
	p.box(Vector3(1.38, 0.03, 0.16), "porcelain", Vector3(0, 0.88, 0.2))
	for i in 26:
		if [2, 6, 9, 13, 16, 20, 23].has(i % 28): continue
		if o.get("broken", false) and i % 7 == 3: continue
		p.box(Vector3(0.025, 0.025, 0.1), "black", Vector3(-0.66 + i * 0.053, 0.905, 0.17))
	p.box(Vector3(1.5, 0.22, 0.04), mat_l, Vector3(0, 1.0, 0.3))
	for xz in [[-0.62, 0.05], [0.62, 0.05], [-0.4, -1.75]]:
		p.lathe([[0.0, 0], [0.06, 0], [0.05, 0.2], [0.08, 0.5], [0.06, 0.66], [0.0, 0.66]], mat_l, Vector3(xz[0], 0, xz[1]), Vector3.ZERO, Vector3.ONE, {"seg": 10})
	p.box(Vector3(0.2, 0.4, 0.04), mat_l, Vector3(0, 0.35, -0.2))
	p.box(Vector3(0.7, 0.3, 0.02), mat_l, Vector3(0, 1.14, -0.05), Vector3(-0.25, 0, 0))
	p.collide(-0.8, -1.95, 0.8, 0.35, 0, 1.4)
	return {"desk": p.world(Vector3(0, 1.2, 0.0))}

static func harp(B: RoomBuilder, at: Dictionary) -> void:
	var p := P.new(B, at)
	p.box(Vector3(0.35, 0.12, 0.5), "gilt", Vector3(0, 0.06, 0))
	p.tube([Vector3(0, 0.1, 0.2), Vector3(0, 0.9, 0.25), Vector3(0, 1.6, 0.15), Vector3(0, 1.85, 0.0)], 0.05, "gilt", {"seg": 16})
	p.tube([Vector3(0, 1.85, 0.0), Vector3(0, 1.75, -0.35), Vector3(0, 1.45, -0.55), Vector3(0, 1.4, -0.75)], 0.04, "gilt", {"seg": 16})
	p.tube([Vector3(0, 0.12, -0.15), Vector3(0, 0.8, -0.4), Vector3(0, 1.4, -0.75)], 0.06, "walnut", {"seg": 16})
	for i in 14:
		var t := float(i) / 13.0
		var zt := 0.12 - t * 0.85; var yb := 0.15 + t * 1.2; var yt := 1.78 - t * 0.35
		p.cyl(0.003, 0.003, yt - yb, "silver", Vector3(0, (yt + yb) * 0.5, zt * 0.7 + 0.02), Vector3.ZERO, {"seg": 3})
	p.collide(-0.2, -0.8, 0.2, 0.3, 0, 2)

static func round_table(B: RoomBuilder, at: Dictionary, o := {}) -> void:
	var p := P.new(B, at)
	var r: float = o.get("r", 0.7)
	p.lathe([[0.0, 0], [0.3, 0], [0.25, 0.06], [0.06, 0.12], [0.08, 0.6], [0.05, 0.72], [0.0, 0.72]], "walnut", Vector3.ZERO)
	p.cyl(r, r, 0.04, "walnut", Vector3(0, 0.74, 0), Vector3.ZERO, {"seg": 28})
	var cloth := MaterialLib.get_mat("dustsheet" if o.get("dusty", false) else "linen")
	if cloth is BaseMaterial3D: cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	p.lathe([[0.001, 0.785], [r + 0.02, 0.78], [r + 0.08, 0.6], [r + 0.12, 0.05], [r + 0.14, 0.02]], cloth, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, {"seg": 30})
	if o.get("setting", false):
		for i in 4:
			var a := float(i) / 4 * TAU + 0.4
			p.cyl(0.11, 0.11, 0.008, "porcelain", Vector3(cos(a) * r * 0.65, 0.79, sin(a) * r * 0.65), Vector3.ZERO, {"seg": 18})
			p.lathe([[0.0, 0], [0.03, 0], [0.005, 0.01], [0.005, 0.1], [0.035, 0.12], [0.03, 0.2], [0.0, 0.2]], "glass", Vector3(cos(a) * r * 0.45, 0.785, sin(a) * r * 0.45), Vector3.ZERO, Vector3.ONE, {"seg": 10})
		candelabra(B, {"pos": p.world(Vector3(0, 0.79, 0))}, {"arms": 3, "h": 0.4, "lit": o.get("lit", true)})
	p.collide(-r - 0.1, -r - 0.1, r + 0.1, r + 0.1, 0, 0.9)

static func gilt_chair(B: RoomBuilder, at: Dictionary, o := {}) -> Node3D:
	# balloon-back gilt chair; dynamic so the Host encounter can push them
	var p := P.new(B, at, o.get("dynamic", false))
	var seat: Variant = o.get("mat", "velvet_red")
	for xz in [[-0.2, -0.2], [0.2, -0.2], [-0.2, 0.2], [0.2, 0.2]]: p.cyl(0.018, 0.014, 0.46, "gilt", Vector3(xz[0], 0.23, xz[1]), Vector3.ZERO, {"seg": 6})
	p.cyl(0.24, 0.24, 0.07, seat, Vector3(0, 0.48, 0.02), Vector3.ZERO, {"seg": 18})
	p.torus(0.2, 0.02, "gilt", Vector3(0, 0.88, -0.2), Vector3.ZERO, {"scl": Vector3(1, 1.25, 1)})
	p.disc(0.18, seat, Vector3(0, 0.88, -0.2), Vector3.ZERO, {"seg": 16})
	for s in [-1, 1]: p.cyl(0.015, 0.015, 0.4, "gilt", Vector3(s * 0.19, 0.68, -0.2), Vector3.ZERO, {"seg": 6})
	if not o.get("dynamic", false) and o.get("collide", true): p.collide(-0.25, -0.25, 0.25, 0.25, 0, 1)
	return p.node

static func cake(B: RoomBuilder, at: Dictionary, rotten := false) -> void:
	var p := P.new(B, at)
	var m := "cake_rotten" if rotten else "cake"; var ic := "cake_rotten" if rotten else "icing"
	p.cyl(0.3, 0.32, 0.02, "silver", Vector3(0, 0.01, 0), Vector3.ZERO, {"seg": 24})
	var y := 0.02
	var tiers := [[0.26, 0.18], [0.19, 0.16], [0.12, 0.14]]
	for i in tiers.size():
		var r: float = tiers[i][0]; var h: float = tiers[i][1] * ((0.6 + i * 0.1) if rotten else 1.0)
		p.cyl(r, r * (1.1 if rotten else 1.0), h, m, Vector3((i - 1) * 0.03 if rotten else 0.0, y + h * 0.5, 0), Vector3(0, 0, (i - 1) * 0.08 if rotten else 0.0), {"seg": 24})
		for k in 14:
			var a := float(k) / 14 * TAU
			p.sph(0.018, ic, Vector3(cos(a) * r, y + h, sin(a) * r))
		y += h
	if not rotten:
		for k in 5:
			var a2 := float(k) / 5 * TAU
			p.cyl(0.006, 0.006, 0.08, "wax", Vector3(cos(a2) * 0.07, y + 0.04, sin(a2) * 0.07), Vector3.ZERO, {"seg": 5})
			p.flame(Vector3(cos(a2) * 0.07, y + 0.1, sin(a2) * 0.07), true, 0.6)
	else:
		for k in 6: p.sph(0.05, "cake_rotten", Vector3((k - 3) * 0.08, 0.03, 0.25 + (k % 2) * 0.06), Vector3(1, 0.4, 1))

static func champagne_tower(B: RoomBuilder, at: Dictionary, toppled := false) -> void:
	var p := P.new(B, at)
	var prof := [Vector2(0, 0), Vector2(0.035, 0), Vector2(0.005, 0.01), Vector2(0.005, 0.08), Vector2(0.05, 0.09), Vector2(0.055, 0.12), Vector2(0, 0.12)]
	var pts: Array = []
	var rng := RandomNumberGenerator.new(); rng.seed = 9
	if not toppled:
		for lvl in 4:
			var n := 4 - lvl
			for i in n:
				for j in n: pts.append(Transform3D(Basis(), Vector3((i - (n - 1) * 0.5) * 0.1, lvl * 0.125, (j - (n - 1) * 0.5) * 0.1)))
	else:
		for i in 22: pts.append(Transform3D(Basis(Vector3.RIGHT, PI * 0.5 if rng.randf() < 0.7 else 0.0).rotated(Vector3.UP, rng.randf() * TAU), Vector3((rng.randf() - 0.5) * 0.9, 0.05, (rng.randf() - 0.5) * 0.6)))
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.mesh = MeshKit.lathe(prof, 10); mm.instance_count = pts.size()
	for i in pts.size(): mm.set_instance_transform(i, p.xf * pts[i])
	var mmi := MultiMeshInstance3D.new(); mmi.multimesh = mm; mmi.material_override = MaterialLib.get_mat("glass"); B.target.add_child(mmi)
	if not toppled: p.glow(Vector3(0, 0.3, 0), Color(1.0, 0.95, 0.75), 0.6, 0.2)

static func folding_screen(B: RoomBuilder, at: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.transform = Transform3D(Basis(Vector3.UP, at.get("ry", 0.0)), at.get("pos", Vector3.ZERO))
	B.target.add_child(root)
	var painted := decal_mat("mural", 0.7)
	for i in 3:
		var pg := Node3D.new(); pg.position.x = (i - 1) * 0.55; pg.rotation.y = 0.35 if i % 2 == 0 else -0.35; root.add_child(pg)
		B.add_node(MeshKit.box(Vector3(0.6, 1.8, 0.03)), painted, Transform3D(Basis(), Vector3(0, 0.95, 0)), pg)
		for s in [-1, 1]: B.add_node(MeshKit.box(Vector3(0.04, 1.9, 0.05)), "ebony", Transform3D(Basis(), Vector3(s * 0.3, 0.95, 0)), pg)
		B.add_node(MeshKit.box(Vector3(0.6, 0.05, 0.05)), "gilt", Transform3D(Basis(), Vector3(0, 1.88, 0)), pg)
	return root

static func rubble(B: RoomBuilder, at: Dictionary, n := 30, spread := 1.5) -> void:
	var p := P.new(B, at)
	var rng := RandomNumberGenerator.new(); rng.seed = int(at.get("pos", Vector3.ZERO).x * 13) + n
	for i in n:
		var s := 0.08 + rng.randf() * 0.3
		p.put(MeshKit.sphere(s, 6, 4), "rubble" if i % 5 else "gilt_dull", p.t(Vector3((rng.randf() - 0.5) * spread * 2, s * 0.4 + rng.randf() * 0.25 * (1.0 - float(i) / n), (rng.randf() - 0.5) * spread), Vector3(rng.randf() * 3, rng.randf() * 3, 0), Vector3(1, 0.6 + rng.randf() * 0.5, 1)))
	for i in 5: p.box(Vector3(0.1, 0.1, 1.2 + rng.randf()), "rotten_wood", Vector3((rng.randf() - 0.5) * spread * 1.5, 0.15 + rng.randf() * 0.4, (rng.randf() - 0.5) * spread), Vector3((rng.randf() - 0.5) * 0.8, rng.randf() * 3, 0))

static func garland(B: RoomBuilder, a: Vector3, b: Vector3, sag := 0.5) -> void:
	var mid := (a + b) * 0.5 - Vector3(0, sag, 0)
	var pts := [a, (a + mid) * 0.5 - Vector3(0, sag * 0.15, 0), mid, (b + mid) * 0.5 - Vector3(0, sag * 0.15, 0), b]
	B.add_static(MeshKit.tube(pts, 0.05, 30, 6), MaterialLib.color(Color(0.1, 0.18, 0.08), 0.9), Transform3D())
	for i in range(1, 10):
		var t := float(i) / 10.0
		var p := a.lerp(b, t) - Vector3(0, sin(t * PI) * sag + 0.03, 0)
		B.sphere(0.06, "velvet_red" if i % 2 else "icing", p)

static func telescope(B: RoomBuilder, at: Dictionary) -> void:
	var p := P.new(B, at)
	for i in 3:
		var a := float(i) / 3 * TAU
		p.cyl(0.015, 0.015, 1.2, "walnut", Vector3(cos(a) * 0.2, 0.55, sin(a) * 0.2), Vector3(-sin(a) * 0.35, 0, cos(a) * 0.35), {"seg": 6})
	p.sph(0.05, "brass", Vector3(0, 1.12, 0))
	p.cyl(0.06, 0.045, 1.1, "brass", Vector3(0, 1.3, 0.15), Vector3(-1.0, 0, 0))
	p.collide(-0.3, -0.3, 0.3, 0.3, 0, 1.5)

static func bench(B: RoomBuilder, at: Dictionary) -> void:
	var p := P.new(B, at)
	p.box(Vector3(1.6, 0.1, 0.45), "stone_trim", Vector3(0, 0.45, 0))
	for s in [-1, 1]:
		p.box(Vector3(0.15, 0.4, 0.4), "stone_trim", Vector3(s * 0.6, 0.2, 0))
		p.sph(0.1, "stone_trim", Vector3(s * 0.6, 0.12, 0.2), Vector3(1, 1, 0.5))
	p.collide(-0.8, -0.25, 0.8, 0.25, 0, 0.6)

static func cobweb(B: RoomBuilder, pos: Vector3, ry: float, s := 1.0) -> void:
	var m := decal_mat("cobweb", 1.0, 0.0, true)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	B.add_static(MeshKit.quad(0.9 * s, 0.9 * s), m, Transform3D(Basis(Vector3.UP, ry), pos + Basis(Vector3.UP, ry) * Vector3(0.45 * s, -0.45 * s, 0)), false)

static func crest(B: RoomBuilder, at: Dictionary) -> void:
	var p := P.new(B, at)
	var shield := PackedVector2Array([Vector2(-0.5, 0.6), Vector2(0.5, 0.6), Vector2(0.5, 0.0), Vector2(0.35, -0.45), Vector2(0, -0.75), Vector2(-0.35, -0.45), Vector2(-0.5, 0.0)])
	p.put(MeshKit.extrude(shield, 0.1, "shield"), "velvet_green", p.t(Vector3.ZERO))
	p.torus(0.25, 0.03, "gilt", Vector3(0, 0.05, 0.12), Vector3.ZERO, {"tubular": 28})
	p.torus(0.36, 0.03, "gilt", Vector3(0, 0.05, 0.12), Vector3(0, 0, PI * 1.15), {"arc": PI})
	p.box(Vector3(0.03, 0.18, 0.03), "gilt", Vector3(-0.04, 0.12, 0.14), Vector3(0, 0, 0.4))
	p.box(Vector3(0.03, 0.12, 0.03), "gilt", Vector3(0.04, 0.08, 0.14), Vector3(0, 0, -0.9))
	for s in [-1, 1]:
		for i in 7: p.sph(0.06, "gilt", Vector3(s * (0.62 + sin(i * 0.5) * 0.05), 0.5 - i * 0.17, 0.05), Vector3(0.6, 1.3, 0.4))
