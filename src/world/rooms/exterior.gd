class_name ExteriorBuilder
extends RefCounted
## The drive in the rain: iron gate, lamps, dead trees, the weeping-angel fountain, Avery's car
## with its headlights cutting through the downpour, and the Ashcombe facade with its clock tower
## stopped at 11:59.

const GY := -0.6

static func build(world: World) -> void:
	var r := world.room("exterior", {
		"name": "The Drive", "bounds": AABB(Vector3(-60, -5, -90), Vector3(120, 45, 89.25)), "neighbors": ["hall"],
		"music": "exterior", "grade": "exterior", "surface": "gravel", "acoustics": Vector3(0.2, 0.04, 0.6),
		"ambience": {"rain_out": 1.0, "wind": 0.75, "drips": 0.3},
		"fog": {"color": Color(0.05, 0.06, 0.1), "density": 0.013, "albedo": Color(0.52, 0.56, 0.72), "moon": 0.5, "saturation": 1.1},
		"ambient": {"color": Color(0.14, 0.15, 0.22), "energy": 1.0},
		"map_rect": Rect2(-30, -62, 60, 61),
	})
	var B := world.builder(r)
	var rng := RandomNumberGenerator.new(); rng.seed = 42
	# --------------------------------------------------------------- ground
	B.floor_rect(-80, -100, 80, -0.6, GY - 0.02, "ground_grass", "grass")
	B.floor_rect(-2.6, -75, 2.6, -6.2, GY, "ground_gravel", "gravel")
	B.floor_rect(-10, -8, 10, -6.2, GY, "ground_gravel", "gravel")
	var ring := MeshKit.lathe([Vector2(3.4, 0.0), Vector2(7.5, 0.0)], 48)
	B.add_static(MeshKit.cyl(7.5, 7.5, 0.04, 48), "ground_gravel", Transform3D(Basis(), Vector3(0, GY - 0.005, -28)), false)
	B.collider(Vector3(0, GY - 0.25, -28), Vector3(15, 0.5, 15), Basis(), "gravel")
	for z in range(-74, -36, 1):
		for s in [-1, 1]: B.box(Vector3(0.25, 0.15, 0.95), "stone_trim", Vector3(s * 2.75, GY + 0.05, z + 0.5), Vector3.ZERO, {"shadow": false})
	# --------------------------------------------------------------- facade & porch
	_facade(world, B)
	for i in 3: B.box(Vector3(12 - i * 0.3, 0.2, 0.6), "stone_trim", Vector3(0, GY + 0.1 + i * 0.2, -5.9 + i * 0.6))
	B.ramp(-6, -6.2, 6, -4.4, GY, 0.0, "z", "stone")
	B.box(Vector3(11.4, 0.6, 3.8), "stone_trim", Vector3(0, GY + 0.3, -2.4))
	B.floor_rect(-5.7, -4.4, 5.7, -0.75, 0.0, "stone_floor", "stone")
	for x in [-4.6, -2.2, 2.2, 4.6]: Props.column(B, {"pos": Vector3(x, 0, -3.9)}, {"h": 6.4, "r": 0.3, "mat": "stone_trim", "capital": "stone_trim"})
	B.box(Vector3(11.6, 0.7, 4.2), "stone_trim", Vector3(0, 6.75, -2.4))
	var ped := PackedVector2Array([Vector2(-6, 0), Vector2(6, 0), Vector2(0, 2.1)])
	B.add_static(MeshKit.extrude(ped, 3.8, "pediment"), "stone_facade", Transform3D(Basis(), Vector3(0, 7.1, -4.3)))
	B.box(Vector3(12.4, 0.25, 4.3), "stone_trim", Vector3(0, 7.12, -2.4))
	B.add_static(MeshKit.torus(0.55, 0.06), "gilt_dull", Transform3D(Basis(), Vector3(0, 7.95, -4.33)))
	for s in [-1, 1]:
		var p := Props.P.new(B, {"pos": Vector3(s * 1.8, 2.6, -0.85)})
		p.box(Vector3(0.08, 0.5, 0.08), "iron", Vector3(0, 0.3, 0.05))
		p.lathe([[0.0, 0], [0.12, 0.05], [0.15, 0.3], [0.08, 0.42], [0.0, 0.45]], "lamp_glass", Vector3(0, -0.1, 0.2), Vector3.ZERO, Vector3.ONE, {"seg": 6})
		p.light(Vector3(0, 0.1, 0.32), {"color": Color(1.0, 0.7, 0.38), "energy": 2.2, "range": 9.0, "flicker": 0.1, "glow_size": 1.1, "priority": 2.5, "fog": 2.0})
	B.add_static(MeshKit.disc(1.3, 24, 0.0, PI), "window_lit", Transform3D(Basis(Vector3.UP, PI), Vector3(0, 3.75, -0.79)), false)
	# --------------------------------------------------------------- gate & boundary
	for s in [-1, 1]:
		var gp := Props.P.new(B, {"pos": Vector3(s * 3.6, GY, -60)})
		gp.box(Vector3(1.0, 3.0, 1.0), "stone_trim", Vector3(0, 1.5, 0)); gp.box(Vector3(1.2, 0.2, 1.2), "stone_trim", Vector3(0, 3.1, 0)); gp.sph(0.4, "stone_trim", Vector3(0, 3.55, 0))
		gp.collide(-0.5, -0.5, 0.5, 0.5, 0, 4)
		Props.model(B, "large_iron_gate", {"pos": Vector3(s * 3.05, GY, -60), "ry": s * 1.1 + (PI if s > 0 else 0.0), "scale": 1.0}, {"collide": false})
		B.box(Vector3(26, 2.4, 1.4), "hedge", Vector3(s * 17.5, GY + 1.2, -60), Vector3.ZERO, {"collide": true})
		B.box(Vector3(1.4, 2.4, 58), "hedge", Vector3(s * 30, GY + 1.2, -31), Vector3.ZERO, {"collide": true})
		for k in 6: Props.model(B, "shrub_02", {"pos": Vector3(s * (10 + k * 3.4), GY, -58.5), "ry": rng.randf() * TAU, "scale": 0.5}, {"collide": false, "vis_range": 70.0})
	B.collider_box(-3.2, -62, 3.2, -60.6, -2, 5)
	var sign_p := Props.P.new(B, {"pos": Vector3(-5, GY, -57), "ry": 0.4})
	sign_p.box(Vector3(0.12, 1.8, 0.12), "rotten_wood", Vector3(0, 0.9, 0))
	sign_p.box(Vector3(1.6, 0.8, 0.05), Props.decal_mat("sign", 0.9), Vector3(0, 1.6, 0.07))
	world.refs.sign_pos = sign_p.world(Vector3(0, 1.5, 0.6))
	var mb := Props.P.new(B, {"pos": Vector3(4.6, GY, -58.5)})
	mb.box(Vector3(0.1, 1.1, 0.1), "iron", Vector3(0, 0.55, 0)); mb.box(Vector3(0.45, 0.32, 0.3), "iron", Vector3(0, 1.25, 0))
	mb.cyl(0.15, 0.15, 0.3, "iron", Vector3(0, 1.41, 0), Vector3(PI * 0.5, 0, 0)); mb.box(Vector3(0.03, 0.2, 0.06), "car_paint", Vector3(0.25, 1.35, 0))
	mb.collide(-0.25, -0.2, 0.25, 0.2, 0, 1.5)
	world.refs.mailbox = mb.world(Vector3(0, 1.2, 0.6))
	# --------------------------------------------------------------- lamps along the drive
	var lamps: Array = []
	for lp in [[-3.6, -52, 0.0], [3.6, -45, 0.6], [-3.6, -38, 0.0], [3.6, -14, 0.08], [-3.6, -14, 0.0]]:
		Props.model(B, "street_lamp_01", {"pos": Vector3(lp[0], GY, lp[1]), "ry": PI * 0.5 if lp[0] < 0 else -PI * 0.5}, {"col_size": Vector3(0.3, 3.9, 0.3)})
		lamps.append(B.light(Vector3(lp[0], GY + 3.5, lp[1]), {"color": Color(1.0, 0.68, 0.36), "energy": 4.6, "range": 14.0, "flicker": lp[2], "glow_size": 1.6, "glow_intensity": 0.45, "priority": 2.0, "fog": 2.5}))
	world.refs.flicker_lamp = lamps[1]
	# --------------------------------------------------------------- trees, logs, shrubs
	for tp in [[-8, -50], [8, -44], [-9, -36], [10, -20], [-12, -16], [14, -52], [-16, -30], [18, -34], [-20, -46], [22, -12], [-24, -10], [9, -64], [-10, -66]]:
		_dead_tree(B, Vector3(tp[0] + rng.randf_range(-1, 1), GY, tp[1] + rng.randf_range(-1, 1)), rng.randf_range(0.8, 1.4), rng.randi())
	Props.model(B, "dead_tree_trunk_02", {"pos": Vector3(-14, GY, -42), "ry": 0.7}, {"col_size": Vector3(4.0, 1.0, 1.0)})
	Props.model(B, "dead_tree_trunk", {"pos": Vector3(12, GY, -26), "ry": -0.4})
	for yp in [[-8, -2.4], [8, -2.4], [-13, -2.6], [13, -2.6]]: _yew(B, Vector3(yp[0], GY, yp[1]))
	for k in 10: Props.model(B, "shrub_04", {"pos": Vector3(rng.randf_range(-24, 24), GY, rng.randf_range(-55, -8)), "ry": rng.randf() * TAU, "scale": 2.5}, {"collide": false, "vis_range": 50.0})
	# --------------------------------------------------------------- fountain & car
	_fountain(B, Vector3(0, GY, -28))
	world.refs.car = _car(B, Vector3(2.8, GY, -18.5), 0.12)
	# --------------------------------------------------------------- distant treeline (a dark ring of silhouettes)
	var tl := MeshKit.displaced_plane(TAU * 120.0, 22.0, 240, 2, func(v: Vector3) -> Vector3:
		var a := v.x / 120.0
		var h := 6.0 + 5.0 * (0.5 + 0.5 * sin(a * 23.0)) * (0.5 + 0.5 * sin(a * 7.0 + 1.0)) + 3.0 * absf(sin(a * 61.0))
		var y := -11.0 if v.y < 0.0 else -11.0 + h + 11.0
		return Vector3(sin(a) * 120.0, y, cos(a) * 120.0), "treeline")
	var tlm := StandardMaterial3D.new(); tlm.albedo_color = Color(0.012, 0.016, 0.022); tlm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; tlm.cull_mode = BaseMaterial3D.CULL_DISABLED
	var tli := MeshInstance3D.new(); tli.mesh = tl; tli.material_override = tlm; tli.position = Vector3(0, GY, -20); tli.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	r.add_child(tli)
	# --------------------------------------------------------------- weather
	world.refs.rain = _rain(r)
	world.refs.ground_fog = _ground_fog(r)
	# --------------------------------------------------------------- bats and the silhouette
	var bats: Array = []
	var wing := ArrayMesh.new()
	var arr := []; arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(0, 0, 0), Vector3(0.35, 0.05, -0.1), Vector3(0.15, 0, 0.15)])
	wing.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var bm := StandardMaterial3D.new(); bm.albedo_color = Color(0.03, 0.03, 0.04); bm.cull_mode = BaseMaterial3D.CULL_DISABLED; bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in 6:
		var bat := Node3D.new()
		var wl := MeshInstance3D.new(); wl.mesh = wing; wl.material_override = bm
		var wr := MeshInstance3D.new(); wr.mesh = wing; wr.material_override = bm; wr.scale.x = -1
		bat.add_child(wl); bat.add_child(wr)
		bat.set_meta("a", rng.randf() * TAU); bat.set_meta("rad", rng.randf_range(4, 9)); bat.set_meta("h", rng.randf_range(18, 24)); bat.set_meta("sp", rng.randf_range(0.4, 0.9))
		r.add_child(bat); bats.append([bat, wl, wr])
	r.updaters.append(func(dt: float, t: float) -> void:
		for b in bats:
			var bat: Node3D = b[0]
			var a: float = bat.get_meta("a") + dt * float(bat.get_meta("sp"))
			bat.set_meta("a", a)
			bat.position = Vector3(cos(a) * float(bat.get_meta("rad")), float(bat.get_meta("h")) + sin(a * 3.0) * 0.8, 8 + sin(a) * float(bat.get_meta("rad")))
			bat.rotation.y = -a
			var f := sin(t * 18.0 + a * 5.0) * 0.8
			b[1].rotation.z = f; b[2].rotation.z = -f)
	var sil := Node3D.new()
	var sm := StandardMaterial3D.new(); sm.albedo_color = Color(0.02, 0.015, 0.03); sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var body := MeshInstance3D.new(); body.mesh = MeshKit.capsule(0.28, 0.9); body.material_override = sm; sil.add_child(body)
	var head := MeshInstance3D.new(); head.mesh = MeshKit.sphere(0.2); head.material_override = sm; head.position.y = 0.75; sil.add_child(head)
	for i in 5:
		var c := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.0; cm.bottom_radius = 0.04; cm.height = 0.16; c.mesh = cm; c.material_override = sm
		c.position = Vector3(-0.12 + i * 0.06, 0.98, 0); sil.add_child(c)
	sil.position = Vector3(7.5, 9.7, -0.6)
	r.add_child(sil)
	world.refs.silhouette = sil
	B.finalize()

static func _facade(world: World, B: RoomBuilder) -> void:
	var z0 := -0.75
	B.wall(-14, -0.75, 14, -0.75, {"y0": GY, "h": 13.6, "t": 0.45, "n": -1.0, "mat": "stone_facade", "skirting": false, "cornice": false,
		"openings": [{"at": 14.0, "w": 2.6, "h": 4.3, "door": true}, {"at": 10.2, "w": 1.7, "h": 3.7, "y": 1.5}, {"at": 17.8, "w": 1.7, "h": 3.7, "y": 1.5}]})
	for x in [-3.8, 3.8]:
		B.box(Vector3(2.2, 0.25, 0.3), "stone_trim", Vector3(x, 0.9, z0 - 0.05))
		B.box(Vector3(2.3, 0.45, 0.3), "stone_trim", Vector3(x, 4.85, z0 - 0.05))
	B.box(Vector3(3.4, 0.5, 0.35), "stone_trim", Vector3(0, 4.95, z0 - 0.08))
	for y in [5.6, 9.2]: B.box(Vector3(28.4, 0.25, 0.5), "stone_trim", Vector3(0, y, z0 - 0.1), Vector3.ZERO, {"shadow": false})
	B.box(Vector3(29, 0.6, 0.9), "stone_trim", Vector3(0, 13.3, z0 - 0.2))
	for i in 28: B.box(Vector3(0.18, 0.3, 0.4), "stone_trim", Vector3(-13.5 + i, 12.85, z0 - 0.15), Vector3.ZERO, {"shadow": false})
	for x in [-14.0, 14.0]:
		for k in 13: B.box(Vector3(0.8 if k % 2 else 1.2, 0.5, 0.2), "stone_trim", Vector3(x + (-0.3 if x > 0 else 0.3), GY + 0.4 + k * 1.05, z0 - 0.1), Vector3.ZERO, {"shadow": false})
	var lit_set := ["-3.8,6.6", "11,10"]
	for y in [6.6, 10.0]:
		for x in [-11.0, -7.5, -3.8, 3.8, 7.5, 11.0]:
			var lit: bool = lit_set.has("%s,%s" % [str(x).trim_suffix(".0"), str(y).trim_suffix(".0")])
			_facade_window(B, x, y, z0, "window_lit" if lit else "window_dark", 2.4 if y > 9 else 2.8)
			if lit: B.light(Vector3(x, y + 1.2, z0 - 0.8), {"color": Color(1.0, 0.7, 0.4), "energy": 1.2, "range": 5.0, "glow_size": 1.6, "glow_intensity": 0.3, "shadow": false})
	for x in [-7.5, 7.5, -11.0, 11.0]: _facade_window(B, x, 1.4, z0, "window_dark", 3.0)
	_roof(B, -14, 14, -0.9, 18, 13.6, 18.4)
	for s in [-1, 1]:
		var xa := -38.0 if s < 0 else 14.0; var xb := -14.0 if s < 0 else 46.0
		B.box(Vector3(xb - xa, 10.6, 0.5), "stone_facade", Vector3((xa + xb) * 0.5, GY + 5.3, 1.6))
		for i in 4:
			for y in [1.6, 5.8]:
				_facade_window(B, xa + 4 + i * 5.5, y, 1.35, "window_lit" if (i + (1 if y > 3 else 0)) % 3 == 0 and s > 0 else "window_dark", 2.6)
		B.box(Vector3(xb - xa + 0.4, 0.5, 0.8), "stone_trim", Vector3((xa + xb) * 0.5, GY + 10.6, 1.4))
		_roof(B, xa, xb, 1.2, 20, GY + 10.8, GY + 14.4)
		B.collider_box(minf(xa, xb), 1.3, maxf(xa, xb), 2.0, -2, 12)
	for ch in [[-10, 10, 4.0], [10, 10, 4.0], [-30, 10, 3.2], [32, 10, 3.2]]:
		B.box(Vector3(1.4, ch[2] + 2, 1.0), "brick", Vector3(ch[0], 16 + ch[2] * 0.5, ch[1]))
		B.box(Vector3(1.6, 0.3, 1.2), "stone_trim", Vector3(ch[0], 17 + ch[2], ch[1]))
		for dx in [-0.35, 0.35]: B.cyl(0.16, 0.2, 0.7, "brick", Vector3(ch[0] + dx, 17.5 + ch[2], ch[1]), Vector3.ZERO, {"seg": 10})
	B.box(Vector3(8, 8, 8), "stone_facade", Vector3(0, 17.5, 6))
	B.box(Vector3(8.6, 0.5, 8.6), "stone_trim", Vector3(0, 21.6, 6))
	var face := StandardMaterial3D.new(); face.albedo_texture = load("res://assets/textures/generated/clock_tower.png"); face.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	face.emission_enabled = true; face.emission_texture = face.albedo_texture; face.emission = Color(0.45, 1.0, 0.65); face.emission_energy_multiplier = 0.7
	B.add_static(MeshKit.quad(4.0, 4.0), face, Transform3D(Basis(Vector3.UP, PI), Vector3(0, 17.6, 1.97)), false)
	B.add_static(MeshKit.torus(2.05, 0.15, TAU, 8, 48), "stone_trim", Transform3D(Basis(), Vector3(0, 17.6, 1.95)))
	B.light(Vector3(0, 17.6, 0.6), {"color": Color(0.4, 1.0, 0.65), "energy": 2.5, "range": 10.0, "priority": 1.5, "glow_size": 5.0, "glow_intensity": 0.2, "fog": 2.5})
	var spire := CylinderMesh.new(); spire.top_radius = 0.0; spire.bottom_radius = 5.6; spire.height = 7.0; spire.radial_segments = 4
	B.add_static(spire, "slate_roof", Transform3D(Basis(Vector3.UP, PI * 0.25), Vector3(0, 25.3, 6)))
	B.cyl(0.05, 0.05, 2, "iron", Vector3(0, 29.5, 6))
	# ivy creeping over the stone (instanced leaves)
	var ivy: Array = []
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	for spec in [[-13.0, 0.0, 90], [12.5, 2.0, 80], [-6.0, 8.0, 40]]:
		var x: float = spec[0]; var y: float = spec[1]
		for i in int(spec[2]):
			x += rng.randf_range(-0.4, 0.4); y += rng.randf() * 0.32
			ivy.append(Transform3D(Basis(Vector3.BACK, rng.randf() * TAU).rotated(Vector3.UP, PI).scaled(Vector3.ONE * rng.randf_range(0.7, 1.3)), Vector3(x, GY + y, z0 - 0.03)))
	var leaf := MeshKit.disc(0.16, 5)
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.mesh = leaf; mm.instance_count = ivy.size()
	for i in ivy.size(): mm.set_instance_transform(i, ivy[i])
	var mmi := MultiMeshInstance3D.new(); mmi.multimesh = mm
	var lm := StandardMaterial3D.new(); lm.albedo_color = Color(0.1, 0.16, 0.08); lm.roughness = 0.5; lm.cull_mode = BaseMaterial3D.CULL_DISABLED
	mmi.material_override = lm
	B.target.add_child(mmi)

static func _facade_window(B: RoomBuilder, x: float, y: float, z: float, m: String, h: float) -> void:
	var w := 1.5
	B.box(Vector3(w, h, 0.05), m, Vector3(x, y + h * 0.5, z - 0.02), Vector3.ZERO, {"shadow": false})
	B.box(Vector3(w + 0.4, 0.22, 0.32), "stone_trim", Vector3(x, y - 0.05, z - 0.12))
	B.box(Vector3(w + 0.5, 0.35, 0.32), "stone_trim", Vector3(x, y + h + 0.15, z - 0.12))
	for s in [-1, 1]: B.box(Vector3(0.2, h, 0.25), "stone_trim", Vector3(x + s * (w * 0.5 + 0.1), y + h * 0.5, z - 0.1), Vector3.ZERO, {"shadow": false})
	B.box(Vector3(0.06, h, 0.08), "walnut", Vector3(x, y + h * 0.5, z - 0.06), Vector3.ZERO, {"shadow": false})
	for k in range(1, 3): B.box(Vector3(w, 0.05, 0.07), "walnut", Vector3(x, y + h * k / 3.0, z - 0.06), Vector3.ZERO, {"shadow": false})

static func _roof(B: RoomBuilder, x0: float, x1: float, zf: float, zb: float, yb: float, yr: float) -> void:
	var w := x1 - x0; var d := zb - zf
	var len := Vector2(d * 0.5, yr - yb).length(); var ang := atan2(yr - yb, d * 0.5)
	B.box(Vector3(w + 0.6, 0.25, len + 0.4), "slate_roof", Vector3((x0 + x1) * 0.5, (yb + yr) * 0.5, zf + d * 0.25), Vector3(-ang, 0, 0))
	B.box(Vector3(w + 0.6, 0.25, len + 0.4), "slate_roof", Vector3((x0 + x1) * 0.5, (yb + yr) * 0.5, zb - d * 0.25), Vector3(ang, 0, 0))
	B.box(Vector3(w + 0.7, 0.18, 0.3), "iron", Vector3((x0 + x1) * 0.5, yr + 0.08, (zf + zb) * 0.5))
	var tri := PackedVector2Array([Vector2(-d * 0.5, 0), Vector2(d * 0.5, 0), Vector2(0, yr - yb)])
	for gx in [x0, x1]:
		B.add_static(MeshKit.extrude(tri, 0.4, "gable%.1f:%.1f" % [d, yr - yb]), "stone_facade", Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(gx - 0.2, yb, (zf + zb) * 0.5)))

static func _dead_tree(B: RoomBuilder, pos: Vector3, s: float, seed: int) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = seed
	var root := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), pos)
	var branch := func(self_ref: Callable, from: Vector3, dir: Vector3, length: float, rad: float, depth: int) -> void:
		var pts: Array = [from]
		var d := dir; var p := from
		for i in 4:
			d.x += rng.randf_range(-0.25, 0.25); d.z += rng.randf_range(-0.25, 0.25); d.y += rng.randf_range(-0.06, 0.14)
			d = d.normalized(); p = p + d * length / 4.0; pts.append(p)
		B.add_static(MeshKit.tube(pts, rad, 8, 7, 0.3), "bark", root)
		if depth > 0:
			for k in 2 + rng.randi() % 2:
				var t: int = 2 + rng.randi() % 3
				var nd := (d + Vector3(rng.randf_range(-0.8, 0.8), rng.randf_range(0.3, 0.7), rng.randf_range(-0.8, 0.8))).normalized()
				self_ref.call(self_ref, pts[t], nd, length * rng.randf_range(0.55, 0.75), rad * 0.5, depth - 1)
	branch.call(branch, Vector3(0, -0.2, 0), Vector3.UP, 5.5, 0.32, 3)
	for i in 5:
		var a := float(i) / 5 * TAU + rng.randf()
		var c := CylinderMesh.new(); c.top_radius = 0.02; c.bottom_radius = 0.18; c.height = 1.2; c.radial_segments = 6
		B.add_static(c, "bark", root * Transform3D(Basis(Vector3(sin(a), 0, -cos(a)).normalized(), 1.2), Vector3(cos(a) * 0.35, 0.1, sin(a) * 0.35)))
	B.collider(pos + Vector3(0, 3, 0), Vector3(0.8, 6, 0.8) * s)

static func _yew(B: RoomBuilder, pos: Vector3) -> void:
	for i in 4:
		var c := CylinderMesh.new(); c.top_radius = 0.0; c.bottom_radius = 1.3 - i * 0.25; c.height = 1.6; c.radial_segments = 10
		B.add_static(c, "hedge", Transform3D(Basis(), pos + Vector3(0, 0.9 + i * 0.9, 0)))
	B.collider(pos + Vector3(0, 2, 0), Vector3(2, 4, 2))

static func _fountain(B: RoomBuilder, pos: Vector3) -> void:
	var p := Props.P.new(B, {"pos": pos})
	p.lathe([[3.0, 0], [3.2, 0.1], [3.2, 0.6], [3.0, 0.7], [2.8, 0.6], [2.8, 0.2], [0.001, 0.2]], "stone_trim", Vector3.ZERO, Vector3.ZERO, Vector3.ONE, {"seg": 40})
	p.disc(2.8, "puddle", Vector3(0, 0.45, 0), Vector3(-PI * 0.5, 0, 0), {"shadow": false})
	p.lathe([[0.7, 0], [0.6, 0.4], [0.35, 0.6], [0.3, 1.4], [0.9, 1.7], [1.0, 1.85], [0.2, 1.9], [0.001, 1.9]], "stone_trim", Vector3(0, 0.2, 0), Vector3.ZERO, Vector3.ONE, {"seg": 24})
	# a weeping angel: robed, hands to the face, wings folded
	p.lathe([[0.001, 0], [0.42, 0], [0.38, 0.4], [0.26, 1.0], [0.2, 1.4], [0.24, 1.55], [0.001, 1.6]], "stone_trim", Vector3(0, 2.1, 0), Vector3.ZERO, Vector3.ONE, {"seg": 18})
	p.sph(0.16, "stone_trim", Vector3(0, 3.85, 0.04))
	for s in [-1, 1]:
		p.cyl(0.06, 0.05, 0.4, "stone_trim", Vector3(s * 0.12, 3.6, 0.12), Vector3(-1.2, 0, s * 0.4))
		p.sph(0.06, "stone_trim", Vector3(s * 0.06, 3.85, 0.17))
		var wing := PackedVector2Array()
		for i in 12:
			var t := float(i) / 11.0
			wing.append(Vector2(0.2 * sin(t * PI) + 0.12 * t, t * 1.6))
		for i in 12:
			var t2 := 1.0 - float(i) / 11.0
			wing.append(Vector2(-0.05 * sin(t2 * PI), t2 * 1.6))
		p.put(MeshKit.extrude(wing, 0.06, "angelwing"), "stone_trim", p.t(Vector3(s * 0.15, 2.6, -0.2), Vector3(0, s * 0.5 + PI, 0), Vector3(s, 1, 1)))
	p.collide(-3.2, -3.2, 3.2, 3.2, 0, 4)
	# a thin trickle of rain running off the angel's wings into the basin
	B.light(pos + Vector3(0, 0.6, 0), {"color": Color(0.5, 0.6, 0.8), "energy": 0.0, "range": 1.0, "glow": false, "shadow": false})

static func _car(B: RoomBuilder, pos: Vector3, ry: float) -> Dictionary:
	# Avery's old estate car (tools/blender/car.py), parked on the gravel with its lights on
	var p := Props.P.new(B, {"pos": pos, "ry": ry})
	var car := Props.model(B, "car_estate", {"pos": pos, "ry": ry}, {"collide": false})
	if car == null:
		p.box(Vector3(1.75, 1.2, 4.4), "car_paint", Vector3(0, 0.75, 0))
	var headlights: Array = []
	for s in [-1, 1]:
		var sp := SpotLight3D.new()
		sp.light_color = Color(1.0, 0.94, 0.78); sp.light_energy = 6.0; sp.spot_range = 22.0; sp.spot_angle = 24.0; sp.spot_attenuation = 1.2
		sp.light_volumetric_fog_energy = 2.5; sp.shadow_enabled = true; sp.distance_fade_enabled = true; sp.distance_fade_begin = 60
		B.target.add_child(sp)
		sp.transform = p.xf * Transform3D(Basis(Vector3.RIGHT, -0.08), Vector3(s * 0.62, 0.7, 2.3))
		headlights.append(sp)
		p.glow(Vector3(s * 0.62, 0.7, 2.26), Color(1.0, 0.95, 0.8), 1.1, 0.8)
		p.glow(Vector3(s * 0.68, 0.82, -2.27), Color(1.0, 0.15, 0.1), 0.45, 0.6)
	p.collide(-0.95, -2.4, 0.95, 2.4, 0, 1.45)
	return {"headlights": headlights, "boot": p.world(Vector3(0, 0.9, -2.8)), "door": p.world(Vector3(-1.3, 1.0, 0.3)), "glovebox": p.world(Vector3(1.3, 1.0, 0.8)), "node": car}

static func _rain(r: Room) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "Rain"
	p.amount = int(14000 * Settings.data.graphics.particles)
	p.lifetime = 1.6
	p.preprocess = 1.6
	p.fixed_fps = 0
	p.visibility_aabb = AABB(Vector3(-30, -30, -30), Vector3(60, 60, 60))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(24, 0.5, 24)
	pm.direction = Vector3(0.12, -1, 0.04); pm.spread = 2.0
	pm.initial_velocity_min = 14.0; pm.initial_velocity_max = 18.0
	pm.gravity = Vector3(0, -6, 0)
	pm.collision_mode = ParticleProcessMaterial.COLLISION_HIDE_ON_CONTACT
	pm.particle_flag_align_y = true
	p.process_material = pm
	var q := QuadMesh.new(); q.size = Vector2(0.012, 0.45)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.72, 0.8, 1.0, 0.32); m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	q.material = m
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	r.add_child(p)
	var col := GPUParticlesCollisionHeightField3D.new()
	col.size = Vector3(60, 40, 60); col.follow_camera_enabled = true; col.resolution = GPUParticlesCollisionHeightField3D.RESOLUTION_512
	r.add_child(col)
	r.updaters.append(func(_dt: float, _t: float) -> void:
		var cam := r.get_viewport().get_camera_3d()
		var outside: bool = r.get_parent().current == "exterior"
		p.emitting = outside
		p.visible = outside
		if cam: p.global_position = Vector3(cam.global_position.x, cam.global_position.y + 14.0, cam.global_position.z))
	return p

static func _ground_fog(r: Room) -> Array:
	var vols: Array = []
	var noise := NoiseTexture3D.new(); var fn := FastNoiseLite.new(); fn.frequency = 0.05; fn.fractal_octaves = 3
	noise.noise = fn; noise.width = 64; noise.height = 32; noise.depth = 64; noise.seamless = true
	for i in 4:
		var fv := FogVolume.new()
		fv.size = Vector3(40, 2.2, 22)
		fv.position = Vector3(-10 + i * 7, GY + 0.4, -14 - i * 11)
		var fm := FogMaterial.new()
		fm.density = 0.12; fm.albedo = Color(0.5, 0.55, 0.66); fm.height_falloff = 2.2; fm.edge_fade = 0.6
		fm.density_texture = noise
		fv.material = fm
		r.add_child(fv); vols.append(fv)
	r.updaters.append(func(_dt: float, t: float) -> void:
		for i in vols.size(): vols[i].position.x = -10 + i * 7 + sin(t * 0.05 + i) * 3.0)
	return vols
