class_name World
extends Node3D
## The estate: builds rooms, owns the environment (sky, moon, fog, grading), streams room
## visibility, switches Now/Then, and holds registries the gameplay systems use.

signal room_changed(id: String, previous: String)

var rooms := {}
var current := ""
var active: Array = []
var we: WorldEnvironment
var env: Environment
var sky_mat: ShaderMaterial
var moon: DirectionalLight3D
var lights: LightManager
var gfx: GraphicsController
var refs := {}
var interactables: Array = []
var traces: Array = []
var echoes: Array = []
var anchors: Array = []
var pushables: Array = []
var observables: Array = []
var post: PostFX
var player: Node3D
var _mood_tween: Tween
var lightning_timer := 12.0
var flash := 0.0

func _ready() -> void:
	name = "World"
	lights = LightManager.new(); lights.name = "LightManager"; add_child(lights)
	_build_environment()
	gfx = GraphicsController.new(); gfx.name = "Graphics"; add_child(gfx)
	gfx.setup(get_viewport(), env, moon)
	post = PostFX.new(); post.name = "PostFX"; add_child(post)
	Audio.world_root = self

func _build_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = load("res://src/fx/night_sky.gdshader")
	var hdri_path := "res://assets/hdri/kloppenheim_07_puresky_4k.hdr"
	if ResourceLoader.exists(hdri_path): sky_mat.set_shader_parameter("hdri", load(hdri_path))
	sky_mat.set_shader_parameter("hdri_energy", 0.9)
	sky_mat.set_shader_parameter("moon_dir", Vector3(0.32, 0.42, 0.85).normalized())
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.35
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.03
	env.volumetric_fog_albedo = Color(0.75, 0.8, 0.9)
	env.volumetric_fog_length = 48.0
	env.volumetric_fog_detail_spread = 1.6
	env.volumetric_fog_gi_inject = 0.6
	env.volumetric_fog_ambient_inject = 0.08
	env.volumetric_fog_sky_affect = 0.15
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_density = 0.02
	env.fog_sky_affect = 0.3
	we = WorldEnvironment.new(); we.environment = env; add_child(we)
	moon = DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = Color(0.62, 0.72, 1.0)
	moon.light_energy = 0.5
	moon.light_volumetric_fog_energy = 3.5
	moon.shadow_enabled = true
	moon.shadow_bias = 0.04
	moon.shadow_normal_bias = 1.0
	moon.directional_shadow_max_distance = 60.0
	moon.shadow_blur = 1.5
	add_child(moon)
	moon.look_at_from_position(Vector3(-14, 30, -34), Vector3(0, 0, 6), Vector3.UP)

# ------------------------------------------------------------------------------- building
func room(id: String, opts: Dictionary) -> Room:
	var r := Room.new().setup(id, opts)
	add_child(r)
	rooms[id] = r
	lights.register_room(r)
	return r

func builder(r: Room) -> RoomBuilder:
	return RoomBuilder.new(self, r)

func build_all(progress: Callable) -> void:
	var steps := [["The drive and gardens", ExteriorBuilder.build], ["The entrance hall", HallBuilder.build], ["The guest wing", GuestWingBuilder.build], ["The Grand Ballroom", BallroomBuilder.build]]
	for i in steps.size():
		progress.call(float(i) / steps.size(), steps[i][0])
		await get_tree().process_frame
		steps[i][1].call(self)
	for r in rooms.values(): _add_probe(r)
	progress.call(1.0, "done")

func _add_probe(r: Room) -> void:
	if r.id == "exterior" or r.bounds.size.length() < 1.0: return
	var p := ReflectionProbe.new()
	p.size = r.bounds.size + Vector3(0.5, 0.5, 0.5)
	p.position = r.bounds.get_center()
	p.interior = true
	p.box_projection = true
	p.update_mode = ReflectionProbe.UPDATE_ONCE
	p.ambient_mode = ReflectionProbe.AMBIENT_COLOR
	p.ambient_color = r.ambient.color
	p.ambient_color_energy = r.ambient.energy
	p.intensity = 0.8
	p.max_distance = 60.0
	r.add_child(p)
	r.reflection_probe = p

# ------------------------------------------------------------------------------- rooms & mood
func update_focus(pos: Vector3) -> void:
	lights.focus = pos
	var id := current
	if current == "" or not rooms[current].contains(pos):
		for r in rooms.values():
			if r.contains(pos):
				id = r.id; break
	if id != current: set_current(id)

func set_current(id: String, instant := false) -> void:
	if not rooms.has(id): return
	var prev := current
	current = id
	var r: Room = rooms[id]
	active = [id] + r.neighbors
	for rid in rooms.keys():
		var rr: Room = rooms[rid]
		rr.visible = active.has(rid)
		rr.process_mode = Node.PROCESS_MODE_INHERIT if rr.visible else Node.PROCESS_MODE_DISABLED
	lights.refresh(active)
	_apply_mood(r, instant)
	room_changed.emit(id, prev)
	Events.room_entered.emit(id, prev)

func _apply_mood(r: Room, instant := false) -> void:
	var fog := r.current_fog()
	var amb := r.current_ambient()
	var outdoor := r.id == "exterior"
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY if outdoor else Environment.AMBIENT_SOURCE_COLOR
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY if outdoor else Environment.REFLECTION_SOURCE_BG
	var grade := r.grade if r.state == "now" or not GraphicsController.GRADES.has(r.grade.replace("_now", "_then")) else r.grade.replace("_now", "_then")
	gfx.set_grade(grade)
	# moonlight only helps indoors when walls can cast shadows; otherwise it would leak through
	var shadows_ok: bool = Settings.data.graphics.shadows in ["medium", "high", "ultra"]
	var moon_energy: float = 0.55 if outdoor else (fog.get("moon", 0.3) if shadows_ok else 0.0)
	if _mood_tween: _mood_tween.kill()
	var d := 0.01 if instant else 1.6
	_mood_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	_mood_tween.tween_property(env, "volumetric_fog_density", fog.density, d)
	_mood_tween.tween_property(env, "volumetric_fog_albedo", fog.get("albedo", Color(0.75, 0.8, 0.9)), d)
	_mood_tween.tween_property(env, "volumetric_fog_emission", fog.get("emission", Color(0.0, 0.0, 0.0)), d)
	_mood_tween.tween_property(env, "fog_light_color", fog.color, d)
	_mood_tween.tween_property(env, "fog_density", fog.density * 0.6, d)
	_mood_tween.tween_property(env, "ambient_light_color", amb.color, d)
	_mood_tween.tween_property(env, "ambient_light_energy", amb.energy, d)
	_mood_tween.tween_property(moon, "light_energy", moon_energy, d)
	_mood_tween.tween_property(env, "adjustment_saturation", fog.get("saturation", 1.0) * 1.12, d)
	Audio.set_ambience(r.ambience)
	Audio.set_acoustics(r.acoustics.x, r.acoustics.y, r.acoustics.z)

func set_room_state(id: String, s: String) -> void:
	var r: Room = rooms.get(id)
	if r == null: return
	r.set_state(s)
	if id == current: _apply_mood(r)
	Events.room_state_changed.emit(id, s)

# ------------------------------------------------------------------------------- registries
func add_interactable(o: Dictionary) -> Dictionary:
	o.merge({"enabled": true, "radius": 1.7, "state": "common", "verb": "Inspect"}, false)
	interactables.append(o)
	return o

func add_trace(o: Dictionary) -> Dictionary:
	o.merge({"progress": 0.0, "revealed": false, "state": "common", "threshold": 1.0}, false)
	traces.append(o)
	return o

func add_observable(o: Dictionary) -> Dictionary:
	o.merge({"state": "common", "time": 2.5, "height": 0.95}, false)
	observables.append(o)
	return o

func add_anchor(o: Dictionary) -> Dictionary:
	o.merge({"state": "common", "radius": 2.6}, false)
	anchors.append(o)
	return o

func post_flash(v: float) -> void:
	post.flash = maxf(post.flash, v)

func fade_to(v: float, d: float) -> void:
	await post.fade_to(v, d)

func add_echo(o: Dictionary) -> Dictionary:
	o.merge({"state": "common", "radius": 3.0}, false)
	echoes.append(o)
	return o

func item_active(o: Dictionary) -> bool:
	if not o.get("enabled", true): return false
	var rid: String = o.get("room", "")
	if rid != "" and not active.has(rid): return false
	var st: String = o.get("state", "common")
	if st != "common" and rooms.has(rid) and rooms[rid].state != st: return false
	return true

func _process(dt: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for rid in active:
		var r: Room = rooms.get(rid)
		if r:
			for fn in r.updaters: fn.call(dt, t)
	# lightning outside (and glimpsed through windows)
	if current == "exterior" or (rooms.has(current) and rooms[current].neighbors.has("exterior")) or current == "balcony":
		lightning_timer -= dt
		if lightning_timer <= 0.0:
			lightning_timer = randf_range(14.0, 28.0)
			_lightning()
	flash = maxf(0.0, flash - dt * 2.5)
	var fl_mul := {"full": 1.0, "reduced": 0.35, "off": 0.0}.get(Settings.data.graphics.flashing, 0.35)
	sky_mat.set_shader_parameter("flash", flash * fl_mul)

func _lightning() -> void:
	flash = 1.0
	var tw := create_tween()
	var base := moon.light_energy
	var fl_mul: float = {"full": 1.0, "reduced": 0.35, "off": 0.0}.get(Settings.data.graphics.flashing, 0.35)
	tw.tween_property(moon, "light_energy", base + 4.0 * fl_mul, 0.05)
	tw.tween_property(moon, "light_energy", base + 0.5 * fl_mul, 0.12)
	tw.tween_property(moon, "light_energy", base + 2.5 * fl_mul, 0.06)
	tw.tween_property(moon, "light_energy", base, 0.5)
	var dist := randf()
	get_tree().create_timer(0.4 + dist * 2.0).timeout.connect(func(): Audio.sfx("thunder", null, {"vol": -2.0 - dist * 6.0}))
	if refs.has("silhouette") and is_instance_valid(refs.silhouette): refs.silhouette.visible = false
