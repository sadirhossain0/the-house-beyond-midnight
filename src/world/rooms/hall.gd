class_name HallBuilder
extends RefCounted
## The entrance hall (the hub): imperial staircase to the Grand Clock on the half-landing,
## galleries, chandelier, rose window, portraits, the hearth beneath the landing, the Porter's desk.

static func build(world: World) -> void:
	var r := world.room("hall", {
		"name": "The Entrance Hall", "bounds": AABB(Vector3(-10, -1, -0.6), Vector3(20, 15, 20.6)), "neighbors": ["exterior", "corridor", "ballroom"],
		"music": "hall", "grade": "hall", "surface": "marble", "acoustics": Vector3(0.85, 0.32, 0.35),
		"ambience": {"rain_in": 0.75, "wind": 0.15, "room_tone": 0.5, "clock_ticks": 0.0},
		"fog": {"color": Color(0.04, 0.09, 0.09), "density": 0.022, "albedo": Color(0.62, 0.85, 0.95), "moon": 0.45, "saturation": 1.15},
		"ambient": {"color": Color(0.24, 0.22, 0.3), "energy": 0.95},
		"map_rect": Rect2(-10, 0, 20, 20),
	})
	var B := world.builder(r)
	var H := 13.0
	# --------------------------------------------------------------- floor, ceiling, walls
	B.floor_rect(-10, 0, 10, 20, 0, "marble_checker", "marble")
	B.ceiling(-10, 0, 10, 20, H, "plaster_cracked")
	for x in range(-10, 11, 4): B.box(Vector3(0.35, 0.4, 20), "walnut", Vector3(x, H - 0.2, 10), Vector3.ZERO, {"shadow": false})
	for z in range(0, 21, 4): B.box(Vector3(20, 0.4, 0.35), "walnut", Vector3(0, H - 0.2, z), Vector3.ZERO, {"shadow": false})
	for x in range(-8, 10, 4):
		for z in range(2, 20, 4): B.box(Vector3(0.5, 0.06, 0.5), "gilt", Vector3(x, H - 0.42, z), Vector3.ZERO, {"shadow": false})
	B.lathe([[0.0, 0], [1.0, 0], [0.9, -0.1], [0.6, -0.18], [0.0, -0.22]], "plaster_moulding", Vector3(0, H - 0.4, 6), Vector3.ZERO, Vector3.ONE, {"seg": 28})
	var wo := {"h": H, "mat": "wall_green", "wainscot": {"h": 1.3}, "picture": 4.1}
	B.wall(-10, 0, 10, 0, wo.merged({"n": 1.0, "openings": [{"at": 10.0, "w": 2.4, "h": 3.4, "door": true}, {"at": 6.2, "w": 1.7, "h": 3.7, "y": 0.9}, {"at": 13.8, "w": 1.7, "h": 3.7, "y": 0.9}, {"at": 10.0, "w": 2.4, "h": 3.6, "y": 5.6}]}))
	B.wall(-10, 20, 10, 20, wo.merged({"n": -1.0, "openings": [{"at": 10.0, "w": 2.3, "h": 2.3, "y": 10.15}]}))
	B.wall(-10, 0, -10, 20, wo.merged({"n": 1.0, "openings": [{"at": 4.0, "w": 1.6, "h": 3.0, "door": true}, {"at": 4.0, "w": 1.4, "h": 2.6, "y": 5.0}, {"at": 17.0, "w": 1.6, "h": 2.8, "y": 2.5}]}))
	B.wall(10, 0, 10, 20, wo.merged({"n": -1.0, "openings": [{"at": 4.0, "w": 2.6, "h": 3.4, "door": true}, {"at": 4.0, "w": 1.4, "h": 2.6, "y": 5.0}, {"at": 17.0, "w": 1.6, "h": 2.8, "y": 2.5}]}))
	# --------------------------------------------------------------- imperial staircase
	Props.stair_flight(B, -2.5, 2.5, 8, 14, 0, 2.5, 13)
	for i in 6:
		var hh := 2.5 * (i / 6.0) - 0.35
		if hh > 0.05: B.collider_box(-2.5, 8 + i, 2.5, 9 + i, -1, hh)
	B.box(Vector3(20, 0.25, 6), "walnut", Vector3(0, 2.375, 17))
	B.floor_rect(-10, 14, 10, 20, 2.5, "boards", "wood")
	B.box(Vector3(19.4, 0.02, 5.2), "runner", Vector3(0, 2.512, 17), Vector3.ZERO, {"shadow": false})
	for seg in [[-7.5, -2.5], [2.5, 7.5]]:
		var cx: float = (seg[0] + seg[1]) * 0.5; var w: float = seg[1] - seg[0]
		B.box(Vector3(w, 2.3, 0.2), "wainscot", Vector3(cx, 1.15, 14.1))
		B.box(Vector3(w, 0.14, 0.3), "walnut", Vector3(cx, 2.3, 14.0))
		Props.balustrade(B, Vector3(seg[0], 2.5, 14.05), Vector3(seg[1], 2.5, 14.05))
	B.collider_box(-10, 14, 10, 20, -1, 2.3)
	for s in [-1, 1]:
		var x0 := -10.0 if s < 0 else 7.5; var x1 := -7.5 if s < 0 else 10.0
		Props.stair_flight(B, x0, x1, 14, 8, 2.5, 5.0, 13, [false, true] if s < 0 else [true, false])
		B.collider_box(x0, 8, x1, 14, -1, 2.2)
		var gx0 := -10.0 if s < 0 else 6.0; var gx1 := -6.0 if s < 0 else 10.0
		B.box(Vector3(4, 0.25, 8), "walnut", Vector3((gx0 + gx1) * 0.5, 4.87, 4))
		B.floor_rect(gx0, 0, gx1, 8, 5.0, "boards", "wood")
		B.box(Vector3(3.0, 0.02, 7.6), "runner", Vector3((gx0 + gx1) * 0.5, 5.012, 4), Vector3.ZERO, {"shadow": false})
		var edge := -6.0 if s < 0 else 6.0
		Props.balustrade(B, Vector3(edge, 5.0, 0.25), Vector3(edge, 5.0, 8.0))
		Props.balustrade(B, Vector3(-7.5 if s < 0 else 6.0, 5.0, 8.0), Vector3(-6.0 if s < 0 else 7.5, 5.0, 8.0))
		for z in [1, 4, 7]: B.box(Vector3(0.25, 0.6, 0.4), "walnut", Vector3(edge, 4.5, z))
	# --------------------------------------------------------------- the Grand Clock
	world.refs.grand_clock = Props.grand_clock(B, {"pos": Vector3(0, 2.5, 19.25), "ry": PI})
	world.refs.grand_clock_front = Vector3(0, 2.5, 17.3)
	# --------------------------------------------------------------- chandelier
	world.refs.hall_chandelier = Props.chandelier(B, {"pos": Vector3(0, H - 0.3, 6)}, {"tiers": 3, "radius": 1.7, "arms": 12, "drop": 3.6, "lit": 0.3, "energy": 9.0, "range": 22.0, "id": "hall_chandelier"})
	# --------------------------------------------------------------- windows, rose window, moonlight
	for x in [-3.8, 3.8]: Props.arched_window(B, {"pos": Vector3(x, 0, 0.0)}, {"w": 1.6, "h": 3.7, "sill": 0.9, "curtains": "velvet_red"})
	Props.arched_window(B, {"pos": Vector3(0, 5.6, 0.0)}, {"w": 2.3, "h": 3.6, "sill": 0.0, "curtains": null})
	var rose := Props.P.new(B, {"pos": Vector3(0, 11.3, 19.9), "ry": PI})
	rose.disc(1.1, "window_night", Vector3(0, 0, -0.05), Vector3.ZERO, {"shadow": false})
	rose.torus(1.12, 0.07, "stone_trim", Vector3.ZERO); rose.torus(0.45, 0.05, "stone_trim", Vector3.ZERO)
	for i in 8: rose.box(Vector3(0.05, 2.2, 0.06), "stone_trim", Vector3.ZERO, Vector3(0, 0, float(i) / 8.0 * PI))
	# a cold moonbeam through the rose window onto the clock (real light; fog makes the shaft)
	var rose_spot := SpotLight3D.new()
	rose_spot.light_color = Color(0.6, 0.7, 1.0); rose_spot.light_energy = 4.0; rose_spot.spot_range = 16.0; rose_spot.spot_angle = 14.0
	rose_spot.light_volumetric_fog_energy = 7.0; rose_spot.shadow_enabled = true
	r.add_child(rose_spot); rose_spot.look_at_from_position(Vector3(0, 11.3, 21.5), Vector3(0, 2.5, 15.0))
	for x in [-3.8, 3.8]:
		var ws := SpotLight3D.new()
		ws.light_color = Color(0.55, 0.65, 1.0); ws.light_energy = 3.0; ws.spot_range = 16.0; ws.spot_angle = 16.0; ws.light_volumetric_fog_energy = 6.0
		ws.shadow_enabled = true
		r.add_child(ws); ws.look_at_from_position(Vector3(x, 5.0, -3.0), Vector3(x * 0.4, 0, 7.0))
	world.refs.hall_moon_spots = [rose_spot]
	_dust(r, AABB(Vector3(-9, 0.2, 0.5), Vector3(18, 11, 18.5)), 900)
	# --------------------------------------------------------------- hearth, desk, clocks
	world.refs.hall_fire = Props.fireplace(B, {"pos": Vector3(5, 0, 13.75), "ry": PI}, {"w": 2.4, "lit": false})
	Props.model(B, "mantel_clock_01", {"pos": Vector3(5, 1.77, 13.55), "ry": PI, "scale": 1.2}, {"collide": false})
	world.refs.mantel_clock_pos = Vector3(5, 1.9, 13.2)
	for dx in [-0.8, 0.8]: Props.model(B, "brass_candleholders", {"pos": Vector3(5 + dx, 1.77, 13.6), "ry": PI, "scale": 0.4}, {"collide": false})
	Props.model(B, "ArmChair_01", {"pos": Vector3(3.6, 0, 11.6), "ry": PI * 0.85})
	Props.model(B, "ArmChair_01", {"pos": Vector3(6.5, 0, 11.4), "ry": -PI * 0.85})
	Props.rug(B, {"pos": Vector3(5, 0, 12.2)}, {"w": 3.2, "d": 2.2, "mat": "rug_guest"})
	Props.reception_desk(B, {"pos": Vector3(-5, 0, 12.4), "ry": PI})
	world.refs.desk_pos = Vector3(-5, 1.1, 11.6)
	world.refs.register_pos = Vector3(-4.7, 1.15, 12.2)
	Props.key_rack(B, {"pos": Vector3(-5, 1.75, 13.88), "ry": PI})
	Props.model(B, "wall_clock", {"pos": Vector3(-2.95, 1.75, 13.95), "ry": PI, "scale": 1.6}, {"collide": false})
	world.refs.wall_clock_pos = Vector3(-2.95, 1.75, 13.4)
	# --------------------------------------------------------------- portraits
	var pp := func(id: String, tex: String, pos: Vector3, ry: float, w: float, h: float) -> void:
		world.refs["portrait_" + id] = Props.portrait(B, {"pos": pos, "ry": ry}, tex, {"w": w, "h": h})
	pp.call("edmund", "portrait_edmund", Vector3(-3.7, 5.1, 19.95), PI, 1.3, 1.75)
	pp.call("margaret", "portrait_margaret", Vector3(3.7, 5.1, 19.95), PI, 1.3, 1.75)
	pp.call("celeste", "portrait_celeste", Vector3(-7.3, 4.9, 19.95), PI, 1.0, 1.3)
	pp.call("youngest", "portrait_youngest", Vector3(7.3, 4.9, 19.95), PI, 1.0, 1.3)
	pp.call("a1", "portrait_ancestor1", Vector3(-9.95, 7.2, 2.2), PI * 0.5, 0.9, 1.2)
	pp.call("a2", "portrait_ancestor2", Vector3(-9.95, 7.2, 6.0), PI * 0.5, 0.9, 1.2)
	pp.call("a3", "portrait_ancestor3", Vector3(9.95, 7.2, 2.2), -PI * 0.5, 0.9, 1.2)
	pp.call("a4", "portrait_ancestor4", Vector3(9.95, 7.2, 6.0), -PI * 0.5, 0.9, 1.2)
	world.refs.youngest_pos = Vector3(7.3, 4.6, 19.0)
	Props.crest(B, {"pos": Vector3(0, 4.4, 0.08)})
	# --------------------------------------------------------------- doors
	world.refs.front_door = Props.door(B, {"pos": Vector3(0, 0, -0.12)}, {"w": 2.4, "h": 3.4, "double": true})
	world.refs.front_door_col = B.collider_box(-1.25, -0.4, 1.25, 0.05, -1, 4)
	world.refs.front_door_col.disabled = true
	world.refs.west_door = Props.door(B, {"pos": Vector3(-10.12, 0, 4), "ry": PI * 0.5}, {"w": 1.6, "h": 3.0, "open": 1.2})
	world.refs.ballroom_door = Props.door(B, {"pos": Vector3(10.12, 0, 4), "ry": -PI * 0.5}, {"w": 2.6, "h": 3.4, "double": true, "mat": "walnut"})
	world.refs.ballroom_door_col = B.collider_box(9.7, 2.7, 10.4, 5.3, -1, 4)
	world.refs.ballroom_chains = Props.spectral_chains(B, {"pos": Vector3(9.8, 0.1, 4), "ry": -PI * 0.5}, {"w": 2.6, "h": 3.2})
	for d in [[-10.12, 17, 2.5, PI * 0.5, 1.6, 2.8, "library"], [10.12, 17, 2.5, -PI * 0.5, 1.6, 2.8, "kitchen"], [-10.12, 4, 5.0, PI * 0.5, 1.4, 2.6, ""], [10.12, 4, 5.0, -PI * 0.5, 1.4, 2.6, ""]]:
		Props.door(B, {"pos": Vector3(d[0], d[2], d[1]), "ry": d[3]}, {"w": d[4], "h": d[5]})
		if d[6] != "":
			world.refs[d[6] + "_chains"] = Props.spectral_chains(B, {"pos": Vector3(d[0] + (0.25 if d[0] < 0 else -0.25), d[2] + 0.1, d[1]), "ry": d[3]}, {"w": d[4], "h": d[5]})
	# --------------------------------------------------------------- furnishings
	Props.rug(B, {"pos": Vector3(0, 0, 4.6)}, {"w": 6.4, "d": 4.6, "mat": "rug_hall"})
	Props.model(B, "side_table_tall_01", {"pos": Vector3(-3.3, 0, 6.3), "scale": 1.05})
	world.refs.lantern_table_pos = Vector3(-3.3, 0.8, 6.3)
	Props.model(B, "GreenChair_01", {"pos": Vector3(-8.8, 0, 1.4), "ry": PI * 0.25})
	Props.model(B, "side_table_01", {"pos": Vector3(-7.6, 0, 1.0)})
	Props.candle(B, {"pos": Vector3(-7.6, 0.55, 1.0)}, {"lit": true})
	Props.model(B, "sofa_03", {"pos": Vector3(8.7, 0, 3.0), "ry": -PI * 0.5, "scale": 0.85})
	_dust_sheet(B, Vector3(8.7, 0, 3.0), -PI * 0.5, Vector3(2.5, 1.0, 0.9))
	Props.model(B, "marble_bust_01", {"pos": Vector3(-9.3, 1.15, 7.3), "ry": PI * 0.5, "scale": 1.5}, {"collide": false})
	B.box(Vector3(0.42, 1.15, 0.42), "stone_trim", Vector3(-9.3, 0.575, 7.3), Vector3.ZERO, {"collide": true})
	for x in [-1.9, 1.9]: Props.model(B, "potted_plant_01", {"pos": Vector3(x, 0, 0.8), "scale": 1.1})
	Props.model(B, "potted_plant_02", {"pos": Vector3(9.2, 0, 7.4), "scale": 1.3})
	Props.umbrella_stand(B, {"pos": Vector3(2.4, 0, 1.6)})
	Props.model(B, "ClassicConsole_01", {"pos": Vector3(-9.6, 0, 10.8), "ry": PI * 0.5, "scale": 0.95})
	Props.model(B, "antique_ceramic_vase_01", {"pos": Vector3(-9.6, 0.92, 10.4)}, {"collide": false})
	Props.candelabra(B, {"pos": Vector3(-9.6, 0.92, 11.3)}, {"arms": 3, "lit": true, "h": 0.4})
	Props.model(B, "ClassicConsole_01", {"pos": Vector3(9.6, 0, 10.8), "ry": -PI * 0.5, "scale": 0.95})
	Props.model(B, "brass_vase_01", {"pos": Vector3(9.6, 0.92, 10.8)}, {"collide": false})
	Props.model(B, "GothicCommode_01", {"pos": Vector3(-8.0, 5.0, 0.6), "scale": 0.9})
	Props.model(B, "vintage_suitcase", {"pos": Vector3(8.2, 5.0, 1.2), "ry": 0.3})
	# hub additions revealed as the house is restored
	world.refs.wardrobe = Props.model(B, "GothicCabinet_01", {"pos": Vector3(-9.35, 0, 1.6), "ry": PI * 0.5, "scale": 0.85}, {"collide": false})
	world.refs.wardrobe.visible = false
	world.refs.wardrobe_pos = Vector3(-8.4, 0, 1.6)
	world.refs.cabinet = Props.model(B, "vintage_cabinet_01", {"pos": Vector3(9.55, 0, 6.2), "ry": -PI * 0.5, "scale": 0.85}, {"collide": false})
	world.refs.cabinet.visible = false
	world.refs.cabinet_pos = Vector3(8.6, 0, 6.2)
	for c in [[Vector3(-9.95, 12.9, 0.05), 0.0], [Vector3(9.95, 12.9, 19.95), PI], [Vector3(-9.95, 4.8, 0.05), 0.0], [Vector3(-9.95, 12.9, 19.95), PI * 0.5]]:
		Props.cobweb(B, c[0], c[1], 1.4)
	# --------------------------------------------------------------- sconces
	var sconces: Array = []
	for sc in [[Vector3(-7, 2.6, 0.05), 0.0, true], [Vector3(7, 2.6, 0.05), 0.0, false], [Vector3(-5.6, 4.7, 19.95), PI, true], [Vector3(5.6, 4.7, 19.95), PI, true],
			[Vector3(-9.95, 7.0, 4.0), PI * 0.5, false], [Vector3(9.95, 7.0, 4.0), -PI * 0.5, true], [Vector3(-9.95, 2.6, 6.5), PI * 0.5, true], [Vector3(9.95, 2.6, 6.5), -PI * 0.5, false]]:
		sconces.append(Props.sconce(B, {"pos": sc[0], "ry": sc[1]}, {"lit": sc[2], "broken": not sc[2]}))
	world.refs.hall_sconces = sconces
	B.finalize()

static func _dust(r: Room, box: AABB, amount: int) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = int(amount * Settings.data.graphics.particles)
	p.lifetime = 14.0
	p.preprocess = 14.0
	p.visibility_aabb = box
	p.position = box.get_center()
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = box.size * 0.5
	pm.gravity = Vector3(0, -0.01, 0)
	pm.initial_velocity_min = 0.0; pm.initial_velocity_max = 0.05
	pm.direction = Vector3(0, 1, 0); pm.spread = 180.0
	pm.turbulence_enabled = true; pm.turbulence_noise_strength = 0.4; pm.turbulence_noise_scale = 3.0; pm.turbulence_influence_min = 0.05; pm.turbulence_influence_max = 0.1
	pm.scale_min = 0.6; pm.scale_max = 1.4
	p.process_material = pm
	var q := QuadMesh.new(); q.size = Vector2(0.012, 0.012)
	var dm := StandardMaterial3D.new()
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	dm.albedo_color = Color(1.0, 0.95, 0.85, 0.5); dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	dm.roughness = 1.0; dm.backlight_enabled = true; dm.backlight = Color(1, 1, 1)
	q.material = dm
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	r.add_child(p)
	return p

static func _dust_sheet(B: RoomBuilder, pos: Vector3, ry: float, size: Vector3) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = int(pos.x * 77)
	var fn := func(v: Vector3) -> Vector3:
		var o := v
		if v.y > 0.0 and v.z > -size.z * 0.2: o.y -= 0.25 * (1.0 - absf(v.x) / (size.x * 0.5))
		if v.y < -size.y * 0.4: o.x *= 1.08; o.z *= 1.12
		o.y += sin(v.x * 4.0 + v.z * 3.0) * 0.03 + (rng.randf() - 0.5) * 0.02
		return o
	var mesh := MeshKit.displaced_box(size, Vector3i(16, 8, 8), fn, "sheet%.2f" % pos.x)
	B.add_static(mesh, "dustsheet", Transform3D(Basis(Vector3.UP, ry), pos + Vector3(0, size.y * 0.5, 0)))
