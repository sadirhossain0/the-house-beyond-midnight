class_name BallroomBuilder
extends RefCounted
## The Grand Ballroom in two states. Now: dust, a crashed chandelier, a rotten cake, moonlight.
## Then (the sealed night, via the anchor clock): candlelight, garlands, confetti frozen in the air.
## Plus the balcony beyond the mirror-door.

static func build(world: World) -> void:
	_ballroom(world)
	_balcony(world)

static func _ballroom(world: World) -> void:
	var r := world.room("ballroom", {
		"name": "The Grand Ballroom", "bounds": AABB(Vector3(10.3, -1, -6), Vector3(29.7, 12, 24)), "neighbors": ["hall", "balcony"],
		"music": "ballroom", "grade": "ballroom_now", "surface": "parquet", "acoustics": Vector3(0.95, 0.38, 0.3),
		"ambience": {"rain_in": 0.55, "wind": 0.2, "room_tone": 0.5},
		"fog": {"color": Color(0.05, 0.07, 0.15), "density": 0.03, "albedo": Color(0.55, 0.7, 1.0), "moon": 0.5, "saturation": 1.0},
		"fog_then": {"color": Color(0.1, 0.06, 0.08), "density": 0.016, "albedo": Color(0.92, 0.84, 0.95), "emission": Color(0.015, 0.008, 0.014), "moon": 0.2, "saturation": 1.2},
		"ambient": {"color": Color(0.12, 0.16, 0.3), "energy": 0.8},
		"ambient_then": {"color": Color(0.26, 0.21, 0.32), "energy": 1.0},
		"map_rect": Rect2(10, -6, 30, 24),
	})
	r.enable_states()
	var B := world.builder(r)
	var H := 10.0
	# --------------------------------------------------------------- shell (common to both states)
	B.collider(Vector3(25, -0.25, 6), Vector3(29.7, 0.5, 24), Basis(), "parquet")
	B.ceiling(10.3, -6, 40, 18, H, "plaster_moulding")
	var wo := {"h": H, "mat": "wall_cream", "wainscot": {"h": 1.1, "mat": "plaster_moulding"}, "rail_mat": "gilt", "picture": 6.6, "picture_mat": "gilt", "cornice_mat": "plaster_moulding"}
	B.wall(10.3, 18, 40, 18, wo.merged({"n": -1.0, "openings": [{"at": 14.7, "w": 2.4, "h": 4.2, "door": true}]}))
	B.wall(10.3, -6, 40, -6, wo.merged({"n": 1.0, "openings": [{"at": 3.7, "w": 2.2, "h": 5.4, "y": 0.8}, {"at": 9.7, "w": 2.2, "h": 5.4, "y": 0.8}, {"at": 19.7, "w": 2.2, "h": 5.4, "y": 0.8}, {"at": 25.7, "w": 2.2, "h": 5.4, "y": 0.8}]}))
	B.wall(10.3, -6, 10.3, 18, wo.merged({"n": 1.0, "openings": [{"at": 10.0, "w": 2.6, "h": 3.4, "door": true}]}))
	B.wall(40, -6, 40, 18, wo.merged({"n": -1.0}))
	# coffered ceiling with a painted night sky in the centre
	for x in range(12, 40, 4): B.box(Vector3(0.3, 0.35, 24), "gilt_dull", Vector3(x, H - 0.17, 6), Vector3.ZERO, {"shadow": false})
	for z in range(-6, 19, 4): B.box(Vector3(29.7, 0.35, 0.3), "gilt_dull", Vector3(25, H - 0.17, z), Vector3.ZERO, {"shadow": false})
	B.add_static(MeshKit.disc(4.5, 64), MaterialLib.get_mat("mural"), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(25, H - 0.36, 6)), false)
	B.add_static(MeshKit.torus(4.6, 0.12, TAU, 8, 64), "gilt", Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(25, H - 0.36, 6)))
	# pilasters between bays
	for x in [11.2, 17.0, 23.0, 27.0, 33.0, 38.9]:
		Props.pilaster(B, {"pos": Vector3(x, 0, -5.97)}, {"h": H, "w": 0.55})
		Props.pilaster(B, {"pos": Vector3(x, 0, 17.97), "ry": PI}, {"h": H, "w": 0.55})
	# windows (south)
	for x in [14.0, 20.0, 30.0, 36.0]:
		B.common(); Props.arched_window(B, {"pos": Vector3(x, 0, -6.0)}, {"w": 2.1, "h": 5.4, "sill": 0.8, "curtains": null})
		B.now(); _curtains(B, x, "velvet_tattered", true)
		B.then(); _curtains(B, x, "velvet_red", false)
	B.common()
	# mirrors (north wall + one on the south wall) and the mirror-door to the balcony
	var mirrors: Array = []
	for mx in [14.0, 20.0, 30.0, 36.0]:
		mirrors.append(Props.mirror(B, {"pos": Vector3(mx, 1.2, 17.95), "ry": PI}, {"w": 2.0, "h": 4.6}))
	mirrors.append(Props.mirror(B, {"pos": Vector3(25.0, 1.2, -5.95)}, {"w": 2.0, "h": 4.6}))
	world.refs.ballroom_mirrors = mirrors
	var door_root := Node3D.new(); door_root.position = Vector3(23.8, 0, 17.92); r.add_child(door_root)
	var door_leaf := Node3D.new(); door_leaf.name = "MirrorDoor"; door_root.add_child(door_leaf)
	B.add_node(MeshKit.box(Vector3(2.4, 4.2, 0.08)), "gilt", Transform3D(Basis(), Vector3(1.2, 2.1, 0)), door_leaf)
	B.add_node(MeshKit.quad(2.0, 3.8), "mirror", Transform3D(Basis(Vector3.UP, PI), Vector3(1.2, 2.1, -0.05)), door_leaf)
	world.refs.mirror_door = door_leaf
	world.refs.mirror_door_col = B.collider_box(23.8, 17.7, 26.2, 18.1, -1, 5)
	# --------------------------------------------------------------- stage
	B.box(Vector3(5.2, 0.8, 16), "walnut", Vector3(37.6, 0.4, 6))
	B.box(Vector3(5.2, 0.02, 16), "parquet", Vector3(37.6, 0.81, 6), Vector3.ZERO, {"shadow": false})
	B.collider(Vector3(37.6, 0.4, 6), Vector3(5.2, 0.8, 16), Basis(), "wood")
	for i in 4: B.box(Vector3(0.4, 0.2 * (i + 1), 4.0), "walnut", Vector3(34.8 - i * 0.4 + 0.2 + 1.2, 0.1 * (i + 1), 6))
	B.ramp(33.4, 4.0, 35.0, 8.0, 0.0, 0.8, "x", "wood")
	B.box(Vector3(0.12, 0.8, 16), "gilt", Vector3(35.0, 0.4, 6), Vector3.ZERO, {"shadow": false})
	var stands: Array = []
	var instruments := ["violin", "cello", "flute"]
	for i in 3:
		stands.append(Props.music_stand(B, {"pos": Vector3(36.6, 0.8, 2.0 + i * 4.0), "ry": -PI * 0.5}, instruments[i]))
		Props.gilt_chair(B, {"pos": Vector3(37.6, 0.8, 2.0 + i * 4.0), "ry": -PI * 0.5}, {"mat": "velvet_red"})
	world.refs.music_stands = stands
	Props.harp(B, {"pos": Vector3(38.8, 0.8, 12.6), "ry": -PI * 0.5})
	B.now(); world.refs.piano = Props.grand_piano(B, {"pos": Vector3(31.6, 0, -2.6), "ry": -PI * 0.3}, {"dusty": true, "broken": true})
	B.then(); Props.grand_piano(B, {"pos": Vector3(31.6, 0, -2.6), "ry": -PI * 0.3}, {})
	B.common()
	world.refs.piano_pos = Vector3(31.1, 1.1, -1.6)
	# --------------------------------------------------------------- the anchor clock
	world.refs.ballroom_anchor = Props.anchor_clock(B, {"pos": Vector3(12.6, 0, -2.4), "ry": PI * 0.5})
	world.refs.ballroom_anchor_pos = Vector3(13.6, 0, -2.4)
	# --------------------------------------------------------------- star inlay
	var star := StandardMaterial3D.new(); star.albedo_texture = load("res://assets/textures/generated/star_inlay.png"); star.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS; star.roughness = 0.25
	B.add_static(MeshKit.quad(6.4, 6.4), star, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(25, 0.015, 6)), false)
	# --------------------------------------------------------------- NOW: dust and ruin
	B.now()
	B.add_static(MeshKit.box(Vector3(29.7, 0.1, 24)), "parquet_dusty", Transform3D(Basis(), Vector3(25.15, -0.05, 6)))
	world.refs.fallen_chandelier = Props.chandelier(B, {"pos": Vector3(25, 0.4, 6)}, {"tiers": 3, "radius": 2.0, "arms": 14, "broken": true})
	Props.rubble(B, {"pos": Vector3(25, 0, 6)}, 45, 2.6)
	B.collider(Vector3(25, 0.8, 6), Vector3(5.0, 1.6, 4.0))
	for cx in [17.0, 33.0]: Props.chandelier(B, {"pos": Vector3(cx, H - 0.35, 6)}, {"tiers": 2, "radius": 1.1, "arms": 9, "drop": 2.4, "lit": 0.0, "energy": 0.0})
	for t in _table_spots(): Props.round_table(B, {"pos": t}, {"r": 0.75, "dusty": true})
	B.box(Vector3(1.2, 0.12, 4.4), "rotten_wood", Vector3(33.6, 0.5, 13.0), Vector3(0.2, 0.4, 0.35))   # fallen gallery beam
	Props.rubble(B, {"pos": Vector3(33.4, 0, 13.6)}, 24, 1.0)
	world.refs.screen_block_col = B.collider_box(32.6, 12.2, 34.4, 14.6, -1, 2)
	Props.cake(B, {"pos": Vector3(11.6, 0.95, 12.6)}, true)
	Props.champagne_tower(B, {"pos": Vector3(11.6, 0.95, 10.4)}, true)
	var fallen_rng := RandomNumberGenerator.new(); fallen_rng.seed = 11
	for i in 6:
		var n := Props.gilt_chair(B, {"pos": Vector3(fallen_rng.randf_range(15, 33), 0, fallen_rng.randf_range(-3, 15)), "ry": fallen_rng.randf() * TAU}, {"mat": "velvet_tattered", "collide": false})
	for c in [[Vector3(39.95, 9.9, 17.95), PI], [Vector3(10.35, 9.9, -5.95), 0.0], [Vector3(39.95, 9.9, -5.95), -PI * 0.5]]: Props.cobweb(B, c[0], c[1], 1.6)
	for x in [14.0, 20.0, 30.0, 36.0]:
		var sp := SpotLight3D.new(); sp.light_color = Color(0.55, 0.66, 1.0); sp.light_energy = 3.0; sp.spot_range = 20; sp.spot_angle = 17; sp.light_volumetric_fog_energy = 6.0; sp.shadow_enabled = true
		r.state_now.add_child(sp); sp.look_at_from_position(Vector3(x, 6.5, -9.5), Vector3(x + 1.5, 0, 4.0))
	for cp in [Vector3(15.5, 0.85, -2.4), Vector3(34.6, 0.85, 14.0)]: Props.candle(B, {"pos": cp}, {"lit": true})
	world.refs.newspaper_pos = Vector3(29.6, 0.05, -1.2)
	# --------------------------------------------------------------- THEN: the sealed night
	B.then()
	B.add_static(MeshKit.box(Vector3(29.7, 0.1, 24)), "parquet", Transform3D(Basis(), Vector3(25.15, -0.05, 6)))
	world.refs.grand_chandelier_then = Props.chandelier(B, {"pos": Vector3(25, H - 0.35, 6)}, {"tiers": 3, "radius": 2.0, "arms": 14, "drop": 2.0, "lit": 1.0, "energy": 10.0, "range": 24.0})
	for cx in [17.0, 33.0]: Props.chandelier(B, {"pos": Vector3(cx, H - 0.35, 6)}, {"tiers": 2, "radius": 1.1, "arms": 9, "drop": 2.4, "lit": 1.0, "energy": 5.0, "range": 16.0})
	for t in _table_spots(): Props.round_table(B, {"pos": t}, {"r": 0.75, "setting": true})
	Props.cake(B, {"pos": Vector3(11.6, 0.95, 12.6)}, false)
	Props.champagne_tower(B, {"pos": Vector3(11.6, 0.95, 10.4)}, false)
	for z in [-3.0, 3.0, 9.0, 15.0]:
		Props.garland(B, Vector3(10.6, 7.0, z), Vector3(10.6, 7.0, z + 3.0), 0.6)
		Props.garland(B, Vector3(39.7, 7.0, z), Vector3(39.7, 7.0, z + 3.0), 0.6)
	for x in [12.0, 18.0, 24.0, 30.0, 36.0]:
		Props.garland(B, Vector3(x, 7.0, -5.7), Vector3(x + 3.0, 7.0, -5.7), 0.5)
		Props.garland(B, Vector3(x, 7.0, 17.7), Vector3(x + 3.0, 7.0, 17.7), 0.5)
	_confetti(r.state_then)
	for cp in [Vector3(11.2, 2.4, 2.0), Vector3(11.2, 2.4, 8.0), Vector3(39.6, 2.4, 2.0), Vector3(39.6, 2.4, 10.0)]:
		Props.sconce(B, {"pos": cp, "ry": PI * 0.5 if cp.x < 20 else -PI * 0.5}, {"lit": true, "energy": 1.2})
	# --------------------------------------------------------------- buffet (common table, contents differ by state)
	B.common()
	var buf := Props.P.new(B, {"pos": Vector3(11.6, 0, 11.5)})
	buf.box(Vector3(1.2, 0.9, 5.0), "walnut", Vector3(0, 0.45, 0))
	buf.box(Vector3(1.4, 0.04, 5.2), "linen", Vector3(0, 0.92, 0))
	buf.collide(-0.7, -2.6, 0.7, 2.6, 0, 1.0)
	world.refs.buffet_pos = Vector3(12.6, 1.0, 11.6)
	world.refs.cake_pos = Vector3(12.6, 1.2, 12.6)
	world.refs.mask_stand_pos = Vector3(11.0, 1.4, -4.6)
	Props.model(B, "side_table_tall_01", {"pos": Vector3(11.0, 0, -4.8)})
	# --------------------------------------------------------------- the folding screen (pushable)
	world.refs.screen = Props.folding_screen(B, {"pos": Vector3(34.0, 0, 15.6), "ry": 0.2})
	world.refs.screen_start = Vector3(34.0, 0, 15.6)
	world.refs.sheet_sun_pos = Vector3(34.6, 0.05, 16.9)
	# --------------------------------------------------------------- the dancers' positions (filled by the story)
	world.refs.dancer_spots = [Vector3(18.5, 0, 2.0), Vector3(21.0, 0, 9.5), Vector3(28.5, 0, 1.5), Vector3(30.5, 0, 10.5), Vector3(19.0, 0, 13.0), Vector3(27.0, 0, -1.0)]
	world.refs.star_spots = [Vector3(20.0, 0, 4.0), Vector3(25.0, 0, 11.0), Vector3(30.0, 0, 4.0)]
	world.refs.emblem_ballroom = GuestWingBuilder.trace_mesh(r, "sym_emblem", Vector2(0.6, 0.6), Transform3D(Basis(), Vector3(36.0, 2.2, -5.92)), Color(1.0, 0.88, 0.54))
	world.refs.code_disco = GuestWingBuilder.trace_mesh(r, "trace_disco", Vector2(2.0, 0.5), Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(34.95, 0.45, 9.6)), Color(1.0, 0.7, 0.9))
	HallBuilder._dust(r, AABB(Vector3(11, 0.2, -5.5), Vector3(28, 9, 23)), 800)
	B.finalize()

static func _curtains(B: RoomBuilder, x: float, m: String, tattered: bool) -> void:
	var p := Props.P.new(B, {"pos": Vector3(x, 0, -6.0)})
	for s in [-1, 1]: Props.curtain(p, s * 1.35, 6.75, 0.3, 0.85, 6.4, m, tattered, s)
	p.box(Vector3(3.4, 0.28, 0.2), "gilt", Vector3(0, 6.9, 0.3))

static func _table_spots() -> Array:
	return [Vector3(14.5, 0, 14.2), Vector3(20.0, 0, 14.6), Vector3(30.0, 0, 14.6), Vector3(15.0, 0, -2.6), Vector3(21.5, 0, -3.0), Vector3(28.5, 0, -3.4)]

static func _confetti(parent: Node3D) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 1891
	var n := int(900 * Settings.data.graphics.particles)
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.use_colors = true
	mm.mesh = MeshKit.quad(0.04, 0.025); mm.instance_count = n
	var cols := [Color(1.0, 0.82, 0.35), Color(0.95, 0.4, 0.55), Color(0.5, 0.7, 1.0), Color(0.95, 0.95, 0.9)]
	for i in n:
		var b := Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU))
		mm.set_instance_transform(i, Transform3D(b, Vector3(rng.randf_range(13, 37), rng.randf_range(0.6, 7.5), rng.randf_range(-4, 16))))
		mm.set_instance_color(i, cols[i % cols.size()])
	var mmi := MultiMeshInstance3D.new(); mmi.multimesh = mm
	var m := StandardMaterial3D.new(); m.vertex_color_use_as_albedo = true; m.metallic = 0.6; m.roughness = 0.25; m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mmi.material_override = m; mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)

static func _balcony(world: World) -> void:
	var r := world.room("balcony", {
		"name": "The Balcony", "hidden": true, "bounds": AABB(Vector3(21, -1, 18.3), Vector3(8, 8, 6)), "neighbors": ["ballroom"],
		"music": "balcony", "grade": "balcony", "surface": "stone", "acoustics": Vector3(0.3, 0.05, 0.6),
		"ambience": {"rain_out": 0.45, "wind": 0.6, "night_garden": 0.6},
		"fog": {"color": Color(0.05, 0.08, 0.18), "density": 0.018, "albedo": Color(0.5, 0.65, 1.0), "moon": 0.6, "saturation": 1.15},
		"ambient": {"color": Color(0.12, 0.14, 0.2), "energy": 0.6}, "map_rect": Rect2(21, 18.3, 8, 6),
	})
	var B := world.builder(r)
	B.floor_rect(21, 18.3, 29, 24, 0, "stone_floor", "stone")
	B.box(Vector3(8, 0.3, 5.9), "stone_trim", Vector3(25, -0.2, 21.2))
	for x in [21.0, 29.0]: Props.balustrade(B, Vector3(x, 0, 18.4), Vector3(x, 0, 24.0), {"mat": "stone_trim", "rail": "stone_trim", "spacing": 0.3})
	Props.balustrade(B, Vector3(21, 0, 24.0), Vector3(29, 0, 24.0), {"mat": "stone_trim", "rail": "stone_trim", "spacing": 0.3})
	for x in [21.0, 29.0]:
		for z in [18.4, 24.0]: B.box(Vector3(0.45, 1.2, 0.45), "stone_trim", Vector3(x, 0.6, z))
	Props.bench(B, {"pos": Vector3(22.4, 0, 22.8), "ry": PI * 0.5})
	Props.telescope(B, {"pos": Vector3(27.6, 0, 23.0), "ry": -0.6})
	for x in [21.6, 28.4]: Props.model(B, "potted_plant_02", {"pos": Vector3(x, 0, 19.0), "scale": 1.2})
	world.refs.mara_spot = Vector3(25.0, 0, 22.6)
	world.refs.letter_pos = Vector3(22.4, 0.55, 22.6)
	world.refs.portrait_fragment_balcony = Vector3(28.0, 0.2, 19.6)
	# the night garden beyond: silhouetted trees on painted hills, a pond catching the moon
	var hill := MeshKit.displaced_plane(80, 12, 40, 4, func(v: Vector3) -> Vector3: return Vector3(v.x, v.y + sin(v.x * 0.15) * 2.0 + sin(v.x * 0.41) * 0.8, 0.0), "hills")
	var hm := StandardMaterial3D.new(); hm.albedo_color = Color(0.02, 0.025, 0.035); hm.roughness = 1.0
	var hi := MeshInstance3D.new(); hi.mesh = hill; hi.material_override = hm; hi.position = Vector3(25, -5, 60); hi.rotation.y = PI; r.add_child(hi)
	var rng := RandomNumberGenerator.new(); rng.seed = 77
	for i in 9: ExteriorBuilder._dead_tree(B, Vector3(rng.randf_range(5, 45), -6, rng.randf_range(34, 50)), rng.randf_range(1.4, 2.2), rng.randi())
	B.finalize()
