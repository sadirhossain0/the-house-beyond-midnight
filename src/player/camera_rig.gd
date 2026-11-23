class_name CameraRig
extends Node3D
## Third-person camera on a spring arm: mouse / stick orbit, shoulder offset, collision, focus zoom,
## gentle auto-follow, shake, and a cinematic mode the story can borrow.

var target: Node3D
var yaw := 0.0
var pitch := -0.18
var arm: SpringArm3D
var cam: Camera3D
var distance := 2.35
var height := 0.95
var shoulder := 0.26
var focus := 0.0
var _shake := 0.0
var _idle := 0.0
var _cine := false
var _cine_xf := Transform3D()
var _cine_fov := 55.0
var _blend := 0.0
var base_fov := 58.0
var input_enabled := true

func _ready() -> void:
	top_level = true
	arm = SpringArm3D.new(); arm.collision_mask = 1; arm.margin = 0.15
	var sh := SphereShape3D.new(); sh.radius = 0.18; arm.shape = sh
	add_child(arm)
	cam = Camera3D.new(); cam.fov = base_fov; cam.near = 0.05; cam.far = 500.0
	arm.add_child(cam)
	cam.make_current()

func _unhandled_input(e: InputEvent) -> void:
	if not input_enabled or _cine: return
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var s: float = Settings.data.controls.mouse_sens * 0.0032
		yaw -= e.relative.x * s * (-1.0 if Settings.data.controls.invert_x else 1.0)
		pitch -= e.relative.y * s * (-1.0 if Settings.data.controls.invert_y else 1.0)
		_idle = 0.0

func snap_behind(t_yaw: float) -> void:
	yaw = t_yaw + PI
	pitch = -0.18

func shake(amount: float) -> void:
	if Settings.data.graphics.get("camera_shake", true) == false: return
	_shake = maxf(_shake, amount)

func aim() -> Vector3:
	return -cam.global_basis.z

func cinematic(pos: Vector3, look: Vector3, fov := 50.0) -> void:
	_cine = true
	_cine_xf = Transform3D(Basis.looking_at(look - pos, Vector3.UP), pos)
	_cine_fov = fov

func release() -> void:
	_cine = false

func _process(dt: float) -> void:
	if target == null: return
	var c: Dictionary = Settings.data.controls
	if input_enabled and not _cine:
		var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
		if look.length() > 0.01:
			var ps: float = c.pad_sens * 2.6
			yaw -= look.x * ps * dt * (-1.0 if c.invert_x else 1.0)
			pitch -= look.y * ps * 0.7 * dt * (-1.0 if c.invert_y else 1.0)
			_idle = 0.0
		if Input.is_action_just_pressed("recenter") and target is Player:
			snap_behind((target as Player).facing)
	pitch = clampf(pitch, -1.15, 0.75)
	base_fov = float(Settings.data.graphics.get("fov", 58.0))   # Settings > Graphics > Field of view
	_idle += dt
	# auto camera: drift behind a walking player after a moment of no camera input
	if c.auto_camera and target is Player and _idle > 1.8:
		var p := target as Player
		if p.velocity.length() > 1.0 and focus < 0.1:
			var want := p.facing + PI
			yaw = lerp_angle(yaw, want, dt * 0.6)
	var tpos := target.global_position + Vector3(0, height * target.scale.y, 0)
	global_position = global_position.lerp(tpos, 1.0 - exp(-14.0 * dt)) if global_position.distance_to(tpos) < 4.0 else tpos
	rotation = Vector3(pitch, yaw, 0)
	var dist := lerpf(distance, 1.35, focus) * clampf(target.scale.y * 1.2, 0.6, 1.0)
	arm.spring_length = dist
	arm.position = Vector3(lerpf(shoulder, 0.5, focus), 0, 0)
	cam.fov = lerpf(base_fov, 46.0, focus)
	_shake = maxf(0.0, _shake - dt * 2.5)
	cam.h_offset = 0.0
	cam.rotation = Vector3(randf_range(-1, 1) * _shake * 0.02, randf_range(-1, 1) * _shake * 0.02, 0) if _shake > 0.0 else Vector3.ZERO
	_blend = move_toward(_blend, 1.0 if _cine else 0.0, dt * 0.9)
	if _blend > 0.0:
		var k := _blend * _blend * (3.0 - 2.0 * _blend)
		var follow := arm.global_transform * Transform3D(Basis(), Vector3(0, 0, arm.get_hit_length()))
		cam.global_transform = follow.interpolate_with(_cine_xf, k)
		cam.fov = lerpf(cam.fov, _cine_fov, k)
