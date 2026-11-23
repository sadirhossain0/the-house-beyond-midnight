class_name Player
extends CharacterBody3D
## Avery (or Mara): movement, dodge, composure candles and fainting, the Gloam Lantern (raise to
## reveal, flare to startle), the Midnight Watch (shift rooms at anchors, recall echoes), Observe,
## and context interaction.

signal flared(origin: Vector3, dir: Vector3)
signal interacted(item: Dictionary)

const WALK := 1.45
const JOG := 3.1
const RAISED := 1.7
const GRAVITY := 18.0

var world: World
var avatar: Character
var rig: CameraRig
var lantern: Lantern
var tool := "none"
var state := "free"               # free | locked | fainted | dance
var facing := 0.0                 # yaw the body faces (0 = +Z)
var candles := 4
var invuln := 0.0
var raise := 0.0
var flare_cd := 0.0
var focus := 0.0
var prompt := ""
var prompt_item: Dictionary = {}
var observe_item: Dictionary = {}
var observe_progress := 0.0
var respawn := Transform3D()
var respawn_room := ""
var _dodge_t := 0.0
var _dodge_v := Vector3.ZERO
var _move := Vector3.ZERO
var _lean_target: Variant = null
var _step_ray := PhysicsRayQueryParameters3D.new()
var _toggle_raise := false
var _last_pos := Vector3.ZERO
var _hurt_flash := 0.0

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 | 2
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(50)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new(); cap.radius = 0.3; cap.height = 1.25
	cs.shape = cap; cs.position = Vector3(0, 0.625, 0)
	add_child(cs)
	rig = CameraRig.new(); rig.name = "CameraRig"
	add_child(rig)
	rig.target = self
	candles = Game.max_candles()
	_step_ray.collision_mask = 1 | 2
	Events.settings_changed.connect(_on_setting)
	build_avatar()

func build_avatar() -> void:
	var who: String = Save.profile.get("character", "avery")
	var costume: String = Save.profile.costumes.get(who, Cast.DEFAULT_COSTUME.get(who, ""))
	var had_lantern := lantern != null
	if avatar: avatar.queue_free()
	lantern = null
	avatar = Character.create(who, costume)
	avatar.name = "Avatar"
	add_child(avatar)
	avatar.rotation.y = facing
	avatar.step.connect(_on_step)
	_apply_cheats()
	if had_lantern or Game.flag("has_lantern"): give_lantern()

func give_lantern() -> void:
	if lantern: return
	lantern = Lantern.new(); lantern.name = "Lantern"
	var sock := avatar.skel.find_bone("socket.L")
	var ba := avatar.attach(lantern, avatar.skel.get_bone_name(sock) if sock >= 0 else "hand.L")
	lantern.position = Vector3(0, -0.15, 0)
	lantern.scale = Vector3.ONE * 0.82
	ba.name = "LanternMount"
	if tool == "none": set_tool("lantern")

func set_tool(t: String) -> void:
	if t == "lantern" and not Game.flag("has_lantern"): return
	if t == "watch" and not Game.flag("has_watch"): return
	if t == tool: return
	tool = t
	Events.tool_changed.emit(t)
	Audio.ui("tool")

func _on_setting(path: String, _v: Variant) -> void:
	if path.begins_with("cheats"): _apply_cheats()

func _apply_cheats() -> void:
	var ch: Dictionary = Settings.data.cheats
	scale = Vector3.ONE * (0.5 if ch.tiny else 1.0)
	if avatar: avatar.big_head = ch.big_head

var _locks := {}

## Freeze player control while a scene runs. Several systems may hold a lock at once; control
## returns only when every one of them has let go.
func lock(key := "story") -> void:
	_locks[key] = true
	if state == "free" or state == "dance": state = "locked"

func unlock(key := "story") -> void:
	_locks.erase(key)
	if _locks.is_empty() and state == "locked": state = "free"

func set_checkpoint(xf: Transform3D, room_id: String) -> void:
	respawn = xf; respawn_room = room_id

func teleport(pos: Vector3, yaw: float) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	facing = yaw
	avatar.rotation.y = yaw
	rig.snap_behind(yaw)
	rig.global_position = pos + Vector3(0, rig.height, 0)
	if world: world.update_focus(pos)

# --------------------------------------------------------------------------------------- frame
func _physics_process(dt: float) -> void:
	if world == null: return
	invuln = maxf(0.0, invuln - dt)
	flare_cd = maxf(0.0, flare_cd - dt)
	var free := state == "free"
	var ch: Dictionary = Settings.data.cheats
	var grav := GRAVITY * (0.3 if ch.low_gravity else 1.0)
	# ---------------------------------------------------------------- movement
	var inp := Input.get_vector("move_left", "move_right", "move_forward", "move_back") if free else Vector2.ZERO
	var cam_yaw := rig.yaw
	var fwd := Vector3(sin(cam_yaw + PI), 0, cos(cam_yaw + PI))
	var right := Vector3(fwd.z, 0, -fwd.x) * -1.0
	var wish := (fwd * -inp.y + right * inp.x)
	var mag := clampf(inp.length(), 0.0, 1.0)
	var walking := Input.is_action_pressed("walk") or mag < 0.55
	var spd := (WALK if walking else JOG)
	if raise > 0.3 or focus > 0.3: spd = minf(spd, RAISED)
	if ch.fleet_feet: spd *= 1.5
	spd *= scale.y * 0.5 + 0.5
	var target_v := wish.normalized() * spd * minf(1.0, mag * 1.4) if mag > 0.05 else Vector3.ZERO
	_move = _move.lerp(target_v, 1.0 - exp(-(10.0 if mag > 0.05 else 12.0) * dt))
	if _dodge_t > 0.0:
		_dodge_t -= dt
		_move = _dodge_v * (_dodge_t / 0.32 + 0.3)
	velocity.x = _move.x; velocity.z = _move.z
	if not is_on_floor(): velocity.y -= grav * dt
	elif velocity.y < 0.0: velocity.y = -0.5
	if free and Input.is_action_just_pressed("dodge") and _dodge_t <= 0.0 and is_on_floor():
		var d := wish.normalized() if mag > 0.1 else Vector3(sin(facing), 0, cos(facing)) * -1.0
		_dodge_v = d * 6.5
		_dodge_t = 0.32
		invuln = maxf(invuln, 0.4)
		if ch.low_gravity: velocity.y = 4.5
		avatar.play("dodge", 0.4)
		Audio.sfx("dodge", global_position)
	move_and_slide()
	# fell out of the world: put them back
	if global_position.y < -30.0: _respawn(false)
	# ---------------------------------------------------------------- facing
	var face_cam := raise > 0.3 or focus > 0.3 or state == "dance"
	var want := facing
	if face_cam: want = cam_yaw + PI
	elif Vector2(_move.x, _move.z).length() > 0.3: want = atan2(_move.x, _move.z)
	var prev := facing
	facing = lerp_angle(facing, want, 1.0 - exp(-12.0 * dt))
	avatar.rotation.y = facing
	avatar.turn = wrapf(facing - prev, -PI, PI) / maxf(dt, 0.001)
	var hs := Vector2(velocity.x, velocity.z).length()
	avatar.moving = hs > 0.15 and is_on_floor()
	avatar.mps = hs / maxf(scale.y, 0.1)
	avatar.speed = clampf(hs / JOG, 0.0, 1.6)
	avatar.airborne = move_toward(avatar.airborne, 0.0 if is_on_floor() else 1.0, dt * 6.0)
	Save.profile.stats.distance = float(Save.profile.stats.distance) + global_position.distance_to(_last_pos) if _last_pos != Vector3.ZERO else 0.0
	_last_pos = global_position
	world.update_focus(global_position)

func _process(dt: float) -> void:
	if world == null: return
	var free := state == "free"
	_tools(dt, free)
	_interaction(free)
	_observe(dt, free)
	_hurt_flash = maxf(0.0, _hurt_flash - dt * 1.5)

# --------------------------------------------------------------------------------------- tools
func _tools(dt: float, free: bool) -> void:
	if free:
		if Input.is_action_just_pressed("tool_lantern"): set_tool("lantern")
		if Input.is_action_just_pressed("tool_watch"): set_tool("watch")
		if Input.is_action_just_pressed("tool_next") or Input.is_action_just_pressed("wheel"):
			set_tool("watch" if tool == "lantern" and Game.flag("has_watch") else "lantern")
	var has_l := lantern != null
	var want_raise := 0.0
	if free and has_l and tool == "lantern":
		if Settings.data.controls.lantern_mode == "toggle":
			if Input.is_action_just_pressed("use_tool"): _toggle_raise = not _toggle_raise
			want_raise = 1.0 if _toggle_raise else 0.0
		else:
			want_raise = 1.0 if Input.is_action_pressed("use_tool") else 0.0
	else:
		_toggle_raise = false
	raise = move_toward(raise, want_raise, dt * 3.5)
	avatar.hold_lantern = has_l and tool != "watch"
	avatar.lantern_raise = raise
	avatar.hold_watch = tool == "watch" and free and Input.is_action_pressed("use_tool")
	var aim := rig.aim()
	if has_l:
		lantern.raise = raise
		lantern.aim(aim)
		lantern.visible = tool != "watch"
		var lp := lantern.global_position + Vector3(0, 0.16, 0)
		RenderingServer.global_shader_parameter_set("lantern_pos", lp)
		RenderingServer.global_shader_parameter_set("lantern_dir", aim)
		RenderingServer.global_shader_parameter_set("lantern_cos", cos(deg_to_rad(lantern.spot.spot_angle * 0.85)))
		RenderingServer.global_shader_parameter_set("lantern_range", 11.0)
		RenderingServer.global_shader_parameter_set("lantern_beam", raise if lantern.visible else 0.0)
		RenderingServer.global_shader_parameter_set("lantern_glow", 1.0 if lantern.visible else 0.0)
		_reveal_traces(dt, lp, aim)
		_update_lean()
		if free and tool == "lantern" and Input.is_action_just_pressed("flare"): do_flare()
	else:
		RenderingServer.global_shader_parameter_set("lantern_beam", 0.0)
		RenderingServer.global_shader_parameter_set("lantern_glow", 0.0)
	if free and tool == "watch" and Input.is_action_just_released("use_tool"): use_watch()

func do_flare() -> void:
	if flare_cd > 0.0 or lantern == null: return
	flare_cd = 1.6 if Settings.data.assist.infinite_lantern else 2.6
	lantern.flare()
	rig.shake(0.25)
	Audio.sfx("flare", global_position)
	Save.profile.stats.flares = int(Save.profile.stats.flares) + 1
	Controls.rumble(0.4, 0.2)
	if world.has_method("post_flash"): world.post_flash(0.35)
	flared.emit(lantern.global_position, rig.aim())

func _reveal_traces(dt: float, lp: Vector3, aim: Vector3) -> void:
	if raise < 0.6: return
	var c := cos(deg_to_rad(24.0))
	for t in world.traces:
		if t.revealed or not world.item_active(t): continue
		var tp: Vector3 = t.pos
		var d := tp - lp
		var dist := d.length()
		if dist > 10.5 or dist < 0.01: continue
		var dot := d.normalized().dot(aim)
		if dot < c: continue
		t.progress += dt * (1.4 if Settings.data.assist.clue_highlights == "strong" else 1.0)
		if t.has("node") and is_instance_valid(t.node):
			(t.node.material_override as ShaderMaterial).set_shader_parameter("pulse", clampf(t.progress / t.threshold, 0.0, 1.0))
		if t.progress >= t.threshold: reveal(t)

func reveal(t: Dictionary) -> void:
	if t.revealed: return
	t.revealed = true
	if t.has("node") and is_instance_valid(t.node):
		var m := t.node.material_override as ShaderMaterial
		var tw := create_tween()
		tw.tween_method(func(v): m.set_shader_parameter("revealed", v), 0.0, 1.0, 0.8)
		m.set_shader_parameter("pulse", 0.0)
	Audio.sfx("reveal", t.pos)
	Save.profile.stats.reveals = int(Save.profile.stats.reveals) + 1
	if t.has("on"): (t.on as Callable).call()

func _update_lean() -> void:
	var best := 1e9
	var target := Vector3.ZERO
	var p := global_position
	for t in world.traces:
		if t.revealed or not world.item_active(t): continue
		var d := p.distance_to(t.pos)
		if d < best: best = d; target = t.pos
	for g in world.observables:
		if not world.item_active(g) or not g.has("node") or not is_instance_valid(g.node) or not g.node.visible: continue
		var d: float = p.distance_to(g.node.global_position) * 1.3
		if d < best: best = d; target = g.node.global_position + Vector3(0, 1.2, 0)
	for a in world.anchors:
		if not world.item_active(a): continue
		var d: float = p.distance_to(a.pos) * 1.6
		if d < best: best = d; target = a.pos
	if best < 22.0:
		lantern.lean_dir = target - lantern.global_position
		lantern.lean_strength = clampf(1.0 - best / 22.0, 0.15, 1.0)
	else:
		lantern.lean_strength = 0.0

func use_watch() -> void:
	avatar.hold_watch = false
	for a in world.anchors:
		if world.item_active(a) and global_position.distance_to(a.pos) < a.get("radius", 2.6):
			if a.has("on"): (a.on as Callable).call(a)
			return
	for e in world.echoes:
		if world.item_active(e) and global_position.distance_to(e.pos) < e.radius:
			if e.has("play"): (e.play as Callable).call(e)
			return
	Audio.sfx("watch_tick", global_position)
	Events.toast.emit("The watch hands tremble, then settle. Nothing here remembers enough.", "info")

# --------------------------------------------------------------------------------------- interaction
func _interaction(free: bool) -> void:
	prompt = ""
	prompt_item = {}
	if not free: return
	var best := 1e9
	var fwd := Vector3(sin(facing), 0, cos(facing))
	var p := global_position + Vector3(0, 1.0, 0)
	for it in world.interactables:
		if not world.item_active(it): continue
		if it.has("cond") and not (it.cond as Callable).call(): continue
		var ip: Vector3 = it.pos
		var d := ip - p
		var flat := Vector3(d.x, 0, d.z)
		var dist := flat.length()
		if dist > it.radius or absf(d.y) > 2.4: continue
		var facing_score := 1.0 - fwd.dot(flat.normalized()) if dist > 0.25 else 0.0
		var cam_score := 1.0 - rig.aim().dot(d.normalized())
		var score := dist + facing_score * 0.9 + cam_score * 0.4
		if score < best: best = score; prompt_item = it
	if not prompt_item.is_empty():
		prompt = "%s %s" % [prompt_item.verb, prompt_item.get("label", "")]
		if Input.is_action_just_pressed("interact"):
			var it := prompt_item
			var to: Vector3 = it.pos - global_position
			if Vector2(to.x, to.z).length() > 0.2: facing = atan2(to.x, to.z)
			if it.get("anim", "reach") != "": avatar.play(it.get("anim", "reach"), 0.8)
			interacted.emit(it)
			(it.on as Callable).call(it)

func _observe(dt: float, free: bool) -> void:
	var want := 1.0 if free and Input.is_action_pressed("focus") else 0.0
	focus = move_toward(focus, want, dt * 4.0)
	rig.focus = focus
	if focus < 0.7:
		observe_progress = maxf(0.0, observe_progress - dt)
		observe_item = {}
		return
	var aim := rig.aim()
	var cp := rig.cam.global_position
	var best: Dictionary = {}
	var bd := 0.0
	for g in world.observables:
		if not world.item_active(g) or g.get("done", false): continue
		var n: Node3D = g.node
		if not is_instance_valid(n) or not n.is_visible_in_tree(): continue
		var tp := n.global_position + Vector3(0, g.get("height", 1.3), 0)
		var d := tp - cp
		var dot := d.normalized().dot(aim)
		if d.length() < 14.0 and dot > 0.95 and dot > bd: bd = dot; best = g
	if best.is_empty():
		observe_progress = maxf(0.0, observe_progress - dt)
		return
	if not is_same(best, observe_item): observe_item = best; observe_progress = 0.0
	observe_progress += dt
	if observe_progress >= best.get("time", 2.5):
		best.done = true
		observe_progress = 0.0
		Audio.sfx("observe", global_position)
		if best.has("on"): (best.on as Callable).call(best)

# --------------------------------------------------------------------------------------- composure
func hurt(from: Vector3, amount := 1) -> void:
	if invuln > 0.0 or state != "free": return
	if Settings.data.assist.ghost_aggression == "none":
		# gentle mode: ghosts brush past with a chill instead of a fright
		invuln = 1.0
		avatar.play("startle", 0.5)
		return
	invuln = 1.4
	var push := (global_position - from); push.y = 0
	_dodge_v = push.normalized() * 4.0; _dodge_t = 0.25
	avatar.play("hurt", 0.6)
	rig.shake(0.5)
	Controls.rumble(0.8, 0.3)
	_hurt_flash = 1.0
	Audio.react(Save.profile.get("character", "avery"), "hurt")
	if Settings.data.assist.no_composure_loss or Settings.data.cheats.get("god", false): return
	candles = maxi(0, candles - amount)
	Save.profile.stats.candles_lost = int(Save.profile.stats.candles_lost) + amount
	Events.composure_changed.emit(candles, Game.max_candles())
	Audio.sfx("candle_out", global_position)
	if candles <= 0: faint()

func relight(full := true) -> void:
	candles = Game.max_candles() if full else mini(Game.max_candles(), candles + 1)
	Events.composure_changed.emit(candles, Game.max_candles())

func hurt_flash() -> float: return _hurt_flash

func faint() -> void:
	state = "fainted"
	Save.profile.stats.faints = int(Save.profile.stats.faints) + 1
	avatar.play("faint", 2.4)
	Audio.react(Save.profile.get("character", "avery"), "faint")
	Events.player_fainted.emit()
	await get_tree().create_timer(2.6).timeout
	_respawn(true)

func _respawn(fade := true) -> void:
	if fade and world.has_method("fade_to"): await world.fade_to(1.0, 0.8)
	if respawn_room != "" and world.rooms.has(respawn_room): world.set_current(respawn_room, true)
	teleport(respawn.origin if respawn != Transform3D() else global_position + Vector3(0, 2, 0), respawn.basis.get_euler().y)
	avatar.clear_action()
	relight()
	_locks.clear()
	state = "free"
	Events.toast.emit("You come round, a little further back. The house waits politely.", "info")
	if fade and world.has_method("fade_to"): await world.fade_to(0.0, 0.8)

func _on_step(_foot: String) -> void:
	_step_ray.from = global_position + Vector3(0, 0.4, 0)
	_step_ray.to = global_position + Vector3(0, -0.6, 0)
	_step_ray.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(_step_ray)
	var surface := "stone"
	if hit and hit.collider: surface = hit.collider.get_meta("surface", "")
	if surface == "" and world.rooms.has(world.current): surface = world.rooms[world.current].surface
	if Settings.data.cheats.squeaky_steps: surface = "squeak"
	Audio.step(surface, global_position)
