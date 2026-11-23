class_name Lantern
extends Node3D
## The Gloam Lantern: a brass carriage lantern whose flame burns warm until raised, when it turns
## spectral and throws a beam that shows what the house hides. The flame leans toward the uncanny.

var omni: OmniLight3D
var spot: SpotLight3D
var flame: MultiMeshInstance3D
var flame_mat: ShaderMaterial
var halo: MeshInstance3D
var halo_mat: ShaderMaterial
var flame_pivot: Node3D
var raise := 0.0
var lit := true
var lean_dir := Vector3.ZERO       # world-space direction the flame leans toward (zero = upright)
var lean_strength := 0.0
var _flare := 0.0
var _swing := Vector2.ZERO
var _swing_v := Vector2.ZERO
var _prev_pos := Vector3.ZERO
var _t := 0.0
var _creak_cd := 0.0

const WARM := Color(1.0, 0.68, 0.38)
const GLOAM := Color(0.55, 1.0, 0.86)

func _ready() -> void:
	var body := Node3D.new(); body.name = "Body"; add_child(body)
	var brass := MaterialLib.get_mat("brass")
	var dark := MaterialLib.get_mat("brass_dark")
	var glass := MaterialLib.get_mat("lamp_glass")
	_mesh(body, MeshKit.cyl(0.075, 0.085, 0.03, 20), brass, Vector3(0, 0.015, 0))
	_mesh(body, MeshKit.cyl(0.06, 0.075, 0.025, 20), dark, Vector3(0, 0.042, 0))
	_mesh(body, MeshKit.cyl(0.058, 0.058, 0.17, 20, true), glass, Vector3(0, 0.14, 0))
	for i in 4:
		var a := TAU * i / 4.0 + PI * 0.25
		_mesh(body, MeshKit.cyl(0.006, 0.006, 0.19, 6), brass, Vector3(cos(a) * 0.066, 0.14, sin(a) * 0.066))
	_mesh(body, MeshKit.cyl(0.07, 0.07, 0.012, 20), brass, Vector3(0, 0.232, 0))
	_mesh(body, MeshKit.cyl(0.018, 0.068, 0.07, 20), dark, Vector3(0, 0.272, 0))
	_mesh(body, MeshKit.cyl(0.022, 0.022, 0.03, 12), brass, Vector3(0, 0.318, 0))
	var ring := _mesh(body, MeshKit.torus(0.05, 0.006, TAU, 6, 24), brass, Vector3(0, 0.37, 0))
	ring.rotation.x = PI * 0.5
	_mesh(body, MeshKit.cyl(0.012, 0.016, 0.05, 10), MaterialLib.get_mat("wax"), Vector3(0, 0.075, 0))
	flame_pivot = Node3D.new(); flame_pivot.position = Vector3(0, 0.1, 0); body.add_child(flame_pivot)
	var q := QuadMesh.new(); q.size = Vector2(0.045, 0.11); q.center_offset = Vector3(0, 0.045, 0)
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.use_custom_data = true; mm.mesh = q; mm.instance_count = 1
	mm.set_instance_transform(0, Transform3D()); mm.set_instance_custom_data(0, Color(0.37, 1.0, 1.0, 0))
	flame = MultiMeshInstance3D.new(); flame.multimesh = mm
	flame_mat = ShaderMaterial.new(); flame_mat.shader = load("res://src/fx/flame.gdshader")
	flame.material_override = flame_mat; flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flame_pivot.add_child(flame)
	halo = MeshInstance3D.new(); var hq := QuadMesh.new(); hq.size = Vector2(0.5, 0.5); halo.mesh = hq
	halo_mat = ShaderMaterial.new(); halo_mat.shader = load("res://src/fx/glow.gdshader")
	halo.material_override = halo_mat; halo.position = Vector3(0, 0.15, 0); halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(halo)
	omni = OmniLight3D.new(); omni.position = Vector3(0, 0.16, 0); omni.omni_range = 6.5; omni.omni_attenuation = 1.4
	omni.light_color = WARM; omni.light_energy = 1.5; omni.light_volumetric_fog_energy = 0.6; omni.light_size = 0.05
	omni.shadow_enabled = true; omni.shadow_bias = 0.05; omni.shadow_normal_bias = 1.2
	add_child(omni)
	spot = SpotLight3D.new(); spot.light_color = GLOAM; spot.spot_range = 11.0; spot.spot_angle = 24.0; spot.spot_attenuation = 1.2
	spot.spot_angle_attenuation = 1.6; spot.light_energy = 0.0; spot.light_volumetric_fog_energy = 2.2; spot.top_level = true
	spot.shadow_enabled = true; spot.shadow_bias = 0.04
	add_child(spot)
	_build_motes()
	apply_quality()
	Events.graphics_applied.connect(apply_quality)

var motes: GPUParticles3D

## Dust drifting through the raised beam, so the light reads as something you could touch.
func _build_motes() -> void:
	motes = GPUParticles3D.new()
	motes.amount = int(90 * float(Settings.data.graphics.get("particles", 1.0)))
	motes.lifetime = 4.0
	motes.preprocess = 4.0
	motes.emitting = false
	motes.local_coords = false
	motes.visibility_aabb = AABB(Vector3(-4, -4, -9), Vector3(8, 8, 10))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.7, 0.7, 2.6)
	pm.gravity = Vector3(0, -0.01, 0)
	pm.initial_velocity_min = 0.01; pm.initial_velocity_max = 0.06
	pm.direction = Vector3(0, 1, 0); pm.spread = 180.0
	pm.turbulence_enabled = true; pm.turbulence_noise_strength = 0.4; pm.turbulence_noise_scale = 2.0
	pm.scale_min = 0.5; pm.scale_max = 1.4
	var fade := Gradient.new(); fade.set_color(0, Color(1, 1, 1, 0)); fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.25, Color(1, 1, 1, 1)); fade.add_point(0.75, Color(1, 1, 1, 1))
	var ft := GradientTexture1D.new(); ft.gradient = fade; pm.color_ramp = ft
	motes.process_material = pm
	var q := QuadMesh.new(); q.size = Vector2(0.012, 0.012)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES; m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(0.75, 1.0, 0.9, 0.8); m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	q.material = m
	motes.draw_pass_1 = q
	motes.position = Vector3(0, 0, -3.0)   # in front of the spot, along its beam
	spot.add_child(motes)

func _mesh(parent: Node3D, m: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); mi.mesh = m; mi.material_override = mat; mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

func apply_quality() -> void:
	var sh: String = Settings.data.graphics.shadows
	omni.shadow_enabled = sh in ["high", "ultra"]
	spot.shadow_enabled = sh in ["medium", "high", "ultra"]

## Point the beam (world-space origin and direction).
func aim(dir: Vector3) -> void:
	var o := global_position + Vector3(0, 0.16, 0)
	spot.global_position = o + dir * 0.12
	if dir.length() > 0.01:
		spot.look_at(spot.global_position + dir, Vector3.UP if absf(dir.y) < 0.98 else Vector3.FORWARD)

func flare() -> void:
	_flare = 1.0

func _process(dt: float) -> void:
	_t += dt
	_flare = maxf(0.0, _flare - dt * 2.2)
	# pendulum: the lantern hangs from its ring and swings as the hand moves
	var gp := global_position
	var vel := (gp - _prev_pos) / maxf(dt, 0.001)
	_prev_pos = gp
	if vel.length() > 20.0: vel = Vector3.ZERO
	var acc := Vector2(vel.x, vel.z) * 0.02
	_swing_v += (-_swing * 38.0 - _swing_v * 3.2) * dt - acc * dt * 10.0
	_swing += _swing_v * dt
	_swing = _swing.limit_length(0.5)
	_creak_cd -= dt
	if _swing_v.length() > 1.4 and _creak_cd <= 0.0 and visible:
		_creak_cd = 1.1
		Audio.sfx("lantern_creak", global_position, {"vol": -5.0, "range": 3.0})
	var yaw := get_parent_node_3d().global_basis.get_euler().y if get_parent_node_3d() else 0.0
	var b := Basis(Vector3.UP, yaw) if raise < 0.5 else Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -0.15)
	b = Basis(Vector3.FORWARD, _swing.x) * Basis(Vector3.RIGHT, _swing.y) * b
	global_basis = b
	# colour and brightness
	var on := 1.0 if lit else 0.0
	var gl := clampf(raise, 0.0, 1.0)
	var col := WARM.lerp(GLOAM, gl)
	var flick := 0.92 + 0.08 * sin(_t * 17.0) * sin(_t * 7.3 + 1.0)
	omni.light_color = col
	omni.light_energy = (1.5 + gl * 0.6 + _flare * 9.0) * flick * on
	omni.omni_range = 6.5 + _flare * 8.0
	spot.light_energy = (gl * 5.5 + _flare * 26.0) * on
	if motes: motes.emitting = gl > 0.4 and lit
	spot.spot_angle = 24.0 + _flare * 18.0
	flame_mat.set_shader_parameter("color", col)
	flame_mat.set_shader_parameter("brightness", (3.0 + gl * 2.0 + _flare * 8.0) * on)
	flame.visible = lit
	halo_mat.set_shader_parameter("intensity", (0.5 + gl * 0.5 + _flare * 3.0) * on)
	halo.visible = lit
	# flame lean toward the uncanny, plus a nervous flutter when it's close
	var tilt := Vector3.ZERO
	if lean_strength > 0.01 and lean_dir.length() > 0.01:
		var local := global_basis.inverse() * lean_dir.normalized()
		tilt = Vector3(local.z, 0, -local.x) * 0.6 * lean_strength
	var flutter := sin(_t * 23.0) * 0.08 * lean_strength
	flame_pivot.rotation = flame_pivot.rotation.lerp(Vector3(tilt.x + flutter, 0, tilt.z), 1.0 - exp(-6.0 * dt))
