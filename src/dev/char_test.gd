extends Node3D
## Dev stage: lines up cast members in assorted poses and saves a screenshot.
## godot --path . res://src/dev/char_test.tscn -- --out=/tmp/ct.png --set=a
func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.05, 0.05, 0.07)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(0.5, 0.5, 0.6); env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	var we := WorldEnvironment.new(); we.environment = env; add_child(we)
	var sun := DirectionalLight3D.new(); sun.light_energy = 2.2; sun.shadow_enabled = true; add_child(sun)
	sun.look_at_from_position(Vector3(3, 6, 6), Vector3.ZERO)
	var fill := OmniLight3D.new(); fill.position = Vector3(-3, 2, 3); fill.omni_range = 10; fill.light_energy = 1.2; fill.light_color = Color(0.7, 0.8, 1.0); add_child(fill)
	var floor_ := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(30, 30); floor_.mesh = pm
	var fm := StandardMaterial3D.new(); fm.albedo_color = Color(0.25, 0.22, 0.2); floor_.material_override = fm; add_child(floor_)
	var set_: String = args.get("set", "a")
	var lineup := {
		"a": [["avery", "fieldcoat", "solid", "lantern"], ["mara", "performer", "", "wave"], ["host", "", "solid", "moustache"], ["porter", "", "solid", "hold"], ["pip", "", "solid", "idle"]],
		"b": [["avery", "raincoat", "", "run"], ["mara", "gown", "", "sing"], ["host", "", "", "idle"], ["dancer_lady", "", "", "dance"], ["dancer_gent", "", "", "dance"]],
		"c": [["avery", "fieldcoat", "", "faint"], ["king", "", "", "walk"], ["musician", "", "", "play_violin"], ["mara", "gown", "", "sing"], ["avery", "nightcap", "", "watch"]],
	}
	var x := -3.2
	var chars: Array = []
	for spec in lineup[set_]:
		var c := Character.create(spec[0], spec[1], spec[2])
		add_child(c)
		c.position = Vector3(x, 0, 0)
		x += 1.45
		match spec[3]:
			"walk": c.moving = true; c.speed = 0.8
			"run": c.moving = true; c.speed = 1.5
			"lantern": c.hold_lantern = true; c.lantern_raise = 1.0; c.expression = "determined"
			"watch": c.hold_watch = true; c.expression = "curious"
			"moustache": c._idle_special = 2.0; c.expression = "smug"
			"idle": c.expression = "happy"
			_: c.play(spec[3], 0.0 if spec[3] in Character.HOLD_ACTIONS else 2.0)
		chars.append(c)
	var cam := Camera3D.new(); cam.fov = 40; add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.0, 6.2), Vector3(0, 0.62, 0))
	cam.make_current()
	for i in int(args.get("frames", "40")):
		await get_tree().process_frame
		if i == 30 and set_ == "c": chars[0].action_dur = 2.0
	var img := get_viewport().get_texture().get_image()
	img.save_png(args.get("out", "/tmp/ct.png"))
	get_tree().quit()
