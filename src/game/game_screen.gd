class_name GameScreen
extends Node
## One play session: builds the estate behind the loading screen, warms every shader, spawns the
## player, runs the story, and owns pausing, menus, saving, documents, chapter cards and fades.

var main: Node
var world: World
var player: Player
var hud: HUD
var dialogue: Dialogue
var story: Story
var menu: GameMenu
var ui: CanvasLayer
var top: CanvasLayer
var fader: ColorRect
var bars: Array[ColorRect] = []
var loading: LoadingScreen
var doc_layer: Control
var _hint_tier := 0
var _hint_time := 0.0
var _autosave_t := 0.0
var ready_to_play := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.world = null
	ui = CanvasLayer.new(); ui.layer = 5; add_child(ui)
	top = CanvasLayer.new(); top.layer = 20; add_child(top)
	fader = ColorRect.new(); fader.color = Color(0, 0, 0, 1); fader.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); fader.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(fader)
	for i in 2:
		var b := ColorRect.new(); b.color = Color.BLACK; b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.anchor_right = 1.0; b.anchor_top = 0.0 if i == 0 else 1.0; b.anchor_bottom = 0.0 if i == 0 else 1.0
		b.offset_bottom = 0.0; b.offset_top = 0.0
		top.add_child(b); bars.append(b)
	loading = LoadingScreen.new()
	top.add_child(loading)

func start() -> void:
	Game.in_game = false
	await loading.begin()
	var t0 := Time.get_ticks_msec()
	world = World.new()
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	Game.world = world
	await world.build_all(func(p, label): loading.set_progress(p * 0.7, "world", label))
	loading.set_progress(0.72, "characters", "")
	await get_tree().process_frame
	player = Player.new(); player.name = "Player"; player.world = world
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	world.add_child(player)
	world.player = player
	world.post.player = player
	hud = HUD.new(); hud.player = player; hud.world = world; ui.add_child(hud)
	dialogue = Dialogue.new(); dialogue.hud = hud; dialogue.player = player; dialogue.process_mode = Node.PROCESS_MODE_PAUSABLE; add_child(dialogue)
	story = Story.new(); story.name = "Story"; story.process_mode = Node.PROCESS_MODE_PAUSABLE; add_child(story)
	story.setup(self)
	var touch := TouchControls.new(); touch.player = player; ui.add_child(touch)
	menu = GameMenu.new(); menu.screen = self; menu.visible = false; ui.add_child(menu)
	doc_layer = Control.new(); doc_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); doc_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE; ui.add_child(doc_layer)
	# place the player where the save says
	var p: Dictionary = Save.profile
	var pos := Vector3(p.pos[0], p.pos[1], p.pos[2]) if p.pos is Array and p.pos.size() == 3 else Vector3(1.2, -0.55, -16.5)
	if not Game.flag("intro_done"): pos = Vector3(1.4, -0.55, -16.6)
	var room: String = p.get("room", "exterior")
	world.set_current(room if world.rooms.has(room) else "exterior", true)
	player.teleport(pos + Vector3(0, 0.1, 0), float(p.get("yaw", 0.0)))
	player.set_checkpoint(Transform3D(Basis(Vector3.UP, float(p.get("yaw", 0.0))), pos), room)
	if Game.flag("has_lantern"): player.give_lantern()
	if Game.flag("has_watch") and not Game.flag("has_lantern"): player.set_tool("watch")
	# warm every room's shaders and lights while the loading screen is still up
	loading.set_progress(0.8, "shaders", "")
	await _warm_up()
	loading.set_progress(1.0, "lighting", "")
	print("game ready in %d ms" % (Time.get_ticks_msec() - t0))
	world.set_current(room if world.rooms.has(room) else "exterior", true)
	world.update_focus(player.global_position)
	var music: String = world.rooms[world.current].music
	if Game.flag("intro_done") and music != "": Audio.play_music(music, 3.0)
	await loading.finish()
	ready_to_play = true
	Game.in_game = true
	capture_mouse()
	if not Game.flag("intro_done"):
		await story.intro()
	else:
		fade_in(1.2)
		Events.toast.emit(Game.objective_text(), "objective")

func _warm_up() -> void:
	var cam := player.rig.cam
	var keep := cam.global_transform
	var ids: Array = world.rooms.keys()
	for i in ids.size():
		var r: Room = world.rooms[ids[i]]
		world.set_current(r.id, true)
		for st in (["now", "then"] if r.state_then != null and r.state_then.get_child_count() > 0 else ["now"]):
			r.set_state(st)
			var c := r.bounds.get_center()
			for k in 2:
				var yaw := k * PI
				player.rig.cinematic(Vector3(c.x, minf(c.y, 2.0), c.z) + Vector3(sin(yaw), 0, cos(yaw)) * 0.5, Vector3(c.x, 1.5, c.z) + Vector3(sin(yaw), 0, cos(yaw)) * 4.0, 70.0)
				player.rig._blend = 1.0
				await get_tree().process_frame
				await get_tree().process_frame
		r.set_state(Save.profile.room_states.get(r.id, "now"))
		loading.set_progress(0.8 + 0.18 * float(i + 1) / ids.size(), "shaders", "")
	player.rig.release()
	player.rig._blend = 0.0
	cam.global_transform = keep

# ------------------------------------------------------------------------------- input & pause
func _unhandled_input(e: InputEvent) -> void:
	if not ready_to_play: return
	if doc_layer.get_child_count() > 0:
		if e.is_action_pressed("interact") or e.is_action_pressed("pause") or e.is_action_pressed("skip") or (e is InputEventMouseButton and e.pressed):
			close_document()
			get_viewport().set_input_as_handled()
		return
	if menu.visible: return
	if e.is_action_pressed("pause"): open_menu("pause"); get_viewport().set_input_as_handled()
	elif e.is_action_pressed("journal") and not dialogue.active: open_menu("journal"); get_viewport().set_input_as_handled()
	elif e.is_action_pressed("map") and not dialogue.active: open_menu("map"); get_viewport().set_input_as_handled()
	elif e.is_action_pressed("hint") and not dialogue.active: _hint()
	elif e is InputEventMouseButton and e.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not dialogue.active: capture_mouse()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and ready_to_play and not get_tree().paused and Settings.data.get("meta", {}).get("pause_on_focus_loss", true):
		open_menu("pause")

func capture_mouse() -> void:
	if Settings.data.controls.touch_controls == "on" or OS.has_feature("mobile"): return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _hint() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _hint_time > 20.0: _hint_tier = 0
	else: _hint_tier = mini(_hint_tier + 1, 2)
	_hint_time = now
	Events.toast.emit(Game.hint(_hint_tier) + ("\n(Press %s again for a stronger hint.)" % Controls.label("hint") if _hint_tier < 2 else ""), "hint")

func open_menu(page := "pause") -> void:
	if menu.visible: menu.show_page(page); return
	get_tree().paused = true
	Events.pause_changed.emit(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Audio.set_music_muffle(true)
	menu.open(page)

func close_menus() -> void:
	if menu.visible: menu.close()

func on_menu_closed() -> void:
	get_tree().paused = false
	Events.pause_changed.emit(false)
	Audio.set_music_muffle(false)
	capture_mouse()

func _process(dt: float) -> void:
	if not ready_to_play: return
	_autosave_t += dt
	if _autosave_t > 120.0 and player.state == "free" and not dialogue.active:
		_autosave_t = 0.0
		autosave("timer")

# ------------------------------------------------------------------------------- saving
func snapshot() -> void:
	if player == null: return
	var p := player.global_position
	Save.profile.pos = [p.x, p.y, p.z]
	Save.profile.yaw = player.facing
	Save.profile.room = world.current
	Save.profile.cheat_active = Settings.experimental_cheats_on()
	if story and story.ch2 and story.ch2.encounter_active:
		# never save mid-encounter positions: resume at the ballroom doors
		Save.profile.pos = [11.4, 0.05, 4.0]; Save.profile.room = "ballroom"

func autosave(reason := "auto") -> void:
	if Settings.data.get("meta", {}).get("autosave", true) == false: return
	snapshot()
	Save.write(reason)

func save_at_register() -> void:
	snapshot()
	var ok := Save.write("register")
	Audio.sfx("quill", player.global_position)
	if ok:
		Events.toast.emit("Your name is in the register. Progress saved.\nMidnight Code: %s" % Save.midnight_code(Save.profile, GameData.CODE_REGISTRY), "info")

# ------------------------------------------------------------------------------- presentation
func show_document(id: String) -> void:
	var d: Dictionary = GameData.DOCUMENTS.get(id, {})
	if d.is_empty(): return
	get_tree().paused = true
	Audio.sfx("paper", null)
	var dim := ColorRect.new(); dim.color = Color(0, 0, 0, 0.6); dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	doc_layer.add_child(dim)
	var paper := PanelContainer.new()
	var st := UIKit.style(Color(0.9, 0.85, 0.74), Color(0.55, 0.45, 0.3), 2, 2, 48, 40)
	st.shadow_size = 22; st.shadow_color = Color(0, 0, 0, 0.6)
	paper.add_theme_stylebox_override("panel", st)
	var v := VBoxContainer.new(); v.custom_minimum_size = Vector2(640, 0)
	var t := UIKit.label(d.title, 30, Color(0.2, 0.13, 0.08), "head"); t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var r := UIKit.label(d.text, 22, Color(0.16, 0.12, 0.09), "italic")
	v.add_child(r)
	var close := UIKit.label("%s  close" % Controls.label("interact"), 16, Color(0.4, 0.32, 0.24), "caps"); close.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(close)
	paper.add_child(v)
	var cc := CenterContainer.new(); cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); cc.add_child(paper)
	doc_layer.add_child(cc)
	paper.rotation = deg_to_rad(-1.2)
	paper.pivot_offset = Vector2(320, 300)
	paper.modulate.a = 0.0
	var tw := paper.create_tween(); tw.tween_property(paper, "modulate:a", 1.0, 0.35)

func close_document() -> void:
	for c in doc_layer.get_children(): c.queue_free()
	get_tree().paused = false

func fade_out(d := 0.8) -> void:
	var tw := create_tween(); tw.tween_property(fader, "color:a", 1.0, d)
	await tw.finished

func fade_in(d := 0.8) -> void:
	var tw := create_tween(); tw.tween_property(fader, "color:a", 0.0, d)
	await tw.finished

func letterbox(on: bool) -> void:
	var h := get_viewport().get_visible_rect().size.y * 0.1 if on else 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(bars[0], "offset_bottom", h, 0.8).set_trans(Tween.TRANS_SINE)
	tw.tween_property(bars[1], "offset_top", -h, 0.8).set_trans(Tween.TRANS_SINE)
	hud.visible = not on

func chapter_card(kicker: String, title: String) -> void:
	var c := VBoxContainer.new(); c.alignment = BoxContainer.ALIGNMENT_CENTER
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var k := UIKit.label(kicker.to_upper(), 24, UIKit.GOLD_DIM, "caps"); k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var t := UIKit.label(title, 64, UIKit.PAPER, "deco_r"); t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8)); t.add_theme_constant_override("shadow_offset_y", 3)
	c.add_child(k); c.add_child(UIKit.rule()); c.add_child(t)
	c.modulate.a = 0.0
	top.add_child(c)
	Audio.sfx("chapter_card", null)
	var tw := create_tween()
	tw.tween_property(c, "modulate:a", 1.0, 1.4)
	tw.tween_interval(2.6)
	tw.tween_property(c, "modulate:a", 0.0, 1.4)
	tw.tween_callback(c.queue_free)
	await tw.finished

func end_card() -> void:
	await fade_out(2.0)
	Audio.play_music("credits", 2.0)
	var v := VBoxContainer.new(); v.alignment = BoxContainer.ALIGNMENT_CENTER; v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var lines := [["THE HOUSE BEYOND MIDNIGHT", 30, UIKit.GOLD_DIM, "caps"], ["Two chimes struck.", 58, UIKit.PAPER, "deco_r"],
		["Ten remain. The Endless Library, the kitchens, the frozen observatory, and whoever waits at the top of the stairs.", 24, UIKit.TEXT, "italic"],
		["", 20, UIKit.TEXT, "body"],
		["Time in the house: %s     Candles lost: %d     Hints: %d     Collectibles: %d / %d" % [UIKit.fmt_time(Save.profile.play_time), Save.profile.stats.candles_lost, Save.profile.stats.hints_used, Save.profile.collectibles.size(), GameData.COLLECTIBLES.size()], 19, UIKit.MUTED, "body"],
		["The house is yours to explore. Press %s to continue." % Controls.label("interact"), 18, UIKit.GOLD_DIM, "caps"]]
	for l in lines:
		var lb := UIKit.label(l[0], l[1], l[2], l[3]); lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lb.custom_minimum_size.x = 1100
		var cc := CenterContainer.new(); cc.add_child(lb); v.add_child(cc)
	v.modulate.a = 0.0
	top.add_child(v)
	var tw := create_tween(); tw.tween_property(v, "modulate:a", 1.0, 2.0)
	await tw.finished
	await get_tree().create_timer(3.0).timeout
	var waited := 0.0
	while waited < 30.0 and not (Input.is_action_pressed("interact") or Input.is_action_pressed("pause") or Input.is_action_pressed("ui_accept") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
		await get_tree().process_frame
		waited += get_process_delta_time()
	var tw2 := create_tween(); tw2.tween_property(v, "modulate:a", 0.0, 1.2)
	await tw2.finished
	v.queue_free()
	Audio.play_music(world.rooms[world.current].music, 2.0)
	autosave("slice_end")
	await fade_in(1.5)

func quit_to_title() -> void:
	snapshot()
	Save.write("quit")
	get_tree().paused = false
	Game.in_game = false
	Game.world = null
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	main.show_title()
