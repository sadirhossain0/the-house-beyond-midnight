extends Node
## Development harness: builds the estate and saves screenshots from named camera poses.
## godot --path . res://src/dev/shots.tscn -- --shots=hall_entry,hall_clock --preset=high --out=/tmp/shots

const POSES := {
	"hall_entry": [Vector3(0, 1.7, 1.2), Vector3(0, 3.5, 14.0)],
	"hall_clock": [Vector3(0.5, 4.2, 12.0), Vector3(0, 5.2, 19.0)],
	"hall_side": [Vector3(-7.5, 1.7, 2.0), Vector3(4.0, 3.0, 12.0)],
	"hall_gallery": [Vector3(-8.0, 6.7, 1.0), Vector3(2.0, 3.0, 12.0)],
	"hall_desk": [Vector3(-3.0, 1.6, 8.5), Vector3(-5.0, 1.2, 13.0)],
	"ext_drive": [Vector3(0.0, 1.2, -24.0), Vector3(0.0, 4.0, 0.0)],
	"ext_car": [Vector3(5.5, 0.9, -13.0), Vector3(1.0, 0.4, -19.0)],
	"ext_porch": [Vector3(0.0, 1.0, -9.0), Vector3(0.0, 2.5, 0.0)],
	"corridor": [Vector3(-11.0, 1.6, 4.0), Vector3(-30.0, 1.4, 4.0)],
	"guestroom": [Vector3(-17.8, 1.6, 1.5), Vector3(-22.0, 0.8, -3.0)],
	"cloakroom": [Vector3(-25.0, 1.6, 7.0), Vector3(-30.0, 1.4, 13.0)],
	"ballroom_now": [Vector3(12.0, 2.0, 4.0), Vector3(30.0, 2.0, 6.0)],
	"ballroom_then": [Vector3(12.0, 2.0, 4.0), Vector3(30.0, 2.0, 6.0)],
	"ballroom_stage": [Vector3(30.0, 2.2, 4.0), Vector3(38.0, 1.4, 6.0)],
}

func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if args.has("preset"): Settings.apply_preset(args.preset)
	var out: String = args.get("out", "/tmp/shots")
	DirAccess.make_dir_recursive_absolute(out)
	var world := World.new()
	add_child(world)
	var cam := Camera3D.new(); cam.fov = 62; cam.far = 400; cam.near = 0.05
	world.add_child(cam); cam.make_current()
	var t0 := Time.get_ticks_msec()
	await world.build_all(func(p, label): print("build %.0f%% %s" % [p * 100, label]))
	print("built in %d ms" % (Time.get_ticks_msec() - t0))
	for name in String(args.get("shots", "hall_entry")).split(","):
		var pose: Array = POSES[name]
		cam.global_position = pose[0]
		cam.look_at(pose[1])
		var room := world.current
		for r in world.rooms.values():
			if r.contains(pose[0]): room = r.id
		world.set_current(room, true)
		if name.ends_with("_then"): world.set_room_state(room, "then")
		world.update_focus(pose[0])
		for i in int(args.get("frames", "24")): await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/%s.png" % [out, name])
		print("shot ", name, " ", world.gfx.stats())
	get_tree().quit()
