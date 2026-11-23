class_name Character
extends Node3D
## A cast member: the Blender-built model, its look (alive, ghost or memory echo) and a procedural
## animator. Animated poses are authored in "character space" (+Z forward, +Y up, +X to the
## character's left, every joint at rest = identity, arms hanging down) and mapped onto each rig with
##   G_i = E_chain_i * Q_i^-1 * C_i,   local_i = G_parent^-1 * G_i
## where C_i is the bone's global rest rotation and Q_i the A-pose correction for the arm chains.

signal step(foot: String)

const EXPR := {
	"neutral": {"brow": 0.0, "tilt": 0.0, "lids": 1.0, "mouth": "neutral"},
	"happy": {"brow": 0.004, "tilt": -0.12, "lids": 0.82, "mouth": "smile"},
	"delighted": {"brow": 0.008, "tilt": -0.15, "lids": 0.9, "mouth": "grin"},
	"surprised": {"brow": 0.011, "tilt": 0.0, "lids": 1.18, "mouth": "o"},
	"worried": {"brow": 0.005, "tilt": 0.3, "lids": 1.0, "mouth": "frown"},
	"angry": {"brow": -0.006, "tilt": -0.38, "lids": 0.72, "mouth": "frown"},
	"sad": {"brow": 0.002, "tilt": 0.35, "lids": 0.7, "mouth": "frown"},
	"smug": {"brow": 0.003, "tilt": -0.2, "lids": 0.6, "mouth": "smile", "asym": 0.01},
	"sleepy": {"brow": -0.002, "tilt": 0.1, "lids": 0.35, "mouth": "neutral"},
	"determined": {"brow": -0.003, "tilt": -0.2, "lids": 0.85, "mouth": "neutral"},
	"curious": {"brow": 0.005, "tilt": 0.05, "lids": 1.05, "mouth": "neutral", "asym": 0.007},
	"scared": {"brow": 0.01, "tilt": 0.35, "lids": 1.2, "mouth": "open"},
	"proud": {"brow": 0.003, "tilt": -0.1, "lids": 0.75, "mouth": "smile"},
}

const GAITS := {
	"avery": {"stride": 0.72, "bounce": 0.028, "arm": 0.45, "sway": 0.02, "lean": 0.06, "idle": "notes"},
	"mara": {"stride": 0.7, "bounce": 0.04, "arm": 0.55, "sway": 0.05, "lean": 0.03, "idle": "flourish"},
	"theo": {"stride": 0.66, "bounce": 0.022, "arm": 0.35, "sway": 0.015, "lean": 0.1, "idle": "read"},
	"june": {"stride": 0.74, "bounce": 0.045, "arm": 0.6, "sway": 0.03, "lean": 0.05, "idle": "tap"},
	"porter": {"float": 0.05, "arm": 0.2, "idle": "cap", "lean": 0.24},
	"host": {"stride": 0.5, "bounce": 0.03, "arm": 0.3, "sway": 0.08, "lean": -0.14, "float": 0.04, "idle": "moustache"},
	"pip": {"float": 0.13, "arm": 0.6, "idle": "spin"},
	"dancer": {"float": 0.02, "arm": 0.2, "idle": "none"},
	"echo": {"stride": 0.7, "bounce": 0.015, "arm": 0.25, "sway": 0.0, "lean": 0.0, "idle": "none"},
}

## character-space joints -> rig bones (parents before children)
const JOINTS := [["body", "root"], ["hips", "hips"], ["spine", "spine"], ["chest", "chest"], ["neck", "neck"], ["head", "head"],
	["shL", "shoulder.L"], ["upperL", "upper_arm.L"], ["foreL", "forearm.L"], ["handL", "hand.L"],
	["shR", "shoulder.R"], ["upperR", "upper_arm.R"], ["foreR", "forearm.R"], ["handR", "hand.R"],
	["thighL", "thigh.L"], ["shinL", "shin.L"], ["footL", "foot.L"], ["thighR", "thigh.R"], ["shinR", "shin.R"], ["footR", "foot.R"],
	["skirt", "skirt"], ["tails", "tails"], ["scarf", "scarf"], ["tail1", "tail.1"], ["tail2", "tail.2"], ["tail3", "tail.3"],
	["eyeL", "eye.L"], ["eyeR", "eye.R"], ["lidL", "lid.L"], ["lidR", "lid.R"], ["browL", "brow.L"], ["browR", "brow.R"]]
const HOLD_ACTIONS := ["faint", "dance", "conduct", "hold", "frozen", "lie", "pose", "play_violin", "play_cello", "play_flute", "sit", "sleep"]

class Targets:
	var body := Vector3.ZERO; var hips := Vector3.ZERO; var spine := Vector3.ZERO; var chest := Vector3.ZERO
	var neck := Vector3.ZERO; var head := Vector3.ZERO
	var shL := Vector3.ZERO; var upperL := Vector3.ZERO; var foreL := Vector3.ZERO; var handL := Vector3.ZERO
	var shR := Vector3.ZERO; var upperR := Vector3.ZERO; var foreR := Vector3.ZERO; var handR := Vector3.ZERO
	var thighL := Vector3.ZERO; var shinL := Vector3.ZERO; var footL := Vector3.ZERO
	var thighR := Vector3.ZERO; var shinR := Vector3.ZERO; var footR := Vector3.ZERO
	var skirt := Vector3.ZERO; var tails := Vector3.ZERO; var scarf := Vector3.ZERO
	var tail1 := Vector3.ZERO; var tail2 := Vector3.ZERO; var tail3 := Vector3.ZERO
	var eyeL := Vector3.ZERO; var eyeR := Vector3.ZERO; var lidL := Vector3.ZERO; var lidR := Vector3.ZERO
	var browL := Vector3.ZERO; var browR := Vector3.ZERO
	func clear() -> void:
		for j in JOINTS: set(j[0], Vector3.ZERO)

static var _mat_cache := {}

var char_id := ""
var model_name := ""
var look := "solid"
var model: Node3D
var skel: Skeleton3D
var mouths := {}
var props := {}
var meshes: Array[MeshInstance3D] = []
var gait: Dictionary = GAITS.avery
var ghost_style := {}

# animation state (set from outside)
var speed := 0.0          # 0..1 walk, up to 1.6 run
var mps := -1.0           # real metres per second (drives stride rate); <0 = derive from speed
var moving := false
var action := ""
var action_dur := 1.0
var expression := "neutral"
var talk := false
var look_at_target: Variant = null   # Vector3 or null
var hold_lantern := false
var lantern_raise := 0.0
var hold_watch := false
var airborne := 0.0
var turn := 0.0
var bpm := 96.0
var freeze := false
var big_head := false
var anim_rate := 1.0

var _idx := {}            # joint key -> bone index
var _rest := {}           # joint key -> Quaternion (global rest C)
var _restpos := {}        # joint key -> Vector3 (local rest origin)
var _q := {}              # joint key -> Quaternion (A-pose correction Q)
var _cur := {}            # joint key -> Vector3 smoothed euler
var _parent := {}         # joint key -> parent joint key or ""
var T := Targets.new()
var _t := 0.0
var _phase := 0.0
var _blink := 0.0
var _next_blink := 2.0
var _idle_t := 0.0
var _idle_special := 0.0
var _action_t := 0.0
var _mouth_t := 0.0
var _mouth_open := false
var _cur_mouth := ""
var _e := {"brow": 0.0, "tilt": 0.0, "lids": 1.0, "asym": 0.0}
var _hips_y := 0.0
var _body_off := Vector3.ZERO
var _hand_busy := false
var _seed := 0.0
var _eye_h := 0.15      # eye height above the head bone (head-local)
var _face_k := 1.0      # face feature scale relative to the original head size

static func create(id: String, costume_id := "", look_override := "") -> Character:
	var c := Character.new()
	c.char_id = id
	var npc: Dictionary = Cast.NPCS.get(id, {})
	if Cast.COSTUMES.has(id):
		c.model_name = Cast.costume(id, costume_id).get("model", id)
		c.gait = GAITS.get(id, GAITS.avery)
	else:
		c.model_name = npc.get("model", id)
		c.gait = GAITS.get(npc.get("gait", "avery"), GAITS.avery)
		c.ghost_style = npc.get("ghost", {})
	c.look = look_override if look_override != "" else npc.get("look", "solid")
	c.expression = npc.get("expr", "neutral")
	c.name = id.capitalize().replace(" ", "")
	c._load_model()
	return c

func _load_model() -> void:
	var ps: PackedScene = load(Cast.model_path(model_name))
	model = ps.instantiate()
	add_child(model)
	skel = model.find_children("*", "Skeleton3D", true, false)[0]
	for mi in skel.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		meshes.append(m)
		if m.name.begins_with("Mouth_"): mouths[m.name.substr(6)] = m
		elif m.name != "Body": props[m.name] = m
	for k in ["Notebook", "Cane", "CaneKnob"]:
		if props.has(k) and k == "Notebook": props[k].visible = false
	_seed = float(hash(name) % 1000) / 100.0
	_next_blink = 1.0 + fmod(_seed, 3.0)
	# rest data
	for j in JOINTS:
		var key: String = j[0]
		var bi := skel.find_bone(j[1])
		if bi < 0: continue
		_idx[key] = bi
		_rest[key] = skel.get_bone_global_rest(bi).basis.get_rotation_quaternion()
		_restpos[key] = skel.get_bone_rest(bi).origin
		_cur[key] = Vector3.ZERO
		_q[key] = Quaternion.IDENTITY
	for j in JOINTS:
		var key: String = j[0]
		if not _idx.has(key): continue
		var p := skel.get_bone_parent(_idx[key])
		_parent[key] = ""
		while p >= 0:
			var found := ""
			for k in _idx.keys():
				if _idx[k] == p: found = k; break
			if found != "": _parent[key] = found; break
			p = skel.get_bone_parent(p)
	# arms are modelled in an A-pose: Q rotates "hanging down" onto the modelled arm direction
	for side in ["L", "R"]:
		var up_key: String = "upper" + str(side)
		if not _rest.has(up_key): continue
		var rq: Quaternion = _rest[up_key]
		var dir: Vector3 = rq * Vector3.UP
		var q := Quaternion(Vector3.DOWN, dir.normalized())
		for k in ["upper" + side, "fore" + side, "hand" + side]: _q[k] = q
	_hips_y = _restpos.get("hips", Vector3.ZERO).y
	if _restpos.has("eyeL"):
		var ep: Vector3 = _restpos.eyeL
		_eye_h = ep.y
		_face_k = clampf(absf(ep.x) / 0.05, 0.6, 3.0)
	apply_look(look)

# ------------------------------------------------------------------------------------- looks
func apply_look(l: String) -> void:
	look = l
	var q: String = Settings.data.graphics.get("quality", "high") if Settings.data.has("graphics") else "high"
	for m in meshes:
		var mesh := m.mesh
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if look != "solid" else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		for i in mesh.get_surface_count():
			var src := mesh.surface_get_material(i)
			m.set_surface_override_material(i, _material_for(src, q))

func _material_for(src: Material, quality: String) -> Material:
	var base := src as BaseMaterial3D
	var mname := src.resource_name if src else "?"
	var key := "%s|%s|%s|%s" % [look, model_name, mname, quality]
	if look == "ghost": key += str(ghost_style.get("color", Color.WHITE))
	if _mat_cache.has(key): return _mat_cache[key]
	var out: Material = src
	var albedo := base.albedo_color if base else Color(0.6, 0.6, 0.6)
	match look:
		"ghost":
			var sm := ShaderMaterial.new()
			sm.shader = preload("res://src/fx/ghost.gdshader")
			var gc: Color = ghost_style.get("color", Color(0.56, 0.91, 0.82))
			sm.set_shader_parameter("color", gc.lerp(albedo, ghost_style.get("keep", 0.5)))
			sm.set_shader_parameter("rim", ghost_style.get("rim", Color(0.94, 1, 0.98)))
			sm.set_shader_parameter("opacity", ghost_style.get("opacity", 0.82))
			sm.set_shader_parameter("wobble", ghost_style.get("wobble", 1.0))
			sm.set_shader_parameter("tail", 1.0 if ghost_style.get("tail", false) else 0.0)
			sm.set_shader_parameter("tail_top", _hips_y * 0.95)
			sm.set_shader_parameter("tail_len", _hips_y * 0.9)
			out = sm
		"echo":
			var em := ShaderMaterial.new()
			em.shader = preload("res://src/fx/echo.gdshader")
			var lum := albedo.get_luminance()
			em.set_shader_parameter("color", Color(1.0, 0.85, 0.62) * (0.45 + lum * 0.8))
			em.set_shader_parameter("opacity", 0.75)
			out = em
		_:
			if base:
				var b := base.duplicate() as BaseMaterial3D
				b.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
				b.rim_enabled = true; b.rim = 0.18; b.rim_tint = 0.6
				var detail := _fabric_for(mname)
				if detail != "" and quality != "low":
					var nt := MaterialLib.tex(detail, "normal")
					if nt:
						b.normal_enabled = true; b.normal_texture = nt; b.normal_scale = 0.7
						b.uv1_scale = Vector3(1.6, 1.6, 1.6)
				if mname == "skin" and quality in ["high", "ultra"]:
					b.subsurf_scatter_enabled = true; b.subsurf_scatter_strength = 0.35
				if mname.begins_with("hair"):
					b.roughness = 0.45; b.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
				out = b
	_mat_cache[key] = out
	return out

static func _fabric_for(mname: String) -> String:
	if mname.begins_with("cloth_main") or mname.begins_with("cloth_second") or mname.begins_with("cloth_legs") or mname.begins_with("cloth_cap"): return "poly_wool_herringbone"
	if mname.begins_with("cloth_vest") or mname.begins_with("cloth_lapel"): return "quatrefoil_jacquard_fabric"
	if mname.begins_with("cloth_shirt") or mname.begins_with("cloth_scarf"): return "fabric_pattern_07"
	if mname.begins_with("leather"): return "brown_leather"
	return ""

## Ghosts dissolve in and out; `amount` 0 = invisible, 1 = fully present.
func set_presence(amount: float) -> void:
	visible = amount > 0.01
	if look != "ghost" and look != "echo": return
	for m in meshes:
		for i in m.mesh.get_surface_count():
			var sm := m.get_surface_override_material(i) as ShaderMaterial
			if sm:
				if not sm.has_meta("own"):
					sm = sm.duplicate(); sm.set_meta("own", true); m.set_surface_override_material(i, sm)
				sm.set_shader_parameter("opacity", float(ghost_style.get("opacity", 0.8)) * amount if look == "ghost" else 0.75 * amount)

func set_flash(v: float) -> void:
	if look != "ghost": return
	for m in meshes:
		for i in m.mesh.get_surface_count():
			var sm := m.get_surface_override_material(i) as ShaderMaterial
			if sm:
				if not sm.has_meta("own"):
					sm = sm.duplicate(); sm.set_meta("own", true); m.set_surface_override_material(i, sm)
				sm.set_shader_parameter("flash", v)

func head_position() -> Vector3:
	if not _idx.has("head"): return global_position + Vector3(0, 1.6, 0)
	return (skel.global_transform * skel.get_bone_global_pose(_idx.head)).origin + global_basis.y * _eye_h * scale.y

func socket(side := "L") -> int:
	return skel.find_bone("socket." + side)

## Attach a node to a bone (e.g. the lantern to socket.L).
func attach(node: Node3D, bone: String) -> BoneAttachment3D:
	var ba := BoneAttachment3D.new()
	ba.bone_name = bone
	skel.add_child(ba)
	ba.add_child(node)
	return ba

# ------------------------------------------------------------------------------------- control
func play(a: String, dur := 1.0) -> void:
	action = a; action_dur = dur; _action_t = 0.0

func clear_action() -> void:
	action = ""

func _process(dt: float) -> void:
	if freeze or skel == null: return
	dt *= anim_rate
	_t += dt
	_update_pose(dt, _t)

func _update_pose(dt: float, time: float) -> void:
	T.clear()
	var g := gait
	var hips_y := 0.0
	var body := Vector3.ZERO
	var spd := clampf(speed, 0.0, 1.6)
	var mov := moving and spd > 0.05
	var floats: bool = g.has("float")
	# ------------------------------------------------------------------ gait
	if not floats or g.has("stride"):
		var stride: float = g.get("stride", 0.7) * (1.35 if spd > 1.0 else 1.0)
		var real_mps: float = mps if mps >= 0.0 else spd * 3.6
		var rate := (real_mps / (2.0 * stride)) * TAU if mov else 0.0
		var prev := _phase
		_phase += rate * dt
		if mov and floori(prev / PI) != floori(_phase / PI):
			step.emit("R" if floori(_phase / PI) % 2 else "L")
		var w := clampf(spd, 0.0, 1.0) if mov else 0.0
		var run := clampf((spd - 0.8) / 0.6, 0.0, 1.0)
		var ph := _phase
		var fl := sin(ph)
		var amp := lerpf(0.42, 0.75, run) * w
		T.thighL.x = -fl * amp; T.thighR.x = fl * amp
		T.shinL.x = maxf(0.0, cos(ph)) * lerpf(0.55, 1.1, run) * w + 0.05
		T.shinR.x = maxf(0.0, -cos(ph)) * lerpf(0.55, 1.1, run) * w + 0.05
		T.footL.x = -T.thighL.x * 0.3 - T.shinL.x * 0.4; T.footR.x = -T.thighR.x * 0.3 - T.shinR.x * 0.4
		var arm_a: float = g.get("arm", 0.4) * w * lerpf(1.0, 1.6, run)
		T.upperL.x = fl * arm_a; T.upperR.x = -fl * arm_a
		T.foreL.x = -0.18 - maxf(0.0, fl) * 0.35 * w - run * 0.8; T.foreR.x = -0.18 - maxf(0.0, -fl) * 0.35 * w - run * 0.8
		hips_y += (absf(sin(ph)) - 0.5) * g.get("bounce", 0.02) * w * 2.0
		T.hips.z = sin(ph) * g.get("sway", 0.02) * w; T.hips.y = sin(ph) * 0.12 * w
		T.spine.y = -sin(ph) * 0.14 * w; T.spine.x = g.get("lean", 0.0) + run * 0.18 + w * 0.04
		T.neck.y = sin(ph) * 0.05 * w
		T.skirt.x = -absf(fl) * 0.08 * w - run * 0.15
		T.tails.x = 0.15 * w + run * 0.5 + absf(fl) * 0.05
		T.scarf.x = 0.2 * w + run * 0.6 + sin(time * 3.0) * 0.04
	if floats:
		body.y += sin(time * 1.7 + _seed) * float(g["float"]) + (0.0 if g.has("stride") else 0.08)
		T.spine.x = g.get("lean", 0.0) + (0.25 * spd if mov else 0.0)
		if not g.has("stride"):
			T.upperL.z = 0.25 + sin(time * 1.3) * 0.08; T.upperR.z = -0.25 - sin(time * 1.3 + 1.0) * 0.08
			T.upperL.x = -0.2 + sin(time * 1.1) * 0.1; T.upperR.x = -0.2 + sin(time * 1.2 + 2.0) * 0.1
			T.foreL.x = -0.5; T.foreR.x = -0.5
		var tl := (0.5 * spd if mov else 0.1) + sin(time * 2.0) * 0.06
		T.tail1.x = tl * 0.5; T.tail2.x = tl * 0.7 + sin(time * 1.6) * 0.05; T.tail3.x = tl + sin(time * 1.6 + 0.8) * 0.1
		T.tail1.z = sin(time * 1.6) * 0.05; T.tail2.z = sin(time * 1.6 + 0.6) * 0.08; T.tail3.z = sin(time * 1.6 + 1.2) * 0.12
	# ------------------------------------------------------------------ idle
	var breathe := sin(time * 1.6) * 0.012
	T.chest.x += breathe; T.shL.z += breathe * 0.5; T.shR.z -= breathe * 0.5
	if not mov:
		T.upperL.z += 0.09; T.upperR.z -= 0.09
		T.foreL.x += -0.12; T.foreR.x += -0.12
		T.hips.z += sin(time * 0.45 + _seed) * 0.025
		T.spine.z += -sin(time * 0.45 + _seed) * 0.02
		_idle_t += dt
		if action == "" and not talk and not hold_watch and lantern_raise < 0.1 and _idle_t > 7.0 and g.idle != "none":
			_idle_special = 4.0; _idle_t = 0.0
	else:
		_idle_t = 0.0
	if _idle_special > 0.0:
		_idle_special -= dt
		if mov or action != "": _idle_special = 0.0
		var k := sin(clampf((4.0 - _idle_special) / 4.0, 0.0, 1.0) * PI)
		_idle_pose(g.idle, k, time)
	elif props.has("Notebook"):
		props.Notebook.visible = false
	# ------------------------------------------------------------------ held tools
	if hold_lantern:
		var r := lantern_raise
		T.upperL.x = lerpf(T.upperL.x * 0.3 - 0.35, -1.25, r); T.upperL.z = lerpf(0.18, 0.05, r)
		T.foreL.x = lerpf(-0.75, -0.25, r)
		T.handL.x = lerpf(0.6, 1.0, r)
	if hold_watch:
		T.upperR.x = -0.55; T.upperR.z = -0.25; T.foreR.x = -1.75; T.foreR.y = 0.4; T.handR.x = 0.2
		T.head.x += 0.25
	# ------------------------------------------------------------------ actions
	if action != "":
		_action_t += dt
		var p := clampf(_action_t / action_dur, 0.0, 1.0) if action_dur > 0.0 else 1.0
		var k := sin(p * PI) if action_dur > 0.0 else 1.0
		var r := _action_pose(action, p, k, time)
		hips_y += r.get("hips", 0.0)
		body.y += r.get("y", 0.0)
		if r.has("x"): body.x = r.x
		if r.has("z"): body.z = r.z
		if action_dur > 0.0 and _action_t >= action_dur and not HOLD_ACTIONS.has(action): action = ""
	if airborne > 0.0:
		T.thighL.x -= 0.5 * airborne; T.thighR.x -= 0.2 * airborne; T.shinL.x += 0.8 * airborne; T.shinR.x += 0.6 * airborne
		T.upperL.z += 0.4 * airborne; T.upperR.z -= 0.4 * airborne
	T.body.z += clampf(-turn * 0.04, -0.12, 0.12) * clampf(spd, 0.0, 1.0)
	# ------------------------------------------------------------------ gaze
	var eye_tgt := Vector3(0, sin(time * 0.3 + _seed) * 0.12, 0)
	var eye_lam := 4.0
	if look_at_target != null and not action in ["faint", "lie", "sleep"] and _idx.has("head"):
		var hx := skel.global_transform * skel.get_bone_global_pose(_idx.head)
		var v: Vector3 = hx.affine_inverse() * (look_at_target as Vector3)
		var yaw := clampf(atan2(v.x, v.z), -1.0, 1.0)
		var pitch := clampf(-atan2(v.y - _eye_h, Vector2(v.x, v.z).length()), -0.5, 0.5)
		var hk := 0.35 if mov else 0.7
		T.neck.y += yaw * hk * 0.55; T.head.y += yaw * hk * 0.45; T.head.x += pitch * hk * 0.6
		eye_tgt = Vector3(clampf(pitch * 0.5, -0.3, 0.3), clampf(yaw * 0.6, -0.45, 0.45), 0)
		eye_lam = 20.0
	# ------------------------------------------------------------------ face
	_face(dt, time)
	# ------------------------------------------------------------------ apply
	var a := 1.0 - exp(-14.0 * dt)
	var ae := 1.0 - exp(-eye_lam * dt)
	for key in _idx.keys():
		var tv: Vector3 = T.get(key)
		if key == "eyeL" or key == "eyeR":
			var ce: Vector3 = _cur[key]
			_cur[key] = ce.lerp(eye_tgt, ae)
		elif key.begins_with("lid") or key.begins_with("brow"):
			_cur[key] = tv
		else:
			var cv: Vector3 = _cur[key]
			_cur[key] = cv.lerp(tv, a)
	_body_off = _body_off.lerp(body, 1.0 - exp(-10.0 * dt))
	var hy := lerpf(skel.get_bone_pose_position(_idx.hips).y, _hips_y + hips_y, 1.0 - exp(-16.0 * dt)) if _idx.has("hips") else 0.0
	_apply(hy)

func _apply(hips_y: float) -> void:
	var chain := {}
	var glob := {}
	for j in JOINTS:
		var key: String = j[0]
		if not _idx.has(key): continue
		var e: Vector3 = _cur[key]
		var eq := Quaternion(Vector3.RIGHT, e.x) * Quaternion(Vector3.UP, e.y) * Quaternion(Vector3.BACK, e.z)
		var par: String = _parent[key]
		var ec: Quaternion = eq
		if par != "":
			var pc: Quaternion = chain[par]
			ec = pc * eq
		chain[key] = ec
		var qk: Quaternion = _q[key]
		var rk: Quaternion = _rest[key]
		var gq: Quaternion = ec * qk.inverse() * rk
		glob[key] = gq
		var parent_g: Quaternion = glob[par] if par != "" else Quaternion.IDENTITY
		var bi: int = _idx[key]
		skel.set_bone_pose_rotation(bi, (parent_g.inverse() * gq).normalized())
	if _idx.has("body"): skel.set_bone_pose_position(_idx.body, _restpos.body + _body_off)
	if _idx.has("hips"): skel.set_bone_pose_position(_idx.hips, Vector3(_restpos.hips.x, hips_y, _restpos.hips.z))
	for side in ["L", "R"]:
		var bk: String = "brow" + side
		if _idx.has(bk):
			var lift: float = (_e.brow + (_e.asym if side == "L" else 0.0)) * _face_k
			skel.set_bone_pose_position(_idx[bk], _restpos[bk] + Vector3(0, lift, 0))
	if _idx.has("head"):
		skel.set_bone_pose_scale(_idx.head, Vector3.ONE * (1.7 if big_head else 1.0))

func _idle_pose(kind: String, k: float, time: float) -> void:
	match kind:
		"notes":
			if int(_seed * 10.0 + _t / 11.0) % 2 == 1:
				# never once late: a glance at the wristwatch worn over the sleeve
				T.upperL.x = -0.75 * k; T.upperL.z = 0.25 * k; T.foreL.x = -1.7 * k; T.foreL.y = -0.9 * k
				T.head.x = 0.35 * k; T.head.y = 0.2 * k; T.spine.y = 0.1 * k
				return
			if props.has("Notebook"): props.Notebook.visible = k > 0.15
			T.upperL.x = -0.6 * k; T.upperL.z = 0.1; T.foreL.x = -1.6 * k; T.foreL.y = 0.6 * k; T.handL.x = 0.4 * k
			T.upperR.x = -0.5 * k; T.foreR.x = -1.4 * k; T.foreR.y = -0.5 * k
			T.head.x = 0.4 * k; T.neck.x = 0.1 * k
			T.handR.z = sin(time * 9.0) * 0.15 * k
		"flourish":
			T.upperR.z = -1.2 * k; T.upperR.x = -0.4 * k; T.foreR.x = -0.6 * k; T.handR.z = sin(time * 6.0) * 0.4 * k
			T.footL.x = maxf(0.0, sin(time * 9.0)) * -0.4 * k; T.head.z = 0.12 * k
		"read":
			T.head.x = 0.35 * k; T.upperL.x = -0.7 * k; T.foreL.x = -1.3 * k; T.upperR.x = -0.7 * k; T.foreR.x = -1.3 * k
		"tap":
			T.footR.x = maxf(0.0, sin(time * 10.0)) * -0.45 * k; T.upperL.x = -0.3 * k; T.foreL.x = -1.2 * k; T.head.y = sin(time * 2.0) * 0.3 * k
		"cap":
			T.upperR.x = -2.2 * k; T.upperR.z = -0.4 * k; T.foreR.x = -1.2 * k; T.head.x = -0.1 * k
		"moustache":
			T.upperR.x = -1.4 * k; T.foreR.x = -1.9 * k; T.foreR.y = -0.5 * k; T.handR.z = sin(time * 8.0) * 0.3 * k; T.spine.x = -0.15
		"spin":
			T.body.y += TAU * k * k

func _action_pose(a: String, p: float, k: float, time: float) -> Dictionary:
	match a:
		"reach":
			T.upperR.x = -1.3 * k; T.upperR.z = -0.1; T.foreR.x = -0.35 * k; T.spine.x = 0.18 * k; T.head.x = 0.2 * k
		"inspect":
			T.spine.x = 0.3 * k; T.head.x = 0.3 * k; T.upperR.x = -0.9 * k; T.foreR.x = -2.0 * k; T.foreR.y = -0.4 * k; T.upperL.x = 0.3 * k
		"pickup":
			T.spine.x = 0.7 * k; T.head.x = 0.3 * k; T.thighL.x = -0.5 * k; T.shinL.x = 0.9 * k; T.thighR.x = -0.2 * k; T.shinR.x = 0.6 * k
			T.upperR.x = -0.9 * k; T.foreR.x = -0.3 * k
			return {"hips": -0.18 * k}
		"startle":
			T.upperL.z = 1.1 * k; T.upperR.z = -1.1 * k; T.foreL.x = -1.0 * k; T.foreR.x = -1.0 * k; T.spine.x = -0.25 * k; T.head.x = -0.2 * k
			return {"y": 0.12 * k}
		"hurt":
			T.spine.x = -0.35 * k; T.upperL.x = -0.8 * k; T.upperR.x = -0.8 * k; T.foreL.x = -1.6 * k; T.foreR.x = -1.6 * k; T.head.x = 0.3 * k
			return {"hips": -0.06 * k}
		"dodge":
			T.spine.x = 0.45 * k; T.thighL.x = -0.9 * k; T.shinL.x = 1.2 * k; T.thighR.x = 0.4 * k; T.shinR.x = 0.8 * k; T.upperL.x = 0.8 * k; T.upperR.x = 0.8 * k
			return {"hips": -0.22 * k}
		"faint":
			var f := clampf(p * 1.4, 0.0, 1.0)
			T.body.x = -1.45 * f; T.spine.x = 0.2 * f; T.head.x = 0.3 * f
			T.upperL.z = 0.9 * f; T.upperR.z = -0.9 * f; T.thighL.x = -0.3 * f; T.shinL.x = 0.5 * f; T.thighR.x = -0.1 * f
			return {"y": lerpf(0.0, 0.2, f), "z": lerpf(0.0, -0.85, f)}
		"lie", "sleep":
			T.body.x = -1.5; T.head.y = 0.4; T.upperL.z = 0.3; T.upperR.z = -0.3
			return {"y": 0.55, "z": -0.85}
		"sit":
			T.thighL.x = -1.45; T.thighR.x = -1.45; T.shinL.x = 1.45; T.shinR.x = 1.45; T.spine.x = -0.05
			T.upperL.x = -0.4; T.upperR.x = -0.4; T.foreL.x = -0.9; T.foreR.x = -0.9
			return {"hips": -0.45}
		"bow":
			T.spine.x = 0.65 * k; T.head.x = 0.2 * k; T.upperR.x = -0.9 * k; T.foreR.x = -1.5 * k; T.foreR.y = -0.9 * k; T.upperL.x = 0.4 * k
		"curtsy":
			T.thighL.x = 0.3 * k; T.shinL.x = 0.8 * k; T.spine.x = 0.25 * k; T.upperL.z = 0.6 * k; T.upperR.z = -0.6 * k
			return {"hips": -0.12 * k}
		"wave":
			T.upperR.z = -2.4 * k; T.foreR.z = sin(time * 10.0) * 0.4 * k
		"hold":
			T.upperL.x = -1.1; T.upperR.x = -1.1; T.upperL.z = 0.25; T.upperR.z = -0.25; T.foreL.x = -0.4; T.foreR.x = -0.4
			T.foreL.y = -1.2; T.foreR.y = 1.2; T.spine.x = 0.15
		"point":
			T.upperR.x = -1.45; T.upperR.z = -0.25; T.foreR.x = -0.1; T.head.x = -0.05
		"gesture":
			T.upperR.x = -0.7 + sin(time * 3.0) * 0.2; T.foreR.x = -1.2; T.foreR.y = -0.6 + sin(time * 2.3) * 0.3
			T.upperL.x = -0.3 + sin(time * 2.7 + 1.0) * 0.15; T.foreL.x = -0.9
		"conduct":
			T.upperR.x = -1.3 + sin(time * 4.4) * 0.5; T.upperR.z = -0.5 + cos(time * 4.4) * 0.3; T.foreR.x = -0.6
			T.upperL.x = -1.0; T.upperL.z = 0.6; T.foreL.x = -0.8; T.spine.x = -0.12; T.head.x = -0.15
		"play_violin":
			T.upperL.x = -1.2; T.upperL.z = 0.5; T.foreL.x = -1.2; T.foreL.y = 0.8; T.head.y = 0.35; T.head.z = 0.25
			T.upperR.x = -0.9 + sin(time * bpm / 30.0) * 0.25; T.upperR.z = -0.5; T.foreR.x = -1.0 + sin(time * bpm / 30.0) * 0.4
		"play_cello":
			T.thighL.x = -1.45; T.thighR.x = -1.45; T.shinL.x = 1.45; T.shinR.x = 1.45
			T.upperL.x = -0.9; T.upperL.z = 0.2; T.foreL.x = -0.9; T.upperR.x = -0.5; T.upperR.z = -0.35 + sin(time * bpm / 30.0) * 0.3; T.foreR.x = -0.9
			T.head.z = 0.15; T.spine.x = 0.1
			return {"hips": -0.45}
		"play_flute":
			T.upperL.x = -1.0; T.upperL.z = 0.3; T.foreL.x = -1.7; T.foreL.y = -0.6; T.upperR.x = -1.0; T.upperR.z = -0.6; T.foreR.x = -1.5; T.foreR.y = 0.6
			T.head.y = -0.15; T.spine.z = sin(time * bpm / 60.0 * PI) * 0.06
		"dance":
			var beat := fmod(time * bpm / 60.0, 3.0)
			var st := floori(beat)
			T.upperL.z = 1.2; T.upperL.x = -0.5; T.foreL.x = -0.9; T.foreL.z = 0.4
			T.upperR.x = -0.7; T.upperR.z = -0.5; T.foreR.x = -1.2; T.foreR.y = 0.8
			T.spine.x = -0.06; T.head.y = 0.35; T.head.x = -0.1
			var lift := sin(fmod(beat, 1.0) * PI)
			if st == 0: T.thighL.x = -0.35 * lift; T.shinL.x = 0.3 * lift
			elif st == 1: T.thighR.z = -0.2 * lift
			else: T.thighL.x = 0.2 * lift
			return {"hips": (-0.03 if st == 0 else 0.02) * lift, "x": [0.0, 0.05, 0.0][st]}
		"celebrate":
			T.upperL.z = 2.4 * k; T.upperR.z = -2.4 * k; T.foreL.z = 0.3; T.foreR.z = -0.3; T.head.x = -0.3 * k
			return {"y": absf(sin(p * TAU)) * 0.12}
		"hang":
			T.upperR.x = -2.4 * k; T.foreR.x = -0.3 * k; T.spine.x = -0.1 * k; T.head.x = -0.35 * k
		"yawn":
			T.upperL.z = 2.2 * k; T.upperR.z = -2.2 * k; T.foreL.x = -1.0 * k; T.foreR.x = -1.0 * k; T.spine.x = -0.25 * k; T.head.x = -0.3 * k
		"sweep":
			T.spine.y = sin(time * 6.0) * 0.6; T.upperL.z = 1.4; T.upperR.z = -1.4
			return {"y": 0.15}
		"cower":
			T.spine.x = 0.5 * k; T.upperL.x = -1.6 * k; T.upperR.x = -1.6 * k; T.foreL.x = -2.0 * k; T.foreR.x = -2.0 * k; T.head.x = 0.4 * k
			return {"hips": -0.15 * k}
		"dizzy":
			T.head.z = sin(time * 6.0) * 0.3; T.spine.z = sin(time * 6.0 + 1.0) * 0.15; T.upperL.z = 0.7; T.upperR.z = -0.7
		"sing":
			T.upperL.x = -0.6; T.upperL.z = 0.5 + sin(time * 1.2) * 0.1; T.foreL.x = -0.7; T.upperR.x = -0.8; T.upperR.z = -0.7; T.foreR.x = -0.3
			T.head.x = -0.2; T.spine.x = -0.08
	return {}

func _face(dt: float, _time: float) -> void:
	var target: Dictionary = EXPR.get(expression, EXPR.neutral)
	var a := 1.0 - exp(-10.0 * dt)
	_e.brow = lerpf(_e.brow, target.brow, a)
	_e.tilt = lerpf(_e.tilt, target.tilt, a)
	_e.lids = lerpf(_e.lids, target.lids, a)
	_e.asym = lerpf(_e.asym, target.get("asym", 0.0), a)
	_next_blink -= dt
	if _next_blink <= 0.0:
		_blink = 0.14
		_next_blink = 1.8 + randf() * 4.0 + (-1.5 if randf() < 0.15 else 0.0)
	var lid: float = _e.lids
	if _blink > 0.0:
		_blink -= dt
		lid = minf(lid, absf(_blink - 0.07) / 0.07 * lid)
	if action in ["faint", "lie", "sleep"]: lid = 0.0
	if action == "frozen": lid = target.lids
	var close := (1.0 - clampf(lid, 0.0, 1.25)) * 1.9
	T.lidL = Vector3(close, 0, 0); T.lidR = Vector3(close, 0, 0)
	T.browL = Vector3(0, 0, -_e.tilt); T.browR = Vector3(0, 0, _e.tilt)
	var shape: String = target.mouth
	if talk and Audio.talking:
		# lip sync: the mouth takes the shape of the vowel the voice is speaking right now
		match Audio.current_viseme:
			"a", "ae", "ai", "@": shape = "grin" if shape in ["smile", "grin"] else "open"
			"o", "ou", "u": shape = "o"
			"e", "i", "ei": shape = "grin"
			_: shape = target.mouth
	elif talk:
		_mouth_t -= dt
		if _mouth_t <= 0.0:
			_mouth_open = not _mouth_open
			_mouth_t = 0.06 + randf() * 0.09
		if _mouth_open: shape = "grin" if shape in ["smile", "grin"] else ("o" if randf() < 0.2 else "open")
	if action in ["sing", "yawn"]: shape = "o"
	if shape != _cur_mouth:
		for key in mouths.keys():
			mouths[key].visible = key == shape or (shape == "grin" and key == "grin_teeth")
		_cur_mouth = shape
