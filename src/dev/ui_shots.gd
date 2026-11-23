extends Node
## Screenshots of the 2D screens: title, loading, and menu pages.
func _ready() -> void:
	var out := "/tmp/ui"
	for a in OS.get_cmdline_user_args(): if a.begins_with("--out="): out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	if Save.read_slot(2) == null: Save.start(2, "Avery")
	var layer := CanvasLayer.new(); add_child(layer)
	var t := TitleScreen.new(); t.main = self; layer.add_child(t)
	await _frames(90); _shot(out, "title")
	t.queue_free()
	var l := LoadingScreen.new(); layer.add_child(l)
	l.begin(); l.set_progress(0.55, "world", "Hanging the chandeliers")
	await _frames(60); _shot(out, "loading")
	l.queue_free()
	var m := GameMenu.new(); m.title_mode = true; layer.add_child(m)
	for p in ["settings_Graphics", "settings_Assistance", "saves", "extras", "help"]:
		m.open(p); await _frames(20); _shot(out, p)
	get_tree().quit()
func _frames(n: int) -> void:
	for i in n: await get_tree().process_frame
func _shot(out: String, name: String) -> void:
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
func show_title() -> void: pass
func start_game(_s: int, _n := "") -> void: pass
