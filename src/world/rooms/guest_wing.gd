class_name GuestWingBuilder
extends RefCounted
## The guest wing: a dark corridor (the lantern tutorial), Guest Room 3 and the hidden cloakroom.

static func build(world: World) -> void:
	_corridor(world)
	_guest_room(world)
	_cloakroom(world)

static func trace_mesh(parent: Node3D, tex: String, size: Vector2, xform: Transform3D, color := Color(0.49, 1.0, 0.77)) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = MeshKit.quad(size.x, size.y)
	var m := ShaderMaterial.new(); m.shader = load("res://src/fx/trace.gdshader")
	m.set_shader_parameter("mask", load("res://assets/textures/generated/%s.png" % tex))
	m.set_shader_parameter("color", color)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.transform = xform
	parent.add_child(mi)
	return mi

static func _corridor(world: World) -> void:
	var r := world.room("corridor", {
		"name": "The Guest Wing", "bounds": AABB(Vector3(-34.3, -1, 2.5), Vector3(24.3, 5, 3.0)), "neighbors": ["hall", "guestroom", "cloakroom"],
		"music": "corridor", "grade": "corridor", "surface": "wood", "acoustics": Vector3(0.45, 0.22, 0.5),
		"ambience": {"rain_in": 0.4, "wind": 0.35, "room_tone": 0.6, "drips": 0.4},
		"fog": {"color": Color(0.08, 0.03, 0.06), "density": 0.035, "albedo": Color(0.95, 0.62, 0.75), "moon": 0.25, "saturation": 1.15},
		"ambient": {"color": Color(0.12, 0.07, 0.1), "energy": 0.62},
		"map_rect": Rect2(-34, 2.5, 24, 3),
	})
	var B := world.builder(r)
	var H := 3.6
	B.floor_rect(-34, 2.5, -10.2, 5.5, 0, "boards", "wood")
	B.box(Vector3(23.4, 0.015, 1.5), "runner", Vector3(-22.2, 0.008, 4.0), Vector3.ZERO, {"shadow": false})
	B.collider(Vector3(-22.2, -0.24, 4.0), Vector3(22, 0.5, 1.5), Basis(), "carpet")
	B.ceiling(-34, 2.5, -10.2, 5.5, H, "plaster_cracked")
	for x in range(-33, -10, 3): B.box(Vector3(0.2, 0.18, 3.0), "walnut", Vector3(x, H - 0.09, 4), Vector3.ZERO, {"shadow": false})
	var wo := {"h": H, "mat": "wall_burgundy", "wainscot": {"h": 1.0}, "picture": 2.6}
	B.wall(-34, 2.5, -10.2, 2.5, wo.merged({"n": 1.0, "openings": [{"at": 20.8, "w": 1.1, "h": 2.4, "door": true}, {"at": 14.3, "w": 1.1, "h": 2.4, "door": true}, {"at": 7.3, "w": 1.1, "h": 2.4, "door": true}]}))
	B.wall(-34, 5.5, -10.2, 5.5, wo.merged({"n": -1.0, "openings": [{"at": 17.8, "w": 1.1, "h": 2.4, "door": true}, {"at": 10.8, "w": 1.1, "h": 2.4, "door": true}, {"at": 5.5, "w": 1.2, "h": 2.5, "door": true}]}))
	B.wall(-34, 2.5, -34, 5.5, wo.merged({"n": 1.0, "openings": [{"at": 1.5, "w": 1.3, "h": 2.1, "y": 0.9}]}))
	Props.arched_window(B, {"pos": Vector3(-34, 0, 4), "ry": PI * 0.5}, {"w": 1.2, "h": 2.1, "sill": 0.9, "curtains": "velvet_tattered", "tattered": true})
	var doors := {}
	for d in [[1, -13.2, "S"], [3, -19.7, "S"], [5, -26.7, "S"], [2, -16.2, "N"], [4, -23.2, "N"]]:
		var z := 2.38 if d[2] == "S" else 5.62
		doors[d[0]] = Props.door(B, {"pos": Vector3(d[1], 0, z), "ry": 0.0 if d[2] == "S" else PI}, {"w": 1.1, "h": 2.4, "number": d[0]})
	world.refs.corridor_doors = doors
	world.refs.guest_door_col = B.collider_box(-20.3, 2.2, -19.1, 2.55, -1, 3)
	for no in [1, 5]: B.collider_box(doors[no].leaves[0].pivot.position.x - 0.1, 2.2, doors[no].leaves[0].pivot.position.x + 1.2, 2.55, -1, 3)
	for no in [2, 4]: B.collider_box(doors[no].leaves[0].pivot.position.x - 1.2, 5.45, doors[no].leaves[0].pivot.position.x + 0.1, 5.8, -1, 3)
	# the hidden doorway: a wall panel only the lantern can see through
	world.refs.hidden_panel = B.box(Vector3(1.2, 2.5, 0.3), "wall_burgundy", Vector3(-28.5, 1.25, 5.65), Vector3.ZERO, {"dynamic": true})
	world.refs.hidden_panel_col = B.collider_box(-29.1, 5.45, -27.9, 5.85, -1, 3)
	world.refs.hidden_door_trace = trace_mesh(r, "sym_door", Vector2(1.4, 2.8), Transform3D(Basis(Vector3.UP, PI), Vector3(-28.5, 1.4, 5.47)))
	world.refs.corridor_message = trace_mesh(r, "trace_coats", Vector2(2.4, 0.6), Transform3D(Basis(Vector3.UP, PI), Vector3(-24.8, 1.9, 5.47)))
	world.refs.emblem_corridor = trace_mesh(r, "sym_emblem", Vector2(0.6, 0.6), Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-33.95, 3.0, 5.0)), Color(1.0, 0.88, 0.54))
	# furnishings
	Props.model(B, "vintage_grandfather_clock_01", {"pos": Vector3(-18.4, 0, 5.2), "ry": PI})
	world.refs.corridor_clock_pos = Vector3(-18.4, 1.6, 4.4)
	for x in [-14.6, -21.8]:
		Props.model(B, "ClassicConsole_01", {"pos": Vector3(x, 0, 2.82), "scale": 0.75})
		Props.model(B, "ceramic_vase_01", {"pos": Vector3(x - 0.25, 0.71, 2.8)}, {"collide": false})
	Props.model(B, "side_table_tall_01", {"pos": Vector3(-24.6, 0, 5.15)})
	var cand := Props.candelabra(B, {"pos": Vector3(-24.6, 0.76, 5.15)}, {"arms": 3, "lit": true, "h": 0.42, "dynamic": true})
	world.refs.pip_candelabra = cand
	world.refs.corridor_tea = Props.tea_trolley(B, {"pos": Vector3(-30.6, 0, 3.0)})
	world.refs.watcher = Props.portrait(B, {"pos": Vector3(-21.0, 1.9, 5.47), "ry": PI}, "portrait_watcher", {"w": 0.8, "h": 1.0})
	var eyes: Array = []
	for s in [-1, 1]:
		var e := MeshInstance3D.new(); e.mesh = MeshKit.sphere(0.016, 10, 6); e.material_override = MaterialLib.color(Color(0.95, 0.93, 0.88), 0.3)
		var pu := MeshInstance3D.new(); pu.mesh = MeshKit.sphere(0.008, 8, 4); pu.material_override = MaterialLib.color(Color(0.05, 0.03, 0.03), 0.2); pu.position.z = 0.011; e.add_child(pu)
		e.position = Vector3(-21.0 - s * 0.044, 1.9 + 0.035, 5.43); r.add_child(e); eyes.append(e)
	r.updaters.append(func(_dt: float, _t: float) -> void:
		var cam := r.get_viewport().get_camera_3d()
		if cam == null: return
		for e in eyes:
			var d: Vector3 = cam.global_position - e.global_position
			e.rotation.y = clampf(atan2(d.x, d.z), -0.6, 0.6)
			e.rotation.x = clampf(-atan2(d.y, Vector2(d.x, d.z).length()) * 0.6, -0.3, 0.3))
	Props.portrait(B, {"pos": Vector3(-15.6, 1.9, 2.53)}, "portrait_lady", {"w": 0.9, "h": 1.15})
	Props.model(B, "hanging_picture_frame_02", {"pos": Vector3(-29.8, 2.0, 2.53)}, {"collide": false})
	world.refs.pip_hide = Vector3(-33.2, 0.9, 4.6)
	var sc: Array = []
	for s in [[Vector3(-12.4, 2.2, 2.55), 0.0, true], [Vector3(-17.8, 2.2, 5.45), PI, false], [Vector3(-22.5, 2.2, 2.55), 0.0, false], [Vector3(-27.6, 2.2, 2.55), 0.0, true], [Vector3(-31.5, 2.2, 5.45), PI, false]]:
		sc.append(Props.sconce(B, {"pos": s[0], "ry": s[1]}, {"lit": s[2], "broken": not s[2], "energy": 0.7}))
	world.refs.corridor_sconces = sc
	for c in [[Vector3(-33.95, 3.55, 2.55), 0.0], [Vector3(-10.4, 3.55, 5.45), PI], [Vector3(-20, 3.55, 2.55), 0.0]]: Props.cobweb(B, c[0], c[1], 0.9)
	HallBuilder._dust(r, AABB(Vector3(-33.5, 0.2, 2.7), Vector3(23, 3.2, 2.6)), 300)
	B.finalize()

static func _guest_room(world: World) -> void:
	var r := world.room("guestroom", {
		"name": "Guest Room 3", "bounds": AABB(Vector3(-24, -1, -4), Vector3(7, 5, 6.2)), "neighbors": ["corridor"],
		"music": "corridor", "grade": "guestroom", "surface": "wood", "acoustics": Vector3(0.35, 0.15, 0.7),
		"ambience": {"rain_in": 0.9, "wind": 0.2, "room_tone": 0.4},
		"fog": {"color": Color(0.06, 0.04, 0.1), "density": 0.03, "albedo": Color(0.75, 0.7, 1.0), "moon": 0.35, "saturation": 1.15},
		"ambient": {"color": Color(0.1, 0.09, 0.18), "energy": 0.66}, "map_rect": Rect2(-24, -4, 7, 6.2),
	})
	var B := world.builder(r)
	var H := 3.6
	B.floor_rect(-24, -4, -17, 2.2, 0, "boards", "wood")
	B.ceiling(-24, -4, -17, 2.2, H, "plaster")
	var wo := {"h": H, "mat": "wall_blue", "wainscot": {"h": 0.9}, "picture": 2.6}
	B.wall(-24, -4, -17, -4, wo.merged({"n": 1.0, "openings": [{"at": 5.3, "w": 1.3, "h": 2.1, "y": 0.9}]}))
	B.wall(-24, -4, -24, 2.2, wo.merged({"n": 1.0}))
	B.wall(-17, -4, -17, 2.2, wo.merged({"n": -1.0}))
	B.collider_box(-24, 2.2, -20.3, 2.5, -1, 4); B.collider_box(-19.1, 2.2, -17, 2.5, -1, 4)
	Props.arched_window(B, {"pos": Vector3(-18.7, 0, -4)}, {"w": 1.2, "h": 2.1, "sill": 0.9, "curtains": "velvet_plum"})
	var ws := SpotLight3D.new(); ws.light_color = Color(0.55, 0.65, 1.0); ws.light_energy = 1.2; ws.spot_range = 8; ws.spot_angle = 18; ws.light_volumetric_fog_energy = 3.0; ws.shadow_enabled = true
	r.add_child(ws); ws.look_at_from_position(Vector3(-18.7, 3.0, -6.0), Vector3(-20.0, 0, -1.0))
	Props.model(B, "GothicBed_01", {"pos": Vector3(-21.6, 0, -2.85)})
	world.refs.bed_pos = Vector3(-21.6, 0.8, -1.4)
	Props.model(B, "vintage_suitcase", {"pos": Vector3(-21.6, 0, -0.95)})
	Props.model(B, "GothicCabinet_01", {"pos": Vector3(-17.45, 0, 0.3), "ry": -PI * 0.5, "scale": 0.82})
	world.refs.guest_wardrobe_pos = Vector3(-18.3, 1.2, 0.3)
	Props.model(B, "GothicCommode_01", {"pos": Vector3(-23.65, 0, 0.6), "ry": PI * 0.5, "scale": 0.85})
	Props.model(B, "ornate_mirror_01", {"pos": Vector3(-23.97, 1.75, 0.6), "ry": PI * 0.5, "scale": 1.3}, {"collide": false})
	world.refs.vanity_pos = Vector3(-23.2, 1.0, 0.6)
	world.refs.rocking_chair = Props.model(B, "Rockingchair_01", {"pos": Vector3(-18.7, 0, -2.5), "ry": -0.6})
	r.updaters.append(func(_dt: float, t: float) -> void:
		var rc: Node3D = world.refs.rocking_chair
		if rc: rc.rotation.x = sin(t * 1.3) * (0.07 if world.refs.get("rocker_active", false) else 0.015))
	Props.model(B, "ClassicNightstand_01", {"pos": Vector3(-23.3, 0, -3.5)})
	Props.candle(B, {"pos": Vector3(-23.3, 0.7, -3.5)}, {"lit": true, "h": 0.14})
	Props.rug(B, {"pos": Vector3(-20.5, 0, -0.6)}, {"w": 3.2, "d": 2.4, "mat": "rug_guest"})
	Props.portrait(B, {"pos": Vector3(-20.5, 2.1, 2.17), "ry": PI}, "portrait_guest", {"w": 0.9, "h": 0.7, "light": false})
	world.refs.code_bighead = trace_mesh(r, "trace_bighead", Vector2(1.2, 0.3), Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(-21.6, 0.03, -2.0)), Color(1.0, 0.82, 0.5))
	B.finalize()

static func _cloakroom(world: World) -> void:
	var r := world.room("cloakroom", {
		"name": "The Cloakroom", "hidden": true, "bounds": AABB(Vector3(-32, -1, 5.8), Vector3(8, 5, 8.2)), "neighbors": ["corridor"],
		"music": "corridor", "grade": "cloakroom", "surface": "wood", "acoustics": Vector3(0.3, 0.12, 0.8),
		"ambience": {"rain_in": 0.3, "room_tone": 0.5},
		"fog": {"color": Color(0.03, 0.08, 0.05), "density": 0.03, "albedo": Color(0.6, 0.95, 0.75), "moon": 0.0, "saturation": 1.15},
		"ambient": {"color": Color(0.08, 0.13, 0.09), "energy": 0.72}, "map_rect": Rect2(-32, 5.8, 8, 8.2),
	})
	var B := world.builder(r)
	var H := 3.4
	B.floor_rect(-32, 5.8, -24, 14, 0, "boards_dark", "wood")
	B.ceiling(-32, 5.8, -24, 14, H, "plaster")
	var wo := {"h": H, "mat": "wall_ochre", "wainscot": {"h": 1.0}, "picture": 2.7}
	B.wall(-32, 14, -24, 14, wo.merged({"n": -1.0}))
	B.wall(-32, 5.8, -32, 14, wo.merged({"n": 1.0}))
	B.wall(-24, 5.8, -24, 14, wo.merged({"n": -1.0}))
	B.collider_box(-32, 5.5, -29.1, 5.8, -1, 4); B.collider_box(-27.9, 5.5, -24, 5.8, -1, 4)
	Props.counter(B, {"pos": Vector3(-29.6, 0, 9.0)}, 4.6, 0.7)
	world.refs.counter_pos = Vector3(-29.6, 1.1, 8.3)
	var north := Props.hook_rail(B, {"pos": Vector3(-31.3, 1.95, 13.95), "ry": PI}, 10, 0.7, 1, [7])
	var west := Props.hook_rail(B, {"pos": Vector3(-31.95, 1.95, 12.6), "ry": PI * 0.5}, 6, 0.75, 11)
	world.refs.hooks = north + west
	for h in north:
		if h.no == 7: world.refs.hook7 = h
	B.box(Vector3(7.4, 0.04, 0.4), "walnut", Vector3(-28.1, 2.75, 13.75))
	var rng := RandomNumberGenerator.new(); rng.seed = 3
	for i in 10:
		var x := -31.4 + i * 0.72
		if rng.randf() < 0.5:
			B.cyl(0.11, 0.11, 0.18, "black", Vector3(x, 2.86, 13.75), Vector3.ZERO, {"seg": 14}); B.cyl(0.18, 0.18, 0.01, "black", Vector3(x, 2.78, 13.75), Vector3.ZERO, {"seg": 16})
		else:
			B.cyl(0.18, 0.18, 0.3, ["velvet_green", "velvet_red", "velvet_plum"][i % 3], Vector3(x, 2.92, 13.75), Vector3.ZERO, {"seg": 16})
	var lamp := Props.P.new(B, {"pos": Vector3(-28.4, 1.11, 8.9)})
	lamp.cyl(0.07, 0.08, 0.02, "brass", Vector3(0, 0.01, 0)); lamp.cyl(0.01, 0.01, 0.3, "brass", Vector3(0, 0.16, 0))
	lamp.lathe([[0.0, 0], [0.14, 0.0], [0.12, 0.08], [0.0, 0.1]], "green_glass", Vector3(0, 0.25, 0.05), Vector3(-0.3, 0, 0), Vector3(1, 1, 0.55))
	lamp.light(Vector3(0, 0.2, 0.15), {"color": Color(0.78, 1.0, 0.65), "energy": 1.1, "range": 6.0, "priority": 2.0, "glow_size": 0.6})
	Props.model(B, "ornate_mirror_01", {"pos": Vector3(-24.03, 1.6, 11.5), "ry": -PI * 0.5, "scale": 1.6}, {"collide": false})
	Props.umbrella_stand(B, {"pos": Vector3(-24.6, 0, 6.6)})
	var lad := Props.P.new(B, {"pos": Vector3(-25.2, 0, 13.3), "ry": 0.2})
	for s in [-1, 1]: lad.box(Vector3(0.05, 3.0, 0.05), "oak", Vector3(s * 0.22, 1.45, 0), Vector3(-0.18, 0, 0))
	for i in 8: lad.box(Vector3(0.44, 0.04, 0.04), "oak", Vector3(0, 0.3 + i * 0.34, 0.05 - i * 0.06))
	world.refs.code_sunglasses = trace_mesh(r, "trace_sunglasses", Vector2(1.6, 0.35), Transform3D(Basis(), Vector3(-30.0, 0.65, 9.37)), Color(0.78, 1.0, 0.94))
	world.refs.porter_home = Vector3(-29.6, 0, 10.4)
	world.refs.cat_pos = Vector3(-26.0, 2.85, 13.7)
	Props.cobweb(B, Vector3(-31.95, 3.35, 13.95), PI * 0.5, 0.8)
	B.finalize()
